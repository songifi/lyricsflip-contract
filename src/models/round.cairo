use starknet::{ContractAddress};

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct RoundsCount {
    #[key]
    pub id: felt252, // represents GAME_ID
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
