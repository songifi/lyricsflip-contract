#[cfg(test)]
mod tests {
    use lyricsflip::models::round::{RoundPlayer};
    use lyricsflip::models::round_player::{RoundPlayerTrait, RoundPlayerValidation};
    use starknet::{contract_address_const, ContractAddress};
    use lyricsflip::alias::ID;

    fn create_test_player(
        ready_state: bool,
        round_completed: bool,
        current_card_start_time: u64,
        card_timeout: u64,
        next_card_index: u8,
    ) -> RoundPlayer {
        let player_address = contract_address_const::<'test_player'>();
        let round_id: ID = 1;

        RoundPlayer {
            player_to_round_id: (player_address, round_id),
            joined: true,
            ready_state,
            next_card_index,
            round_completed,
            current_card_start_time,
            card_timeout,
            correct_answers: 0,
            total_answers: 0,
            total_score: 0,
            best_time: 0,
        }
    }

    #[test]
    fn test_start_next_card_success() {
        let player = create_test_player(
            true,  // ready_state
            false, // round_completed
            0,     // current_card_start_time (no active card)
            30,    // card_timeout
            0,     // next_card_index
        );

        let start_time = 1000;
        let result = player.start_next_card(start_time);

        assert!(result.is_ok(), "Should successfully start next card");
        
        let updated_player = result.unwrap();
        assert_eq!(updated_player.current_card_start_time, start_time);
        assert_eq!(updated_player.next_card_index, 1);
    }

    #[test]
    fn test_start_next_card_player_not_ready() {
        let player = create_test_player(
            false, // ready_state (not ready)
            false, // round_completed
            0,     // current_card_start_time
            30,    // card_timeout
            0,     // next_card_index
        );

        let result = player.start_next_card(1000);
        
        assert!(result.is_err(), "Should fail when player not ready");
        assert_eq!(result.unwrap_err(), RoundPlayerValidation::PlayerNotReady);
    }

    #[test]
    fn test_start_next_card_round_completed() {
        let player = create_test_player(
            true, // ready_state
            true, // round_completed (completed)
            0,    // current_card_start_time
            30,   // card_timeout
            0,    // next_card_index
        );

        let result = player.start_next_card(1000);
        
        assert!(result.is_err(), "Should fail when round completed");
        assert_eq!(result.unwrap_err(), RoundPlayerValidation::RoundCompleted);
    }

    #[test]
    fn test_start_next_card_already_active() {
        let player = create_test_player(
            true, // ready_state
            false, // round_completed
            500,  // current_card_start_time (card already active)
            30,   // card_timeout
            1,    // next_card_index
        );

        let result = player.start_next_card(1000);
        
        assert!(result.is_err(), "Should fail when card already active");
        assert_eq!(result.unwrap_err(), RoundPlayerValidation::CardAlreadyActive);
    }

    #[test]
    fn test_is_answering_card_true() {
        let player = create_test_player(
            true, // ready_state
            false, // round_completed
            1000, // current_card_start_time (active card)
            30,   // card_timeout
            1,    // next_card_index
        );

        assert!(player.is_answering_card(), "Should return true when card is active");
    }

    #[test]
    fn test_is_answering_card_false() {
        let player = create_test_player(
            true, // ready_state
            false, // round_completed
            0,    // current_card_start_time (no active card)
            30,   // card_timeout
            0,    // next_card_index
        );

        assert!(!player.is_answering_card(), "Should return false when no active card");
    }

    #[test]
    fn test_current_card_timed_out_no_active_card() {
        let player = create_test_player(
            true, // ready_state
            false, // round_completed
            0,    // current_card_start_time (no active card)
            30,   // card_timeout
            0,    // next_card_index
        );

        let current_time = 2000;
        assert!(!player.current_card_timed_out(current_time), "Should return false when no active card");
    }

    #[test]
    fn test_current_card_timed_out_not_expired() {
        let player = create_test_player(
            true, // ready_state
            false, // round_completed
            1000, // current_card_start_time
            30,   // card_timeout (30 seconds)
            1,    // next_card_index
        );

        let current_time = 1020; // 20 seconds elapsed, within timeout
        assert!(!player.current_card_timed_out(current_time), "Should return false when within timeout");
    }

    #[test]
    fn test_current_card_timed_out_expired() {
        let player = create_test_player(
            true, // ready_state
            false, // round_completed
            1000, // current_card_start_time
            30,   // card_timeout (30 seconds)
            1,    // next_card_index
        );

        let current_time = 1035; // 35 seconds elapsed, beyond timeout
        assert!(player.current_card_timed_out(current_time), "Should return true when timed out");
    }

    #[test]
    fn test_current_card_timed_out_exact_timeout() {
        let player = create_test_player(
            true, // ready_state
            false, // round_completed
            1000, // current_card_start_time
            30,   // card_timeout (30 seconds)
            1,    // next_card_index
        );

        let current_time = 1030; // Exactly 30 seconds elapsed
        assert!(player.current_card_timed_out(current_time), "Should return true at exact timeout boundary");
    }

    #[test]
    fn test_current_card_timed_out_time_before_start() {
        let player = create_test_player(
            true, // ready_state
            false, // round_completed
            1000, // current_card_start_time
            30,   // card_timeout
            1,    // next_card_index
        );

        let current_time = 500; // Before start time (edge case)
        assert!(!player.current_card_timed_out(current_time), "Should handle time before start gracefully");
    }

    #[test]
    fn test_get_time_remaining_no_active_card() {
        let player = create_test_player(
            true, // ready_state
            false, // round_completed
            0,    // current_card_start_time (no active card)
            30,   // card_timeout
            0,    // next_card_index
        );

        let current_time = 2000;
        assert_eq!(player.get_time_remaining(current_time), 0, "Should return 0 when no active card");
    }

    #[test]
    fn test_get_time_remaining_within_timeout() {
        let player = create_test_player(
            true, // ready_state
            false, // round_completed
            1000, // current_card_start_time
            30,   // card_timeout (30 seconds)
            1,    // next_card_index
        );

        let current_time = 1020; // 20 seconds elapsed
        let expected_remaining = 10; // 30 - 20 = 10 seconds remaining
        assert_eq!(player.get_time_remaining(current_time), expected_remaining, "Should return correct remaining time");
    }

    #[test]
    fn test_get_time_remaining_timed_out() {
        let player = create_test_player(
            true, // ready_state
            false, // round_completed
            1000, // current_card_start_time
            30,   // card_timeout (30 seconds)
            1,    // next_card_index
        );

        let current_time = 1035; // 35 seconds elapsed, beyond timeout
        assert_eq!(player.get_time_remaining(current_time), 0, "Should return 0 when timed out");
    }

    #[test]
    fn test_get_time_remaining_exact_timeout() {
        let player = create_test_player(
            true, // ready_state
            false, // round_completed
            1000, // current_card_start_time
            30,   // card_timeout (30 seconds)
            1,    // next_card_index
        );

        let current_time = 1030; // Exactly 30 seconds elapsed
        assert_eq!(player.get_time_remaining(current_time), 0, "Should return 0 at exact timeout");
    }

    #[test]
    fn test_get_time_remaining_time_before_start() {
        let player = create_test_player(
            true, // ready_state
            false, // round_completed
            1000, // current_card_start_time
            30,   // card_timeout
            1,    // next_card_index
        );

        let current_time = 500; // Before start time (edge case)
        assert_eq!(player.get_time_remaining(current_time), 30, "Should return full timeout when time is before start");
    }

    #[test]
    fn test_get_time_remaining_full_timeout_at_start() {
        let player = create_test_player(
            true, // ready_state
            false, // round_completed
            1000, // current_card_start_time
            30,   // card_timeout
            1,    // next_card_index
        );

        let current_time = 1000; // Exactly at start time
        assert_eq!(player.get_time_remaining(current_time), 30, "Should return full timeout at start time");
    }

    #[test]
    fn test_card_index_increments_correctly() {
        let mut player = create_test_player(
            true, // ready_state
            false, // round_completed
            0,    // current_card_start_time
            30,   // card_timeout
            5,    // next_card_index (starting at 5)
        );

        let result = player.start_next_card(1000);
        assert!(result.is_ok(), "Should successfully start card");
        
        let updated_player = result.unwrap();
        assert_eq!(updated_player.next_card_index, 6, "Card index should increment by 1");
    }

    #[test]
    fn test_zero_timeout_handling() {
        let player = create_test_player(
            true, // ready_state
            false, // round_completed
            1000, // current_card_start_time
            0,    // card_timeout (zero timeout)
            1,    // next_card_index
        );

        let current_time = 1000; // Same as start time
        assert!(player.current_card_timed_out(current_time), "Should be timed out immediately with zero timeout");
        assert_eq!(player.get_time_remaining(current_time), 0, "Should have no time remaining with zero timeout");
    }
}
