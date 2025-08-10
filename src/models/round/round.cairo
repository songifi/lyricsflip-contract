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

    /// Creates a new RoundConfig with defaults
    fn new(mode: Mode, cards_per_round: u32) -> RoundConfig {
        RoundConfig {
            mode,
            challenge_type: Option::None,
            challenge_param1: Option::None,
            challenge_param2: Option::None,
            wager_amount: 0,
            max_players: if mode == Mode::Solo {
                1
            } else {
                10
            },
            cards_per_round,
            card_timeout: 60 // 60 seconds default
        }
    }

    /// Creates a challenge round config
    fn new_challenge(
        mode: Mode,
        challenge_type: ChallengeType,
        param1: felt252,
        param2: Option<felt252>,
        cards_per_round: u32,
    ) -> RoundConfig {
        RoundConfig {
            mode,
            challenge_type: Option::Some(challenge_type),
            challenge_param1: Option::Some(param1),
            challenge_param2: param2,
            wager_amount: 0,
            max_players: if mode == Mode::Solo {
                1
            } else {
                10
            },
            cards_per_round,
            card_timeout: 60,
        }
    }

    /// Creates a wager round config
    fn new_wager(wager_amount: u256, cards_per_round: u32) -> RoundConfig {
        RoundConfig {
            mode: Mode::WagerMultiPlayer,
            challenge_type: Option::None,
            challenge_param1: Option::None,
            challenge_param2: Option::None,
            wager_amount,
            max_players: 10,
            cards_per_round,
            card_timeout: 60,
        }
    }

    /// Sets max players
    fn with_max_players(mut self: RoundConfig, max_players: u32) -> RoundConfig {
        self.max_players = max_players;
        self
    }

    /// Sets card timeout
    fn with_card_timeout(mut self: RoundConfig, timeout: u64) -> RoundConfig {
        self.card_timeout = timeout;
        self
    }

}

#[cfg(test)]
mod tests {
    use super::{RoundTrait, RoundConfigTrait, RoundConfig, RoundImpl};
    use starknet::contract_address_const;
    use lyricsflip::models::game_types::{Mode, ChallengeType, RoundState};

    #[test]
    fn test_new_solo_config() {
        let config = RoundConfigTrait::new(Mode::Solo, 10);

        assert(config.mode == Mode::Solo, 'wrong_mode');
        assert(config.challenge_type == Option::None, 'challenge_type_set');
        assert(config.challenge_param1 == Option::None, 'param1_set');
        assert(config.challenge_param2 == Option::None, 'param2_set');
        assert(config.wager_amount == 0, 'wager_not_zero');
        assert(config.max_players == 1, 'max_players_wrong'); // Solo mode should have 1 player
        assert(config.cards_per_round == 10, 'cards_wrong');
        assert(config.card_timeout == 60, 'timeout_wrong');
    }

    #[test]
    fn test_new_multiplayer_config() {
        let config = RoundConfigTrait::new(Mode::MultiPlayer, 15);

        assert(config.mode == Mode::MultiPlayer, 'wrong_mode');
        assert(config.challenge_type == Option::None, 'challenge_type_set');
        assert(config.challenge_param1 == Option::None, 'param1_set');
        assert(config.challenge_param2 == Option::None, 'param2_set');
        assert(config.wager_amount == 0, 'wager_not_zero');
        assert(
            config.max_players == 10, 'max_players_wrong',
        ); // Non-solo mode should have 10 players
        assert(config.cards_per_round == 15, 'cards_wrong');
        assert(config.card_timeout == 60, 'timeout_wrong');
    }

    #[test]
    fn test_new_challenge_config_with_single_param() {
        let config = RoundConfigTrait::new_challenge(
            Mode::Solo,
            ChallengeType::Year,
            2020, // param1: year
            Option::None, // param2: not needed for Year challenge
            8,
        );

        assert(config.mode == Mode::Solo, 'wrong_mode');
        assert(config.challenge_type == Option::Some(ChallengeType::Year), 'wrong_challenge');
        assert(config.challenge_param1 == Option::Some(2020), 'wrong_param1');
        assert(config.challenge_param2 == Option::None, 'param2_set');
        assert(config.wager_amount == 0, 'wager_not_zero');
        assert(config.max_players == 1, 'max_players_wrong');
        assert(config.cards_per_round == 8, 'cards_wrong');
        assert(config.card_timeout == 60, 'timeout_wrong');
    }

    #[test]
    fn test_new_challenge_config_with_two_params() {
        let config = RoundConfigTrait::new_challenge(
            Mode::MultiPlayer,
            ChallengeType::GenreAndDecade,
            'rock', // param1: genre
            Option::Some(1990), // param2: decade
            12,
        );

        assert(config.mode == Mode::MultiPlayer, 'wrong_mode');
        assert(
            config.challenge_type == Option::Some(ChallengeType::GenreAndDecade), 'wrong_challenge',
        );
        assert(config.challenge_param1 == Option::Some('rock'), 'wrong_param1');
        assert(config.challenge_param2 == Option::Some(1990), 'wrong_param2');
        assert(config.wager_amount == 0, 'wager_not_zero');
        assert(config.max_players == 10, 'max_players_wrong');
        assert(config.cards_per_round == 12, 'cards_wrong');
        assert(config.card_timeout == 60, 'timeout_wrong');
    }

#[test]
    fn test_new_wager_config() {
        let wager_amount = 1000_u256;
        let config = RoundConfigTrait::new_wager(wager_amount, 20);

        assert(config.mode == Mode::WagerMultiPlayer, 'wrong_mode');
        assert(config.challenge_type == Option::None, 'challenge_type_set');
        assert(config.challenge_param1 == Option::None, 'param1_set');
        assert(config.challenge_param2 == Option::None, 'param2_set');
        assert(config.wager_amount == wager_amount, 'wrong_wager');
        assert(config.max_players == 10, 'max_players_wrong');
        assert(config.cards_per_round == 20, 'cards_wrong');
        assert(config.card_timeout == 60, 'timeout_wrong');
    }

    #[test]
    fn test_with_max_players() {
        let mut config = RoundConfigTrait::new(Mode::MultiPlayer, 5);
        config = config.with_max_players(25);

        assert(config.max_players == 25, 'max_players_wrong');
        // Verify other fields remain unchanged
        assert(config.mode == Mode::MultiPlayer, 'mode_changed');
        assert(config.cards_per_round == 5, 'cards_changed');
        assert(config.card_timeout == 60, 'timeout_changed');
    }

    #[test]
    fn test_with_card_timeout() {
        let mut config = RoundConfigTrait::new(Mode::Solo, 7);
        config = config.with_card_timeout(120);

        assert(config.card_timeout == 120, 'timeout_wrong');
        // Verify other fields remain unchanged
        assert(config.mode == Mode::Solo, 'mode_changed');
        assert(config.cards_per_round == 7, 'cards_changed');
        assert(config.max_players == 1, 'max_players_changed');
    }

    #[test]
    fn test_method_chaining() {
        let config = RoundConfigTrait::new(Mode::MultiPlayer, 10)
            .with_max_players(5)
            .with_card_timeout(90);

        assert(config.mode == Mode::MultiPlayer, 'wrong_mode');
        assert(config.cards_per_round == 10, 'wrong_cards');
        assert(config.max_players == 5, 'wrong_max_players');
        assert(config.card_timeout == 90, 'wrong_timeout');
        assert(config.wager_amount == 0, 'wager_set');
    }

    #[test]
    fn test_edge_cases() {
        // Test with 0 cards per round
        let config = RoundConfigTrait::new(Mode::Solo, 0);
        assert(config.cards_per_round == 0, 'cards_not_zero');

        // Test with 0 wager amount
        let wager_config = RoundConfigTrait::new_wager(0_u256, 5);
        assert(wager_config.wager_amount == 0, 'wager_not_zero');

        // Test with 0 timeout
        let timeout_config = RoundConfigTrait::new(Mode::MultiPlayer, 5).with_card_timeout(0);
        assert(timeout_config.card_timeout == 0, 'timeout_not_zero');

        // Test with 0 max players
        let max_players_config = RoundConfigTrait::new(Mode::MultiPlayer, 5).with_max_players(0);
        assert(max_players_config.max_players == 0, 'max_not_zero');
    }

    #[test]
    fn test_different_challenge_types() {
        // Test Year challenge
        let year_config = RoundConfigTrait::new_challenge(
            Mode::Solo, ChallengeType::Year, 2023, Option::None, 5,
        );
        assert(year_config.challenge_type == Option::Some(ChallengeType::Year), 'wrong_challenge');
        assert(year_config.challenge_param1 == Option::Some(2023), 'wrong_param1');

        // Test Artist challenge
        let artist_config = RoundConfigTrait::new_challenge(
            Mode::MultiPlayer, ChallengeType::Artist, 'drake', Option::None, 7,
        );
        assert(
            artist_config.challenge_type == Option::Some(ChallengeType::Artist), 'wrong_challenge',
        );
        assert(artist_config.challenge_param1 == Option::Some('drake'), 'wrong_param1');

        // Test Genre challenge
        let genre_config = RoundConfigTrait::new_challenge(
            Mode::MultiPlayer, ChallengeType::Genre, 'pop', Option::None, 6,
        );
        assert(
            genre_config.challenge_type == Option::Some(ChallengeType::Genre), 'wrong_challenge',
        );
        assert(genre_config.challenge_param1 == Option::Some('pop'), 'wrong_param1');

        // Test Decade challenge
        let decade_config = RoundConfigTrait::new_challenge(
            Mode::Solo, ChallengeType::Decade, 2000, Option::None, 9,
        );
        assert(
            decade_config.challenge_type == Option::Some(ChallengeType::Decade), 'wrong_challenge',
        );
        assert(decade_config.challenge_param1 == Option::Some(2000), 'wrong_param1');
    }

    #[test]
    fn test_large_values() {
        // Test with large wager amount
        let large_wager = 1_000_000_000_u256;
        let config = RoundConfigTrait::new_wager(large_wager, 50);
        assert(config.wager_amount == large_wager, 'wrong_wager');

        // Test with large cards per round
        let large_cards_config = RoundConfigTrait::new(Mode::MultiPlayer, 1000);
        assert(large_cards_config.cards_per_round == 1000, 'wrong_cards');

        // Test with large timeout
        let large_timeout_config = RoundConfigTrait::new(Mode::Solo, 10)
            .with_card_timeout(3600); // 1 hour
        assert(large_timeout_config.card_timeout == 3600, 'wrong_timeout');

        // Test with large max players
        let large_players_config = RoundConfigTrait::new(Mode::MultiPlayer, 5)
            .with_max_players(100);
        assert(large_players_config.max_players == 100, 'wrong_max_players');
    }
}
