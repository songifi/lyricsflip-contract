use starknet::{ContractAddress};

// #[derive(Copy, Drop, Serde, Debug)]
// #[dojo::model]
// pub struct Position {
//     #[key]
//     pub player: ContractAddress,
//     pub vec: Vec2,
// }

pub const GAME_ID: felt252 = 'v0';

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct GameConfig {
    #[key]
    pub id: felt252,
    pub cards_per_round: u32,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct RoundsCount {
    #[key]
    pub id: felt252,
    pub count: u256,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Rounds {
    #[key]
    pub round_id: u256,
    pub round: Round,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, Debug)]
pub struct Round {
    pub creator: ContractAddress,
    pub genre: felt252,
    pub wager_amount: u256,
    pub start_time: u64,
    pub is_started: bool,
    pub is_completed: bool,
    pub end_time: u64,
    pub next_card_index: u8,
    pub players_count: u256,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct RoundPlayers {
    #[key]
    pub round_id: u256,
    #[key]
    pub count: u256,
    pub player: ContractAddress,
}

#[derive(Drop, Copy, Serde, PartialEq, Introspect, Debug)]
pub enum Genre {
    HipHop,
    Pop,
    Rock,
    RnB,
    Electronic,
    Classical,
    Jazz,
    Country,
    Blues,
    Reggae,
    Afrobeat,
    Gospel,
    Folk,
}


#[derive(Copy, Drop, Serde, IntrospectPacked, Debug)]
pub struct Vec2 {
    pub x: u32,
    pub y: u32,
}


impl GenreIntoFelt252 of Into<Genre, felt252> {
    fn into(self: Genre) -> felt252 {
        match self {
            Genre::HipHop => 'HipHop',
            Genre::Pop => 'Pop',
            Genre::Rock => 'Rock',
            Genre::RnB => 'RnB',
            Genre::Electronic => 'Electronic',
            Genre::Classical => 'Classical',
            Genre::Jazz => 'Jazz',
            Genre::Country => 'Country',
            Genre::Reggae => 'Reggae',
            Genre::Blues => 'Blues',
            Genre::Afrobeat => 'Afrobeat',
            Genre::Gospel => 'Gospel',
            Genre::Folk => 'Folk',
        }
    }
}

impl Felt252TryIntoGenre of TryInto<felt252, Genre> {
    fn try_into(self: felt252) -> Option<Genre> {
        if self == 'HipHop' {
            Option::Some(Genre::HipHop)
        } else if self == 'Pop' {
            Option::Some(Genre::Pop)
        } else if self == 'Rock' {
            Option::Some(Genre::Rock)
        } else if self == 'RnB' {
            Option::Some(Genre::RnB)
        } else if self == 'Electronic' {
            Option::Some(Genre::Electronic)
        } else if self == 'Classical' {
            Option::Some(Genre::Classical)
        } else if self == 'Jazz' {
            Option::Some(Genre::Jazz)
        } else if self == 'Country' {
            Option::Some(Genre::Country)
        } else if self == 'Reggae' {
            Option::Some(Genre::Reggae)
        } else if self == 'Blues' {
            Option::Some(Genre::Blues)
        } else if self == 'Afrobeat' {
            Option::Some(Genre::Afrobeat)
        } else if self == 'Gospel' {
            Option::Some(Genre::Gospel)
        } else if self == 'Folk' {
            Option::Some(Genre::Folk)
        } else {
            Option::None
        }
    }
}
