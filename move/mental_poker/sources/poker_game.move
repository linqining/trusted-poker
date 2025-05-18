module mental_poker::poker_game;
use std::address;
use std::string::append;
use std::vector::length;
use sui::bag::add;
use sui::balance::Balance;
use sui::balance;
use sui::coin;
use sui::object::{uid_to_inner, uid_to_address};
use sui::sui::SUI;
use sui::token::from_coin_action;

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

// public fun uid(game: &PokerGame): UID {
//     game.id
// }

public fun id(game: &PokerGame):ID {
   uid_to_inner(&game.id)
}

public fun get_state(game: &PokerGame):u64{
    game.stake
}