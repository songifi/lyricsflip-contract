use starknet::ContractAddress;
use core::traits::{Into};
use dojo::model::ModelStorage;
use dojo::world::WorldStorage;
use lyricsflip::constants::{SECONDS_IN_DAY, GAME_LAUNCH_TIMESTAMP, BASE_REWARD};
use starknet::get_block_timestamp;

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

#[derive(Copy, Drop, Serde, Debug)]
pub enum DailyChallengeType {
    ScoreTarget, // Achieve X points in a single round
    AccuracyChallenge, // Maintain Y% accuracy over Z cards
    SpeedRun, // Complete round under time limit
    GenreMaster, // Perfect score on specific genre
    DecadeExpert, // Play only songs from specific decade
    ArtistFocus, // Only songs from specific artist
    PerfectStreak, // Get X correct answers in a row
    TimeAttack, // Answer as many as possible in time limit
    Survival, // How many can you get right before wrong answer
    NoMistakes, // Complete round with 100% accuracy
    MixedBag, // Random selection with high difficulty
    BeatTheAverage // Score higher than daily average
}


impl DailyChallengeTypeImpl of Into<DailyChallengeType, felt252> {
    fn into(self: DailyChallengeType) -> felt252 {
        match self {
            DailyChallengeType::ScoreTarget => 1,
            DailyChallengeType::AccuracyChallenge => 2,
            DailyChallengeType::SpeedRun => 3,
            DailyChallengeType::GenreMaster => 4,
            DailyChallengeType::DecadeExpert => 5,
            DailyChallengeType::ArtistFocus => 6,
            DailyChallengeType::PerfectStreak => 7,
            DailyChallengeType::TimeAttack => 8,
            DailyChallengeType::Survival => 9,
            DailyChallengeType::NoMistakes => 10,
            DailyChallengeType::MixedBag => 11,
            DailyChallengeType::BeatTheAverage => 12,
        }
    }
}


pub trait DailyChallengeTrait {
    fn ensure_daily_challenge_exists(ref world: WorldStorage);
    fn get_todays_date() -> u64;
    fn generate_seed_from_date(date: u64) -> u64;
    fn get_day_of_week(date: u64) -> u64;
    fn is_valid_challenge_date(date: u64) -> bool;
    fn generate_sunday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8);
    fn generate_monday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8);
    fn generate_tuesday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8);
    fn generate_wednesday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8);

    fn generate_thursday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8);

    fn generate_friday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8);

    fn generate_saturday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8);
    fn generate_daily_challenge(ref world: WorldStorage, date: u64) -> DailyChallenge;
    fn check_challenge_completion_criteria(
        challenge: DailyChallenge, score: u64, accuracy: u64,
    ) -> bool;

    /// Reward
    /// Calculate reward amount based on difficulty and challenge type
    /// Higher difficulty = more rewards, special types get bonuses
    fn calculate_reward_amount(difficulty: u8, challenge_type: felt252) -> u64;

    /// Determine reward type based on challenge characteristics
    /// Most are 'POINTS', special ones might be 'BADGE' or 'POWERUP'
    fn determine_reward_type(difficulty: u8, challenge_type: felt252) -> felt252;

    /// Get base reward for difficulty level
    /// Foundation reward before challenge type bonuses
    fn get_base_reward_for_difficulty(difficulty: u8) -> u64;

    /// Get challenge type bonus multiplier
    /// Additional reward based on challenge complexity
    fn get_challenge_type_bonus(challenge_type: felt252) -> u64;

    /// Validate reward amount is reasonable
    /// Ensures rewards stay within acceptable bounds
    fn is_valid_reward_amount(amount: u64) -> bool;
}

impl DailyChallengeImpl of DailyChallengeTrait {
    /// Ensure today's challenge exists, create if missing
    fn ensure_daily_challenge_exists(ref world: WorldStorage) {
        let today = Self::get_todays_date();
        let existing_challenge: DailyChallenge = world.read_model(today);

        // Check if challenge already exists (challenge_type = 0 means no challenge)
        if existing_challenge.challenge_type == 0 {
            // Generate new challenge for today
            let new_challenge = Self::generate_daily_challenge(ref world, today);
            world.write_model(@new_challenge);
        }
    }

    /// Get current date
    fn get_todays_date() -> u64 {
        let current_timestamp = get_block_timestamp();
        current_timestamp - (current_timestamp % SECONDS_IN_DAY)
    }

    /// Generate deterministic seed from date
    fn generate_seed_from_date(date: u64) -> u64 {
        let day_number = date / 86400;
        let base = day_number * 31;
        let weekly = (day_number % 7) * 13;
        (base + weekly) % 1000
    }

    /// Calculate day of week from timestamp (0=Monday, 6=Sunday)
    fn get_day_of_week(date: u64) -> u64 {
        let days_since_epoch = date / 86400;
        (days_since_epoch + 3) % 7
    }

    /// Validate date is appropriate for challenge generation
    fn is_valid_challenge_date(date: u64) -> bool {
        let now = get_block_timestamp();
        let today_midnight = now - (now % SECONDS_IN_DAY);
        if date % SECONDS_IN_DAY != 0 {
            return false;
        }
        if date > today_midnight {
            return false;
        }
        if date < GAME_LAUNCH_TIMESTAMP {
            return false;
        }
        true
    }

    fn generate_sunday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8) {
        // Set fixed values according to spec
        let challenge_type = DailyChallengeType::PerfectStreak.into();
        let challenge_param1 = 0;
        let challenge_param2 = 0;
        let target_score = 0;
        let target_accuracy = 0;

        // Calculate streak using: 5 + (seed % 8) -> range 5-12
        let streak_variation = seed % 8;
        let target_streak = 5 + streak_variation;

        // Difficulty always high (4 stars)
        let difficulty = 4;

        // Return tuple
        return (
            challenge_type,
            challenge_param1,
            challenge_param2,
            target_score,
            target_accuracy,
            target_streak,
            difficulty,
        );
    }

    fn generate_monday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8) {
        let genre_index = seed % 13;

        let selected_genre = match genre_index {
            0 => 'HipHop'.into(),
            1 => 'Rock'.into(),
            2 => 'Pop'.into(),
            3 => 'Jazz'.into(),
            4 => 'Classical'.into(),
            5 => 'Reggae'.into(),
            6 => 'Electronic'.into(),
            7 => 'Country'.into(),
            8 => 'Blues'.into(),
            9 => 'Metal'.into(),
            10 => 'Folk'.into(),
            11 => 'Soul'.into(),
            12 => 'Latin'.into(),
            _ => 'HipHop'.into(),
        };

        // Convert difficulty to u8 without using 'as'
        let difficulty: u8 = (3 + (seed / 100) % 2).try_into().unwrap();

        let challenge_type = DailyChallengeType::GenreMaster.into();
        let challenge_param1 = selected_genre;
        let challenge_param2 = 0.into();

        let target_score = 800;
        let target_accuracy = 85;
        let target_streak = 0;

        (
            challenge_type,
            challenge_param1,
            challenge_param2,
            target_score,
            target_accuracy,
            target_streak,
            difficulty,
        )
    }


    fn generate_tuesday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8) {
        let challenge_type = DailyChallengeType::TimeAttack.into();

        let time_variation = seed % 120;
        let time_limit = 180 + time_variation;

        let question_variation = (seed / 50) % 3;
        let target_questions = 10 + question_variation;

        let target_score = 0;
        let target_accuracy = 75;
        let target_streak = 0;
        let difficulty = 4;

        (
            challenge_type,
            time_limit.into(),
            target_questions.into(),
            target_score,
            target_accuracy,
            target_streak,
            difficulty,
        )
    }

    fn generate_wednesday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8) {
        let challenge_selector = seed % 3;

        let (
            challenge_type,
            challenge_param1,
            challenge_param2,
            target_score,
            target_accuracy,
            target_streak,
        ) =
            if challenge_selector == 0 {
            // MIXED_BAG
            (DailyChallengeType::MixedBag.into(), 0.into(), 0.into(), 1000, 90, 0)
        } else if challenge_selector == 1 {
            // BEAT_THE_AVERAGE
            (DailyChallengeType::BeatTheAverage.into(), 0.into(), 0.into(), 1000, 90, 0)
        } else {
            // SURVIVAL
            let survival_count = 15 + (seed % 10);
            (
                DailyChallengeType::Survival.into(),
                survival_count.into(),
                0.into(),
                0,
                0,
                survival_count,
            )
        };

        let difficulty = 5;

        (
            challenge_type,
            challenge_param1,
            challenge_param2,
            target_score,
            target_accuracy,
            target_streak,
            difficulty,
        )
    }

    fn generate_thursday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8) {
        let index = seed % 6;
        let selected_decade = match index {
            0 => 1960,
            1 => 1970,
            2 => 1980,
            3 => 1990,
            4 => 2000,
            5 => 2010,
            _ => 1960,
        };

        let challenge_type = DailyChallengeType::DecadeExpert.into();
        let challenge_param1 = selected_decade.into();
        let challenge_param2 = 0.into();
        let target_score = 700;
        let target_accuracy = 80;
        let target_streak = 0;
        let difficulty = 3;

        (
            challenge_type,
            challenge_param1,
            challenge_param2,
            target_score,
            target_accuracy,
            target_streak,
            difficulty,
        )
    }


    fn generate_friday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8) {
        let challenge_type = DailyChallengeType::NoMistakes.into();
        let challenge_param1 = 0.into();
        let challenge_param2 = 0.into();
        let target_score = 0;
        let target_accuracy = 100;
        let target_streak = 0;
        let difficulty = 5;

        (
            challenge_type,
            challenge_param1,
            challenge_param2,
            target_score,
            target_accuracy,
            target_streak,
            difficulty,
        )
    }

    fn generate_saturday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8) {
        let challenge_type = DailyChallengeType::SpeedRun.into();

        let time_variation = seed % 60;
        let time_limit = 120 + time_variation;

        let challenge_param1 = time_limit.into();
        let challenge_param2 = 0.into();

        let target_score = 0;
        let target_accuracy = 75;
        let target_streak = 0;
        let difficulty = 4;

        (
            challenge_type,
            challenge_param1,
            challenge_param2,
            target_score,
            target_accuracy,
            target_streak,
            difficulty,
        )
    }

    fn generate_daily_challenge(ref world: WorldStorage, date: u64) -> DailyChallenge {
        assert(Self::is_valid_challenge_date(date), 'Invalid challenge date');

        let seed = Self::generate_seed_from_date(date);
        let day_of_week = Self::get_day_of_week(date);

        // Get challenge parameters from appropriate day generator
        let (
            challenge_type,
            param1,
            param2,
            target_score,
            target_accuracy,
            target_streak,
            difficulty,
        ) =
            match day_of_week {
            0 => Self::generate_monday_challenge(seed), // Monday
            1 => Self::generate_tuesday_challenge(seed), // Tuesday
            2 => Self::generate_wednesday_challenge(seed), // Wednesday
            3 => Self::generate_thursday_challenge(seed), // Thursday
            4 => Self::generate_friday_challenge(seed), // Friday
            5 => Self::generate_saturday_challenge(seed), // Saturday
            6 => Self::generate_sunday_challenge(seed), // Sunday
            _ => panic!("Invalid day of week"),
        };

        // Calculate rewards
        let reward_amount = Self::calculate_reward_amount(difficulty, challenge_type);
        let reward_type = Self::determine_reward_type(difficulty, challenge_type);

        DailyChallenge {
            date,
            challenge_type,
            challenge_param1: param1,
            challenge_param2: param2,
            target_score,
            target_accuracy,
            target_streak,
            reward_type,
            reward_amount,
            difficulty,
            participants_count: 0,
            completion_count: 0,
            is_active: true,
        }
    }

    fn check_challenge_completion_criteria(
        challenge: DailyChallenge, score: u64, accuracy: u64,
    ) -> bool {
        let challenge_type = challenge.challenge_type;

        // Map DailyChallengeType enum values to completion logic
        if challenge_type == 4 { // GenreMaster (Monday)
            score >= challenge.target_score && accuracy >= challenge.target_accuracy
        } else if challenge_type == 8 { // TimeAttack (Tuesday)
            accuracy >= challenge.target_accuracy
        } else if challenge_type == 3 { // SpeedRun (Saturday)
            accuracy >= challenge.target_accuracy
        } else if challenge_type == 5 { // DecadeExpert (Thursday)
            score >= challenge.target_score && accuracy >= challenge.target_accuracy
        } else if challenge_type == 10 { // NoMistakes (Friday)
            accuracy >= challenge.target_accuracy // Should be 100%
        } else if challenge_type == 11 { // MixedBag (Wednesday)
            score >= challenge.target_score && accuracy >= challenge.target_accuracy
        } else if challenge_type == 12 { // BeatTheAverage (Wednesday)
            score >= challenge.target_score && accuracy >= challenge.target_accuracy
        } else {
            // For Sunday (PerfectStreak) and Survival, simplified without streaks
            // Treat as score + accuracy challenges for now
            let score_met = challenge.target_score == 0 || score >= challenge.target_score;
            let accuracy_met = challenge.target_accuracy == 0
                || accuracy >= challenge.target_accuracy;

            score_met && accuracy_met
        }
    }

    fn calculate_reward_amount(difficulty: u8, challenge_type: felt252) -> u64 {
        // Validate difficulty is in valid range (1-5)
        assert(difficulty >= 1 && difficulty <= 5, 'Invalid difficulty level');

        // Difficulty scaling: each difficulty level adds 50 points
        let difficulty_bonus = (difficulty.into() - 1) * 50; // 0, 50, 100, 150, 200

        // Challenge type bonus based on complexity and uniqueness
        let type_bonus = Self::get_challenge_type_bonus(challenge_type);

        // Calculate total reward
        let total_reward = BASE_REWARD + difficulty_bonus + type_bonus;

        // Validate final amount is reasonable
        assert(Self::is_valid_reward_amount(total_reward), 'Reward amount out of bounds');

        total_reward
    }

    fn get_base_reward_for_difficulty(difficulty: u8) -> u64 {
        assert(difficulty >= 1 && difficulty <= 5, 'Invalid difficulty');

        match difficulty {
            0 => 0,
            1 => 100, // Easy challenges: 100 base points
            2 => 150, // Medium-Easy: 150 base points
            3 => 200, // Medium: 200 base points  
            4 => 250, // Hard: 250 base points
            5 => 300, // Expert: 300 base points
            _ => 0,
        }
    }

    fn get_challenge_type_bonus(challenge_type: felt252) -> u64 {
        if challenge_type == 'NO_MISTAKES' {
            200 // Friday perfect accuracy - highest bonus
        } else if challenge_type == 'SURVIVAL' {
            175 // Sunday survival challenges - high pressure
        } else if challenge_type == 'TIME_ATTACK' {
            150 // Tuesday time attack - speed pressure
        } else if challenge_type == 'SPEED_RUN' {
            150 // Saturday speed challenges - time pressure
        } else if challenge_type == 'MIXED_BAG' {
            125 // Wednesday wildcard - high variety
        } else if challenge_type == 'BEAT_AVERAGE' {
            125 // Wednesday competitive - community challenge
        } else if challenge_type == 'GENRE_MASTER' {
            100 // Monday genre focus - standard challenge
        } else if challenge_type == 'DECADE_EXPERT' {
            100 // Thursday throwback - standard challenge
        } else if challenge_type == 'PERFECT_STREAK' {
            175 // Sunday streak challenges - consistency pressure
        } else {
            75 // Default bonus for unknown challenge types
        }
    }

    fn determine_reward_type(difficulty: u8, challenge_type: felt252) -> felt252 {
        // Special reward types for unique achievements
        if challenge_type == 'NO_MISTAKES' && difficulty == 5 {
            'BADGE' // Perfect Friday challenges earn badges
        } else if challenge_type == 'SURVIVAL' && difficulty >= 4 {
            'BADGE' // Difficult survival challenges earn badges
        } else if difficulty == 5 {
            'BONUS_POINTS' // All max difficulty challenges get bonus point type
        } else {
            'POINTS' // Standard point rewards for most challenges
        }
    }

    fn is_valid_reward_amount(amount: u64) -> bool {
        // Minimum reasonable reward
        if amount < 50 {
            return false;
        }

        // Maximum reasonable reward (prevent exploitation)
        if amount > 1000 {
            return false;
        }

        true
    }
}
