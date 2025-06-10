use starknet::{contract_address_const};
use lyricsflip::models::leaderboard::{Leaderboard, TopPlayer, LeaderboardConfig, LeaderboardImpl};
use lyricsflip::tests::test_utils::{setup};
use dojo::model::ModelStorage;

#[test]
fn test_find_lowest_scoring_player() {
    // Setup world storage
    let mut world = setup();

    // Game ID
    let game_id: felt252 = 'v0';

    // Create mock players
    let player1 = contract_address_const::<0x1>();
    let player2 = contract_address_const::<0x2>();
    let player3 = contract_address_const::<0x3>();

    // Set up TopPlayer structs
    let top_player1 = TopPlayer {
        player: player1, total_score: 30, total_wins: 2, last_updated: 1,
    };
    let top_player2 = TopPlayer {
        player: player2, total_score: 200, total_wins: 3, last_updated: 2,
    };
    let top_player3 = TopPlayer {
        player: player3, total_score: 150, total_wins: 1, last_updated: 3,
    };

    world.write_model(@top_player1);
    world.write_model(@top_player2);
    world.write_model(@top_player3);

    // Set up the leaderboard span
    let players = array![player1, player2, player3];

    // Write leaderboard to world
    let leaderboard = Leaderboard { id: game_id, players: players.span() };
    world.write_model(@leaderboard);

    // // Set up leaderboard config (min_score_to_qualify = 120)
    let config = LeaderboardConfig {
        id: game_id, min_score_to_qualify: 50, current_player_count: 3,
    };
    world.write_model(@config);

    // function call
    let result = LeaderboardImpl::find_lowest_scoring_player(ref world, game_id);

    // Only player2 and player3 qualify (scores 200, 150). Player1 has the lowest qualifying score.
    assert(result == Option::Some(player1), 'Should return player1 as lowest');
}

#[test]
fn test_player_with_same_score() {
    // Setup world storage
    let mut world = setup();

    // Game ID
    let game_id: felt252 = 'v0';

    // Create mock players
    let player1 = contract_address_const::<0x1>();
    let player2 = contract_address_const::<0x2>();
    let player3 = contract_address_const::<0x3>();

    // Set up TopPlayer structs
    let top_player1 = TopPlayer {
        player: player1, total_score: 150, total_wins: 1, last_updated: 1,
    };
    let top_player2 = TopPlayer {
        player: player2, total_score: 200, total_wins: 3, last_updated: 2,
    };
    let top_player3 = TopPlayer {
        player: player3, total_score: 150, total_wins: 2, last_updated: 3,
    };

    world.write_model(@top_player1);
    world.write_model(@top_player2);
    world.write_model(@top_player3);

    // Set up the leaderboard span
    let players = array![player1, player2, player3];

    // Write leaderboard to world
    let leaderboard = Leaderboard { id: game_id, players: players.span() };
    world.write_model(@leaderboard);

    // // Set up leaderboard config (min_score_to_qualify = 120)
    let config = LeaderboardConfig {
        id: game_id, min_score_to_qualify: 50, current_player_count: 3,
    };
    world.write_model(@config);

    // function call
    let result = LeaderboardImpl::find_lowest_scoring_player(ref world, game_id);

    // Only player2 and player1 qualify (scores 200, 150). Player3 has the lowest qualifying score
    // due to last_updated.
    assert(result == Option::Some(player3), 'Should return player3 as lowest');
}

#[test]
fn test_no_players_in_leaderboard() {
    // Setup world storage
    let mut world = setup();

    // Game ID
    let game_id: felt252 = 'v0';

    // Set up the leaderboard span (empty)
    let players = array![];

    // Write leaderboard to world with no players
    let leaderboard = Leaderboard { id: game_id, players: players.span() };
    world.write_model(@leaderboard);

    // Set up leaderboard config (min_score_to_qualify = 50)
    let config = LeaderboardConfig {
        id: game_id, min_score_to_qualify: 50, current_player_count: 0,
    };
    world.write_model(@config);

    // function call
    let result = LeaderboardImpl::find_lowest_scoring_player(ref world, game_id);

    // Assert that result is None
    assert(result.is_none(), 'Should return None');
}


#[test]
fn test_get_config() {
    // Setup world storage
    let mut world = setup();

    let config: LeaderboardConfig = LeaderboardImpl::get_config(ref world);

    assert(config.min_score_to_qualify == 0, 'Default min score should be 0');
    assert(config.current_player_count == 0, 'Default count should be 0');
}
