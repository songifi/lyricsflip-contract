use lyricsflip::constants::{SECONDS_IN_DAY, GAME_LAUNCH_TIMESTAMP};
use starknet::get_block_timestamp;

pub fn is_valid_challenge_date(date: u64) -> bool {
    let now = get_block_timestamp();
    let today_midnight = now - (now % SECONDS_IN_DAY);

    // Rule 1: Must be exactly midnight UTC
    if date % SECONDS_IN_DAY != 0 {
        return false;
    }

    // Rule 2: Cannot be in the future
    if date > today_midnight {
        return false;
    }

    // Rule 3: Cannot be before game launch
    if date < GAME_LAUNCH_TIMESTAMP {
        return false;
    }

    true
}
