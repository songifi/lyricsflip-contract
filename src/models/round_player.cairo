use lyricsflip::models::round::RoundPlayer;

/// Validation errors for RoundPlayer operations
#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub enum RoundPlayerValidation {
    PlayerNotReady,
    RoundCompleted,
    CardAlreadyActive,
    NoActiveCard,
}

#[generate_trait]
pub impl RoundPlayerImpl of RoundPlayerTrait {
    /// Start the next card for a ready player
    /// Sets card start time and increments card index
    /// Validates player can start a new card
    /// Returns updated player with active card state
    fn start_next_card(self: @RoundPlayer, start_time: u64) -> Result<RoundPlayer, RoundPlayerValidation> {
        // Validate player is ready to start a card
        if !*self.ready_state {
            return Result::Err(RoundPlayerValidation::PlayerNotReady);
        }

        // Validate round is not completed
        if *self.round_completed {
            return Result::Err(RoundPlayerValidation::RoundCompleted);
        }

        // Validate no card is currently active
        if *self.current_card_start_time > 0 {
            return Result::Err(RoundPlayerValidation::CardAlreadyActive);
        }

        // Create updated player with new card started
        let updated_player = RoundPlayer {
            player_to_round_id: *self.player_to_round_id,
            joined: *self.joined,
            ready_state: *self.ready_state,
            next_card_index: *self.next_card_index + 1,
            round_completed: *self.round_completed,
            current_card_start_time: start_time,
            card_timeout: *self.card_timeout,
            correct_answers: *self.correct_answers,
            total_answers: *self.total_answers,
            total_score: *self.total_score,
            best_time: *self.best_time,
        };

        Result::Ok(updated_player)
    }

    /// Check if player is currently answering a card
    /// Returns true if card is active (start time > 0)
    /// Simple state query with no side effects
    fn is_answering_card(self: @RoundPlayer) -> bool {
        *self.current_card_start_time > 0
    }

    /// Check if current card has exceeded timeout
    /// Compares elapsed time against card timeout
    /// Returns false if no active card
    /// Handles edge cases gracefully
    fn current_card_timed_out(self: @RoundPlayer, current_time: u64) -> bool {
        // Return false if no active card
        if *self.current_card_start_time == 0 {
            return false;
        }

        // Handle edge case where current_time is before start_time
        if current_time < *self.current_card_start_time {
            return false;
        }

        // Calculate elapsed time and check against timeout
        let elapsed_time = current_time - *self.current_card_start_time;
        elapsed_time >= *self.card_timeout
    }

    /// Calculate remaining time for current card
    /// Returns 0 if no active card or timed out
    /// Provides countdown functionality for UI
    /// Handles negative time scenarios
    fn get_time_remaining(self: @RoundPlayer, current_time: u64) -> u64 {
        // Return 0 if no active card
        if *self.current_card_start_time == 0 {
            return 0;
        }

        // Handle edge case where current_time is before start_time
        if current_time < *self.current_card_start_time {
            return *self.card_timeout;
        }

        // Calculate elapsed time
        let elapsed_time = current_time - *self.current_card_start_time;

        // Return 0 if timed out, otherwise return remaining time
        if elapsed_time >= *self.card_timeout {
            0
        } else {
            *self.card_timeout - elapsed_time
        }
    }
}
