#[derive(Drop, Serde, Copy, Clone, PartialEq)]
enum Mode {
    Solo,
    MultiPlayer,
    WagerMultiPlayer,
    Challenge,
}

#[derive(Drop, Serde, Copy, Clone, PartialEq)]
enum ChallengeType {
    Random,
    Year,
    Artist,
    Genre,
    Decade,
    GenreAndDecade,
}

#[derive(Drop, Serde, Copy, Clone, PartialEq)]
enum RoundState {
    Pending,
    Started,
    Completed,
}

#[derive(Drop, Serde, Copy, Clone, PartialEq)]
enum Answer {
    OptionOne,
    OptionTwo,
    OptionThree,
    OptionFour,
}

impl ModeIntoFelt252 of Into<Mode, felt252> {
    fn into(self: Mode) -> felt252 {
        match self {
            Mode::Solo => 'SOLO',
            Mode::MultiPlayer => 'MULTIPLAYER',
            Mode::WagerMultiPlayer => 'WAGERMULTI',
            Mode::Challenge => 'CHALLENGE',
        }
    }
}

impl Felt252TryIntoMode of TryInto<felt252, Mode> {
    fn try_into(self: felt252) -> Option<Mode> {
        if self == 'SOLO' {
            Option::Some(Mode::Solo)
        } else if self == 'MULTIPLAYER' {
            Option::Some(Mode::MultiPlayer)
        } else if self == 'WAGERMULTI' {
            Option::Some(Mode::WagerMultiPlayer)
        } else if self == 'CHALLENGE' {
            Option::Some(Mode::Challenge)
        } else {
            Option::None
        }
    }
}
impl ChallengeTypeIntoFelt252 of Into<ChallengeType, felt252> {
    fn into(self: ChallengeType) -> felt252 {
        match self {
            ChallengeType::Random => 'RANDOM',
            ChallengeType::Year => 'YEAR',
            ChallengeType::Artist => 'ARTIST',
            ChallengeType::Genre => 'GENRE',
            ChallengeType::Decade => 'DECADE',
            ChallengeType::GenreAndDecade => 'GENREANDDECADE',
        }
    }
}

impl Felt252TryIntoChallengeType of TryInto<felt252, ChallengeType> {
    fn try_into(self: felt252) -> Option<ChallengeType> {
        if self == 'RANDOM' {
            Option::Some(ChallengeType::Random)
        } else if self == 'YEAR' {
            Option::Some(ChallengeType::Year)
        } else if self == 'ARTIST' {
            Option::Some(ChallengeType::Artist)
        } else if self == 'GENRE' {
            Option::Some(ChallengeType::Genre)
        } else if self == 'DECADE' {
            Option::Some(ChallengeType::Decade)
        } else if self == 'GENREANDDECADE' {
            Option::Some(ChallengeType::GenreAndDecade)
        } else {
            Option::None
        }
    }
}
impl RoundStateIntoFelt252 of Into<RoundState, felt252> {
    fn into(self: RoundState) -> felt252 {
        match self {
            RoundState::Pending => 'PENDING',
            RoundState::Started => 'STARTED',
            RoundState::Completed => 'COMPLETED',
        }
    }
}

impl Felt252TryIntoRoundState of TryInto<felt252, RoundState> {
    fn try_into(self: felt252) -> Option<RoundState> {
        if self == 'PENDING' {
            Option::Some(RoundState::Pending)
        } else if self == 'STARTED' {
            Option::Some(RoundState::Started)
        } else if self == 'COMPLETED' {
            Option::Some(RoundState::Completed)
        } else {
            Option::None
        }
    }
}

impl AnswerIntoFelt252 of Into<Answer, felt252> {
    fn into(self: Answer) -> felt252 {
        match self {
            Answer::OptionOne => 'OPT1',
            Answer::OptionTwo => 'OPT2',
            Answer::OptionThree => 'OPT3',
            Answer::OptionFour => 'OPT4',
        }
    }
}

impl Felt252TryIntoAnswer of TryInto<felt252, Answer> {
    fn try_into(self: felt252) -> Option<Answer> {
        if self == 'OPT1' {
            Option::Some(Answer::OptionOne)
        } else if self == 'OPT2' {
            Option::Some(Answer::OptionTwo)
        } else if self == 'OPT3' {
            Option::Some(Answer::OptionThree)
        } else if self == 'OPT4' {
            Option::Some(Answer::OptionFour)
        } else {
            Option::None
        }
    }
}

#[generate_trait]
impl ModeImpl of ModeTrait {
    fn all() -> Array<Mode> {
        array![Mode::Solo, Mode::MultiPlayer, Mode::WagerMultiPlayer, Mode::Challenge]
    }

    fn is_multiplayer(self: Mode) -> bool {
        match self {
            Mode::Solo => false,
            _ => true,
        }
    }

    fn has_wager(self: Mode) -> bool {
        match self {
            Mode::WagerMultiPlayer => true,
            _ => false,
        }
    }

    fn is_valid(mode_felt: felt252) -> bool {
        let result: Option<Mode> = mode_felt.try_into();
        result.is_some()
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
            ChallengeType::Random => false,
            _ => true,
        }
    }

    fn requires_two_params(self: ChallengeType) -> bool {
        match self {
            ChallengeType::GenreAndDecade => true,
            _ => false,
        }
    }

    fn is_valid(challenge_felt: felt252) -> bool {
        let result: Option<ChallengeType> = challenge_felt.try_into();
        result.is_some()
    }

    fn has_required_parameters(self: ChallengeType) -> bool {
        self.requires_param() || self.requires_two_params()
    }
}
#[generate_trait]
impl RoundStateImpl of RoundStateTrait {
    fn all() -> Array<RoundState> {
        array![RoundState::Pending, RoundState::Started, RoundState::Completed]
    }

    fn can_transition_to(self: RoundState, new_state: RoundState) -> bool {
        match (self, new_state) {
            (RoundState::Pending, RoundState::Started) => true,
            (RoundState::Started, RoundState::Completed) => true,
            _ => false,
        }
    }

    fn is_active(self: RoundState) -> bool {
        match self {
            RoundState::Started => true,
            _ => false,
        }
    }

    fn is_valid(state_felt: felt252) -> bool {
        let result: Option<RoundState> = state_felt.try_into();
        result.is_some()
    }
}
#[generate_trait]
impl AnswerImpl of AnswerTrait {
    fn all() -> Array<Answer> {
        array![Answer::OptionOne, Answer::OptionTwo, Answer::OptionThree, Answer::OptionFour]
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
#[cfg(test)]
mod tests {
    use super::{*};

    #[test]
    fn test_mode_conversion_roundtrip() {
        let all_modes = ModeTrait::all();

        for i in 0..all_modes.len() {
            let mode = *all_modes[i];
            let felt_val: felt252 = mode.into();
            let converted_back: Option<Mode> = felt_val.try_into();

            assert(converted_back.is_some(), 'Mode conversion should succeed');
            assert(converted_back.unwrap() == mode, 'Should match original mode');
        }
    }
    #[test]
    fn test_mode_multiplayer_check() {
        assert(!ModeTrait::is_multiplayer(Mode::Solo), 'Solo should not be multiplayer');
        assert!(
            ModeTrait::is_multiplayer(Mode::MultiPlayer), "MultiPlayer should be
    multiplayer",
        );
        assert!(
            ModeTrait::is_multiplayer(Mode::WagerMultiPlayer),
            "WagerMultiPlayer should be multiplayer",
        );
        assert!(ModeTrait::is_multiplayer(Mode::Challenge), "Challenge should be multiplayer");
    }

    #[test]
    fn test_mode_wager_check() {
        assert(!ModeTrait::has_wager(Mode::Solo), 'Solo should not have wager');
        assert!(!ModeTrait::has_wager(Mode::MultiPlayer), "MultiPlayer should not have wager");
        assert!(
            ModeTrait::has_wager(Mode::WagerMultiPlayer), "WagerMultiPlayer should have
    wager",
        );
        assert(!ModeTrait::has_wager(Mode::Challenge), 'Challenge should not have wager');
    }

    #[test]
    fn test_challenge_type_conversion_roundtrip() {
        let all_challenges = ChallengeTypeTrait::all();

        for i in 0..all_challenges.len() {
            let challenge = *all_challenges[i];
            let felt_val: felt252 = challenge.into();
            let converted_back: Option<ChallengeType> = felt_val.try_into();

            assert!(converted_back.is_some(), "Challenge conversion should succeed");
            assert(converted_back.unwrap() == challenge, 'Should match original challenge');
        }
    }

    #[test]
    fn test_challenge_type_parameter_validation() {
        assert!(
            ChallengeTypeTrait::has_required_parameters(ChallengeType::Decade),
            "Speed should have required parameters",
        );
        assert!(
            ChallengeTypeTrait::has_required_parameters(ChallengeType::Artist),
            "Accuracy should have required parameters",
        );
        assert!(
            !ChallengeTypeTrait::has_required_parameters(ChallengeType::Random),
            "Default should not have required parameters",
        );
    }

    #[test]
    fn test_round_state_conversion_roundtrip() {
        let all_states = RoundStateTrait::all();

        for i in 0..all_states.len() {
            let state = *all_states[i];
            let felt_val: felt252 = state.into();
            let converted_back: Option<RoundState> = felt_val.try_into();

            assert(converted_back.is_some(), 'State conversion should succeed');
            assert(converted_back.unwrap() == state, 'Should match original state');
        }
    }

    #[test]
    fn test_round_state_transitions() {
        assert!(
            RoundStateTrait::can_transition_to(RoundState::Pending, RoundState::Started),
            "Idle should transition to Active",
        );
        assert!(
            RoundStateTrait::can_transition_to(RoundState::Started, RoundState::Completed),
            "Active should transition to Completed",
        );
        assert!(
            !RoundStateTrait::can_transition_to(RoundState::Completed, RoundState::Started),
            "Completed should not go back to Active",
        );
    }

    #[test]
    fn test_answer_conversion_roundtrip() {
        let all_answers = AnswerTrait::all();

        for i in 0..all_answers.len() {
            let answer = *all_answers[i];
            let index = AnswerTrait::to_index(answer);
            let converted_back = AnswerTrait::from_index(index);

            assert!(converted_back.is_some(), "Answer conversion should succeed");
            assert(converted_back.unwrap() == answer, 'Should match original answer');
        }
    }
}
