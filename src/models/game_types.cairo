use array::ArrayTrait;
use traits::{Into, TryInto};
use option::OptionTrait;

#[derive(Copy, Drop, Serde)]
enum Mode {
    Solo,
    MultiPlayer,
    WagerMultiPlayer,
    Challenge,
}

#[derive(Copy, Drop, Serde)]
enum ChallengeType {
    Random,
    Year,
    Artist,
    Genre,
    Decade,
    GenreAndDecade,
}

#[derive(Copy, Drop, Serde)]
enum RoundState {
    Pending,
    Started,
    Completed,
}

#[derive(Copy, Drop, Serde)]
enum Answer {
    OptionOne,
    OptionTwo,
    OptionThree,
    OptionFour,
}

// ─────────────────── //
//   Into / TryFrom
// ─────────────────── //
impl Into<felt252> for Mode {
    fn into(self) -> felt252 {
        match self {
            Mode::Solo => 0,
            Mode::MultiPlayer => 1,
            Mode::WagerMultiPlayer => 2,
            Mode::Challenge => 3,
        }
    }
}

impl TryFrom<felt252> for Mode {
    fn try_from(value: felt252) -> Option<Mode> {
        match value {
            0 => Option::Some(Mode::Solo),
            1 => Option::Some(Mode::MultiPlayer),
            2 => Option::Some(Mode::WagerMultiPlayer),
            3 => Option::Some(Mode::Challenge),
            _ => Option::None,
        }
    }
}

impl Into<felt252> for ChallengeType {
    fn into(self) -> felt252 {
        match self {
            ChallengeType::Random => 0,
            ChallengeType::Year => 1,
            ChallengeType::Artist => 2,
            ChallengeType::Genre => 3,
            ChallengeType::Decade => 4,
            ChallengeType::GenreAndDecade => 5,
        }
    }
}

impl TryFrom<felt252> for ChallengeType {
    fn try_from(value: felt252) -> Option<ChallengeType> {
        match value {
            0 => Option::Some(ChallengeType::Random),
            1 => Option::Some(ChallengeType::Year),
            2 => Option::Some(ChallengeType::Artist),
            3 => Option::Some(ChallengeType::Genre),
            4 => Option::Some(ChallengeType::Decade),
            5 => Option::Some(ChallengeType::GenreAndDecade),
            _ => Option::None,
        }
    }
}

impl Into<felt252> for RoundState {
    fn into(self) -> felt252 {
        match self {
            RoundState::Pending => 0,
            RoundState::Started => 1,
            RoundState::Completed => 2,
        }
    }
}

impl TryFrom<felt252> for RoundState {
    fn try_from(value: felt252) -> Option<RoundState> {
        match value {
            0 => Option::Some(RoundState::Pending),
            1 => Option::Some(RoundState::Started),
            2 => Option::Some(RoundState::Completed),
            _ => Option::None,
        }
    }
}

impl Into<felt252> for Answer {
    fn into(self) -> felt252 {
        match self {
            Answer::OptionOne => 0,
            Answer::OptionTwo => 1,
            Answer::OptionThree => 2,
            Answer::OptionFour => 3,
        }
    }
}

impl TryFrom<felt252> for Answer {
    fn try_from(value: felt252) -> Option<Answer> {
        match value {
            0 => Option::Some(Answer::OptionOne),
            1 => Option::Some(Answer::OptionTwo),
            2 => Option::Some(Answer::OptionThree),
            3 => Option::Some(Answer::OptionFour),
            _ => Option::None,
        }
    }
}

// ─────────────────── //
//  Traits For Logic
// ─────────────────── //

#[generate_trait]
impl ModeImpl of ModeTrait {
    fn all() -> Array<Mode> {
        array![Mode::Solo, Mode::MultiPlayer, Mode::WagerMultiPlayer, Mode::Challenge]
    }

    fn is_multiplayer(self: Mode) -> bool {
        match self {
            Mode::MultiPlayer | Mode::WagerMultiPlayer => true,
            _ => false,
        }
    }

    fn has_wager(self: Mode) -> bool {
        match self {
            Mode::WagerMultiPlayer => true,
            _ => false,
        }
    }

    fn is_valid(mode_felt: felt252) -> bool {
        matches!(mode_felt, 0 | 1 | 2 | 3)
    }
}

#[generate_trait]
impl ChallengeTypeImpl of ChallengeTypeTrait {
    fn all() -> Array<ChallengeType> {
        array![
            ChallengeType::Random,
            ChallengeType::Year,
            ChallengeType::Artist,
            ChallengeType::Genre,
            ChallengeType::Decade,
            ChallengeType::GenreAndDecade,
        ]
    }

    fn requires_param(self: ChallengeType) -> bool {
        match self {
            ChallengeType::Year
            | ChallengeType::Artist
            | ChallengeType::Genre
            | ChallengeType::Decade
            | ChallengeType::GenreAndDecade => true,
            _ => false,
        }
    }

    fn requires_two_params(self: ChallengeType) -> bool {
        match self {
            ChallengeType::GenreAndDecade => true,
            _ => false,
        }
    }

    fn is_valid(value: felt252) -> bool {
        value >= 0 && value <= 5
    }
}

#[generate_trait]
impl RoundStateImpl of RoundStateTrait {
    fn all() -> Array<RoundState> {
        array![RoundState::Pending, RoundState::Started, RoundState::Completed]
    }

    fn can_transition_to(self: RoundState, next: RoundState) -> bool {
        match self {
            RoundState::Pending => matches!(next, RoundState::Started | RoundState::Completed),
            RoundState::Started => matches!(next, RoundState::Completed),
            RoundState::Completed => false,
        }
    }

    fn is_active(self: RoundState) -> bool {
        match self {
            RoundState::Started => true,
            _ => false,
        }
    }

    fn is_valid(value: felt252) -> bool {
        matches!(value, 0 | 1 | 2)
    }
}

#[generate_trait]
impl AnswerImpl of AnswerTrait {
    fn all() -> Array<Answer> {
        array![
            Answer::OptionOne,
            Answer::OptionTwo,
            Answer::OptionThree,
            Answer::OptionFour
        ]
    }

    fn to_index(self: Answer) -> u8 {
        match self {
            Answer::OptionOne => 0,
            Answer::OptionTwo => 1,
            Answer::OptionThree => 2,
            Answer::OptionFour => 3,
        }
    }

    fn from_index(index: u8) -> Option<Answer> {
        match index {
            0 => Option::Some(Answer::OptionOne),
            1 => Option::Some(Answer::OptionTwo),
            2 => Option::Some(Answer::OptionThree),
            3 => Option::Some(Answer::OptionFour),
            _ => Option::None,
        }
    }
}
