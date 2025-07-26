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

