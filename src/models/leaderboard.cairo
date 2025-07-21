use starknet::{ContractAddress, get_block_timestamp};
use dojo::world::WorldStorage;
use dojo::model::ModelStorage;
use core::array::{ArrayTrait, Array};

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

    fn update_leaderboard(
        ref world: WorldStorage,
        player: ContractAddress,
        player_total_score: u64, // Player's all-time total score
        player_total_wins: u64 // Player's all-time total wins
    ) {
        let timestamp = get_block_timestamp();

        // Check if player is already in leaderboard
        let mut existing_player: TopPlayer = world.read_model(player);
        let is_already_top_player = existing_player.last_updated > 0;

        if is_already_top_player {
            // Update existing TopPlayer entry
            existing_player.total_score = player_total_score;
            existing_player.total_wins = player_total_wins;
            existing_player.last_updated = timestamp;
            world.write_model(@existing_player);
        } else {
            // Add new TopPlayer entry
            let new_top_player = TopPlayer {
                player,
                total_score: player_total_score,
                total_wins: player_total_wins,
                last_updated: timestamp,
            };
            world.write_model(@new_top_player);
            // Add player to leaderboard span if not present
            let mut leaderboard: Leaderboard = world.read_model(GAME_ID);
            let players_span = leaderboard.players;
            let mut players_array: Array<ContractAddress> = ArrayTrait::new();
            let mut found = false;
            for i in 0..players_span.len() {
                let addr = *players_span[i];
                if addr == player {
                    found = true;
                }
                players_array.append(addr);
            };
            if !found {
                players_array.append(player);
                leaderboard.players = players_array.span();
                world.write_model(@leaderboard);
            }
        }
    }
}

