module mental_poker::mental_poker;

use sui::coin;
use sui::coin::{Coin};
use sui::sui::SUI;
use sui::event::emit;
use sui::dynamic_object_field::{Self as dof};
use sui::balance::{Self, Balance};
use sui::package::{Self};


// === Errors ===
const EStakeTooLow: u64 = 0;
const EStakeTooHigh: u64 = 1;
// const EInvalidBlsSig: u64 = 2;
// const EInsufficientHouseBalance: u64 = 5;
const EGameDoesNotExist: u64 = 6;
const EPlayerMisMatch: u64 = 7;
const EExceedClaim: u64 = 8;

// // For Move coding conventions, see
// // https://docs.sui.io/concepts/sui-move-concepts/conventions


public struct AdminCap has key{
    id:UID,
}

public struct GameDataCap has key {
    id: UID
}

// === Errors ===
const ECallerNotHouse: u64 = 0;
// const EInsufficientBalance: u64 = 1;
// === Structs ===

/// Configuration and Treasury shared object, managed by the house.
public struct GameData has key {
    id: UID,
    // House's balance which also contains the accrued winnings of the house.
    balance: Balance<SUI>,
    // Address of the house or the game operator.
    house: address,
    // // Public key used to verify the beacon produced by the back-end.
    // public_key: vector<u8>,
    // Maximum stake amount a player can bet in a single game.
    max_stake: u64,
    // Minimum stake amount required to play the game.
    min_stake: u64,
    // The accrued fees from games played.
    fees: Balance<SUI>,
    // The default fee in basis points. 1 basis point = 0.01%.
    base_fee_in_bp: u16,
    current_game_id:ID,
}


public struct MENTAL_POKER has drop{}


fun init(mental_poker:MENTAL_POKER,ctx: &mut TxContext){
    package::claim_and_keep(mental_poker,ctx);

    // // Creating and sending the HouseCap object to the sender.
    // let game_data_cap = GameDataCap {
    //     id: object::new(ctx)
    // };
    initialize_game_data(ctx);
    // object::delete(game_data_cap.id);
    // transfer::transfer(game_data_cap, ctx.sender());
}

public struct UserGameResult {
    player: address,
    chip_amount: u64,
}



// === Events ===
public struct NewGame has copy, drop {
    game_id: ID,
    user_stake: u64,
    fee_bp: u16,
    players: vector<address>
}

public struct UserRes has copy, drop {
    player: address,
    amount: u64,
}

/// Emitted when a game has finished.
public struct Outcome has copy, drop {
    game_id: ID,
    result: vector<UserRes>,
}

// === Public Functions ===
public fun start_game(bet_coins: Coin<SUI>, game_data: &mut GameData, ctx: &mut TxContext): ID {
    let fee_bp = game_data.base_fee_in_bp();
    let (id, _new_game,isNew) = internal_start_game(bet_coins, game_data, fee_bp, ctx);
    //todo 编译器为什么要在面认为可以？
    if (isNew){
        let new_game = new_poker_game(ctx);
        game_data.current_game_id = new_game.id();
        dof::add(game_data.borrow_mut(),new_game.id(),new_game);
    };
    id
}

public fun finish_game(game_id: ID,  game_data: &mut GameData,user_results:&vector<UserGameResult>,  ctx: &mut TxContext): (u64) {
    // Ensure that the game exists.
    assert!(game_exists(game_data, game_id), EGameDoesNotExist);

    let exist_game:&PokerGame = dof::borrow(game_data.borrow(),game_id);
    assert!(exist_game.get_players().length()==user_results.length(),EPlayerMisMatch);

    let mut counter: u64 = 0;
    let mut total_claim:u64=0;
    while (counter < user_results.length()) {
        total_claim = total_claim+user_results[counter].chip_amount;
        counter = counter + 1;
    };
    assert!(total_claim<=exist_game.get_stake(),EExceedClaim);

    // Retrieves and removes the game from HouseData, preparing for outcome calculation.
    let PokerGame {
        id,
        game_start_epoch: _,
        stake:_,
        fee_bp: _,
        players:_,
    } = dof::remove<ID, PokerGame>(game_data.borrow_mut(), game_id);
    object::delete(id);


   let mut outcome =  Outcome {
        game_id,
       result:vector[]
    };

    let mut player_counter: u64 = 0;
    while (player_counter < user_results.length()) {
        if (user_results[player_counter].chip_amount>0){
            let payout_balance_mut = game_data.borrow_balance_mut();
            let payout_coin: Coin<SUI> = coin::take(payout_balance_mut, user_results[player_counter].chip_amount, ctx);
            transfer::public_transfer(payout_coin, user_results[player_counter].player);
        };
        let current_num = outcome.result.length();
        outcome.result.insert(UserRes{
            player:user_results[player_counter].player,
            amount:user_results[player_counter].chip_amount,
        },current_num);
        player_counter = player_counter + 1;
    };
    // Emit the Outcome event
    emit(outcome);
    // return the total amount to be sent to the player, (and the player address)
    (total_claim)
}

// === Public-View Functions ===



// === Admin Functions ===

public fun game_exists(game_data: &GameData, game_id: ID): bool {
    dof::exists_(game_data.borrow(), game_id)
}

public fun borrow_game(game_id: ID, game_data: &GameData): &PokerGame {
    assert!(game_exists(game_data, game_id), EGameDoesNotExist);
    dof::borrow(game_data.borrow(), game_id)
}

public fun borrow_game_mut(game_id: ID, game_data: &mut GameData): &mut PokerGame {
    assert!(game_exists(game_data, game_id), EGameDoesNotExist);
    dof::borrow_mut(game_data.borrow_mut(), game_id)
}

// === Private Functions ===
fun internal_start_game(coin: Coin<SUI>, game_data: &mut GameData, fee_bp: u16, ctx: &mut TxContext): (ID, &mut PokerGame,bool) {
    let user_stake = coin.value();
    assert!(user_stake <= game_data.max_stake(), EStakeTooHigh);
    assert!(user_stake >= game_data.min_stake(), EStakeTooLow);

    let coin_amount = coin.value();
    let bet_balance = coin.into_balance();
    game_data.add_balalce(bet_balance);

    let current_game = borrow_game_mut(game_data.current_game_id,game_data);
    let player_num = current_game.join_user(ctx.sender(),coin_amount);
    if (player_num>=2){
        // Emit a NewGame event
        let game_id = current_game.id();
        emit(NewGame {
            game_id:game_id,
            user_stake: current_game.get_stake(),
            fee_bp,
            players: current_game.get_players(),
        });
        // 为什么不能转回来
        // delete(curr_game.id());
        return (current_game.id(),current_game,true)
    };

    (current_game.id(),current_game,false)
}

public fun initialize_game_data( ctx: &mut TxContext) {
    let new_game = new_poker_game(ctx);
    let mut  game_data =   GameData {
        id: object::new(ctx),
        balance: sui::balance::zero(),
        house: ctx.sender(),
        // public_key: ctx.sender(),
        max_stake: 10_000_000_000, // 10 SUI = 10^9.
        min_stake: 100_000_000, // 0.1 SUI.
        fees: balance::zero(),
        base_fee_in_bp: 100, // 1% in basis points.
        current_game_id: new_game.id(),
    };
    let borrow_game_data = &mut game_data;
    dof::add(borrow_game_data.borrow_mut(),new_game.id(),new_game);
    transfer::share_object(game_data);
}

// === Public-Mutative Functions ===

/// Function used to top up the house balance. Can be called by anyone.
/// House can have multiple accounts so giving the treasury balance is not limited.
public fun top_up(game_data: &mut GameData, coin: Coin<SUI>, _: &mut TxContext) {
    coin::put(&mut game_data.balance, coin)
}

/// A function to withdraw the entire balance of the house object.
/// It can be called only by the house
public fun withdraw(game_data: &mut GameData, ctx: &mut TxContext) {
    // Only the house address can withdraw funds.
    assert!(ctx.sender() == game_data.house(), ECallerNotHouse);

    let total_balance = game_data.balance();
    let coin = coin::take(&mut game_data.balance, total_balance, ctx);
    transfer::public_transfer(coin, game_data.house());
}

/// House can withdraw the accumulated fees of the house object.
public fun claim_fees(game_data: &mut GameData, ctx: &mut TxContext) {
    // Only the house address can withdraw fee funds.
    assert!(ctx.sender() == game_data.house(), ECallerNotHouse);

    let total_fees = game_data.fees();
    let coin = coin::take(&mut game_data.fees, total_fees, ctx);
    transfer::public_transfer(coin, game_data.house());
}

/// House can update the max stake. This allows larger stake to be placed.
public fun update_max_stake(game_data: &mut GameData, max_stake: u64, ctx: &mut TxContext) {
    // Only the house address can update the base fee.
    assert!(ctx.sender() == game_data.house(), ECallerNotHouse);

    game_data.max_stake = max_stake;
}

/// House can update the min stake. This allows smaller stake to be placed.
public fun update_min_stake(game_data: &mut GameData, min_stake: u64, ctx: &mut TxContext) {
    // Only the house address can update the min stake.
    assert!(ctx.sender() == game_data.house(), ECallerNotHouse);

    game_data.min_stake = min_stake;
}

// === Public-View Functions ===

/// Returns the balance of the house.
public fun balance(game_data: &GameData): u64 {
    game_data.balance.value()
}

/// Returns the address of the house.
public fun house(game_data: &GameData): address {
    game_data.house
}

// /// Returns the public key of the house.
// public fun public_key(game_data: &GameData): vector<u8> {
//     game_data.public_key
// }

/// Returns the max stake of the house.
public fun max_stake(game_data: &GameData): u64 {
    game_data.max_stake
}

/// Returns the min stake of the house.
public fun min_stake(game_data: &GameData): u64 {
    game_data.min_stake
}

/// Returns the fees of the house.
public fun fees(game_data: &GameData): u64 {
    game_data.fees.value()
}

/// Returns the base fee.
public fun base_fee_in_bp(game_data: &GameData): u16 {
    game_data.base_fee_in_bp
}

public fun add_bets(game_data: &mut GameData,bet:Coin<SUI>){
    game_data.balance.join(bet.into_balance());
}

public fun add_balalce(game_data: &mut GameData,balance:Balance<SUI>){
    game_data.balance.join(balance);
}


// === Public-Friend Functions ===

/// Returns a reference to the house id.
public(package) fun borrow(game_data: &GameData): &UID {
    &game_data.id
}

/// Returns a mutable reference to the balance of the house.
public(package) fun borrow_balance_mut(game_data: &mut GameData): &mut Balance<SUI> {
    &mut game_data.balance
}

/// Returns a mutable reference to the fees of the house.
public(package) fun borrow_fees_mut(game_data: &mut GameData): &mut Balance<SUI> {
    &mut game_data.fees
}

/// Returns a mutable reference to the house id.
public(package) fun borrow_mut(game_data: &mut GameData): &mut UID {
    &mut game_data.id
}

// === Test Functions ===
//
// #[test_only]
// public fun start_game_test(ctx: &mut TxContext):bool {
//     let origin = coin::mint_for_testing<SUI>(0,ctx);
//     let balance = coin::mint_for_testing<SUI>(0,ctx);
//     let pk = object::new(ctx);
//     let game_data = &mut GameData{
//         id:  object::new(ctx),
//         // House's balance which also contains the accrued winnings of the house.
//         balance: origin.into_balance<SUI>(),
//         // Address of the house or the game operator.
//         house: @0x12341234,
//         // Public key used to verify the beacon produced by the back-end.
//         public_key: object::uid_to_bytes(&pk),
//         // Maximum stake amount a player can bet in a single game.
//         max_stake: 1_000_000_000,
//         // Minimum stake amount required to play the game.
//         min_stake: 100_000_000,
//         // The accrued fees from games played.
//         fees: balance.into_balance<SUI>(),
//         // The default fee in basis points. 1 basis point = 0.01%.
//         base_fee_in_bp: 100,
//     };
//     //TODO 这里没有drop不能返回，但是在game_data测试start_game会循环引用，有问题，需要反馈
//     // // 这个规则是有冲突的new_game_data_testing 又需要drop,drop又需要uiddrop
//     // let game_data = &mut new_game_data_for_testing(ctx);
//     let user_bet = coin::mint_for_testing<SUI>(100_000_000,ctx);
//     start_game(user_bet,game_data,ctx);
//     let user_bet2 = coin::mint_for_testing<SUI>(100_000_000,ctx);
//     start_game(user_bet2,game_data,ctx);
//     let user_bet3 = coin::mint_for_testing<SUI>(100_000_000,ctx);
//     start_game(user_bet3,game_data,ctx);
//     // object::delete(game_data.id)
//     let success = true;
//     success
// }


// === Structs ===
public struct PokerGame has  key,store {
    id: UID,
    game_start_epoch: u64,
    stake: u64, // sui amount
    fee_bp: u16,
    players: vector<address>
}

public fun new_poker_game(ctx :&mut TxContext): PokerGame {
    PokerGame{
        id:object::new(ctx),
        game_start_epoch:ctx.epoch(),
        stake: 0,
        fee_bp:100,
        players:vector[],
    }
}

public fun join_user(game: &mut PokerGame,join_user:address,coin_amount: u64) :u64{
    let current_num = game.players.length();
    game.players.insert(join_user,current_num);
    game.stake = game.stake + coin_amount;
    game.players.length()
}

// === Public-View Functions ===

/// Returns the epoch in which the game started.
public fun game_start_epoch(game: &PokerGame): u64 {
    game.game_start_epoch
}

/// Returns the total stake.
public fun stake(game: &PokerGame): u64 {
    game.stake
}

/// Returns the fee of the game.
public fun fee_in_bp(game: &PokerGame): u16 {
    game.fee_bp
}

/// Returns the fee of the game.
public fun get_players(game: &PokerGame): vector<address> {
    game.players
}


public fun id(game: &PokerGame):ID {
    object::uid_to_inner(&game.id)
}

public fun get_stake(game: &PokerGame):u64{
    game.stake
}

