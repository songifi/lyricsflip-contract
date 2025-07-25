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
    pub win_rate: u64, // Percentage (0-100)
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
        assert(player.is_not_zero(), 'address cannot be zero');
        PlayerStats { player, total_rounds: 0, rounds_won: 0, current_streak: 0, max_streak: 0 }
    }

    fn is_new_player(self: @PlayerStats) -> bool {
        self.total_rounds == 0
    }

    fn record_round(mut self: PlayerStats, won: bool) -> PlayerStats {
        self.total_rounds += 1;
        if won {
            self.rounds_won += 1;
            self.current_streak += 1;
            if self.current_streak > self.max_streak {
                self.max_streak = self.current_streak;
            }
        } else {
            self.current_streak = 0;
        }
        self
    }

    fn record_win(self: PlayerStats) -> PlayerStats {
        self.record_round(true);
        self
    }

    fn record_loss(self: PlayerStats) -> PlayerStats {
        self.record_round(false);
        self
    }

    fn reset_streak(mut self: PlayerStats) -> PlayerStats {
        self.current_streak = 0;
        self
    }

    fn rounds_lost(self: @PlayerStats) -> u64 {
        self.total_rounds - self.rounds_won
    }

    fn win_rate_percentage(self: @PlayerStats) -> u64 {
        if self.total_rounds == 0 {
            0
        } else {
            self.rounds_won * 100 / self.total_rounds
        }
    }

    fn is_on_streak(self: @PlayerStats) -> bool {
        self.current_streak > 0
    }

    fn get_performance(self: @PlayerStats) -> PlayerPerformance {
        PlayerPerformance {
            win_rate: self.win_rate_percentage(),
            rounds_lost: self.rounds_lost(),
            is_on_streak: self.is_on_streak(),
        }
    }

    fn calculate_ranking_score(self: @PlayerStats) -> u64 {
        self.rounds_won * 10 + self.max_streak * 5 + self.win_rate_percentage()
    }

    fn to_rank(self: @PlayerStats) -> PlayerRank {
        PlayerRank { player: self.player, score: self.calculate_ranking_score() }
    }

    fn is_valid(self: @PlayerStats) -> bool {
        self.total_rounds > 0
    }

    fn ranks_higher_than(self: @PlayerStats, other: @PlayerStats) -> bool {
        self.calculate_ranking_score() > other.calculate_ranking_score()
    }
}
