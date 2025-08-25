use lyricsflip::constants::{CardIndex, RoundId};
use lyricsflip::models::game_types::Answer;
use starknet::ContractAddress;
use core::num::traits::Zero;

/// Player participation in a specific round
#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct RoundPlayer {
    #[key]
    pub player_to_round_id: (ContractAddress, RoundId),
    pub joined: bool,
    pub ready_state: bool,
    pub next_card_index: CardIndex,
    pub round_completed: bool,
    pub current_card_start_time: u64,
    pub card_timeout: u64,
    pub correct_answers: u64,
    pub total_answers: u64,
    pub total_score: u64,
    pub best_time: u64, // Best answer time in seconds
    pub average_time: u64,
}

/// Player performance summary for a round
#[derive(Copy, Drop, Serde, Debug)]
pub struct RoundPlayerPerformance {
    pub accuracy_percentage: u64, // 0-100
    pub wrong_answers: u64,
    pub completion_percentage: u64, // 0-100
    pub cards_remaining: u64,
    pub is_leading: bool,
}

/// Round player validation results
#[derive(Copy, Drop, Serde, Debug)]
pub struct RoundPlayerValidation {
    pub is_valid: bool,
    pub error_message: felt252,
}

/// Answer submission result
#[derive(Copy, Drop, Serde, Debug)]
pub struct AnswerResult {
    pub is_correct: bool,
    pub time_taken: u64,
    pub score_earned: u64,
    pub timed_out: bool,
}

#[generate_trait]
pub impl RoundPlayerImpl of RoundPlayerTrait {
    fn new(
        player: ContractAddress, round_id: RoundId, card_timeout: u64,
    ) -> Result<RoundPlayer, RoundPlayerValidation> {
        if player.is_zero() {
            return Result::Err(
                RoundPlayerValidation { is_valid: false, error_message: 'Invalid player address' },
            );
        }

        if round_id.is_zero() {
            return Result::Err(
                RoundPlayerValidation { is_valid: false, error_message: 'Invalid round ID' },
            );
        }

        let player = RoundPlayer {
            player_to_round_id: (player, round_id),
            joined: true,
            ready_state: false,
            next_card_index: 0,
            round_completed: false,
            current_card_start_time: 0,
            card_timeout,
            correct_answers: 0,
            total_answers: 0,
            total_score: 0,
            best_time: 0,
            average_time: 0,
        };

        Result::Ok(player)
    }

    /// Marks player as ready
    fn mark_ready(
        self: @RoundPlayer, ready_time: u64,
    ) -> Result<RoundPlayer, RoundPlayerValidation> {
        if *self.ready_state {
            return Result::Err(
                RoundPlayerValidation { is_valid: false, error_message: 'Player marked as ready' },
            );
        }

        if !*self.joined {
            return Result::Err(
                RoundPlayerValidation { is_valid: false, error_message: 'Player not in round' },
            );
        }

        let mut new_player = *self;
        new_player.ready_state = true;

        Result::Ok(new_player)
    }

    /// Marks the round as completed for this player
    fn complete_round(self: @RoundPlayer) -> Result<RoundPlayer, RoundPlayerValidation> {
        if *self.round_completed {
            return Result::Err(
                RoundPlayerValidation { is_valid: false, error_message: 'Round already completed' },
            );
        }

        let mut new_player = *self;
        new_player.round_completed = true;
        new_player.current_card_start_time = 0; // Clear any active card

        Result::Ok(new_player)
    }

    fn calculate_answer_score(time_taken: u64, timeout: u64) -> u64 {
        if time_taken >= timeout {
            return 0;
        }
        let base_score: u64 = 100;

        // Calculate time bonus
        let time_bonus = ((timeout - time_taken) * 100) / timeout;
        base_score + time_bonus
    }

    fn calculate_average_time(current_avg: u64, total_answers: u64, new_time: u64) -> u64 {
        if total_answers == 0 {
            // First answer case
            return new_time;
        }

        ((current_avg * total_answers) + new_time) / (total_answers + 1)
    }

    fn get_accuracy_percentage(self: @RoundPlayer) -> u64 {
        if *self.total_answers == 0 {
            return 0;
        }
        (*self.correct_answers * 100) / *self.total_answers
    }

    fn get_completion_percentage(self: @RoundPlayer, total_cards: u64) -> u64 {
        if *self.total_answers == 0 {
            return 0;
        }
        (*self.total_answers * 100) / total_cards
    }

    fn get_wrong_answers(self: @RoundPlayer) -> u64 {
        *self.total_answers - *self.correct_answers
    }

    fn get_cards_remaining(self: @RoundPlayer, total_cards: u64) -> u64 {
        if *self.total_answers == 0 {
            return total_cards;
        }
        if (*self.total_answers).into() >= total_cards {
            return 0;
        }
        total_cards - *self.total_answers
    }

    fn submit_answer(
        self: @RoundPlayer, current_time: u64, is_correct: bool,
    ) -> Result<(RoundPlayer, AnswerResult), RoundPlayerValidation> {
        // Validate that player has an active card
        if *self.current_card_start_time == 0 {
            return Result::Err(
                RoundPlayerValidation {
                    is_valid: false, error_message: 'No active card to submit answer',
                },
            );
        }

        // Validate that round is not completed
        if *self.round_completed {
            return Result::Err(
                RoundPlayerValidation {
                    is_valid: false, error_message: 'Round is already completed',
                },
            );
        }

        // Validate current_time is not before card start time
        if current_time < *self.current_card_start_time {
            return Result::Err(
                RoundPlayerValidation { is_valid: false, error_message: 'Invalid time for answer' },
            );
        }

        // Calculate time taken
        let time_taken = current_time - *self.current_card_start_time;

        // Check for timeout - timeout overrides correct answers
        let timed_out = time_taken >= *self.card_timeout;
        let final_is_correct = is_correct && !timed_out;

        // Calculate score using existing helper function
        let score_earned = if final_is_correct {
            Self::calculate_answer_score(time_taken, *self.card_timeout)
        } else {
            0
        };

        // Create updated player state
        let mut updated_player = *self;

        // Update statistics - total answers always incremented
        updated_player.total_answers += 1;

        // Increment correct answers only for correct submissions
        if final_is_correct {
            updated_player.correct_answers += 1;
        }

        // Add earned score to total
        updated_player.total_score += score_earned;

        // Update best time only for correct, non-timed-out answers
        if final_is_correct && !timed_out {
            if updated_player.best_time == 0 || time_taken < updated_player.best_time {
                updated_player.best_time = time_taken;
            }
        }

        // Update average time for all submissions using existing helper
        updated_player
            .average_time =
                Self::calculate_average_time(
                    updated_player.average_time,
                    updated_player.total_answers - 1, // Previous total count
                    time_taken,
                );

        // Clear active card state after submission
        updated_player.current_card_start_time = 0;

        // Create answer result
        let answer_result = AnswerResult {
            is_correct: final_is_correct, time_taken, score_earned, timed_out,
        };

        Result::Ok((updated_player, answer_result))
    }

    fn force_timeout(
        self: @RoundPlayer, current_time: u64,
    ) -> Result<(RoundPlayer, AnswerResult), RoundPlayerValidation> {
        // Validate that player has an active card
        if *self.current_card_start_time == 0 {
            return Result::Err(
                RoundPlayerValidation {
                    is_valid: false, error_message: 'No active card to force timeout',
                },
            );
        }

        // Validate that round is not completed
        if *self.round_completed {
            return Result::Err(
                RoundPlayerValidation {
                    is_valid: false, error_message: 'Round is already completed',
                },
            );
        }

        // Validate current_time is not before card start time
        if current_time < *self.current_card_start_time {
            return Result::Err(
                RoundPlayerValidation {
                    is_valid: false, error_message: 'Invalid time for timeout action',
                },
            );
        }

        // Calculate time taken
        let time_taken = current_time - *self.current_card_start_time;

        // Create updated player state
        let mut updated_player = *self;

        // Update statistics - forced timeout is always incorrect
        updated_player.total_answers += 1;
        // No increment to correct_answers since it's timed out
        // No score earned for timed out answers (score remains 0)

        // Update average time for all submissions including timeouts
        updated_player
            .average_time =
                Self::calculate_average_time(
                    updated_player.average_time,
                    updated_player.total_answers - 1, // Previous total count
                    time_taken,
                );

        // Clear active card state after timeout
        updated_player.current_card_start_time = 0;

        // Create answer result - forced timeout is always incorrect
        let answer_result = AnswerResult {
            is_correct: false, time_taken, score_earned: 0, timed_out: true,
        };

        Result::Ok((updated_player, answer_result))
    }
}


#[cfg(test)]
mod tests {
    use lyricsflip::models::game_types::Answer;
    use starknet::{contract_address_const, ContractAddress};
    use super::{RoundPlayer, RoundPlayerTrait};

    const ROUND_ID: u64 = 1;
    const CARD_TIMEOUT: u64 = 60;

    fn player() -> starknet::ContractAddress {
        contract_address_const::<'player'>()
    }

    fn create_round_player() -> RoundPlayer {
        RoundPlayerTrait::new(player(), ROUND_ID, CARD_TIMEOUT).unwrap()
    }

    #[test]
    fn test_new_round_player_zero_id() {
        let result = RoundPlayerTrait::new(player(), 0, CARD_TIMEOUT);

        assert!(result.is_err(), "Should reject zero round ID");
        let error = result.unwrap_err();
        assert_eq!(error.error_message, 'Invalid round ID');
    }

    #[test]
    fn test_new_round_player_zero_player_address() {
        let result = RoundPlayerTrait::new(0.try_into().unwrap(), ROUND_ID, CARD_TIMEOUT);

        assert!(result.is_err(), "Should reject zero player address");
        let error = result.unwrap_err();
        assert_eq!(error.error_message, 'Invalid player address');
    }

    #[test]
    fn test_round_player_creation() {
        let round_player = create_round_player();
        let (player, round_id) = round_player.player_to_round_id;

        assert(round_player.joined, 'Should be joined');
        assert(!round_player.ready_state, 'Should not be ready initially');
        assert(round_player.next_card_index == 0, 'Should start at card 0');
        assert(!round_player.round_completed, 'Should not be completed');
        assert(round_player.card_timeout == CARD_TIMEOUT, 'Wrong timeout');
        // assert(player == player(), 'Wrong player'); // TODO: use get_player() once available
        assert(round_id == ROUND_ID, 'Wrong round ID');
    }

    #[test]
    fn test_mark_ready() {
        let round_player = create_round_player();
        let result = round_player.mark_ready(1000);

        assert(result.is_ok(), 'Marking ready should succeed');
        let round_player = result.unwrap();
        assert(round_player.ready_state, 'Should be ready');
    }

    #[test]
    fn test_mark_ready_twice() {
        let round_player = create_round_player();
        let round_player = round_player.mark_ready(1000).unwrap();

        let result = round_player.mark_ready(1001);
        assert(result.is_err(), 'Marking ready twice should fail');
    }

    #[test]
    fn test_complete_round() {
        let round_player = create_round_player();
        let result = round_player.complete_round();
        assert(result.is_ok(), 'Completing round should succeed');

        let round_player = result.unwrap();
        assert(round_player.round_completed, 'Should be completed');
        assert(round_player.current_card_start_time == 0, 'Should clear active card');
    }

    #[test]
    fn test_get_accuracy_percentage() {
        let player = create_round_player();
        assert_eq!(player.get_accuracy_percentage(), 0);

        let mut player = player;
        player.correct_answers = 5;
        player.total_answers = 10;
        assert_eq!(player.get_accuracy_percentage(), 50);
    }

    #[test]
    fn test_get_accuracy_percentage_zero_answers() {
        let player = create_round_player();
        assert_eq!(player.get_accuracy_percentage(), 0);
    }


    #[test]
    fn test_get_completion_percentage() {
        let player = create_round_player();
        assert_eq!(player.get_completion_percentage(10), 0);

        let mut player = player;
        player.total_answers = 5;
        assert_eq!(player.get_completion_percentage(10), 50);
    }

    #[test]
    fn test_get_completion_percentage_zero_answers() {
        let player = create_round_player();
        assert_eq!(player.get_completion_percentage(10), 0);
    }

    #[test]
    fn test_get_wrong_answers() {
        let player = create_round_player();
        assert_eq!(player.get_wrong_answers(), 0);

        let mut player = player;
        player.correct_answers = 3;
        player.total_answers = 5;
        assert_eq!(player.get_wrong_answers(), 2);
    }

    #[test]
    fn test_get_cards_remaining() {
        let player = create_round_player();
        assert_eq!(player.get_cards_remaining(10), 10);

        let mut player = player;
        player.total_answers = 5;
        assert_eq!(player.get_cards_remaining(10), 5);

        player.total_answers = 10;
        assert_eq!(player.get_cards_remaining(10), 0);
    }

    #[test]
    fn test_get_cards_remaining_zero_answers() {
        let player = create_round_player();
        assert_eq!(player.get_cards_remaining(10), 10);
    }

    #[test]
    fn test_calculate_answer_score() {
        // Test timeout case
        assert_eq!(RoundPlayerTrait::calculate_answer_score(60, 60), 0);
        assert_eq!(RoundPlayerTrait::calculate_answer_score(61, 60), 0);

        // Test instant answer (maximum score)
        assert_eq!(RoundPlayerTrait::calculate_answer_score(0, 60), 200);

        // Test mid-range cases
        // At 30 seconds (half timeout), should get 150 points (base 100 + half bonus)
        assert_eq!(RoundPlayerTrait::calculate_answer_score(30, 60), 150);

        // At 45 seconds (3/4 timeout), should get 125 points (base 100 + quarter bonus)
        assert_eq!(RoundPlayerTrait::calculate_answer_score(45, 60), 125);
    }

    #[test]
    fn test_calculate_answer_score_edge_cases() {
        // Test with very large numbers (close to u64 limits but safe)
        let large_timeout = 1000000;
        assert_eq!(
            RoundPlayerTrait::calculate_answer_score(0, large_timeout), 200,
        ); // Should still work with large timeouts
        assert_eq!(
            RoundPlayerTrait::calculate_answer_score(large_timeout / 2, large_timeout), 150,
        ); // Half time

        // Test with minimum possible timeout (1 second)
        assert_eq!(RoundPlayerTrait::calculate_answer_score(0, 1), 200); // Instant answer
        assert_eq!(RoundPlayerTrait::calculate_answer_score(1, 1), 0); // Timeout
    }

    #[test]
    fn test_calculate_average_time() {
        // Test first answer
        assert_eq!(RoundPlayerTrait::calculate_average_time(0, 0, 10), 10);

        // Test second answer
        // Average of 10 and 20 should be 15
        assert_eq!(RoundPlayerTrait::calculate_average_time(10, 1, 20), 15);

        // Test third answer
        // Current average 15, new value 30
        // ((15 * 2) + 30) / 3 = 20
        assert_eq!(RoundPlayerTrait::calculate_average_time(15, 2, 30), 20);

        // Test with larger numbers
        // Current average 50, 5 answers, new value 70
        // ((50 * 5) + 70) / 6 = 53
        assert_eq!(RoundPlayerTrait::calculate_average_time(50, 5, 70), 53);
    }

    #[test]
    fn test_calculate_average_time_edge_cases() {
        // Test with zero new_time
        assert_eq!(RoundPlayerTrait::calculate_average_time(10, 1, 0), 5); // Average of 10 and 0

        // Test with same value multiple times
        assert_eq!(RoundPlayerTrait::calculate_average_time(5, 2, 5), 5); // Average should stay 5

        // Test with very large numbers (but safe from overflow)
        let large_time = 1000000;
        assert_eq!(RoundPlayerTrait::calculate_average_time(large_time, 1, large_time), large_time);

        // Test averaging with large and small numbers
        assert_eq!(RoundPlayerTrait::calculate_average_time(1000000, 1, 0), 500000);
    }


    #[test]
    fn test_submit_answer_correct_within_timeout() {
        let mut player = create_round_player();
        player.current_card_start_time = 1000;

        let result = player.submit_answer(1030, true); // 30 seconds, correct

        match result {
            Result::Ok((
                updated_player, answer_result,
            )) => {
                assert_eq!(updated_player.total_answers, 1);
                assert_eq!(updated_player.correct_answers, 1);
                assert_eq!(answer_result.is_correct, true);
                assert_eq!(answer_result.time_taken, 30);
                assert_eq!(answer_result.timed_out, false);
                assert!(answer_result.score_earned > 100); // Should have time bonus
                assert_eq!(updated_player.current_card_start_time, 0); // Card cleared
                assert_eq!(updated_player.best_time, 30);
                assert_eq!(updated_player.average_time, 30);
            },
            Result::Err(_) => panic!("Should succeed for valid submission"),
        }
    }

    #[test]
    fn test_submit_answer_incorrect_within_timeout() {
        let mut player = create_round_player();
        player.current_card_start_time = 1000;

        let result = player.submit_answer(1030, false); // 30 seconds, incorrect

        match result {
            Result::Ok((
                updated_player, answer_result,
            )) => {
                assert_eq!(updated_player.total_answers, 1);
                assert_eq!(updated_player.correct_answers, 0);
                assert_eq!(answer_result.is_correct, false);
                assert_eq!(answer_result.time_taken, 30);
                assert_eq!(answer_result.timed_out, false);
                assert_eq!(answer_result.score_earned, 0);
                assert_eq!(updated_player.current_card_start_time, 0);
                assert_eq!(updated_player.best_time, 0); // No update for incorrect
                assert_eq!(updated_player.average_time, 30);
            },
            Result::Err(_) => panic!("Should succeed for valid submission"),
        }
    }

    #[test]
    fn test_submit_answer_timeout_overrides_correct() {
        let mut player = create_round_player();
        player.current_card_start_time = 1000;

        let result = player.submit_answer(1070, true); // 70 seconds, timed out

        match result {
            Result::Ok((
                updated_player, answer_result,
            )) => {
                assert_eq!(updated_player.total_answers, 1);
                assert_eq!(updated_player.correct_answers, 0); // Timeout overrides correct
                assert_eq!(answer_result.is_correct, false);
                assert_eq!(answer_result.time_taken, 70);
                assert_eq!(answer_result.timed_out, true);
                assert_eq!(answer_result.score_earned, 0);
                assert_eq!(updated_player.current_card_start_time, 0);
                assert_eq!(updated_player.best_time, 0); // No update for timed out
            },
            Result::Err(_) => panic!("Should succeed for valid submission"),
        }
    }

    #[test]
    fn test_submit_answer_no_active_card() {
        let player = create_round_player(); // No active card

        let result = player.submit_answer(1030, true);

        match result {
            Result::Ok(_) => panic!("Should fail for no active card"),
            Result::Err(validation) => {
                assert_eq!(validation.is_valid, false);
                assert_eq!(validation.error_message, 'No active card to submit answer');
            },
        }
    }

    #[test]
    fn test_submit_answer_round_completed() {
        let mut player = create_round_player();
        player.current_card_start_time = 1000;
        player.round_completed = true;

        let result = player.submit_answer(1030, true);

        match result {
            Result::Ok(_) => panic!("Should fail for completed round"),
            Result::Err(validation) => {
                assert_eq!(validation.is_valid, false);
                assert_eq!(validation.error_message, 'Round is already completed');
            },
        }
    }

    #[test]
    fn test_submit_answer_invalid_time() {
        let mut player = create_round_player();
        player.current_card_start_time = 1000;

        let result = player.submit_answer(999, true); // Time before card start

        match result {
            Result::Ok(_) => panic!("Should fail for invalid time"),
            Result::Err(validation) => {
                assert_eq!(validation.is_valid, false);
                assert_eq!(validation.error_message, 'Invalid time for answer');
            },
        }
    }

    #[test]
    fn test_force_timeout_success() {
        let mut player = create_round_player();
        player.current_card_start_time = 1000;

        let result = player.force_timeout(1070);

        match result {
            Result::Ok((
                updated_player, answer_result,
            )) => {
                assert_eq!(updated_player.total_answers, 1);
                assert_eq!(updated_player.correct_answers, 0);
                assert_eq!(answer_result.is_correct, false);
                assert_eq!(answer_result.time_taken, 70);
                assert_eq!(answer_result.timed_out, true);
                assert_eq!(answer_result.score_earned, 0);
                assert_eq!(updated_player.current_card_start_time, 0);
                assert_eq!(updated_player.best_time, 0);
                assert_eq!(updated_player.average_time, 70);
            },
            Result::Err(_) => panic!("Should succeed for valid timeout"),
        }
    }

    #[test]
    fn test_force_timeout_no_active_card() {
        let player = create_round_player(); // No active card

        let result = player.force_timeout(1070);

        match result {
            Result::Ok(_) => panic!("Should fail for no active card"),
            Result::Err(validation) => {
                assert_eq!(validation.is_valid, false);
                assert_eq!(validation.error_message, 'No active card to force timeout');
            },
        }
    }

    #[test]
    fn test_force_timeout_round_completed() {
        let mut player = create_round_player();
        player.current_card_start_time = 1000;
        player.round_completed = true;

        let result = player.force_timeout(1070);

        match result {
            Result::Ok(_) => panic!("Should fail for completed round"),
            Result::Err(validation) => {
                assert_eq!(validation.is_valid, false);
                assert_eq!(validation.error_message, 'Round is already completed');
            },
        }
    }

    #[test]
    fn test_best_time_tracking_multiple_answers() {
        let mut player = create_round_player();

        // First correct answer in 30 seconds
        player.current_card_start_time = 1000;
        let result = player.submit_answer(1030, true);
        let (mut updated_player, _) = result.unwrap();
        assert_eq!(updated_player.best_time, 30);

        // Second correct answer in 20 seconds (should update best time)
        updated_player.current_card_start_time = 2000;
        let result = updated_player.submit_answer(2020, true);
        let (mut updated_player, _) = result.unwrap();
        assert_eq!(updated_player.best_time, 20);

        // Third correct answer in 40 seconds (should not update best time)
        updated_player.current_card_start_time = 3000;
        let result = updated_player.submit_answer(3040, true);
        let (updated_player, _) = result.unwrap();
        assert_eq!(updated_player.best_time, 20); // Should remain 20
    }

    #[test]
    fn test_statistics_accumulation() {
        let mut player = create_round_player();

        // First answer: correct
        player.current_card_start_time = 1000;
        let result = player.submit_answer(1030, true);
        let (mut updated_player, _) = result.unwrap();
        assert_eq!(updated_player.total_answers, 1);
        assert_eq!(updated_player.correct_answers, 1);
        assert!(updated_player.total_score > 0);

        // Second answer: incorrect
        updated_player.current_card_start_time = 2000;
        let result = updated_player.submit_answer(2040, false);
        let (mut updated_player, _) = result.unwrap();
        assert_eq!(updated_player.total_answers, 2);
        assert_eq!(updated_player.correct_answers, 1); // Still 1

        // Third answer: timeout
        updated_player.current_card_start_time = 3000;
        let result = updated_player.force_timeout(3080);
        let (updated_player, _) = result.unwrap();
        assert_eq!(updated_player.total_answers, 3);
        assert_eq!(updated_player.correct_answers, 1); // Still 1
    }
}
