use starknet::ContractAddress;
use lyricsflip::models::game_types::Answer;
use lyricsflip::constants::{RoundId, CardIndex};

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
pub impl RoundPlayerImpl of RoundPlayerTrait {}

#[cfg(test)]
mod tests {
    use super::{RoundPlayerTrait, RoundPlayer};
    use starknet::contract_address_const;
    use lyricsflip::models::game_types::Answer;
}
