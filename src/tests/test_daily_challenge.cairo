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
    assert(DailyChallengeTrait::is_valid_challenge_date(not_midnight) == false, 'Expected false: not midnight');

    // Future date (midnight next day)
    let future_date = valid_date + SECONDS_IN_DAY;
    assert(DailyChallengeTrait::is_valid_challenge_date(future_date) == false, 'Expected false: future date');

    // Before game launch
    let pre_launch = GAME_LAUNCH_TIMESTAMP - SECONDS_IN_DAY;
    assert(DailyChallengeTrait::is_valid_challenge_date(pre_launch) == false, 'Expected false: before launch');
}
