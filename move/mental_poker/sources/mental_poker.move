module mental_poker::mental_poker;

use std::option::none;
use sui::coin;
use sui::coin::create_currency;
use sui::transfer::{public_freeze_object,};
use sui::url::Url;
use sui::transfer::{ public_transfer,share_object,transfer};
use tp_coin::tp_coin::TP_COIN;

use std::ascii::String;
use std::string::append;
use mental_poker::poker_game::{new_poker_game, PokerGame};
use mental_poker::poker_game;
use sui::coin::{Coin};
use sui::sui::SUI;
use sui::bls12381::bls12381_min_pk_verify;
use sui::event::emit;
use sui::dynamic_object_field::{Self as dof};
use sui::balance::{Self, Balance};
use sui::package::{Self};
#[test_only]
use sui::object::uid_to_inner;

// === Errors ===
const EStakeTooLow: u64 = 0;
const EStakeTooHigh: u64 = 1;
const EInvalidBlsSig: u64 = 2;
const EInsufficientHouseBalance: u64 = 5;
const EGameDoesNotExist: u64 = 6;







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
const EInsufficientBalance: u64 = 1;
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
    game_count:u64,
    current_game: PokerGame
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





// === Events ===
public struct NewGame has copy, drop {
    game_id: u64,
    user_stake: u64,
    fee_bp: u16,
    players: vector<address>
}

/// Emitted when a game has finished.
public struct Outcome has copy, drop {
    game_id: ID,
    result: u64,
    player: address,
}

// === Public Functions ===
public fun start_game(bet_coins: Coin<SUI>, game_data: &mut GameData, ctx: &mut TxContext): u64 {
    let fee_bp = game_data.base_fee_in_bp();
    let (id, _new_game,isNew) = internal_start_game(bet_coins, game_data, fee_bp, ctx);
    //todo 编译器为什么要在面认为可以？
    if (isNew){
        game_data.game_count = game_data.game_count + 1;
        let new_game = new_poker_game(game_data.game_count,ctx);
        game_data.current_game = new_game;
    };
    id
}

// /// finish_game Completes the game by calculating the outcome and transferring the funds to the player.
// /// The player must provide a BLS signature of the VRF input and the number of balls to calculate the outcome.
// /// It emits an Outcome event with the game result and the trace path of the extended beacon.
// public fun finish_game(game_id: ID, bls_sig: vector<u8>, game_data: &mut GameData, num_balls: u64, ctx: &mut TxContext): (u64, address, vector<u8>) {
//     // Ensure that the game exists.
//     assert!(game_exists(game_data, game_id), EGameDoesNotExist);
//
//     // Retrieves and removes the game from HouseData, preparing for outcome calculation.
//     let PokerGame {
//         id,
//         game_start_epoch: _,
//         stake,
//         fee_bp: _,
//         players:_,
//     } = dof::remove<ID, PokerGame>(game_data.borrow_mut(), game_id);
//
//     object::delete(id);
//
//     // Validates the BLS signature against the VRF input.
//     let is_sig_valid = bls12381_min_pk_verify(&bls_sig, &game_data.public_key(), &vrf_input);
//     assert!(is_sig_valid, EInvalidBlsSig);
//
//     // Initialize the extended beacon vector and a counter for hashing.
//     let mut extended_beacon = vector[];
//     let mut counter: u8 = 0;
//
//     // Extends the beacon until it has enough data for all ball outcomes.
//     while (extended_beacon.length() < (num_balls * 12)) {
//         // Create a new vector combining the original BLS signature with the current counter value.
//         let mut hash_input = vector[];
//         hash_input.append(bls_sig);
//         hash_input.push_back(counter);
//         // Generate a new hash block from the unique hash input.
//         let block = blake2b256(&hash_input);
//         // Append the generated hash block to the extended beacon.
//         extended_beacon.append(block);
//         // Increment the counter for the next iteration to ensure a new unique hash input.
//         counter = counter + 1;
//     };
//
//     // Initializes variables for calculating game outcome.
//     let mut trace = vector[];
//     // Calculate the stake amount per ball
//     let stake_per_ball = stake.value<SUI>() / num_balls;
//     let mut total_funds_amount: u64 = 0;
//
//     // Calculates outcome for each ball based on the extended beacon.
//     let mut ball_index = 0;
//     while (ball_index < num_balls) {
//         let mut state: u64 = 0;
//         let mut i = 0;
//         while (i < 12) {
//             // Calculate the byte index for the current ball and iteration.
//             let byte_index = (ball_index * 12) + i;
//             // Retrieve the byte from the extended beacon.
//             let byte = extended_beacon[byte_index];
//             // Add the byte to the trace vector
//             trace.push_back<u8>(byte);
//             // Count the number of even bytes
//             // If even, add 1 to the state
//             // Odd byte -> 0, Even byte -> 1
//             // The state is used to calculate the multiplier index
//             state = if (byte % 2 == 0) { state + 1 } else { state };
//             i = i + 1;
//         };
//     };
//
//     // Processes the payout to the player and returns the game outcome.
//     let payout_balance_mut = game_data.borrow_balance_mut();
//     let payout_coin: Coin<SUI> = coin::take(payout_balance_mut, total_funds_amount, ctx);
//
//     payout_balance_mut.join(stake);
//
//     // transfer the payout coins to the player
//     transfer::public_transfer(payout_coin, player);
//     // Emit the Outcome event
//     emit(Outcome {
//         game_id,
//         result: total_funds_amount,
//         player,
//         trace
//     });
//
//     // return the total amount to be sent to the player, (and the player address)
//     (total_funds_amount, player, trace)
// }

// === Public-View Functions ===



// === Admin Functions ===

/// Helper function to check if a game exists.
public fun game_exists(game_data: &GameData, game_id: ID): bool {
    dof::exists_(game_data.borrow(), game_id)
}

// /// Helper function to check that a game exists and return a reference to the game Object.
// /// Can be used in combination with any accessor to retrieve the desired game field.
// public fun borrow_game(game_id: ID, game_data: &GameData): &poker_game::PokerGame {
//     assert!(game_exists(game_data, game_id), EGameDoesNotExist);
//     dof::borrow(game_data.borrow(), game_id)
// }

// === Private Functions ===
fun internal_start_game(coin: Coin<SUI>, game_data: &mut GameData, fee_bp: u16, ctx: &mut TxContext): (u64, &mut poker_game::PokerGame,bool) {
    let user_stake = coin.value();
    assert!(user_stake <= game_data.max_stake(), EStakeTooHigh);
    assert!(user_stake >= game_data.min_stake(), EStakeTooLow);

    let coin_amount = coin.value();
    let bet_balance = coin.into_balance();
    game_data.add_balalce(bet_balance);

    let curr_game:&mut PokerGame =&mut  game_data.current_game;

    let player_num = curr_game.join_user(ctx.sender(),coin_amount);
    if (player_num>=2){
        // Emit a NewGame event
        let game_id = curr_game.id();
        emit(NewGame {
            game_id:game_id,
            user_stake: curr_game.get_state(),
            fee_bp,
            players: curr_game.get_players(),
        });
        // 为什么不能转回来
        // delete(curr_game.id());
        return (curr_game.id(),curr_game,true)
    };

    (curr_game.id(),curr_game,false)
}

public fun initialize_game_data( ctx: &mut TxContext) {
    let  game_data = GameData {
        id: object::new(ctx),
        balance: sui::balance::zero(),
        house: ctx.sender(),
        // public_key: ctx.sender(),
        max_stake: 10_000_000_000, // 10 SUI = 10^9.
        min_stake: 100_000_000, // 0.1 SUI.
        fees: balance::zero(),
        base_fee_in_bp: 100, // 1% in basis points.
        game_count:10000,
        current_game: new_poker_game(10000,ctx)
    };
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

