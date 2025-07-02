#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct DailyChallenge {
    #[key]
    pub date: u64,
    pub challenge_type: felt252,
    pub challenge_param1: felt252, // Primary parameter (genre, artist, decade, etc.)
    pub challenge_param2: felt252, // Secondary parameter (for GenreAndDecade)
    pub target_score: u64,
    pub target_accuracy: u64, // Percentage (0-100)
    pub target_streak: u64,
    pub reward_type: felt252, // 'POINTS', 'BADGE', 'POWERUP', 'CURRENCY'
    pub reward_amount: u64,
    pub difficulty: u8, // 1-5 stars
    pub participants_count: u64,
    pub completion_count: u64,
    pub is_active: bool,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct DailyChallengeStreak {
    #[key]
    pub player: ContractAddress,
    pub current_streak: u64,
    pub max_streak: u64,
    pub last_completion_date: u64,
    pub total_challenges_completed: u64,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct PlayerDailyProgress {
    #[key]
    pub player_date_id: (ContractAddress, u64), // (player, date)
    pub challenge_completed: bool,
    pub best_score: u64,
    pub best_accuracy: u64,
    pub attempts: u64,
    pub last_attempt_time: u64,
    pub reward_claimed: bool,
}