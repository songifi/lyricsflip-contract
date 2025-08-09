use starknet::ContractAddress;
use core::num::traits::Zero;

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
pub impl PlayerStatsImpl of PlayerStatsTrait {
    fn new(player: ContractAddress) -> PlayerStats {
        assert(player != Zero::zero(), 'address cannot be zero');
        PlayerStats { player, total_rounds: 0, rounds_won: 0, current_streak: 0, max_streak: 0 }
    }

    fn is_new_player(self: @PlayerStats) -> bool {
        *self.total_rounds == 0
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
        let player_stats = self.record_round(true);
        player_stats
    }

    fn record_loss(self: PlayerStats) -> PlayerStats {
        let player_stats = self.record_round(false);
        player_stats
    }

    fn reset_streak(mut self: PlayerStats) -> PlayerStats {
        self.current_streak = 0;
        self
    }

    fn rounds_lost(self: @PlayerStats) -> u64 {
        *self.total_rounds - *self.rounds_won
    }

    fn win_rate_percentage(self: @PlayerStats) -> u64 {
        if *self.total_rounds == 0 {
            0
        } else {
            *self.rounds_won * 100 / *self.total_rounds
        }
    }

    fn is_on_streak(self: @PlayerStats) -> bool {
        *self.current_streak > 0
    }

    fn get_performance(self: @PlayerStats) -> PlayerPerformance {
        PlayerPerformance {
            win_rate: self.win_rate_percentage(),
            rounds_lost: self.rounds_lost(),
            is_on_streak: self.is_on_streak(),
        }
    }

    fn calculate_ranking_score(self: @PlayerStats) -> u64 {
        *self.rounds_won * 10 + *self.max_streak * 5 + self.win_rate_percentage()
    }

    fn to_rank(self: @PlayerStats) -> PlayerRank {
        PlayerRank { player: *self.player, score: self.calculate_ranking_score() }
    }

    fn is_valid(self: @PlayerStats) -> bool {
        *self.total_rounds >= *self.rounds_won
            && *self.current_streak <= *self.max_streak
            && *self.max_streak <= *self.rounds_won
            && *self.player != Zero::zero()
    }

    fn ranks_higher_than(self: @PlayerStats, other: @PlayerStats) -> bool {
        self.calculate_ranking_score() > other.calculate_ranking_score()
    }
}

#[cfg(test)]
mod tests {
    use starknet::contract_address_const;
    use super::{PlayerStatsImpl, PlayerStatsTrait};


    #[test]
    fn test_player_stats_new() {
        let player_address = contract_address_const::<1>();

        let player = PlayerStatsTrait::new(player_address);
        assert(player.total_rounds == 0, 'total_rounds should be 0');
        assert(player.rounds_won == 0, 'rounds_won should be 0');
        assert(player.current_streak == 0, 'current_streak should be 0');
        assert(player.max_streak == 0, 'max_streak should be 0');
    }


    #[test]
    #[should_panic(expected: 'address cannot be zero')]
    fn test_player_stats_new_zero_address() {
        let player_address = contract_address_const::<0>();
        PlayerStatsTrait::new(player_address); // should panic
    }

    #[test]
    fn test_player_stats_is_new_player() {
        let player_address = contract_address_const::<1>();
        let player = PlayerStatsTrait::new(player_address);
        assert(player.is_new_player(), 'player should be new');
    }

    // Game Recording tests

    #[test]
    fn test_player_stats_record_round_true() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        let player = player.record_round(true);
        assert(player.total_rounds == 1, 'total_rounds should be 1');
        assert(player.rounds_won == 1, 'rounds_won should be 1');
    }

    #[test]
    fn test_player_stats_record_round_false() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        let player = player.record_round(false);
        assert(player.total_rounds == 1, 'total_rounds should be 1');
        assert(player.rounds_won == 0, 'rounds_won should be 0');
    }

    #[test]
    fn test_player_stats_record_win() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        let player = player.record_win();
        assert(player.total_rounds == 1, 'total_rounds should be 1');
        assert(player.rounds_won == 1, 'rounds_won should be 1');
        assert(player.current_streak == 1, 'current_streak should be 1');
        assert(player.max_streak == 1, 'max_streak should be 1');
    }

    #[test]
    fn test_player_stats_record_loss() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        let player = player.record_loss();
        assert(player.total_rounds == 1, 'total_rounds should be 1');
        assert(player.rounds_won == 0, 'rounds_won should be 0');
    }

    // Streak tests

    #[test]
    fn test_player_stats_win_streak() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        let player = player.record_win();
        let player = player.record_win();
        let player = player.record_win();
        assert(player.total_rounds == 3, 'total_rounds should be 3');
        assert(player.rounds_won == 3, 'rounds_won should be 3');
        assert(player.current_streak == 3, 'current_streak should be 3');
        assert(player.max_streak == 3, 'max_streak should be 3');
    }

    #[test]
    fn test_player_stats_loss_streak() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        let player = player.record_win();
        let player = player.record_win();
        let player = player.record_loss();
        assert(player.total_rounds == 3, 'total_rounds should be 3');
        assert(player.rounds_won == 2, 'rounds_won should be 2');
        assert(player.current_streak == 0, 'current_streak should be 0');
        assert(player.max_streak == 2, 'max_streak should be 2');
    }

    #[test]
    fn test_player_stats_streak_reset() {
        let player_address = contract_address_const::<1>();
        let player = PlayerStatsTrait::new(player_address);
        let mut player = player.record_win();
        let player = player.record_win();
        assert(player.total_rounds == 2, 'total_rounds should be 2');
        assert(player.rounds_won == 2, 'rounds_won should be 2');
        assert(player.current_streak == 2, 'current_streak should be 2');
        let player = player.reset_streak();
        assert(player.current_streak == 0, 'current_streak should be 0');
        assert(player.max_streak == 2, 'max_streak should be 2');
    }

    #[test]
    fn test_player_stats_is_on_streak() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        let player = player.record_win();
        let player = player.record_win();
        let player = player.record_win();
        assert(player.is_on_streak(), 'player should be on a streak');
        let player = player.record_loss();
        assert(!player.is_on_streak(), 'no streak should be on');
    }

    // Performance Metrics tests

    #[test]
    fn test_player_stats_win_rate() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        let player = player.record_win();
        let player = player.record_win();
        assert(player.win_rate_percentage() == 100, 'win rate should be 100');
    }

    #[test]
    fn test_player_stats_win_rate_zero() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        assert(player.win_rate_percentage() == 0, 'win rate should be 0');
    }

    #[test]
    fn test_player_stats_win_rate_with_loss() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        let player = player.record_win();
        let player = player.record_loss();
        assert(player.win_rate_percentage() == 50, 'win rate should be 50');
    }

    #[test]
    fn test_player_stats_rounds_lost() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        let player = player.record_win();
        let player = player.record_win();
        let player = player.record_win();
        let player = player.record_loss();
        let player = player.record_loss();
        assert(player.rounds_lost() == 2, 'rounds lost should be 2');
    }

    #[test]
    fn test_player_stats_rounds_lost_zero() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        let player = player.record_win();
        let player = player.record_win();
        assert(player.rounds_lost() == 0, 'rounds lost should be 0');
    }

    #[test]
    fn test_player_stats_get_performance() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        let player = player.record_win();
        let player = player.record_win();
        let player = player.record_loss();
        let player = player.record_loss();
        let performance = player.get_performance();
        assert(performance.win_rate == 50, 'win rate should be 50');
        assert(performance.rounds_lost == 2, 'rounds lost should be 2');
        assert(!performance.is_on_streak, 'no streak should be on');
    }

    // Ranking System tests

    #[test]
    fn test_player_stats_calculate_ranking_score() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        let player = player.record_win();
        let player = player.record_win();
        let player = player.record_loss();
        let player = player.record_loss();
        assert(player.calculate_ranking_score() == 80, 'ranking score should be 20');
    }

    #[test]
    fn test_player_stats_to_rank() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        let player = player.record_win();
        let player = player.record_win();
        let player = player.record_loss();
        let player = player.record_loss();
        let rank = player.to_rank();
        assert(rank.score == 80, 'ranking score should be 20');
    }

    // Data Validation tests

    #[test]
    fn test_player_stats_is_valid() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        let player = player.record_win();
        let player = player.record_win();
        let player = player.record_loss();
        assert(player.is_valid(), 'player should be valid');
    }

    #[test]
    fn test_player_stats_is_not_valid_with_rounds_won_greater_than_total_rounds() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        let mut player = player.record_win();
        let mut player = player.record_win();
        player.rounds_won = 3;
        assert(!player.is_valid(), 'player should not be valid');
    }

    #[test]
    fn test_player_stats_is_not_valid_with_zero_address() {
        let player_address = contract_address_const::<1>();
        let mut player = PlayerStatsTrait::new(player_address);
        player.player = contract_address_const::<0>();
        assert(!player.is_valid(), 'player should not be valid');
    }

    #[test]
    fn test_player_stats_ranks_higher_than() {
        let player_address = contract_address_const::<1>();
        let player_address2 = contract_address_const::<2>();
        let mut player = PlayerStatsTrait::new(player_address);
        let mut player2 = PlayerStatsTrait::new(player_address2);
        let player = player.record_win();
        let player = player.record_win();
        let player = player.record_loss();
        let player2 = player2.record_win();
        let player2 = player2.record_loss();
        let player2 = player2.record_loss();
        assert(player.ranks_higher_than(@player2), 'rank higher than player2');
    }
}
