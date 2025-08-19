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

    /// Check if round is in Pending state
    fn is_pending(self: @Round) -> bool {
        self.get_state() == RoundState::Pending
    }

    /// Check if round is in Started/Active state
    fn is_active(self: @Round) -> bool {
        self.get_state() == RoundState::Started
    }

    /// Check if round is in Completed state
    fn is_completed(self: @Round) -> bool {
        self.get_state() == RoundState::Completed
    }

    /// Check if round is joinable by new players
    fn is_joinable(self: @Round) -> bool {
        if !self.is_pending() {
            return false;
        }

        // Must not be at max capacity
        if *self.players_count >= *self.max_players {
            return false;
        }

        // Solo mode is never joinable
        if self.get_mode() == Mode::Solo {
            return false;
        }

        true
    }

    /// Checks if round has minimum players
    fn has_minimum_players(self: @Round) -> bool {
        let mode = self.get_mode();

        match mode {
            Mode::Solo => {
                // Solo mode requires exactly 1 player
                *self.players_count >= 1
            },
            _ => {
                // All other modes require at least 2 players
                *self.players_count >= 2
            },
        }
    }

    fn validate_config(config: @RoundConfig) -> RoundValidation {
        let mut is_valid = true;
        let mut error_message: felt252 = 0;

        if *config.mode == Mode::WagerMultiPlayer {
            if *config.wager_amount == 0 {
                is_valid = false;
                error_message = 'Wager amount cannot be zero';
            }
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
                        Option::None => { // No action needed, param2 is optional
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

    fn add_player(self: @Round, player: ContractAddress) -> Result<Round, RoundValidation> {
        if player.is_zero() {
            return Result::Err(
                RoundValidation { is_valid: false, error_message: 'Invalid player address' },
            );
        }

        if *self.players_count >= *self.max_players {
            return Result::Err(
                RoundValidation { is_valid: false, error_message: 'Round is at max capacity' },
            );
        }

        if !self.is_joinable() {
            return Result::Err(
                RoundValidation { is_valid: false, error_message: 'Round is not joinable' },
            );
        }

        if self.has_player(player) {
            return Result::Err(
                RoundValidation { is_valid: false, error_message: 'Player already in round' },
            );
        }

        let mut new_players = array![];
        let players_span = *self.players;
        let mut i = 0;
        loop {
            if i >= players_span.len() {
                break;
            }
            new_players.append(*players_span.at(i));
            i += 1;
        };
        new_players.append(player);

        let updated_round = Round {
            round_id: *self.round_id,
            creator: *self.creator,
            mode: *self.mode,
            challenge_type: *self.challenge_type,
            challenge_param1: *self.challenge_param1,
            challenge_param2: *self.challenge_param2,
            state: *self.state,
            wager_amount: *self.wager_amount,
            start_time: *self.start_time,
            end_time: *self.end_time,
            creation_time: *self.creation_time,
            players_count: *self.players_count + 1,
            ready_players_count: *self.ready_players_count,
            max_players: *self.max_players,
            cards_per_round: *self.cards_per_round,
            card_timeout: *self.card_timeout,
            players: new_players.span(),
            round_cards: *self.round_cards,
            question_cards: *self.question_cards,
        };

        Result::Ok(updated_round)
    }


    fn has_player(self: @Round, player: ContractAddress) -> bool {
        let players_span = *self.players;

        let mut i = 0;
        loop {
            if i >= players_span.len() {
                break false;
            }

            if *players_span.at(i) == player {
                break true;
            }

            i += 1;
        }
    }

    fn mark_player_ready(self: @Round) -> Result<Round, RoundValidation> {
        if !self.is_pending() {
            return Result::Err(
                RoundValidation { is_valid: false, error_message: 'Round is not in pending state' },
            );
        }

        if *self.ready_players_count >= *self.players_count {
            return Result::Err(
                RoundValidation { is_valid: false, error_message: 'All players already ready' },
            );
        }

        let updated_round = Round {
            round_id: *self.round_id,
            creator: *self.creator,
            mode: *self.mode,
            challenge_type: *self.challenge_type,
            challenge_param1: *self.challenge_param1,
            challenge_param2: *self.challenge_param2,
            state: *self.state,
            wager_amount: *self.wager_amount,
            start_time: *self.start_time,
            end_time: *self.end_time,
            creation_time: *self.creation_time,
            players_count: *self.players_count,
            ready_players_count: *self.ready_players_count + 1,
            max_players: *self.max_players,
            cards_per_round: *self.cards_per_round,
            card_timeout: *self.card_timeout,
            players: *self.players,
            round_cards: *self.round_cards,
            question_cards: *self.question_cards,
        };

        Result::Ok(updated_round)
    }

    fn all_players_ready(self: @Round) -> bool {
        if *self.players_count == 0 {
            return false;
        }

        return *self.ready_players_count == *self.players_count;
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
    use super::{Round, RoundTrait, RoundConfigTrait, RoundConfig, RoundImpl};
    use starknet::contract_address_const;
    use lyricsflip::models::game_types::{Mode, ChallengeType, RoundState};
    use starknet::ContractAddress;


    fn create_base_config() -> RoundConfig {
        RoundConfig {
            wager_amount: 100,
            mode: Mode::WagerMultiPlayer,
            max_players: 5,
            cards_per_round: 10,
            card_timeout: 30,
            challenge_type: Option::None,
            challenge_param1: Option::None,
            challenge_param2: Option::None,
        }
    }


    fn create_round_with_players(
        round_id: u64,
        mode: Mode,
        state: RoundState,
        players: Array<ContractAddress>,
        ready_players_count: u32,
        max_players: u32,
    ) -> Round {
        let players_count = players.len();
        Round {
            round_id,
            creator: contract_address_const::<'creator'>(),
            mode: mode.into(),
            challenge_type: ChallengeType::Random.into(),
            challenge_param1: 0,
            challenge_param2: 0,
            state: state.into(),
            wager_amount: 0,
            start_time: 0,
            end_time: 0,
            creation_time: 1000,
            players_count,
            ready_players_count,
            max_players,
            cards_per_round: 10,
            card_timeout: 60,
            players: players.span(),
            round_cards: array![].span(),
            question_cards: array![].span(),
        }
    }

    #[test]
    fn test_has_player_empty_players() {
        let round = create_test_round(1, Mode::MultiPlayer, RoundState::Pending, 0, 10);
        let player = contract_address_const::<'player1'>();

        assert!(!round.has_player(player), "Empty players array should return false");
    }

    #[test]
    fn test_has_player_found() {
        let player1 = contract_address_const::<'player1'>();
        let player2 = contract_address_const::<'player2'>();
        let players = array![player1, player2];

        let round = create_round_with_players(
            1, Mode::MultiPlayer, RoundState::Pending, players, 0, 10,
        );

        assert!(round.has_player(player1), "Should find player1");
        assert!(round.has_player(player2), "Should find player2");
    }

    #[test]
    fn test_has_player_not_found() {
        let player1 = contract_address_const::<'player1'>();
        let player2 = contract_address_const::<'player2'>();
        let player3 = contract_address_const::<'player3'>();
        let players = array![player1, player2];

        let round = create_round_with_players(
            1, Mode::MultiPlayer, RoundState::Pending, players, 0, 10,
        );

        assert!(!round.has_player(player3), "Should not find player3");
    }
    #[test]
    fn test_all_players_ready_zero_players() {
        let round = create_test_round(1, Mode::MultiPlayer, RoundState::Pending, 0, 10);

        assert!(!round.all_players_ready(), "Zero players should return false");
    }

    #[test]
    fn test_all_players_ready_partial() {
        let players = array![
            contract_address_const::<'player1'>(),
            contract_address_const::<'player2'>(),
            contract_address_const::<'player3'>(),
        ];

        let round = create_round_with_players(
            1, Mode::MultiPlayer, RoundState::Pending, players, 2, 10,
        );

        assert!(!round.all_players_ready(), "Partial ready should return false");
    }

    #[test]
    fn test_all_players_ready_all_ready() {
        let players = array![
            contract_address_const::<'player1'>(), contract_address_const::<'player2'>(),
        ];

        let round = create_round_with_players(
            1, Mode::MultiPlayer, RoundState::Pending, players, 2, 10,
        );

        assert!(round.all_players_ready(), "All ready should return true");
    }

    #[test]
    fn test_add_player_success() {
        let round = create_test_round(1, Mode::MultiPlayer, RoundState::Pending, 0, 10);
        let player = contract_address_const::<'player1'>();

        let result = round.add_player(player);

        assert!(result.is_ok(), "Should successfully add player");
        let updated_round = result.unwrap();
        assert!(updated_round.players_count == 1, "Player count should be 1");
        assert!(updated_round.has_player(player), "Should contain the new player");
    }

    #[test]
    fn test_add_player_zero_address() {
        let round = create_test_round(1, Mode::MultiPlayer, RoundState::Pending, 0, 10);
        let zero_player = contract_address_const::<0>();

        let result = round.add_player(zero_player);

        assert!(result.is_err(), "Should reject zero address");
        let error = result.unwrap_err();
        assert_eq!(error.error_message, 'Invalid player address');
    }

    #[test]
    fn test_add_player_not_joinable_started() {
        let round = create_test_round(1, Mode::MultiPlayer, RoundState::Started, 0, 10);
        let player = contract_address_const::<'player1'>();

        let result = round.add_player(player);

        assert!(result.is_err(), "Should reject adding to started round");
        let error = result.unwrap_err();
        assert_eq!(error.error_message, 'Round is not joinable');
    }

    #[test]
    fn test_add_player_not_joinable_solo() {
        let round = create_test_round(1, Mode::Solo, RoundState::Pending, 0, 1);
        let player = contract_address_const::<'player1'>();

        let result = round.add_player(player);

        assert!(result.is_err(), "Should reject adding to solo round");
        let error = result.unwrap_err();
        assert_eq!(error.error_message, 'Round is not joinable');
    }

    #[test]
    fn test_add_player_duplicate() {
        let player1 = contract_address_const::<'player1'>();
        let players = array![player1];
        let round = create_round_with_players(
            1, Mode::MultiPlayer, RoundState::Pending, players, 0, 10,
        );

        let result = round.add_player(player1);

        assert!(result.is_err(), "Should reject duplicate player");
        let error = result.unwrap_err();
        assert_eq!(error.error_message, 'Player already in round');
    }

    #[test]
    fn test_add_player_at_capacity() {
        let players = array![
            contract_address_const::<'player1'>(), contract_address_const::<'player2'>(),
        ];
        let round = create_round_with_players(
            1, Mode::MultiPlayer, RoundState::Pending, players, 0, 2,
        );
        let new_player = contract_address_const::<'player3'>();

        let result = round.add_player(new_player);

        assert!(result.is_err(), "Should reject when at capacity");
        let error = result.unwrap_err();
        println!("Error: {}", error.error_message);
        assert_eq!(error.error_message, 'Round is at max capacity');
    }

    #[test]
    fn test_add_multiple_players() {
        let mut round = create_test_round(1, Mode::MultiPlayer, RoundState::Pending, 0, 10);
        let player1 = contract_address_const::<'player1'>();
        let player2 = contract_address_const::<'player2'>();

        let result1 = round.add_player(player1);
        assert!(result1.is_ok(), "Should add first player");
        round = result1.unwrap();

        let result2 = round.add_player(player2);
        assert!(result2.is_ok(), "Should add second player");
        round = result2.unwrap();

        assert!(round.players_count == 2, "Should have 2 players");
        assert!(round.has_player(player1), "Should contain player1");
        assert!(round.has_player(player2), "Should contain player2");
    }

    #[test]
    fn test_mark_player_ready_success() {
        let players = array![
            contract_address_const::<'player1'>(), contract_address_const::<'player2'>(),
        ];
        let round = create_round_with_players(
            1, Mode::MultiPlayer, RoundState::Pending, players, 0, 10,
        );

        let result = round.mark_player_ready();

        assert!(result.is_ok(), "Should successfully mark player ready");
        let updated_round = result.unwrap();
        assert!(updated_round.ready_players_count == 1, "Ready count should be 1");
    }

    #[test]
    fn test_mark_player_ready_not_pending() {
        let players = array![contract_address_const::<'player1'>()];
        let round = create_round_with_players(
            1, Mode::MultiPlayer, RoundState::Started, players, 0, 10,
        );

        let result = round.mark_player_ready();

        assert!(result.is_err(), "Should reject when not pending");
        let error = result.unwrap_err();
        assert_eq!(error.error_message, 'Round is not in pending state');
    }

    #[test]
    fn test_mark_player_ready_all_already_ready() {
        let players = array![
            contract_address_const::<'player1'>(), contract_address_const::<'player2'>(),
        ];
        let round = create_round_with_players(
            1, Mode::MultiPlayer, RoundState::Pending, players, 2, 10,
        );

        let result = round.mark_player_ready();

        assert!(result.is_err(), "Should reject when all already ready");
        let error = result.unwrap_err();
        assert_eq!(error.error_message, 'All players already ready');
    }

    #[test]
    fn test_mark_multiple_players_ready() {
        let players = array![
            contract_address_const::<'player1'>(),
            contract_address_const::<'player2'>(),
            contract_address_const::<'player3'>(),
        ];
        let mut round = create_round_with_players(
            1, Mode::MultiPlayer, RoundState::Pending, players, 0, 10,
        );

        let result1 = round.mark_player_ready();
        assert!(result1.is_ok(), "Should mark first player ready");
        round = result1.unwrap();
        assert!(round.ready_players_count == 1, "Ready count should be 1");
        assert!(!round.all_players_ready(), "Not all players ready yet");

        let result2 = round.mark_player_ready();
        assert!(result2.is_ok(), "Should mark second player ready");
        round = result2.unwrap();
        assert!(round.ready_players_count == 2, "Ready count should be 2");
        assert!(!round.all_players_ready(), "Not all players ready yet");

        let result3 = round.mark_player_ready();
        assert!(result3.is_ok(), "Should mark third player ready");
        round = result3.unwrap();
        assert!(round.ready_players_count == 3, "Ready count should be 3");
        assert!(round.all_players_ready(), "All players should be ready");
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

    fn create_test_round(
        round_id: u64, mode: Mode, state: RoundState, players_count: u32, max_players: u32,
    ) -> Round {
        Round {
            round_id,
            creator: contract_address_const::<'creator'>(),
            mode: mode.into(),
            challenge_type: ChallengeType::Random.into(),
            challenge_param1: 0,
            challenge_param2: 0,
            state: state.into(),
            wager_amount: 0,
            start_time: 0,
            end_time: 0,
            creation_time: 1000,
            players_count,
            ready_players_count: 0,
            max_players,
            cards_per_round: 10,
            card_timeout: 60,
            players: array![].span(),
            round_cards: array![].span(),
            question_cards: array![].span(),
        }
    }

    #[test]
    fn test_is_pending() {
        let pending_round = create_test_round(1, Mode::MultiPlayer, RoundState::Pending, 1, 10);
        let started_round = create_test_round(2, Mode::MultiPlayer, RoundState::Started, 2, 10);
        let completed_round = create_test_round(3, Mode::MultiPlayer, RoundState::Completed, 2, 10);

        assert!(pending_round.is_pending(), "Pending round should return true");
        assert!(!started_round.is_pending(), "Started round should return false");
        assert!(!completed_round.is_pending(), "Completed round should return false");
    }

    #[test]
    fn test_is_active() {
        let pending_round = create_test_round(1, Mode::MultiPlayer, RoundState::Pending, 1, 10);
        let started_round = create_test_round(2, Mode::MultiPlayer, RoundState::Started, 2, 10);
        let completed_round = create_test_round(3, Mode::MultiPlayer, RoundState::Completed, 2, 10);

        assert!(!pending_round.is_active(), "Pending round should return false");
        assert!(started_round.is_active(), "Started round should return true");
        assert!(!completed_round.is_active(), "Completed round should return false");
    }

    #[test]
    fn test_is_completed() {
        let pending_round = create_test_round(1, Mode::MultiPlayer, RoundState::Pending, 1, 10);
        let started_round = create_test_round(2, Mode::MultiPlayer, RoundState::Started, 2, 10);
        let completed_round = create_test_round(3, Mode::MultiPlayer, RoundState::Completed, 2, 10);

        assert!(!pending_round.is_completed(), "Pending round should return false");
        assert!(!started_round.is_completed(), "Started round should return false");
        assert!(completed_round.is_completed(), "Completed round should return true");
    }

    #[test]
    fn test_is_joinable_pending_multiplayer() {
        // Pending MultiPlayer round with space should be joinable
        let round = create_test_round(1, Mode::MultiPlayer, RoundState::Pending, 2, 10);
        assert!(round.is_joinable(), "Pending MultiPlayer round with space should be joinable");
    }

    #[test]
    fn test_is_joinable_not_pending() {
        // Started round should not be joinable
        let started_round = create_test_round(1, Mode::MultiPlayer, RoundState::Started, 2, 10);
        assert!(!started_round.is_joinable(), "Started round should not be joinable");

        // Completed round should not be joinable
        let completed_round = create_test_round(2, Mode::MultiPlayer, RoundState::Completed, 2, 10);
        assert!(!completed_round.is_joinable(), "Completed round should not be joinable");
    }

    #[test]
    fn test_is_joinable_at_capacity() {
        // Round at max capacity should not be joinable
        let full_round = create_test_round(1, Mode::MultiPlayer, RoundState::Pending, 10, 10);
        assert!(!full_round.is_joinable(), "Full round should not be joinable");
    }

    #[test]
    fn test_is_joinable_solo_mode() {
        // Solo mode should never be joinable
        let solo_round = create_test_round(1, Mode::Solo, RoundState::Pending, 0, 1);
        assert!(!solo_round.is_joinable(), "Solo round should never be joinable");
    }

    #[test]
    fn test_is_joinable_wager_mode() {
        // Pending WagerMultiPlayer round with space should be joinable
        let wager_round = create_test_round(1, Mode::WagerMultiPlayer, RoundState::Pending, 1, 5);
        assert!(
            wager_round.is_joinable(),
            "Pending WagerMultiPlayer round with space should be joinable",
        );
    }

    #[test]
    fn test_is_joinable_challenge_mode() {
        // Pending Challenge round with space should be joinable
        let challenge_round = create_test_round(1, Mode::Challenge, RoundState::Pending, 1, 8);
        assert!(
            challenge_round.is_joinable(), "Pending Challenge round with space should be joinable",
        );
    }

    #[test]
    fn test_has_minimum_players_solo() {
        // Solo mode with 1 player should have minimum
        let solo_with_player = create_test_round(1, Mode::Solo, RoundState::Pending, 1, 1);
        assert!(
            solo_with_player.has_minimum_players(), "Solo round with 1 player should have minimum",
        );

        // Solo mode with 0 players should not have minimum
        let solo_empty = create_test_round(2, Mode::Solo, RoundState::Pending, 0, 1);
        assert!(
            !solo_empty.has_minimum_players(), "Solo round with 0 players should not have minimum",
        );
    }

    #[test]
    fn test_has_minimum_players_multiplayer() {
        // MultiPlayer with 2 players should have minimum
        let multi_with_two = create_test_round(1, Mode::MultiPlayer, RoundState::Pending, 2, 10);
        assert!(
            multi_with_two.has_minimum_players(),
            "MultiPlayer round with 2 players should have minimum",
        );

        // MultiPlayer with 1 player should not have minimum
        let multi_with_one = create_test_round(2, Mode::MultiPlayer, RoundState::Pending, 1, 10);
        assert!(
            !multi_with_one.has_minimum_players(),
            "MultiPlayer round with 1 player should not have minimum",
        );

        // MultiPlayer with 0 players should not have minimum
        let multi_empty = create_test_round(3, Mode::MultiPlayer, RoundState::Pending, 0, 10);
        assert!(
            !multi_empty.has_minimum_players(),
            "MultiPlayer round with 0 players should not have minimum",
        );
    }

    #[test]
    fn test_has_minimum_players_wager() {
        // WagerMultiPlayer with 2 players should have minimum
        let wager_with_two = create_test_round(
            1, Mode::WagerMultiPlayer, RoundState::Pending, 2, 5,
        );
        assert!(
            wager_with_two.has_minimum_players(),
            "WagerMultiPlayer round with 2 players should have minimum",
        );

        // WagerMultiPlayer with 1 player should not have minimum
        let wager_with_one = create_test_round(
            2, Mode::WagerMultiPlayer, RoundState::Pending, 1, 5,
        );
        assert!(
            !wager_with_one.has_minimum_players(),
            "WagerMultiPlayer round with 1 player should not have minimum",
        );
    }

    #[test]
    fn test_has_minimum_players_challenge() {
        // Challenge with 2 players should have minimum
        let challenge_with_two = create_test_round(1, Mode::Challenge, RoundState::Pending, 2, 8);
        assert!(
            challenge_with_two.has_minimum_players(),
            "Challenge round with 2 players should have minimum",
        );

        // Challenge with 1 player should not have minimum
        let challenge_with_one = create_test_round(2, Mode::Challenge, RoundState::Pending, 1, 8);
        assert!(
            !challenge_with_one.has_minimum_players(),
            "Challenge round with 1 player should not have minimum",
        );
    }

    #[test]
    fn test_state_query_consistency() {
        // Test that state queries are mutually exclusive
        let pending_round = create_test_round(1, Mode::MultiPlayer, RoundState::Pending, 2, 10);
        let started_round = create_test_round(2, Mode::MultiPlayer, RoundState::Started, 2, 10);
        let completed_round = create_test_round(3, Mode::MultiPlayer, RoundState::Completed, 2, 10);

        assert!(
            pending_round.is_pending()
                && !pending_round.is_active()
                && !pending_round.is_completed(),
            "Pending state should be exclusive",
        );

        assert!(
            !started_round.is_pending()
                && started_round.is_active()
                && !started_round.is_completed(),
            "Started state should be exclusive",
        );

        assert!(
            !completed_round.is_pending()
                && !completed_round.is_active()
                && completed_round.is_completed(),
            "Completed state should be exclusive",
        );
    }

    #[test]
    fn test_joinable_edge_cases() {
        // Test edge case: exactly at capacity
        let at_capacity = create_test_round(1, Mode::MultiPlayer, RoundState::Pending, 5, 5);
        assert!(!at_capacity.is_joinable(), "Round at exact capacity should not be joinable");

        // Test edge case: one spot left
        let one_spot_left = create_test_round(2, Mode::MultiPlayer, RoundState::Pending, 4, 5);
        assert!(one_spot_left.is_joinable(), "Round with one spot left should be joinable");

        // Test edge case: empty pending round
        let empty_pending = create_test_round(3, Mode::MultiPlayer, RoundState::Pending, 0, 10);
        assert!(empty_pending.is_joinable(), "Empty pending round should be joinable");
    }
}
