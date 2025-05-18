module mental_poker::plinko {
    use std::ascii::String;
    use std::string::append;
    use mental_poker::poker_game::{new_poker_game, PokerGame};
    use mental_poker::poker_game;
    use sui::coin::{Self, Coin};
    use sui::balance::Balance;
    use sui::sui::SUI;
    use sui::bls12381::bls12381_min_pk_verify;
    use sui::event::emit;
    use sui::dynamic_object_field::{Self as dof};
    use mental_poker::game_data::GameData;

    // === Errors ===
    const EStakeTooLow: u64 = 0;
    const EStakeTooHigh: u64 = 1;
    const EInvalidBlsSig: u64 = 2;
    const EInsufficientHouseBalance: u64 = 5;
    const EGameDoesNotExist: u64 = 6;


    // === Events ===
    public struct NewGame has copy, drop {
        game_id: ID,
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
    public fun start_game(bet_coins: Coin<SUI>, game_data: &mut GameData, ctx: &mut TxContext): ID {
        let fee_bp = game_data.base_fee_in_bp();


        let (id, new_game,isNew) = internal_start_game(bet_coins, game_data, fee_bp, ctx);
        //todo 编译器为什么要在面认为可以？
        if (isNew){
            let new_game = new_poker_game(ctx);
            dof::add(game_data.borrow_mut(), b"current_game",new_game);
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

    /// Helper function to check that a game exists and return a reference to the game Object.
    /// Can be used in combination with any accessor to retrieve the desired game field.
    public fun borrow_game(game_id: ID, game_data: &GameData): &poker_game::PokerGame {
        assert!(game_exists(game_data, game_id), EGameDoesNotExist);
        dof::borrow(game_data.borrow(), game_id)
    }

    // === Private Functions ===
    fun internal_start_game(coin: Coin<SUI>, game_data: &mut GameData, fee_bp: u16, ctx: &mut TxContext): (ID, &mut poker_game::PokerGame,bool) {
        let user_stake = coin.value();
        assert!(user_stake <= game_data.max_stake(), EStakeTooHigh);
        assert!(user_stake >= game_data.min_stake(), EStakeTooLow);

        let coin_amount = coin.value();
        let bet_balance = coin.into_balance();
        // let remain_balance = bet_balance.withdraw_all();
        // bet_balance.destroy_zero();
        game_data.add_balalce(bet_balance);

        if (!dof::exists_with_type<vector<u8>,PokerGame>(game_data.borrow(), b"current_game")){
            let new_game = new_poker_game(ctx);
            dof::add(game_data.borrow_mut(), b"current_game",new_game);
        };

        let curr_game:&mut PokerGame = dof::borrow_mut(game_data.borrow_mut(), b"current_game");

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

    // #[test_only]
    // public fun start_game_test(ctx: &mut TxContext) {
    //     //TODO 这里没有drop不能返回，但是在game_data测试start_game会循环引用，有问题，需要反馈
    //     // 这个规则是有冲突的new_game_data_testing 又需要drop,drop又需要uiddrop
    //    let game_data = new_game_data_testing(ctx);
    //     let user_bet = coin::mint_for_testing<SUI>(100_000_000,ctx);
    //     start_game(user_bet,game_data,ctx);
    //     start_game(user_bet,game_data,ctx);
    //     start_game(user_bet,game_data,ctx);
    // }
}
