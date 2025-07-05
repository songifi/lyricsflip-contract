use starknet::testing::set_block_timestamp;
use lyricsflip::constants::{SECONDS_IN_DAY, GAME_LAUNCH_TIMESTAMP};
use lyricsflip::models::daily_challenge::{DailyChallengeTrait, DailyChallengeType};

#[test]
fn test_is_valid_challenge_date() {
    // Simulate current time (e.g., July 1, 2025 00:00:00 UTC)
    let simulated_now = 1751328000; // midnight timestamp
    set_block_timestamp(simulated_now);

    // Valid timestamp (same day, midnight, after launch)
    let valid_date = simulated_now;
    assert(DailyChallengeTrait::is_valid_challenge_date(valid_date) == true, 'Expected valid');

    // Not midnight
    let not_midnight = valid_date + 3600;
    assert(
        DailyChallengeTrait::is_valid_challenge_date(not_midnight) == false,
        'Expected false: not midnight',
    );

    // Future date (midnight next day)
    let future_date = valid_date + SECONDS_IN_DAY;
    assert(
        DailyChallengeTrait::is_valid_challenge_date(future_date) == false,
        'Expected false: future date',
    );

    // Before game launch
    let pre_launch = GAME_LAUNCH_TIMESTAMP - SECONDS_IN_DAY;
    assert(
        DailyChallengeTrait::is_valid_challenge_date(pre_launch) == false,
        'Expected false: before launch',
    );
}


#[test]
fn test_get_day_of_week() {
    let day = 86400;

    // Jan 1, 2025 (Wednesday)
    let jan_1 = 1735689600;
    assert(DailyChallengeTrait::get_day_of_week(jan_1) == 2, 'Expected Wednesday (2)');

    // Jan 2, 2025 (Thursday)
    let jan_2 = jan_1 + day;
    assert(DailyChallengeTrait::get_day_of_week(jan_2) == 3, 'Expected Thursday (3)');

    // Jan 3, 2025 (Friday)
    let jan_3 = jan_2 + day;
    assert(DailyChallengeTrait::get_day_of_week(jan_3) == 4, 'Expected Friday (4)');

    // Jan 4, 2025 (Saturday)
    let jan_4 = jan_3 + day;
    assert(DailyChallengeTrait::get_day_of_week(jan_4) == 5, 'Expected Saturday (5)');

    // Jan 5, 2025 (Sunday)
    let jan_5 = jan_4 + day;
    assert(DailyChallengeTrait::get_day_of_week(jan_5) == 6, 'Expected Sunday (6)');

    // Jan 6, 2025 (Monday)
    let jan_6 = jan_5 + day;
    assert(DailyChallengeTrait::get_day_of_week(jan_6) == 0, 'Expected Monday (0)');

    // Jan 7, 2025 (Tuesday)
    let jan_7 = jan_6 + day;
    assert(DailyChallengeTrait::get_day_of_week(jan_7) == 1, 'Expected Tuesday (1)');
}

#[test]
fn test_generate_seed_from_date() {
    // Jan 1, 2025
    let jan_1 = 1735689600;
    assert(DailyChallengeTrait::generate_seed_from_date(jan_1) <= 999, 'out of range');

    // Jan 2, 2025
    let jan_2 = jan_1 + 86400;
    assert(
        DailyChallengeTrait::generate_seed_from_date(
            jan_2,
        ) != DailyChallengeTrait::generate_seed_from_date(jan_1),
        'same seed next day',
    );

    // Same date = same seed
    assert(
        DailyChallengeTrait::generate_seed_from_date(
            jan_1,
        ) == DailyChallengeTrait::generate_seed_from_date(jan_1),
        'seed not stable',
    );

    // Jan 8, 2025 = same weekday as Jan 1, test variation
    let jan_8 = jan_1 + 86400 * 7;
    assert(
        DailyChallengeTrait::generate_seed_from_date(
            jan_8,
        ) != DailyChallengeTrait::generate_seed_from_date(jan_1),
        'seed repeat weekly',
    );
}

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
        DailyChallengeTrait::generate_thursday_challenge(
        0,
    );
    let d: u64 = decade.try_into().unwrap();
    assert(
        d == 1960 || d == 1970 || d == 1980 || d == 1990 || d == 2000 || d == 2010,
        'Thursday decade',
    );
    assert(ctype == DailyChallengeType::DecadeExpert.into(), 'Thursday type');
    assert(score == 700, 'Thursday score');
    assert(acc == 80, 'Thursday accuracy');
    assert(streak == 0, 'Thursday streak');
    assert(diff == 3, 'Thursday difficulty');
}

#[test]
fn test_generate_friday_challenge() {
    let (ctype, _, _, score, acc, streak, diff) = DailyChallengeTrait::generate_friday_challenge(
        100,
    );
    assert(ctype == DailyChallengeType::NoMistakes.into(), 'Friday type');
    assert(score == 0, 'Friday score');
    assert(acc == 100, 'Friday accuracy');
    assert(streak == 0, 'Friday streak');
    assert(diff == 5, 'Friday difficulty');
}

#[test]
fn test_generate_saturday_challenge() {
    let (_, time_limit, _, _, acc, _, diff) = DailyChallengeTrait::generate_saturday_challenge(100);
    let time: u64 = time_limit.try_into().unwrap();
    assert(time >= 120 && time < 180, 'Saturday time');
    assert(acc == 75, 'Saturday accuracy');
    assert(diff == 4, 'Saturday difficulty');
}
