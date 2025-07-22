#[cfg(test)]
mod tests {
    use super::*;
    use src::models::game_types::{Mode, ChallengeType, RoundState, Answer, ModeTrait, ChallengeTypeTrait, RoundStateTrait, AnswerTrait};

    #[test]
    fn test_mode_serialization() {
        assert(Match!(Mode::from(0), Some(Mode::Solo)));
        assert(Match!(Mode::from(1), Some(Mode::MultiPlayer)));
        assert(Match!(Mode::from(2), Some(Mode::WagerMultiPlayer)));
        assert(Match!(Mode::from(3), Some(Mode::Challenge)));
        assert(Match!(Mode::from(99), None));
    }

    #[test]
    fn test_challenge_type_serialization() {
        assert(Match!(ChallengeType::from(1), Some(ChallengeType::Year)));
        assert(Match!(ChallengeType::from(10), None));
    }

    #[test]
    fn test_round_state_transitions() {
        assert(RoundState::Pending.can_transition_to(RoundState::Started));
        assert(RoundState::Pending.can_transition_to(RoundState::Completed));
        assert(RoundState::Started.can_transition_to(RoundState::Completed));
        assert(!RoundState::Completed.can_transition_to(RoundState::Started));
    }

    #[test]
    fn test_answer_index() {
        assert(Match!(Answer::from_index(0), Some(Answer::OptionOne)));
        assert(Match!(Answer::from_index(3), Some(Answer::OptionFour)));
        assert(Match!(Answer::from_index(4), None));
    }
}
