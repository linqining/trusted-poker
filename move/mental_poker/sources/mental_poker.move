module mental_poker::mental_poker;

use std::option::none;
use sui::coin;
use sui::coin::create_currency;
use sui::transfer::{public_freeze_object,};
use sui::url::Url;
use sui::transfer::{ public_transfer,share_object,transfer};
use sui::balance::Balance;
use tp_coin::tp_coin::TP_COIN;
use sui::sui::SUI;
use std::hash;







// // For Move coding conventions, see
// // https://docs.sui.io/concepts/sui-move-concepts/conventions

public struct JoinEvent has copy, drop {

}

public struct AdminCap has key{
    id:UID,
}

public struct Game  has key,store{
    id: UID,
    // 存钱必须用这个结构体，
    amount: Balance<TP_COIN>,
}

public struct MENTAL_POKER has drop{}


fun init(mental_poker:MENTAL_POKER,ctx: &mut TxContext){
    let tp_coin_img = none<Url>();
    let (treasury,metadata) = create_currency(mental_poker,8,b"TPCoin",b"TPCoin",b"Trusted poker coin",tp_coin_img,ctx);
    public_freeze_object(metadata);
    public_transfer(treasury,ctx.sender());

    let game = Game {
        id: object::new(ctx),
        amount: sui::balance::zero(),
    };
    share_object(game);
    let admin = AdminCap{id:object::new(ctx)};
    transfer(admin,ctx.sender());
}


// // 0是反面1是正面
// entry fun join(game: &mut Game,  user_bet_coin: coin::Coin<SUI>, ctx: &mut TxContext){
//     let game_balance = game.amount.value();
//     let user_bet_amount = user_bet_coin.value();


//     // 奖池大于用户奖池
//     // assert!(game_balance >= user_bet_amount * 10,0x1);

//     // up 正面 !up 反面
//     let mut generator = sui::random::new_generator(rand,ctx);
//     let gen_val = sui::random::generate_bool(&mut generator);
//     let mut  is_up = false;
//     if (guess_val ==1){
//         is_up = true
//     };
//     if (is_up ==gen_val){
//         let out_balance = game.amount.split(user_bet_amount);
//         let out_coin = coin::from_balance(out_balance,ctx);
//         public_transfer(out_coin,ctx.sender());
//         public_transfer(user_bet_coin,ctx.sender());
//     }else{
//         let in_amt_balance = coin::into_balance(user_bet_coin);
//         game.amount.join(in_amt_balance);
//     }

//     let in_amt_balance = coin::into_balance(user_bet_coin);
//     let tp_amount = in_amt_balance.value() * 100000;


//     game.amount.join(in_amt_balance);
// }





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


