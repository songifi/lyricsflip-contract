use starknet::ContractAddress;
use core::traits::{Into};

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
    fn generate_sunday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8);
    fn generate_monday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8);
    fn generate_tuesday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8);
    fn generate_wednesday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8);

    fn generate_thursday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8);

    fn generate_friday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8);

    fn generate_saturday_challenge(seed: u64) -> (felt252, felt252, felt252, u64, u64, u64, u8);
}

impl DailyChallengeImpl of DailyChallengeTrait {
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


#[cfg(test)]
mod tests {
    use super::{*, DailyChallengeTrait};

    #[test]
    fn test_generate_sunday_challenge() {
        let seed = 7;
        let (challenge_type, _, _, target_score, target_accuracy, target_streak, difficulty) =
            DailyChallengeTrait::generate_sunday_challenge(
            seed,
        );

        assert(challenge_type == DailyChallengeType::PerfectStreak.into(), 'Sunday type mismatch');
        assert(target_score == 0, 'Sunday target score wrong');
        assert(target_accuracy == 0, 'Sunday accuracy wrong');
        assert(target_streak >= 5 && target_streak <= 12, 'Sunday streak out of range');
        assert(difficulty == 4, 'Sunday difficulty wrong');
    }
    #[test]
    fn test_generate_monday_challenge() {
        let (challenge_type, _, _, target_score, target_accuracy, target_streak, difficulty) =
            DailyChallengeTrait::generate_monday_challenge(
            0,
        );
        assert(challenge_type == DailyChallengeType::GenreMaster.into(), 'Monday type mismatch');
        assert(target_score == 800, 'Monday score wrong');
        assert(target_accuracy == 85, 'Monday accuracy wrong');
        assert(target_streak == 0, 'Monday streak wrong');
        assert(difficulty == 3 || difficulty == 4, 'Monday difficulty');

        let (_, _, _, _, _, _, difficulty2) = DailyChallengeTrait::generate_monday_challenge(500);
        assert(difficulty2 == 3 || difficulty2 == 4, 'Monday difficulty range');
    }

    #[test]
    fn test_generate_tuesday_challenge() {
        let (_, time_limit, questions, _, target_accuracy, _, difficulty) =
            DailyChallengeTrait::generate_tuesday_challenge(
            100,
        );
        let time: u64 = time_limit.try_into().unwrap();
        let q: u64 = questions.try_into().unwrap();
        assert(time >= 180 && time < 300, 'Tuesday time range');
        assert(q >= 10 && q <= 12, 'Tuesday question count');
        assert(target_accuracy == 75, 'Tuesday accuracy');
        assert(difficulty == 4, 'Tuesday difficulty');
    }

     #[test]
    fn test_generate_wednesday_challenge() {
        let (t1, _, _, s1, a1, st1, d1) = DailyChallengeTrait::generate_wednesday_challenge(0);
        if t1 == DailyChallengeType::MixedBag.into() {
            assert(s1 == 1000, 'Wed MixedBag score');
            assert(a1 == 90, 'Wed MixedBag accuracy');
            assert(st1 == 0, 'Wed MixedBag streak');
        } else if t1 == DailyChallengeType::BeatTheAverage.into() {
            assert(s1 == 1000, 'Wed BeatTheAverage score');
            assert(a1 == 90, 'Wed BeatTheAverage accuracy');
            assert(st1 == 0, 'Wed BeatTheAverage streak');
        } else {
            let sc: u64 = s1;
            assert(sc >= 15 && sc <= 24, 'Wed Survival count');
        }
        assert(d1 == 5, 'Wed difficulty');
    }

    #[test]
    fn test_generate_thursday_challenge() {
        let (ctype, decade, _, score, acc, streak, diff) =
            DailyChallengeTrait::generate_thursday_challenge(0);
        let d: u64 = decade.try_into().unwrap();
        assert(
            d == 1960 || d == 1970 || d == 1980 ||
            d == 1990 || d == 2000 || d == 2010,
            'Thursday decade'
        );
        assert(ctype == DailyChallengeType::DecadeExpert.into(), 'Thursday type');
        assert(score == 700, 'Thursday score');
        assert(acc == 80, 'Thursday accuracy');
        assert(streak == 0, 'Thursday streak');
        assert(diff == 3, 'Thursday difficulty');
    }

       #[test]
    fn test_generate_friday_challenge() {
        let (ctype, _, _, score, acc, streak, diff) =
            DailyChallengeTrait::generate_friday_challenge(100);
        assert(ctype == DailyChallengeType::NoMistakes.into(), 'Friday type');
        assert(score == 0, 'Friday score');
        assert(acc == 100, 'Friday accuracy');
        assert(streak == 0, 'Friday streak');
        assert(diff == 5, 'Friday difficulty');
    }

    #[test]
    fn test_generate_saturday_challenge() {
        let (_, time_limit, _, _, acc, _, diff) =
            DailyChallengeTrait::generate_saturday_challenge(100);
        let time: u64 = time_limit.try_into().unwrap();
        assert(time >= 120 && time < 180, 'Saturday time');
        assert(acc == 75, 'Saturday accuracy');
        assert(diff == 4, 'Saturday difficulty');
    }
}
