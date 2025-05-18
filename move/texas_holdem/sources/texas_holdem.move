/*
/// Module: texas_holdem
*/

module texas_holdem::texas_holdem;

// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions


public enum Suite has  copy {
    Club,
    Diamond,
    Heart,
    Spade
}

public enum Rank has Copy {
    Deuce,
    Trey,
    Four,
    Five,
    Six,
    Seven,
    Eight,
    Nine,
    Ten,
    Jack,
    Queen,
    King,
    Ace,
}

public struct InitialCard{
    pub suite:SUite,
    pub rank:Rank,
}

public struct Game {
    id:UID,
    players:HashMap<String, InitialCard>
}

public struct Player{
    public_key:string,
}

// create a game with initial deck
entry fun create_game(ctx: &mut TxContext){

}


