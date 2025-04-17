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
pub struct Round {
    #[key]
    pub round_id: u256,
    pub creator: ContractAddress,
    pub genre: felt252,
    pub wager_amount: u256,
    pub start_time: u64,
    pub state: felt252,
    pub end_time: u64,
    pub players_count: u256,
    pub ready_players_count: u256,
    pub round_cards: Span<u256>,
    pub players: Span<ContractAddress>,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct RoundPlayer {
    #[key]
    pub player_to_round_id: (ContractAddress, u256),
    pub joined: bool,
    pub ready_state: bool,
    pub next_card_index: u8,
    pub round_completed: bool,
}


#[derive(Copy, Drop, Serde, Introspect, Debug)]
pub enum RoundState {
    Pending,
    Started,
    Completed,
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


#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct PlayerStats {
    #[key]
    player: ContractAddress,
    pub total_rounds: u64,
    pub rounds_won: u64,
    pub current_streak: u64,
    pub max_streak: u64,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
pub enum Answer {
    Artist: felt252,
    Year: u64,
    Title: felt252,
}
