module mental_poker::game_data {
    // === Imports ===
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::package::{Self};
    use std::option::some;
    use sui::token::new_policy;
    use mental_poker::poker_game;
    use mental_poker::poker_game::{PokerGame, new_poker_game};


    // === Errors ===
    const ECallerNotHouse: u64 = 0;
    const EInsufficientBalance: u64 = 1;

    public struct Queue has  store,drop {
        stake: u64, // sui amount
        players: vector<address>
    }


    // === Structs ===

    /// Configuration and Treasury shared object, managed by the house.
    public struct GameData has key {
        id: UID,
        // House's balance which also contains the accrued winnings of the house.
        balance: Balance<SUI>,
        // Address of the house or the game operator.
        house: address,
        // Public key used to verify the beacon produced by the back-end.
        public_key: vector<u8>,
        // Maximum stake amount a player can bet in a single game.
        max_stake: u64,
        // Minimum stake amount required to play the game.
        min_stake: u64,
        // The accrued fees from games played.
        fees: Balance<SUI>,
        // The default fee in basis points. 1 basis point = 0.01%.
        base_fee_in_bp: u16,

        // curr_game: PokerGame,
    }

    /// A one-time use capability to initialize the house data;
    /// created and sent to sender in the initializer.
    public struct GameDataCap has key {
        id: UID
    }

    /// Used as a one time witness to generate the publisher.
    public struct GAME_DATA has drop {}

    fun init(otw: GAME_DATA, ctx: &mut TxContext) {
        // Creating and sending the Publisher object to the sender.
        package::claim_and_keep(otw, ctx);

        // Creating and sending the HouseCap object to the sender.
        let house_cap = GameDataCap {
            id: object::new(ctx)
        };

        transfer::transfer(house_cap, ctx.sender());
    }

    /// Initializer function that should only be called once and by the creator of the contract.
    /// Initializes the house data object with the house's public key and an initial balance.
    /// It also sets the max and min stake values, that can later on be updated.
    /// Stores the house address and the base fee in basis points.
    /// This object is involved in all games created by the same instance of this package.
    public fun initialize_game_data(house_cap: GameDataCap, coin: Coin<SUI>, public_key: vector<u8>, ctx: &mut TxContext) {
        assert!(coin.value() > 0, EInsufficientBalance);

        let mut game_data = GameData {
            id: object::new(ctx),
            balance: coin.into_balance(),
            house: ctx.sender(),
            public_key,
            max_stake: 10_000_000_000, // 10 SUI = 10^9.
            min_stake: 1_000_000_000, // 1 SUI.
            fees: balance::zero(),
            base_fee_in_bp: 100, // 1% in basis points.
            // curr_game: new_poker_game(ctx),
        };

        let GameDataCap { id } = house_cap;
        object::delete(id);

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

    /// Returns the public key of the house.
    public fun public_key(game_data: &GameData): vector<u8> {
        game_data.public_key
    }

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
    //
    // public fun current_game(game_data: &GameData):std::option::Option<PokerGame>{
    //     game_data.current_game
    // }

    // public fun reset_game(game_data: &mut GameData,ctx: &mut TxContext){
    //     game_data.curr_game = new_poker_game(ctx)
    // }

    // public fun set_current_game(game_data: &mut GameData,queue: PokerGame){
    //     game_data.curr_game = queue;
    // }


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

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(GAME_DATA {}, ctx);
    }

    // #[test_only]
    // public fun new_game_data_testing(ctx: &mut TxContext):&mut GameData{
    //     let origin = coin::mint_for_testing<SUI>(0,ctx);
    //     let balance = coin::mint_for_testing<SUI>(0,ctx);
    //     let pk = object::new(ctx);
    //     let house_addr  = object::uid_to_address(&object::new(ctx));
    //     let mut game_data = &mut GameData{
    //         id:  object::new(ctx),
    //         // House's balance which also contains the accrued winnings of the house.
    //         balance: origin.into_balance<SUI>(),
    //         // Address of the house or the game operator.
    //         house: house_addr,
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
    //         // curr_game:new_poker_game(ctx)
    //     };
    //     return game_data
    // }
}

