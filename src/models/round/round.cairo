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

    fn validate_config(config: @RoundConfig) -> RoundValidation {
        let mut is_valid = true;
        let mut error_message: felt252 = 0;

        if *config.wager_amount == 0 {
            is_valid = false;
            error_message = 'Wager amount cannot be zero';
        }

        if *config.mode == Mode::Solo {
            if *config.max_players != 1 {
                is_valid = false;
                error_message = 'Solo mode must have one player';
            }
        }

        if *config.max_players <= 0 || *config.max_players > 50 {
            is_valid = false;
            error_message = 'Invalid max players count';
        }

        if *config.cards_per_round <= 0 || *config.cards_per_round > 100 {
            is_valid = false;
            error_message = 'Invalid cards per round count';
        }

        if *config.card_timeout <= 0 {
            is_valid = false;
            error_message = 'Card timeout cannot be zero';
        }

        match *config.challenge_type {
            Option::Some(challenge_type) => {
                if challenge_type.requires_param() {
                    match config.challenge_param1 {
                        Option::Some(param1) => {
                            if *param1 == 0 {
                                is_valid = false;
                                error_message = 'Challenge param1 cannot be zero';
                            }
                        },
                        Option::None => {
                            is_valid = false;
                            error_message = 'Challenge param1 required';
                        },
                    }

                    match config.challenge_param2 {
                        Option::Some(param2) => {
                            if challenge_type != ChallengeType::GenreAndDecade {
                                is_valid = false;
                                error_message = 'Challenge param2 not required';
                            }
                        },
                        Option::None => {// No action needed, param2 is optional
                        },
                    }
                }

                if challenge_type.requires_two_params() {
                    match config.challenge_param2 {
                        Option::Some(param2) => {
                            if *param2 == 0 {
                                is_valid = false;
                                error_message = 'Challenge param2 cannot be zero';
                            }
                        },
                        Option::None => {
                            is_valid = false;
                            error_message = 'Challenge param2 required';
                        },
                    }

                    match config.challenge_param1 {
                        Option::Some(param1) => {
                            if *param1 == 0 {
                                is_valid = false;
                                error_message = 'Challenge param1 cannot be zero';
                            }
                        },
                        Option::None => {
                            is_valid = false;
                            error_message = 'Both challenge params required';
                        },
                    }
                }

                if challenge_type == ChallengeType::Random {
                    if config.challenge_param1.is_some() || config.challenge_param2.is_some() {
                        is_valid = false;
                        error_message = 'Random challenge has params';
                    }
                }

                if challenge_type == ChallengeType::GenreAndDecade {
                    if config.challenge_param1.is_none() || config.challenge_param2.is_none() {
                        is_valid = false;
                        error_message = 'Challenge requires both params';
                    }
                }
            },
            Option::None => {
                if config.challenge_param1.is_some() || config.challenge_param2.is_some() {
                    is_valid = false;
                    error_message = 'Challenge params without type';
                }
            },
        }

        RoundValidation { is_valid, error_message }
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

    fn create_base_config() -> RoundConfig {
        RoundConfig {
            wager_amount: 100,
            mode: Mode::MultiPlayer,
            max_players: 5,
            cards_per_round: 10,
            card_timeout: 30,
            challenge_type: Option::None,
            challenge_param1: Option::None,
            challenge_param2: Option::None,
        }
    }

    #[test]
    fn test_valid_config() {
        let config = create_base_config();
        let validation = RoundTrait::validate_config(@config);

        assert!(validation.is_valid, "Valid config should pass validation");
        assert_eq!(validation.error_message, 0, "Valid config should have no error message");
    }

    #[test]
    fn test_zero_wager_amount() {
        let mut config = create_base_config();
        config.wager_amount = 0;

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "Zero wager amount should be invalid");
        assert_eq!(validation.error_message, 'Wager amount cannot be zero');
    }

    #[test]
    fn test_solo_mode_with_one_player() {
        let mut config = create_base_config();
        config.mode = Mode::Solo;
        config.max_players = 1;

        let validation = RoundTrait::validate_config(@config);
        assert!(validation.is_valid, "Solo mode with 1 player should be valid");
    }

    #[test]
    fn test_solo_mode_with_multiple_players() {
        let mut config = create_base_config();
        config.mode = Mode::Solo;
        config.max_players = 5;

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "Solo mode with multiple players should be invalid");
        assert_eq!(validation.error_message, 'Solo mode must have one player');
    }

    #[test]
    fn test_invalid_max_players() {
        let mut config = create_base_config();
        config.max_players = 0;

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "Max players count of 0 should be invalid");
        assert_eq!(validation.error_message, 'Invalid max players count');
    }


    #[test]
    fn test_max_players_over_limit() {
        let mut config = create_base_config();
        config.max_players = 51;

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "Max players over 50 should be invalid");
        assert_eq!(validation.error_message, 'Invalid max players count');
    }

    #[test]
    fn test_zero_cards_per_round() {
        let mut config = create_base_config();
        config.cards_per_round = 0;

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "Zero cards per round should be invalid");
        assert_eq!(validation.error_message, 'Invalid cards per round count');
    }

    #[test]
    fn test_cards_per_round_over_limit() {
        let mut config = create_base_config();
        config.cards_per_round = 101;

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "Cards per round over 100 should be invalid");
        assert_eq!(validation.error_message, 'Invalid cards per round count');
    }

    #[test]
    fn test_zero_card_timeout() {
        let mut config = create_base_config();
        config.card_timeout = 0;

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "Zero card timeout should be invalid");
        assert_eq!(validation.error_message, 'Card timeout cannot be zero');
    }

    #[test]
    fn test_random_challenge_without_params() {
        let mut config = create_base_config();
        config.challenge_type = Option::Some(ChallengeType::Random);

        let validation = RoundTrait::validate_config(@config);

        assert!(validation.is_valid, "Random challenge without params should be valid");
    }

    fn test_random_challenge_with_param1() {
        let mut config = create_base_config();
        config.challenge_type = Option::Some(ChallengeType::Random);
        config.challenge_param1 = Option::Some(1);

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "Random challenge with param1 should be invalid");
        assert_eq!(validation.error_message, 'Random challenge has params');
    }

    #[test]
    fn test_random_challenge_with_param2() {
        let mut config = create_base_config();
        config.challenge_type = Option::Some(ChallengeType::Random);
        config.challenge_param2 = Option::Some(1);

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "Random challenge with param2 should be invalid");
        assert_eq!(validation.error_message, 'Random challenge has params');
    }

    #[test]
    fn test_random_challenge_with_both_params() {
        let mut config = create_base_config();
        config.challenge_type = Option::Some(ChallengeType::Random);
        config.challenge_param1 = Option::Some(1);
        config.challenge_param2 = Option::Some(2);

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "Random challenge with both params should be invalid");
        assert_eq!(validation.error_message, 'Random challenge has params');
    }

    #[test]
    fn test_genre_and_decade_with_both_params() {
        let mut config = create_base_config();
        config.challenge_type = Option::Some(ChallengeType::GenreAndDecade);
        config.challenge_param1 = Option::Some(1);
        config.challenge_param2 = Option::Some(1980);

        let validation = RoundTrait::validate_config(@config);

        assert!(validation.is_valid, "GenreAndDecade with both params should be valid");
    }

    #[test]
    fn test_genre_and_decade_challenge_without_params() {
        let mut config = create_base_config();
        config.challenge_type = Option::Some(ChallengeType::GenreAndDecade);

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "GenreAndDecade challenge without params should be invalid");
        assert_eq!(validation.error_message, 'Challenge requires both params');
    }

    #[test]
    fn test_genre_and_decade_missing_param1() {
        let mut config = create_base_config();
        config.challenge_type = Option::Some(ChallengeType::GenreAndDecade);
        config.challenge_param2 = Option::Some(1980);

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "GenreAndDecade missing param1 should be invalid");
        assert_eq!(validation.error_message, 'Challenge requires both params');
    }

    #[test]
    fn test_genre_and_decade_missing_param2() {
        let mut config = create_base_config();
        config.challenge_type = Option::Some(ChallengeType::GenreAndDecade);
        config.challenge_param1 = Option::Some(1);

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "GenreAndDecade missing param2 should be invalid");
        assert_eq!(validation.error_message, 'Challenge requires both params');
    }

    #[test]
    fn test_challenge_params_without_type() {
        let mut config = create_base_config();
        config.challenge_param1 = Option::Some(1);
        config.challenge_param2 = Option::Some(2);

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "Challenge params without type should be invalid");
        assert_eq!(validation.error_message, 'Challenge params without type');
    }

    #[test]
    fn test_challenge_params_with_none_type() {
        let mut config = create_base_config();
        config.challenge_type = Option::None;
        config.challenge_param1 = Option::Some(1);
        config.challenge_param2 = Option::Some(2);

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "Challenge params with None type should be invalid");
        assert_eq!(validation.error_message, 'Challenge params without type');
    }

    #[test]
    fn test_required_challenge_param1() {
        let mut config = create_base_config();
        config.challenge_type = Option::Some(ChallengeType::Genre);

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "Missing challenge_param1 should be invalid");
        assert_eq!(validation.error_message, 'Challenge param1 required');
    }

    #[test]
    fn test_challenge_with_require_param_has_param_2() {
        let mut config = create_base_config();
        config.challenge_type = Option::Some(ChallengeType::Genre);
        config.challenge_param2 = Option::Some(1);

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "Missing challenge_param2 should be invalid");
        assert_eq!(validation.error_message, 'Challenge param2 not required');
    }

    #[test]
    fn test_challenge_requiring_two_params_with_zero_param2() {
        let mut config = create_base_config();
        config.challenge_type = Option::Some(ChallengeType::GenreAndDecade);
        config.challenge_param1 = Option::Some(1);
        config.challenge_param2 = Option::Some(0);

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "Challenge param2 of zero should be invalid");
        assert_eq!(validation.error_message, 'Challenge param2 cannot be zero');
    }

    #[test]
    fn test_challenge_requiring_param_with_zero_param1() {
        let mut config = create_base_config();
        config.challenge_type = Option::Some(ChallengeType::Genre);
        config.challenge_param1 = Option::Some(0);

        let validation = RoundTrait::validate_config(@config);

        assert!(!validation.is_valid, "Challenge param1 of zero should be invalid");
        assert_eq!(validation.error_message, 'Challenge param1 cannot be zero');
    }
}
