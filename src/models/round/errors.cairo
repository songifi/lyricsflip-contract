/// Centralized error messages for Round operations
pub mod RoundErrors {
    // Round creation errors
    pub const INVALID_ROUND_ID: felt252 = 'Round ID must be greater than 0';
    pub const INVALID_CREATOR_ADDRESS: felt252 = 'Creator address cannot be zero';
    pub const INVALID_CREATION_TIME: felt252 = 'Creation time must be provided';

    // Configuration validation errors
    pub const WAGER_AMOUNT_ZERO: felt252 = 'Wager amount cannot be zero';
    pub const SOLO_MODE_MULTIPLE_PLAYERS: felt252 = 'Solo mode must have one player';
    pub const INVALID_MAX_PLAYERS: felt252 = 'Invalid max players count';
    pub const INVALID_CARDS_PER_ROUND: felt252 = 'Invalid cards per round count';
    pub const INVALID_CARD_TIMEOUT: felt252 = 'Card timeout cannot be zero';

    // Challenge parameter errors
    pub const CHALLENGE_PARAM1_REQUIRED: felt252 = 'Challenge param1 required';
    pub const CHALLENGE_PARAM2_REQUIRED: felt252 = 'Challenge param2 required';
    pub const CHALLENGE_PARAM1_ZERO: felt252 = 'Challenge param1 cannot be zero';
    pub const CHALLENGE_PARAM2_ZERO: felt252 = 'Challenge param2 cannot be zero';
    pub const CHALLENGE_PARAM2_NOT_REQUIRED: felt252 = 'Challenge param2 not required';
    pub const RANDOM_CHALLENGE_HAS_PARAMS: felt252 = 'Random challenge has params';
    pub const GENRE_DECADE_REQUIRES_BOTH_PARAMS: felt252 = 'Challenge requires both params';
    pub const CHALLENGE_PARAMS_WITHOUT_TYPE: felt252 = 'Challenge params without type';
    pub const BOTH_REQUIRED_PARAMS: felt252 = 'Both challenge params required';

    // Round state transition errors
    pub const ROUND_NOT_PENDING: felt252 = 'Round is not in pending state';
    pub const ROUND_NOT_ACTIVE: felt252 = 'Must be in started state';
    pub const ROUND_ALREADY_COMPLETED: felt252 = 'Round is already completed';
    pub const INSUFFICIENT_PLAYERS: felt252 = 'Round must have minimum players';
    pub const ROUND_AT_CAPACITY: felt252 = 'Round is at max capacity';
    pub const ROUND_NOT_JOINABLE: felt252 = 'Round is not joinable';

    // Time validation errors
    pub const START_TIME_ZERO: felt252 = 'Start time must be > 0';
    pub const START_TIME_BEFORE_CREATION: felt252 = 'Start time must be after create';
    pub const END_TIME_ZERO: felt252 = 'End time must be greater than 0';
    pub const END_TIME_BEFORE_START: felt252 = 'End time must be after start';

    // Player management errors
    pub const INVALID_PLAYER_ADDRESS: felt252 = 'Invalid player address';
    pub const PLAYER_ALREADY_IN_ROUND: felt252 = 'Player already in round';
    pub const ALL_PLAYERS_ALREADY_READY: felt252 = 'All players already ready';

    pub const PLAYER_MARKED_AS_READY: felt252 = 'Player marked as ready';
    pub const PLAYER_NOT_IN_ROUND: felt252 = 'Player not in round';
    pub const PLAYER_NOT_READY: felt252 = 'Player is not ready';

    pub const INVALID_TIME_ANSWER: felt252 = 'Invalid time for answer';
    pub const CARD_START_TIME_IN_FUTURE: felt252 = 'Card start time in future';
    pub const NO_ACTIVE_CARD: felt252 = 'No active card';
    pub const CARD_IS_ACTIVE: felt252 = 'Card is already active';
}
