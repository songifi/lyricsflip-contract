// The Test in the file should encompase:
// Player Creation: new(), address validation, initial state
// Game Recording: record_win(), record_loss(), record_round()
// Streak Management: Streak building, breaking, reset functionality
// Performance Metrics: Win rate calculation, loss tracking
// Ranking System: Score calculation, player comparison
// Data Validation: Internal consistency, constraint checking
// Edge Cases: New players, perfect records, boundary conditions

use lyricsflip::tests::test_utils::{setup_with_config};
use starknet::{ContractAddress, contract_address_const};
use lyricsflip::models::player::{PlayerStats, PlayerPerformance, PlayerRank, PlayerStatsTrait};


// Player Creation tests

#[test]
fn test_player_stats_new() {
    let player_address = contract_address_const::<1>();

    let player = PlayerStats::new(player_address);
    assert(player.total_rounds == 0, 'total_rounds should be 0');
    assert(player.rounds_won == 0, 'rounds_won should be 0');
    assert(player.current_streak == 0, 'current_streak should be 0');
    assert(player.max_streak == 0, 'max_streak should be 0');
}


#[test]
#[should_panic(expected: 'address cannot be zero')]
fn test_player_stats_new_zero_address() {
    let player_address = contract_address_const::<0>();
    let player = PlayerStats::new(player_address); // should panic
}

#[test]
fn test_player_stats_is_new_player() {
    let player_address = contract_address_const::<1>();
    let player = PlayerStats::new(player_address);
    assert(player.is_new_player(), 'player should be new');
}

// Game Recording tests

#[test]
fn test_player_stats_record_round_true() {
    let player_address = contract_address_const::<1>();
    let mut player = PlayerStats::new(player_address);
    player.record_round(true);
    assert(player.total_rounds == 1, 'total_rounds should be 1');
    assert(player.rounds_won == 1, 'rounds_won should be 1');
}

#[test]
fn test_player_stats_record_round_false() {
    let player_address = contract_address_const::<1>();
    let mut player = PlayerStats::new(player_address);
    player.record_round(false);
    assert(player.total_rounds == 1, 'total_rounds should be 1');
    assert(player.rounds_won == 0, 'rounds_won should be 0');
}

#[test]
fn test_player_stats_record_win() {
    let player_address = contract_address_const::<1>();
    let mut player = PlayerStats::new(player_address);
    player.record_win();
    assert(player.total_rounds == 1, 'total_rounds should be 1');
    assert(player.rounds_won == 1, 'rounds_won should be 1');
    assert(player.current_streak == 1, 'current_streak should be 1');
    assert(player.max_streak == 1, 'max_streak should be 1');
}

#[test]
fn test_player_stats_record_loss() {
    let player_address = contract_address_const::<1>();
    let mut player = PlayerStats::new(player_address);
    player.record_loss();
    assert(player.total_rounds == 1, 'total_rounds should be 1');
    assert(player.rounds_won == 0, 'rounds_won should be 0');
}

// Streak tests

#[test]
fn test_player_stats_win_streak() {
    let player_address = contract_address_const::<1>();
    let mut player = PlayerStats::new(player_address);
    player.record_win();
    player.record_win();
    player.record_win();
    assert(player.total_rounds == 3, 'total_rounds should be 3');
    assert(player.rounds_won == 3, 'rounds_won should be 3');
    assert(player.current_streak == 3, 'current_streak should be 3');
    assert(player.max_streak == 3, 'max_streak should be 3');
}

#[test]
fn test_player_stats_loss_streak() {
    let player_address = contract_address_const::<1>();
    let mut player = PlayerStats::new(player_address);
    player.record_win();
    player.record_win();
    player.record_loss();
    assert(player.total_rounds == 4, 'total_rounds should be 4');
    assert(player.rounds_won == 2, 'rounds_won should be 2');
    assert(player.current_streak == 0, 'current_streak should be 0');
    assert(player.max_streak == 2, 'max_streak should be 2');
}

#[test]
fn test_player_stats_streak_reset() {
    let player_address = contract_address_const::<1>();
    let mut player = PlayerStats::new(player_address);
    player.record_win();
    player.record_win();
    assert(player.total_rounds == 2, 'total_rounds should be 2');
    assert(player.rounds_won == 2, 'rounds_won should be 2');
    assert(player.current_streak == 2, 'current_streak should be 2');
    player.reset_streak();
    assert(player.current_streak == 0, 'current_streak should be 0');
    assert(player.max_streak == 2, 'max_streak should be 2');
}

#[test]
fn test_player_stats_is_on_streak() {
    let player_address = contract_address_const::<1>();
    let mut player = PlayerStats::new(player_address);
    player.record_win();
    player.record_win();
    player.record_win();
    assert(player.is_on_streak(), 'player should be on a streak');
    player.record_loss();
    assert(!player.is_on_streak(), 'player should not be on a streak');
}

// Performance Metrics tests

#[test]
fn test_player_stats_win_rate() {
    let player_address = contract_address_const::<1>();
    let mut player = PlayerStats::new(player_address);
    player.record_win();
    player.record_win();
    assert(player.win_rate_percentage() == 100, 'win rate should be 100');
}

#[test]
fn test_player_stats_win_rate_zero() {
    let player_address = contract_address_const::<1>();
    let mut player = PlayerStats::new(player_address);
    assert(player.win_rate_percentage() == 0, 'win rate should be 0');
}

#[test]
fn test_player_stats_win_rate_with_loss() {
    let player_address = contract_address_const::<1>();
    let mut player = PlayerStats::new(player_address);
    player.record_win();
    player.record_loss();
    assert(player.win_rate_percentage() == 50, 'win rate should be 50');
}

#[test]
fn test_player_stats_rounds_lost() {
    let player_address = contract_address_const::<1>();
    let mut player = PlayerStats::new(player_address);
    player.record_win();
    player.record_win();
    player.record_win();
    player.record_loss();
    player.record_loss();
    assert(player.rounds_lost() == 2, 'rounds lost should be 2');
}

#[test]
fn test_player_stats_rounds_lost_zero() {
    let player_address = contract_address_const::<1>();
    let mut player = PlayerStats::new(player_address);
    player.record_win();
    player.record_win();
    assert(player.rounds_lost() == 0, 'rounds lost should be 0');
}

#[test]
fn test_player_stats_get_performance() {
    let player_address = contract_address_const::<1>();
    let mut player = PlayerStats::new(player_address);
    player.record_win();
    player.record_win();
    player.record_loss();
    player.record_loss();
    let performance = player.get_performance();
    assert(performance.win_rate == 50, 'win rate should be 50');
    assert(performance.rounds_lost == 2, 'rounds lost should be 2');
    assert(!performance.is_on_streak, 'player should not be on a streak');
}
