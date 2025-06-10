use starknet::{ContractAddress};
use dojo::world::WorldStorage;
use dojo::model::ModelStorage;

use lyricsflip::constants::{GAME_ID};

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct TopPlayer {
    #[key]
    pub player: ContractAddress,
    pub total_score: u64,
    pub total_wins: u64,
    pub last_updated: u64,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct LeaderboardConfig {
    #[key]
    pub id: felt252, // represents GAME_ID
    pub min_score_to_qualify: u64, // Minimum score needed to be in top 50
    pub current_player_count: u32,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Leaderboard {
    #[key]
    pub id: felt252, // represents GAME_ID
    pub players: Span<ContractAddress>,
}


#[generate_trait]
pub impl LeaderboardImpl of LeaderboardTrait {
    fn find_lowest_scoring_player(
        ref world: WorldStorage, game_id: felt252,
    ) -> Option<ContractAddress> {
        let leaderboard: Leaderboard = world.read_model(game_id);
        let default_config: LeaderboardConfig = world.read_model(game_id);
        let default_config_score = @default_config.min_score_to_qualify;

        let players = leaderboard.players;
        if players.len() == 0 {
            return Option::None;
        }
        let mut lowest_scoring_player = players[0];
        for player in players {
            let player_data: TopPlayer = world.read_model(*player);
            let lowest_data: TopPlayer = world.read_model(*lowest_scoring_player);
            if player_data.total_score >= *default_config_score {
                if player_data.total_score < lowest_data.total_score {
                    lowest_scoring_player = player;
                } else if player_data.total_score == lowest_data.total_score {
                    if player_data.last_updated < lowest_data.last_updated {
                        lowest_scoring_player = @lowest_data.player;
                    } else {
                        lowest_scoring_player = @player_data.player;
                    }
                }
            }
        };
        Option::Some(*lowest_scoring_player)
    }

    fn get_config(ref world: WorldStorage) -> LeaderboardConfig {
        let mut config: LeaderboardConfig = world.read_model(GAME_ID);

        // Check if config exists (uninitialized configs have both values as 0)
        if config.current_player_count == 0 && config.min_score_to_qualify == 0 {
            // initialize with defaults
            config =
                LeaderboardConfig {
                    id: GAME_ID,
                    min_score_to_qualify: 0, // Will be set when first player added
                    current_player_count: 0,
                };
            world.write_model(@config);
        }

        config
    }
}

