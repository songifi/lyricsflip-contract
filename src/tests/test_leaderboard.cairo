use dojo::model::ModelStorage;
use dojo::world::{WorldStorageTrait};
use lyricsflip::constants::GAME_ID;
use lyricsflip::models::leaderboard::{LeaderboardConfig, LeaderboardTrait};
use lyricsflip::tests::test_utils::{setup};

#[test]
fn test_leaderboard_config_lazy_init() {
    let mut world = setup();

    // First access should initialize with default values
    let config = LeaderboardTrait::get_config(ref world);
    assert(config.current_player_count == 0, 'Initial player count should be 0');
    assert(config.min_score_to_qualify == 0, 'Initial min score should be 0');

    // Second access should return the same config
    let config2 = LeaderboardTrait::get_config(ref world);
    assert(config2.current_player_count == 0, 'Second access should maintain player count');
    assert(config2.min_score_to_qualify == 0, 'Second access should maintain min score');

    // Verify the config was actually written to storage
    let stored_config: LeaderboardConfig = world.read_model(GAME_ID);
    assert(stored_config.current_player_count == 0, 'Stored player count should be 0');
    assert(stored_config.min_score_to_qualify == 0, 'Stored min score should be 0');
} 