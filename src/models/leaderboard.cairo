use dojo::world::WorldStorage;
use dojo::model::ModelStorage;
use starknet::ContractAddress;
use lyricsflip::constants::GAME_ID;

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct LeaderboardConfig {
    #[key]
    pub id: felt252, // represents GAME_ID
    pub current_player_count: u64,
    pub min_score_to_qualify: u64,
}

#[generate_trait]
pub impl LeaderboardImpl of LeaderboardTrait {
    /// Gets the leaderboard configuration, initializing it with default values if not already set
    fn get_config(ref world: WorldStorage) -> LeaderboardConfig {
        // Try to read existing config
        let config: LeaderboardConfig = world.read_model(GAME_ID);

        // Check if config is uninitialized (both values are 0)
        if config.current_player_count == 0 && config.min_score_to_qualify == 0 {
            // Initialize with default values
            let default_config = LeaderboardConfig {
                id: GAME_ID,
                current_player_count: 0,
                min_score_to_qualify: 0,
            };
            world.write_model(@default_config);
            default_config
        } else {
            config
        }
    }
} 
