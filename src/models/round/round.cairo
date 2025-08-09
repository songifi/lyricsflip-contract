use starknet::ContractAddress;
use lyricsflip::models::game_types::{Mode, ChallengeType, RoundState, ChallengeTypeTrait};
use lyricsflip::models::card::card::QuestionCard;
use core::num::traits::Zero;
use lyricsflip::constants::RoundId;

/// Core round configuration and state
#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Round {
    #[key]
    pub round_id: RoundId,
    pub creator: ContractAddress,
    pub mode: felt252, // Serialized Mode enum
    pub challenge_type: felt252, // Serialized ChallengeType enum
    pub challenge_param1: felt252, // Primary parameter (year, artist, genre, decade)
    pub challenge_param2: felt252, // Secondary parameter (for GenreAndDecade)
    pub state: felt252, // Serialized RoundState enum
    pub wager_amount: u256,
    pub start_time: u64,
    pub end_time: u64,
    pub creation_time: u64,
    pub players_count: u32,
    pub ready_players_count: u32,
    pub max_players: u32,
    pub cards_per_round: u32,
    pub card_timeout: u64, // Time allowed per card (in seconds)
    pub players: Span<ContractAddress>,
    pub round_cards: Span<u64>, // Card IDs for this round
    pub question_cards: Span<QuestionCard>,
}

/// Round validation results
#[derive(Copy, Drop, Serde)]
pub struct RoundValidation {
    pub is_valid: bool,
    pub error_message: felt252,
}

/// Round configuration for creation
#[derive(Copy, Drop, Serde)]
pub struct RoundConfig {
    pub mode: Mode,
    pub challenge_type: Option<ChallengeType>,
    pub challenge_param1: Option<felt252>,
    pub challenge_param2: Option<felt252>,
    pub wager_amount: u256,
    pub max_players: u32,
    pub cards_per_round: u32,
    pub card_timeout: u64,
}

/// Round summary for display
#[derive(Copy, Drop, Serde)]
pub struct RoundSummary {
    pub round_id: RoundId,
    pub creator: ContractAddress,
    pub mode: Mode,
    pub state: RoundState,
    pub players_count: u32,
    pub is_joinable: bool,
    pub creation_time: u64,
}

#[generate_trait]
pub impl RoundImpl of RoundTrait {
    /// Gets the round mode as enum
    fn get_mode(self: @Round) -> Mode {
        (*self.mode).try_into().unwrap()
    }

    /// Gets the round state as enum
    fn get_state(self: @Round) -> RoundState {
        (*self.state).try_into().unwrap()
    }

    /// Gets the challenge type as enum
    fn get_challenge_type(self: @Round) -> ChallengeType {
        (*self.challenge_type).try_into().unwrap()
    }
}

#[generate_trait]
pub impl RoundConfigImpl of RoundConfigTrait {
    ///TODO: Validates the configuration
    fn is_valid(self: @RoundConfig) -> bool {
        // let validation = RoundTrait::validate_config(self);
        // validation.is_valid
        true // remove after implementing validate_config in RoundTrait
    }
}

#[cfg(test)]
mod tests {
    use super::{RoundTrait, RoundConfigTrait, RoundConfig, RoundImpl};
    use starknet::contract_address_const;
    use lyricsflip::models::game_types::{Mode, ChallengeType, RoundState};
}
