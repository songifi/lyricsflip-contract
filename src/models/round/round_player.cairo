use lyricsflip::constants::{CardIndex, RoundId};
use lyricsflip::models::game_types::Answer;
use starknet::ContractAddress;

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
    fn calculate_answer_score(time_taken: u64, timeout: u64) -> u64 {
        if time_taken >= timeout {
            return 0;
        }
        let base_score: u64 = 100;

        // Calculate time bonus
        let time_bonus = ((timeout - time_taken) * 100) / timeout;
        base_score + time_bonus
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
}

#[cfg(test)]
mod tests {
    use lyricsflip::models::game_types::Answer;
    use starknet::contract_address_const;
    use super::{RoundPlayer, RoundPlayerTrait};

    fn create_round_player() -> RoundPlayer {
        let player_address = contract_address_const::<'player'>();
        RoundPlayer {
            player_to_round_id: (player_address, 1),
            joined: true,
            ready_state: false,
            next_card_index: 0,
            round_completed: false,
            current_card_start_time: 0,
            card_timeout: 60,
            correct_answers: 0,
            total_answers: 0,
            total_score: 0,
            best_time: 0,
            average_time: 0,
        }
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
}
