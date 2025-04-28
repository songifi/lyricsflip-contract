use starknet::{ContractAddress};
use lyricsflip::models::card::{QuestionCard};
use lyricsflip::alias::ID;


#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct RoundsCount {
    #[key]
    pub id: felt252, // represents GAME_ID
    pub count: u64,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Round {
    #[key]
    pub round_id: ID,
    pub creator: ContractAddress,
    pub genre: felt252,
    pub wager_amount: u256,
    pub start_time: u64,
    pub state: felt252,
    pub end_time: u64,
    pub players_count: u256,
    pub ready_players_count: u256,
    pub round_cards: Span<u64>,
    pub players: Span<ContractAddress>,
    pub question_cards: Span<QuestionCard>,
    pub mode: felt252,
    pub creation_time: u64,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct RoundPlayer {
    #[key]
    pub player_to_round_id: (ContractAddress, ID),
    pub joined: bool,
    pub ready_state: bool,
    pub next_card_index: u8,
    pub round_completed: bool,
    pub current_card_start_time: u64, // Track when player started current card
    pub card_timeout: u64, // Time allowed per card (in seconds)
    // Performance metrics
    pub correct_answers: u64,
    pub total_answers: u64,
    pub total_score: u64,
    pub best_time: u64,
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
    pub player: ContractAddress,
    pub total_rounds: u64,
    pub rounds_won: u64,
    pub current_streak: u64,
    pub max_streak: u64,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
pub enum Answer {
    OptionOne,
    OptionTwo,
    OptionThree,
    OptionFour,
}

#[derive(Drop, Copy, Serde, PartialEq, Introspect)]
pub enum Mode {
    Solo, // Just the creator playing
    MultiPlayer, // multiple players
    WagerMultiPlayer, // Multiplayer with wager
    Challenge // Special challenge mode
}

impl ModeIntoFelt252 of Into<Mode, felt252> {
    fn into(self: Mode) -> felt252 {
        match self {
            Mode::Solo => 'SOLO',
            Mode::MultiPlayer => 'MULTIPLAYER',
            Mode::WagerMultiPlayer => 'WAGERMULTIPLAYER',
            Mode::Challenge => 'CHALLENGE',
        }
    }
}

impl Felt252TryIntoMode of TryInto<felt252, Mode> {
    fn try_into(self: felt252) -> Option<Mode> {
        if self == 'SOLO' {
            Option::Some(Mode::Solo)
        } else if self == 'MULTIPLAYER' {
            Option::Some(Mode::MultiPlayer)
        } else if self == 'WAGERMULTIPLAYER' {
            Option::Some(Mode::WagerMultiPlayer)
        } else if self == 'CHALLENGE' {
            Option::Some(Mode::Challenge)
        } else {
            Option::None
        }
    }
}

