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

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct RoundPlayer {
    #[key]
    pub player_to_round_id: (ContractAddress, u256),
    pub joined: bool,
}


#[derive(Copy, Drop, Serde, Introspect, Debug)]
pub enum RoundState {
    Pending,
    Started,
    Completed,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, Debug)]
pub struct Round {
    pub creator: ContractAddress,
    pub genre: felt252,
    pub wager_amount: u256,
    pub start_time: u64,
    pub state: felt252,
    pub end_time: u64,
    pub next_card_index: u8,
    pub players_count: u256,
}

impl RoundStateIntoFelt252 of Into<RoundState, felt252> {
    fn into(self: RoundState) -> felt252 {
        match self {
            RoundState::Pending => 'PENDING',
            RoundState::Started => 'STARTED',
            RoundState::Completed => 'COMPLETED',
        }
    }
}

impl Felt252TryIntoRoundState of TryInto<felt252, RoundState> {
    fn try_into(self: felt252) -> Option<RoundState> {
        if self == 'PENDING' {
            Option::Some(RoundState::Pending)
        } else if self == 'STARTED' {
            Option::Some(RoundState::Started)
        } else if self == 'COMPLETED' {
            Option::Some(RoundState::Completed)
        } else {
            Option::None
        }
    }
}

