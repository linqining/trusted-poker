
/// Module: tp_coin
module tp_coin::tp_coin;
use std::option::none;
use sui::coin::create_currency;
use sui::transfer::{public_freeze_object, public_share_object};
use sui::url::Url;

public struct TP_COIN has drop{}

fun init(tp_coin:TP_COIN,ctx: &mut TxContext){
    let tp_coin_img = none<Url>();
    let (treasury,metadata) = create_currency(tp_coin,8,b"TPCoin",b"TPCoin",b"tp coin",tp_coin_img,ctx);
    public_freeze_object(metadata);
    public_share_object(treasury);
}


