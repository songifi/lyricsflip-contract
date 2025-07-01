use starknet::testing::set_block_timestamp;
use lyricsflip::constants::{SECONDS_IN_DAY, GAME_LAUNCH_TIMESTAMP};
use lyricsflip::models::daily_challenge::DailyChallengeTrait;

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
