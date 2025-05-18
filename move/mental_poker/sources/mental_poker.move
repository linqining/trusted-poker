/*
/// Module: mental_poker
*/

module mental_poker::mental_poker;

use std::option::none;
use sui::coin::create_currency;
use sui::transfer::{public_freeze_object,};
use sui::url::Url;
use sui::transfer::{ public_transfer};
use sui::balance::Balance;







// // For Move coding conventions, see
// // https://docs.sui.io/concepts/sui-move-concepts/conventions

public struct JoinEvent has copy, drop {

}

public struct AdminCap has key{
    id:UID,
}

public struct LinkGame  has key,store{
    id: UID,
    // 存钱必须用这个结构体，
    amount: Balance<EIG>,
}

public struct MENTAL_POKER has drop{}


fun init(mental_poker:MENTAL_POKER,ctx: &mut TxContext){
    let tp_coin_img = none<Url>();
    let (treasury,metadata) = create_currency(mental_poker,8,b"TPCoin",b"TPCoin",b"Trusted poker coin",tp_coin_img,ctx);
    public_freeze_object(metadata);
    public_transfer(treasury,ctx.sender());
}




// public enum Suite has  store {
//     Club,
//     Diamond,
//     Heart,
//     Spade
// }

// public enum Rank has store {
//     Deuce,
//     Trey,
//     Four,
//     Five,
//     Six,
//     Seven,
//     Eight,
//     Nine,
//     Ten,
//     Jack,
//     Queen,
//     King,
//     Ace,
// }

// public struct InitialCard has store{
//      suite:Suite,
//      rank:Rank,
// }

// public struct Game has key, store {
//     id:UID,
//     initial_card_map:Table<String, InitialCard>,
//     seed_hex:String,
//     // all player's game_user public key
//     game_joined_public_key: String,

//     // all player's sui wallet joined public key,
//     // each player's public key will revealed on game end 
//     joined_public_key:String, 
// }


// // create a game with initial deck
// entry fun create_game(game:Game,ctx: &mut TxContext){
    
// }


