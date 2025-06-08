use core::num::traits::Zero;
use dojo::event::EventStorage;
use dojo::model::ModelStorage;
use dojo::world::WorldStorage;
use lyricsflip::alias::ID;
use lyricsflip::constants::GAME_ID;
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
