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
}



#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct PlayerRank {
    #[key]
    pub player: ContractAddress,
    pub score: u64,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct PlayerPerformance {
    pub win_rate: u64,        // Percentage (0-100)
    pub rounds_lost: u64,
    pub is_on_streak: bool,
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
            && player_stats.max_streak == 0 {
            // Initialize with default values
            world
                .write_model(
                    @PlayerStats {
                        player, total_rounds: 0, rounds_won: 0, current_streak: 0, max_streak: 0,
                    },
                );
        }
    }
}

#[generate_trait]
pub impl PlayerStatsImpl of PlayerStatsTrait {
    fn new(player: ContractAddress) -> PlayerStats {
        PlayerStats {
            player,
            total_rounds: 0,
            rounds_won: 0,
            current_streak: 0,
            max_streak: 0,
        }
    }
    
    fn is_new_player(self: @PlayerStats) -> bool;
    
    fn record_round(mut self: PlayerStats, won: bool) -> PlayerStats;
    
    fn record_win(self: PlayerStats) -> PlayerStats;
    
    fn record_loss(self: PlayerStats) -> PlayerStats;
    
    fn reset_streak(mut self: PlayerStats) -> PlayerStats;
    
    fn rounds_lost(self: @PlayerStats) -> u64;
    
    fn win_rate_percentage(self: @PlayerStats) -> u64;
    
    fn is_on_streak(self: @PlayerStats) -> bool;
    
    fn get_performance(self: @PlayerStats) -> PlayerPerformance;
    
    fn calculate_ranking_score(self: @PlayerStats) -> u64;
    
    fn to_rank(self: @PlayerStats) -> PlayerRank;
    
    fn is_valid(self: @PlayerStats) -> bool;
    
    fn ranks_higher_than(self: @PlayerStats, other: @PlayerStats) -> bool;
}
