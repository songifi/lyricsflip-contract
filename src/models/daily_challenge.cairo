use starknet::ContractAddress;
use core::traits::{Into};
use dojo::world::WorldStorage;
use lyricsflip::constants::{SECONDS_IN_DAY, GAME_LAUNCH_TIMESTAMP};
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
}

impl DailyChallengeImpl of DailyChallengeTrait {
    /// Ensure today's challenge exists, create if missing
    fn ensure_daily_challenge_exists(ref world: WorldStorage) {}

    /// Get current date
    fn get_todays_date() -> u64 {
        0
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
}
