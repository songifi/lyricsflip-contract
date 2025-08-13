use core::num::traits::Zero;
use dojo::event::EventStorage;
use dojo::model::ModelStorage;
use dojo::world::WorldStorage;
use lyricsflip::alias::ID;
use lyricsflip::constants::{GAME_ID, MAX_PLAYERS};
use lyricsflip::models::card::QuestionCard;
use lyricsflip::models::player::PlayerStats;
use lyricsflip::systems::actions::actions::RoundWinner;
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};


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
    pub challenge_type: felt252,
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

#[derive(Drop, Copy, Serde, PartialEq, Introspect)]
pub enum ChallengeType {
    Random, // Standard random card selection
    Year, // Cards from a specific artist
    Artist, // Cards from a specific year
    Genre, // Cards from a specific genre
    Decade, // Cards from a specific decade
    GenreAndDecade // Cards matching both genre and decade criteria
}

impl ChallengeTypeIntoFelt252 of Into<ChallengeType, felt252> {
    fn into(self: ChallengeType) -> felt252 {
        match self {
            ChallengeType::Random => 'RANDOM',
            ChallengeType::Year => 'YEAR',
            ChallengeType::Artist => 'ARTIST',
            ChallengeType::Genre => 'GENRE',
            ChallengeType::Decade => 'DECADE',
            ChallengeType::GenreAndDecade => 'GENREANDDECADE',
        }
    }
}

impl Felt252TryIntoChallengeType of TryInto<felt252, ChallengeType> {
    fn try_into(self: felt252) -> Option<ChallengeType> {
        if self == 'RANDOM' {
            Option::Some(ChallengeType::Random)
        } else if self == 'YEAR' {
            Option::Some(ChallengeType::Year)
        } else if self == 'ARTIST' {
            Option::Some(ChallengeType::Artist)
        } else if self == 'GENRE' {
            Option::Some(ChallengeType::Genre)
        } else if self == 'DECADE' {
            Option::Some(ChallengeType::Decade)
        } else if self == 'GENREANDDECADE' {
            Option::Some(ChallengeType::GenreAndDecade)
        } else {
            Option::None
        }
    }
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

#[generate_trait]
pub impl RoundImpl of RoundTrait {
    fn get_state(self: @Round) -> Option<RoundState> {
         (*self.state).try_into()
    }

    fn get_mode(self: @Round) -> Option<Mode> {
        (*self.mode).try_into()
    }

    fn is_pending(self: @Round) -> bool {
        match Self::get_state(self) {
            Option::Some(state) => match state {
                RoundState::Pending => true,
                _ => false,
            },
            _ => false,
        }
    }

    fn is_active(self: @Round) -> bool {
        match Self::get_state(self) {
            Option::Some(state) => match state {
                RoundState::Started => true,
                _ => false,
            },
            _ => false,
        }
    }

    fn is_completed(self: @Round) -> bool {
        match Self::get_state(self) {
            Option::Some(state) => match state {
                RoundState::Completed => true,
                _ => false,
            },
            _ => false,
        }
    }

    fn is_joinable(self: @Round) -> bool {
        if !Self::is_pending(self) {
            return false;
        }

        let is_solo = match Self::get_mode(self) {
            Option::Some(mode) => match mode {
                Mode::Solo => true,
                _ => false,
            },
            _ => false,
        };
        if is_solo {
            return false;
        }

        // Capacity check
        let current_players: u256 = *self.players_count;
        let max_players_u256: u256 = u256 { low: MAX_PLAYERS.into(), high: 0 };
        current_players < max_players_u256
    }


    fn has_minimum_players(self: @Round) -> bool {
        let players: u256 = *self.players_count;
        match Self::get_mode(self) {
            Option::Some(mode) => {
                let min_required: u256 = match mode {
                    Mode::Solo => u256 { low: 1_u64.into(), high: 0 },
                    _ => u256 { low: 2_u64.into(), high: 0 },
                };
                players >= min_required
            },
            _ => players >= u256 { low: 2_u64.into(), high: 0 },
        }
    }

    /// Retrieves the next available round ID
    fn get_round_id(world: @WorldStorage) -> ID {
        // compute next round ID from round counts
        let rounds_count: RoundsCount = world.read_model(GAME_ID);
        rounds_count.count + 1
    }

    fn is_valid_round(world: @WorldStorage, round_id: ID) {
        let round: Round = world.read_model(round_id);
        assert(!round.creator.is_zero(), 'Round does not exist');
    }

    fn validate_round_participation(
        world: @WorldStorage, round_id: ID, caller: ContractAddress,
    ) -> (Round, RoundPlayer) {
        // Validate round exists
        let round: Round = world.read_model(round_id);
        assert(!round.creator.is_zero(), 'Round does not exist');

        // Validate player participation
        let round_player: RoundPlayer = world.read_model((caller, round_id));
        assert(round_player.joined, 'Caller is non participant');

        (round, round_player)
    }

    /// Checks if all players have completed the round
    /// If so, marks the round as completed and determines the winner
    fn check_round_completion(ref world: WorldStorage, round_id: ID) {
        let mut round: Round = world.read_model(round_id);
        let players = round.players;

        // Check if all players have completed the round
        let mut all_completed = true;
        for i in 0..players.len() {
            let round_player: RoundPlayer = world.read_model((*players[i], round_id));
            if !round_player.round_completed {
                all_completed = false;
                break;
            }
        };

        // If all players have completed, finish the round
        if all_completed {
            // Mark round as completed
            round.state = RoundState::Completed.into();
            round.end_time = get_block_timestamp();
            world.write_model(@round);

            // Determine the winner
            Self::determine_round_winner(ref world, round_id);
        }
    }

    /// Determines the winner of a completed round
    /// Updates player stats including streaks and emits winner event
    fn determine_round_winner(ref world: WorldStorage, round_id: ID) {
        let round: Round = world.read_model(round_id);
        let players = round.players;

        // Find the player with the highest score
        let mut highest_score = 0;
        let mut winner = contract_address_const::<0>();

        for i in 0..players.len() {
            let player = *players[i];
            let round_player: RoundPlayer = world.read_model((player, round_id));

            if round_player.total_score > highest_score {
                highest_score = round_player.total_score;
                winner = player;
            }
        };

        // Update winner's stats
        if !winner.is_zero() {
            let mut winner_stats: PlayerStats = world.read_model(winner);
            winner_stats.rounds_won += 1;
            winner_stats.current_streak += 1;

            // Update max streak if current streak is higher
            if winner_stats.current_streak > winner_stats.max_streak {
                winner_stats.max_streak = winner_stats.current_streak;
            }

            world.write_model(@winner_stats);

            // Reset streaks for non-winners
            for i in 0..players.len() {
                let player = *players[i];
                if player != winner {
                    let mut player_stats: PlayerStats = world.read_model(player);
                    player_stats.current_streak = 0;
                    world.write_model(@player_stats);
                }
            }
        }
        //TODO Emit winner event
        world.emit_event(@RoundWinner { round_id, winner, score: highest_score });
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use starknet::{ContractAddress, contract_address_const};

    // Helper function to create a test Round
    fn create_test_round(
        round_id: ID,
        state: felt252,
        mode: felt252,
        players_count: u256,
        creator: ContractAddress
    ) -> Round {
        Round {
            round_id,
            creator,
            wager_amount: 0,
            start_time: 0,
            state,
            end_time: 0,
            players_count,
            ready_players_count: 0,
            round_cards: array![1_u64, 2_u64, 3_u64].span(),
            players: array![creator].span(),
            question_cards: array![].span(),
            mode,
            challenge_type: ChallengeType::Random.into(),
            creation_time: 0,
        }
    }

    fn test_creator() -> ContractAddress {
        contract_address_const::<'wheval'>()
    }

    #[test]
    fn test_round_get_state_valid_values() {
        let creator = test_creator();
        
        // Test PENDING state
        let pending_round = create_test_round(1, 'PENDING', 'SOLO', 1, creator);
        let state = RoundTrait::get_state(@pending_round);
        assert!(state.is_some(), "Should return Some for valid state");
        match state.unwrap() {
            RoundState::Pending => {},
            _ => panic!("Should be Pending state"),
        };

        // Test STARTED state
        let started_round = create_test_round(1, 'STARTED', 'SOLO', 1, creator);
        let state = RoundTrait::get_state(@started_round);
        assert!(state.is_some(), "Should return Some for valid state");
        match state.unwrap() {
            RoundState::Started => {},
            _ => panic!("Should be Started state"),
        };

        // Test COMPLETED state
        let completed_round = create_test_round(1, 'COMPLETED', 'SOLO', 1, creator);
        let state = RoundTrait::get_state(@completed_round);
        assert!(state.is_some(), "Should return Some for valid state");
        match state.unwrap() {
            RoundState::Completed => {},
            _ => panic!("Should be Completed state"),
        };
    }

    #[test]
    fn test_round_get_state_invalid_value() {
        let creator = test_creator();
        let invalid_round = create_test_round(1, 'INVALID', 'SOLO', 1, creator);
        let state = RoundTrait::get_state(@invalid_round);
        assert!(state.is_none(), "Should return None for invalid state");
    }

    #[test]
    fn test_round_get_mode_valid_values() {
        let creator = test_creator();
        
        // Test SOLO mode
        let solo_round = create_test_round(1, 'PENDING', 'SOLO', 1, creator);
        let mode = RoundTrait::get_mode(@solo_round);
        assert!(mode.is_some(), "Should return Some for valid mode");
        match mode.unwrap() {
            Mode::Solo => {},
            _ => panic!("Should be Solo mode"),
        };

        // Test MULTIPLAYER mode
        let multi_round = create_test_round(1, 'PENDING', 'MULTIPLAYER', 2, creator);
        let mode = RoundTrait::get_mode(@multi_round);
        assert!(mode.is_some(), "Should return Some for valid mode");
        match mode.unwrap() {
            Mode::MultiPlayer => {},
            _ => panic!("Should be MultiPlayer mode"),
        };

        // Test WAGERMULTIPLAYER mode
        let wager_round = create_test_round(1, 'PENDING', 'WAGERMULTIPLAYER', 2, creator);
        let mode = RoundTrait::get_mode(@wager_round);
        assert!(mode.is_some(), "Should return Some for valid mode");
        match mode.unwrap() {
            Mode::WagerMultiPlayer => {},
            _ => panic!("Should be WagerMultiPlayer mode"),
        };

        // Test CHALLENGE mode
        let challenge_round = create_test_round(1, 'PENDING', 'CHALLENGE', 2, creator);
        let mode = RoundTrait::get_mode(@challenge_round);
        assert!(mode.is_some(), "Should return Some for valid mode");
        match mode.unwrap() {
            Mode::Challenge => {},
            _ => panic!("Should be Challenge mode"),
        };
    }

    #[test]
    fn test_round_get_mode_invalid_value() {
        let creator = test_creator();
        let invalid_round = create_test_round(1, 'PENDING', 'INVALID', 1, creator);
        let mode = RoundTrait::get_mode(@invalid_round);
        assert!(mode.is_none(), "Should return None for invalid mode");
    }

    #[test]
    fn test_round_is_pending() {
        let creator = test_creator();
        
        // Test pending round
        let pending_round = create_test_round(1, 'PENDING', 'SOLO', 1, creator);
        assert!(RoundTrait::is_pending(@pending_round), "Should be pending");

        // Test non-pending round
        let started_round = create_test_round(1, 'STARTED', 'SOLO', 1, creator);
        assert!(!RoundTrait::is_pending(@started_round), "Should not be pending");

        // Test invalid state
        let invalid_round = create_test_round(1, 'INVALID', 'SOLO', 1, creator);
        assert!(!RoundTrait::is_pending(@invalid_round), "Invalid state should not be pending");
    }

    #[test]
    fn test_round_is_active() {
        let creator = test_creator();
        
        // Test active round
        let active_round = create_test_round(1, 'STARTED', 'SOLO', 1, creator);
        assert!(RoundTrait::is_active(@active_round), "Should be active");

        // Test non-active round
        let pending_round = create_test_round(1, 'PENDING', 'SOLO', 1, creator);
        assert!(!RoundTrait::is_active(@pending_round), "Should not be active");

        // Test invalid state
        let invalid_round = create_test_round(1, 'INVALID', 'SOLO', 1, creator);
        assert!(!RoundTrait::is_active(@invalid_round), "Invalid state should not be active");
    }

    #[test]
    fn test_round_is_completed() {
        let creator = test_creator();
        
        // Test completed round
        let completed_round = create_test_round(1, 'COMPLETED', 'SOLO', 1, creator);
        assert!(RoundTrait::is_completed(@completed_round), "Should be completed");

        // Test non-completed round
        let pending_round = create_test_round(1, 'PENDING', 'SOLO', 1, creator);
        assert!(!RoundTrait::is_completed(@pending_round), "Should not be completed");

        // Test invalid state
        let invalid_round = create_test_round(1, 'INVALID', 'SOLO', 1, creator);
        assert!(!RoundTrait::is_completed(@invalid_round), "Invalid state should not be completed");
    }

    #[test]
    fn test_round_is_joinable_pending_multiplayer() {
        let creator = test_creator();
        
        // Test pending multiplayer round with space
        let joinable_round = create_test_round(1, 'PENDING', 'MULTIPLAYER', 5, creator);
        assert!(RoundTrait::is_joinable(@joinable_round), "Should be joinable");
    }

    #[test]
    fn test_round_is_joinable_not_pending() {
        let creator = test_creator();
        
        // Test started round (not pending)
        let started_round = create_test_round(1, 'STARTED', 'MULTIPLAYER', 5, creator);
        assert!(!RoundTrait::is_joinable(@started_round), "Started round should not be joinable");

        // Test completed round (not pending)
        let completed_round = create_test_round(1, 'COMPLETED', 'MULTIPLAYER', 5, creator);
        assert!(!RoundTrait::is_joinable(@completed_round), "Completed round should not be joinable");
    }

    #[test]
    fn test_round_is_joinable_solo_mode() {
        let creator = test_creator();
        
        // Test solo mode (never joinable)
        let solo_round = create_test_round(1, 'PENDING', 'SOLO', 1, creator);
        assert!(!RoundTrait::is_joinable(@solo_round), "Solo round should not be joinable");
    }

    #[test]
    fn test_round_is_joinable_at_capacity() {
        let creator = test_creator();
        
        // Test round at maximum capacity
        let max_players_u256: u256 = u256 { low: MAX_PLAYERS.into(), high: 0 };
        let full_round = create_test_round(1, 'PENDING', 'MULTIPLAYER', max_players_u256, creator);
        assert!(!RoundTrait::is_joinable(@full_round), "Full round should not be joinable");
    }

    #[test]
    fn test_round_is_joinable_unknown_mode() {
        let creator = test_creator();
        
        // Test unknown mode (treated as non-solo, so joinable if pending and has space)
        let unknown_mode_round = create_test_round(1, 'PENDING', 'UNKNOWN', 5, creator);
        assert!(RoundTrait::is_joinable(@unknown_mode_round), "Unknown mode should be joinable if pending and has space");
    }

    #[test]
    fn test_round_has_minimum_players_solo() {
        let creator = test_creator();
        
        // Test solo with 1 player (minimum met)
        let solo_one = create_test_round(1, 'PENDING', 'SOLO', 1, creator);
        assert!(RoundTrait::has_minimum_players(@solo_one), "Solo with 1 player should meet minimum");

        // Test solo with 0 players (minimum not met)
        let solo_zero = create_test_round(1, 'PENDING', 'SOLO', 0, creator);
        assert!(!RoundTrait::has_minimum_players(@solo_zero), "Solo with 0 players should not meet minimum");

        // Test solo with 2 players (exceeds minimum)
        let solo_two = create_test_round(1, 'PENDING', 'SOLO', 2, creator);
        assert!(RoundTrait::has_minimum_players(@solo_two), "Solo with 2 players should meet minimum");
    }

    #[test]
    fn test_round_has_minimum_players_multiplayer() {
        let creator = test_creator();
        
        // Test multiplayer with 2 players (minimum met)
        let multi_two = create_test_round(1, 'PENDING', 'MULTIPLAYER', 2, creator);
        assert!(RoundTrait::has_minimum_players(@multi_two), "Multiplayer with 2 players should meet minimum");

        // Test multiplayer with 1 player (minimum not met)
        let multi_one = create_test_round(1, 'PENDING', 'MULTIPLAYER', 1, creator);
        assert!(!RoundTrait::has_minimum_players(@multi_one), "Multiplayer with 1 player should not meet minimum");

        // Test multiplayer with 0 players (minimum not met)
        let multi_zero = create_test_round(1, 'PENDING', 'MULTIPLAYER', 0, creator);
        assert!(!RoundTrait::has_minimum_players(@multi_zero), "Multiplayer with 0 players should not meet minimum");

        // Test multiplayer with 5 players (exceeds minimum)
        let multi_five = create_test_round(1, 'PENDING', 'MULTIPLAYER', 5, creator);
        assert!(RoundTrait::has_minimum_players(@multi_five), "Multiplayer with 5 players should meet minimum");
    }

    #[test]
    fn test_round_has_minimum_players_wager_multiplayer() {
        let creator = test_creator();
        
        // Test wager multiplayer with 2 players (minimum met)
        let wager_two = create_test_round(1, 'PENDING', 'WAGERMULTIPLAYER', 2, creator);
        assert!(RoundTrait::has_minimum_players(@wager_two), "Wager multiplayer with 2 players should meet minimum");

        // Test wager multiplayer with 1 player (minimum not met)
        let wager_one = create_test_round(1, 'PENDING', 'WAGERMULTIPLAYER', 1, creator);
        assert!(!RoundTrait::has_minimum_players(@wager_one), "Wager multiplayer with 1 player should not meet minimum");
    }

    #[test]
    fn test_round_has_minimum_players_challenge() {
        let creator = test_creator();
        
        // Test challenge with 2 players (minimum met)
        let challenge_two = create_test_round(1, 'PENDING', 'CHALLENGE', 2, creator);
        assert!(RoundTrait::has_minimum_players(@challenge_two), "Challenge with 2 players should meet minimum");

        // Test challenge with 1 player (minimum not met)
        let challenge_one = create_test_round(1, 'PENDING', 'CHALLENGE', 1, creator);
        assert!(!RoundTrait::has_minimum_players(@challenge_one), "Challenge with 1 player should not meet minimum");
    }

    #[test]
    fn test_round_has_minimum_players_unknown_mode() {
        let creator = test_creator();
        
        // Test unknown mode with 2 players (treated as non-solo, minimum met)
        let unknown_two = create_test_round(1, 'PENDING', 'UNKNOWN', 2, creator);
        assert!(RoundTrait::has_minimum_players(@unknown_two), "Unknown mode with 2 players should meet minimum");

        // Test unknown mode with 1 player (treated as non-solo, minimum not met)
        let unknown_one = create_test_round(1, 'PENDING', 'UNKNOWN', 1, creator);
        assert!(!RoundTrait::has_minimum_players(@unknown_one), "Unknown mode with 1 player should not meet minimum");
    }

    #[test]
    fn test_round_edge_cases_u256_boundaries() {
        let creator = test_creator();
        
        // Test with u256 max value
        let max_u256 = u256 { low: 0xffffffffffffffffffffffffffffffff, high: 0xffffffffffffffffffffffffffffffff };
        let max_round = create_test_round(1, 'PENDING', 'MULTIPLAYER', max_u256, creator);
        assert!(RoundTrait::has_minimum_players(@max_round), "Max u256 players should meet minimum");
        assert!(!RoundTrait::is_joinable(@max_round), "Max u256 players should not be joinable");
    }
}
