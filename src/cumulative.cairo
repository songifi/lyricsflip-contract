==========
//src/models/player.cairo
==============

use dojo::world::WorldStorage;
use dojo::model::ModelStorage;
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct PlayerStats {
    #[key]
    pub player: ContractAddress,
    pub total_rounds: u64,
    pub rounds_won: u64,
    pub current_streak: u64,
    pub max_streak: u64,
    pub total_score: u64,
    pub average_score: u64,
    pub best_score: u64,
    pub total_correct_answers: u64,
    pub total_answers: u64,
    pub accuracy_rate: u64, // Stored as percentage (0-100)
}


#[generate_trait]
pub impl PlayerImpl of PlayerTrait {
    fn initialize_player_stats(ref world: WorldStorage, player: ContractAddress) {
        // Try to read existing player stats
        let player_stats: PlayerStats = world.read_model(player);

        // If this is a new player, initialize their stats
        if player_stats.total_rounds == 0
            && player_stats.rounds_won == 0
            && player_stats.current_streak == 0
            && player_stats.max_streak == 0
            && player_stats.total_score == 0
            && player_stats.average_score == 0
            && player_stats.best_score == 0
            && player_stats.total_correct_answers == 0
            && player_stats.total_answers == 0
            && player_stats.accuracy_rate == 0 {
            // Initialize with default values
            world
                .write_model(
                    @PlayerStats {
                        player,
                        total_rounds: 0,
                        rounds_won: 0,
                        current_streak: 0,
                        max_streak: 0,
                        total_score: 0,
                        average_score: 0,
                        best_score: 0,
                        total_correct_answers: 0,
                        total_answers: 0,
                        accuracy_rate: 0,
                    },
                );
        }
    }

    /// Updates player stats after a round completion
    fn update_player_stats(
        ref world: WorldStorage,
        player: ContractAddress,
        round_score: u64,
        correct_answers: u64,
        total_answers: u64,
    ) {
        let mut player_stats: PlayerStats = world.read_model(player);
        
        // Update basic stats
        player_stats.total_score += round_score;
        player_stats.total_correct_answers += correct_answers;
        player_stats.total_answers += total_answers;
        
        // Update best score if current round score is higher
        if round_score > player_stats.best_score {
            player_stats.best_score = round_score;
        }
        
        // Update average score
        player_stats.average_score = player_stats.total_score / (player_stats.total_rounds + 1);
        
        // Update accuracy rate (as percentage)
        if player_stats.total_answers > 0 {
            player_stats.accuracy_rate = (player_stats.total_correct_answers * 100) / player_stats.total_answers;
        }
        
        world.write_model(@player_stats);
    }
}


==============
//src/models/round.cairo
==============

use starknet::{ContractAddress};
use lyricsflip::models::card::{QuestionCard};
use lyricsflip::alias::ID;

use dojo::world::WorldStorage;
use dojo::model::ModelStorage;
use dojo::event::EventStorage;

use lyricsflip::constants::{GAME_ID};
use core::num::traits::Zero;
use starknet::{get_block_timestamp, contract_address_const};
use lyricsflip::models::player::{PlayerStats};

use lyricsflip::systems::actions::actions::RoundWinner;


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

            // Update winner's detailed stats
            let winner_round: RoundPlayer = world.read_model((winner, round_id));
            PlayerTrait::update_player_stats(
                ref world,
                winner,
                winner_round.total_score,
                winner_round.correct_answers,
                winner_round.total_answers,
            );

            world.write_model(@winner_stats);

            // Reset streaks for non-winners and update their stats
            for i in 0..players.len() {
                let player = *players[i];
                if player != winner {
                    let mut player_stats: PlayerStats = world.read_model(player);
                    let round_player: RoundPlayer = world.read_model((player, round_id));
                    player_stats.current_streak = 0;
                    
                    // Update non-winner's detailed stats
                    PlayerTrait::update_player_stats(
                        ref world,
                        player,
                        round_player.total_score,
                        round_player.correct_answers,
                        round_player.total_answers,
                    );
                    
                    world.write_model(@player_stats);
                }
            }
        }
        //TODO Emit winner event
        world.emit_event(@RoundWinner { round_id, winner, score: highest_score });
    }
}


==============
//src/tests/test_integration.cairo

================

use starknet::{testing};
use dojo::model::ModelStorage;
use lyricsflip::models::genre::Genre;
use lyricsflip::models::round::{Round, RoundPlayer, Answer};
use lyricsflip::models::player::{PlayerStats};
use lyricsflip::models::round::{RoundState, Mode};
use lyricsflip::systems::actions::{IActionsDispatcherTrait};

use lyricsflip::tests::test_utils::{setup_with_config, get_answers};

#[test]
#[available_gas(20000000000)]
fn test_full_game_flow_two_players() {
    // Setup players
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();

    let (mut world, actions_system) = setup_with_config();

    // 1. Player 1 creates a round
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Pop, Mode::MultiPlayer);

    // 2. Player 2 joins the round
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);

    // Verify both players are in the round
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'Should have 2 players');

    // 3. Both players signal readiness
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id);

    testing::set_contract_address(player_2);
    actions_system.start_round(round_id);

    // Verify round started
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Started.into(), 'Round should be started');

    // 4. Player 1 gets card and answers
    testing::set_contract_address(player_1);
    let question_card = actions_system.next_card(round_id);

    let (correct_option, wrong_option) = get_answers(ref world, round_id, player_1, @question_card);

    // Submit correct answer
    let is_correct = actions_system.submit_answer(round_id, correct_option.unwrap());
    assert(is_correct, 'Answer should be correct');

    // Verify player stats updated
    let player_1_data: RoundPlayer = world.read_model((player_1, round_id));
    assert(player_1_data.correct_answers == 1, 'Should have 1 correct answer');
    assert(player_1_data.total_score > 0, 'Should have score > 0');

    // 5. Player 2 gets the same card and answers incorrectly
    testing::set_contract_address(player_2);
    actions_system.next_card(round_id);

    // Submit incorrect answer
    let is_correct = actions_system.submit_answer(round_id, wrong_option);
    assert(!is_correct, 'Answer should be incorrect');

    // 6. Both players get second card
    testing::set_contract_address(player_1);
    let question_card = actions_system.next_card(round_id);
    let (correct_option, _) = get_answers(ref world, round_id, player_1, @question_card);

    let is_correct = actions_system.submit_answer(round_id, correct_option.unwrap());
    assert(is_correct, 'Answer should be correct');

    testing::set_contract_address(player_2);
    actions_system.next_card(round_id);

    let is_correct = actions_system.submit_answer(round_id, correct_option.unwrap());
    assert(is_correct, 'Answer should be correct');

    // Player_1 plays
    // fast forward to end of round
    testing::set_contract_address(player_1);
    for _ in 0..13_u64 {
        actions_system.next_card(round_id);
        actions_system.submit_answer(round_id, Answer::OptionOne);
    };
    // Player_2 plays
    // fast forward to end of round
    testing::set_contract_address(player_2);
    for _ in 0..13_u64 {
        actions_system.next_card(round_id);
        actions_system.submit_answer(round_id, Answer::OptionOne);
    };

    // 7. Verify round completed and winner determined
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Completed.into(), 'Round should be completed');

    // Player 1 should be winner (more correct answers)
    let player_1_stats: PlayerStats = world.read_model(player_1);
    assert(player_1_stats.rounds_won == 1, 'Player 1 should win');
    assert(player_1_stats.current_streak == 1, 'Player 1 should have streak');
    assert(player_1_stats.total_score > 0, 'Player 1 should have total score > 0');
    assert(player_1_stats.average_score > 0, 'Player 1 should have average score > 0');
    assert(player_1_stats.best_score > 0, 'Player 1 should have best score > 0');
    assert(player_1_stats.total_correct_answers > 0, 'Player 1 should have correct answers > 0');
    assert(player_1_stats.total_answers > 0, 'Player 1 should have total answers > 0');
    assert(player_1_stats.accuracy_rate > 0, 'Player 1 should have accuracy rate > 0');

    let player_2_stats: PlayerStats = world.read_model(player_2);
    assert(player_2_stats.rounds_won == 0, 'Player 2 should not win');
    assert(player_2_stats.current_streak == 0, 'Player 2 should have no streak');
    assert(player_2_stats.total_score > 0, 'Player 2 should have total score > 0');
    assert(player_2_stats.average_score > 0, 'Player 2 should have average score > 0');
    assert(player_2_stats.best_score > 0, 'Player 2 should have best score > 0');
    assert(player_2_stats.total_correct_answers > 0, 'Player 2 should have correct answers > 0');
    assert(player_2_stats.total_answers > 0, 'Player 2 should have total answers > 0');
    assert(player_2_stats.accuracy_rate > 0, 'Player 2 should have accuracy rate > 0');

    // Verify total scores are different
    assert(player_1_stats.total_score != player_2_stats.total_score, 'Players should have different total scores');
    
    // Verify accuracy rates are different
    assert(player_1_stats.accuracy_rate != player_2_stats.accuracy_rate, 'Players should have different accuracy rates');
    
    // Verify best scores are different
    assert(player_1_stats.best_score != player_2_stats.best_score, 'Players should have different best scores');
}

#[test]
fn test_timeout_mechanics() {
    // Setup players
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();
    let original_timestamp = 1000;

    let (mut world, actions_system) = setup_with_config();

    // Create and setup round
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::HipHop, Mode::MultiPlayer);

    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);

    // Start round
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id);
    testing::set_contract_address(player_2);
    actions_system.start_round(round_id);

    // Player 1 gets card
    testing::set_contract_address(player_1);
    testing::set_block_timestamp(original_timestamp);
    actions_system.next_card(round_id);

    // Set timestamp to simulate timeout (60 seconds + 1)
    testing::set_block_timestamp(original_timestamp + 61);
    // Answer after timeout
    let is_correct = actions_system.submit_answer(round_id, Answer::OptionOne);

    // Even though answer is correct, it should be marked incorrect due to timeout
    assert!(!is_correct, "Timed out answer should be incorrect");

    // Player 2 gets card and answers quickly
    testing::set_contract_address(player_2);
    testing::set_block_timestamp(original_timestamp);
    actions_system.next_card(round_id);

    // Answer within timeout (reset timestamp)
    let is_correct = actions_system.submit_answer(round_id, Answer::OptionOne);
    assert!(is_correct, "Answer within time should be correct");

    // Compare scores - player 2 should have higher score
    let player_1_data: RoundPlayer = world.read_model((player_1, round_id));
    let player_2_data: RoundPlayer = world.read_model((player_2, round_id));

    assert!(
        player_2_data.total_score > player_1_data.total_score,
        "Player answering within time should have higher score",
    );
}

#[test]
#[available_gas(20000000000)]
fn test_multi_round_streaks() {
    // Setup players
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();

    let (mut world, actions_system) = setup_with_config();

    // First round - player 1 wins
    testing::set_contract_address(player_1);
    let round_id_1 = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);

    testing::set_contract_address(player_2);
    actions_system.join_round(round_id_1);

    // Start round
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id_1);
    testing::set_contract_address(player_2);
    actions_system.start_round(round_id_1);

    // Player 1 gets card and answers correctly
    testing::set_contract_address(player_1);
    let question_card = actions_system.next_card(round_id_1);
    let (correct_option, wrong_option) = get_answers(
        ref world, round_id_1, player_1, @question_card,
    );

    actions_system.submit_answer(round_id_1, correct_option.unwrap());

    // Player 2 gets card and answers incorrectly
    testing::set_contract_address(player_2);
    actions_system.next_card(round_id_1);
    actions_system.submit_answer(round_id_1, wrong_option);

    // Player_1 plays
    // fast forward to end of round
    testing::set_contract_address(player_1);
    for _ in 0..14_u64 {
        actions_system.next_card(round_id_1);
        actions_system.submit_answer(round_id_1, Answer::OptionOne);
    };

    // Player_2 plays
    // fast forward to end of round
    testing::set_contract_address(player_2);
    for _ in 0..14_u64 {
        actions_system.next_card(round_id_1);
        actions_system.submit_answer(round_id_1, Answer::OptionOne);
    };

    // Verify player 1 wins round 1
    let player_1_stats: PlayerStats = world.read_model(player_1);
    assert(player_1_stats.rounds_won == 1, 'Player 1 should win round 1');
    assert(player_1_stats.current_streak == 1, 'Player 1 should have streak 1');
    let round_1_score = player_1_stats.total_score;
    assert(round_1_score > 0, 'Player 1 should have score > 0');

    // Second round - player 1 wins again
    testing::set_contract_address(player_1);
    let round_id_2 = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);

    testing::set_contract_address(player_2);
    actions_system.join_round(round_id_2);

    // Start round
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id_2);
    testing::set_contract_address(player_2);
    actions_system.start_round(round_id_2);

    // Player 1 gets card and answers correctly
    testing::set_contract_address(player_1);
    let question_card = actions_system.next_card(round_id_2);
    let (correct_option, wrong_option) = get_answers(
        ref world, round_id_2, player_1, @question_card,
    );

    actions_system.submit_answer(round_id_2, correct_option.unwrap());

    // Player 2 gets card and answers incorrectly
    testing::set_contract_address(player_2);
    actions_system.next_card(round_id_2);
    actions_system.submit_answer(round_id_2, wrong_option);

    // Player_1 plays
    // fast forward to end of round
    testing::set_contract_address(player_1);
    for _ in 0..14_u64 {
        actions_system.next_card(round_id_2);
        actions_system.submit_answer(round_id_2, Answer::OptionOne);
    };

    // Player_2 plays
    // fast forward to end of round
    testing::set_contract_address(player_2);
    for _ in 0..14_u64 {
        actions_system.next_card(round_id_2);
        actions_system.submit_answer(round_id_2, Answer::OptionOne);
    };

    // Verify player 1's streak increases and score accumulates
    let player_1_stats: PlayerStats = world.read_model(player_1);
    assert(player_1_stats.rounds_won == 2, 'Player 1 should win round 2');
    assert(player_1_stats.current_streak == 2, 'Player 1 streak should be 2');
    assert(player_1_stats.max_streak == 2, 'Player 1 max streak should be 2');
    assert(player_1_stats.total_score > round_1_score, 'Player 1 total score should increase');

    // Third round - player 2 wins
    testing::set_contract_address(player_1);
    let round_id_3 = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);

    testing::set_contract_address(player_2);
    actions_system.join_round(round_id_3);

    // Start round
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id_3);
    testing::set_contract_address(player_2);
    actions_system.start_round(round_id_3);

    // This time player 1 answers incorrectly
    testing::set_contract_address(player_1);
    let question_card = actions_system.next_card(round_id_3);
    let (correct_option, wrong_option) = get_answers(
        ref world, round_id_3, player_1, @question_card,
    );

    actions_system.submit_answer(round_id_3, wrong_option);

    // Player 2 answers correctly
    testing::set_contract_address(player_2);
    actions_system.next_card(round_id_3);
    actions_system.submit_answer(round_id_3, correct_option.unwrap());

    // Player_1 plays
    // fast forward to end of round
    testing::set_contract_address(player_1);
    for _ in 0..14_u64 {
        actions_system.next_card(round_id_3);
        actions_system.submit_answer(round_id_3, Answer::OptionOne);
    };

    // Player_2 plays
    // fast forward to end of round
    testing::set_contract_address(player_2);
    for _ in 0..14_u64 {
        actions_system.next_card(round_id_3);
        actions_system.submit_answer(round_id_3, Answer::OptionOne);
    };

    // Verify player 1's streak resets but max_streak remains and score accumulates
    let player_1_stats: PlayerStats = world.read_model(player_1);
    assert(player_1_stats.rounds_won == 2, 'Player 1 wins unchanged');
    assert(player_1_stats.current_streak == 0, 'Player 1 streak reset to 0');
    assert(player_1_stats.max_streak == 2, 'Player 1 max streak remains 2');
    let final_score = player_1_stats.total_score;
    assert(final_score > round_1_score, 'Player 1 total score should increase from round 1');

    // Verify player 2's stats
    let player_2_stats: PlayerStats = world.read_model(player_2);
    assert(player_2_stats.rounds_won == 1, 'Player 2 should win round 3');
    assert(player_2_stats.current_streak == 1, 'Player 2 streak should be 1');
    assert(player_2_stats.max_streak == 1, 'Player 2 max streak should be 1');
    assert(player_2_stats.total_score > 0, 'Player 2 should have total score > 0');
}

#[test]
#[available_gas(20000000000)]
fn test_full_game_flow_solo_mode() {
    // Setup players
    let player_1 = starknet::contract_address_const::<0x1>();

    let (mut world, actions_system) = setup_with_config();

    // 1. Player 1 creates a round
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Pop, Mode::Solo);

    // Verify one players are in round
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 1, 'Should have 1 player');

    // Verify round started
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Started.into(), 'Round should be started');

    // 4. Player 1 gets card and answers
    testing::set_contract_address(player_1);
    let question_card = actions_system.next_card(round_id);

    let (correct_option, _) = get_answers(ref world, round_id, player_1, @question_card);

    // Submit correct answer
    let is_correct = actions_system.submit_answer(round_id, correct_option.unwrap());
    assert(is_correct, 'Answer should be correct');

    // Verify player stats updated
    let player_1_data: RoundPlayer = world.read_model((player_1, round_id));
    assert(player_1_data.correct_answers == 1, 'Should have 1 correct answer');
    assert(player_1_data.total_score > 0, 'Should have score > 0');

    // 6. player gets second card
    testing::set_contract_address(player_1);
    let question_card = actions_system.next_card(round_id);
    let (correct_option, _) = get_answers(ref world, round_id, player_1, @question_card);

    let is_correct = actions_system.submit_answer(round_id, correct_option.unwrap());
    assert(is_correct, 'Answer should be correct');

    // Player_1 plays
    // fast forward to end of round
    testing::set_contract_address(player_1);
    for _ in 0..13_u64 {
        actions_system.next_card(round_id);
        actions_system.submit_answer(round_id, Answer::OptionOne);
    };

    // 7. Verify round completed and winner determined
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Completed.into(), 'Round should be completed');

    // Player 1 should be winner (more correct answers)
    let player_1_stats: PlayerStats = world.read_model(player_1);
    assert(player_1_stats.rounds_won == 1, 'Player 1 should win');
    assert(player_1_stats.current_streak == 1, 'Player 1 should have streak');
    assert(player_1_stats.total_score > 0, 'Player 1 should have total score > 0');
    assert(player_1_stats.average_score > 0, 'Player 1 should have average score > 0');
    assert(player_1_stats.best_score > 0, 'Player 1 should have best score > 0');
    assert(player_1_stats.total_correct_answers > 0, 'Player 1 should have correct answers > 0');
    assert(player_1_stats.total_answers > 0, 'Player 1 should have total answers > 0');
    assert(player_1_stats.accuracy_rate > 0, 'Player 1 should have accuracy rate > 0');

    // Verify round score matches total score
    let player_1_data: RoundPlayer = world.read_model((player_1, round_id));
    assert(player_1_stats.total_score == player_1_data.total_score, 'Total score should match round score');
    assert(player_1_stats.best_score == player_1_data.total_score, 'Best score should match round score');
    assert(player_1_stats.average_score == player_1_data.total_score, 'Average score should match round score');
}


