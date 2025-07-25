#[cfg(test)]
mod test_card {
    use lyricsflip::models::card::{
        LyricsCardTrait, LyricsCardCountTrait, CardDataTrait, QuestionCardTrait,
    };
    use lyricsflip::models::genre::Genre;

    #[test]
    fn test_card_system_integration() {
        // Test the complete card creation flow
        let mut count = LyricsCardCountTrait::new('lyricsflip');

        // Create card data
        let data = CardDataTrait::new(
            Genre::Rock, 'The Beatles', 'Hey Jude', 1968, "Hey Jude, don't make it bad",
        );

        // Validate data
        assert(data.is_valid(), 'Data should be valid');

        // Get next card ID and create card
        let card_id = count.next_card_id();
        let card = data.to_card(card_id);

        // Verify card properties
        assert(card.is_valid(), 'Card should be valid');
        assert(card.matches_genre(Genre::Rock), 'Should match Rock genre');
        assert(card.is_from_decade(1960), 'Should be from 1960s');

        // Increment count
        count = count.increment();
        assert(count.has_cards(), 'Should have cards');
        assert(count.total() == 1, 'Should have 1 card');
    }

    #[test]
    fn test_question_card_integration() {
        // Test question card creation with proper validation
        let correct_option = ('The Beatles', 'Hey Jude');
        let wrong_options = array![
            ('Rolling Stones', 'Paint It Black'),
            ('Led Zeppelin', 'Stairway to Heaven'),
            ('Pink Floyd', 'Wish You Were Here'),
        ];

        let question = QuestionCardTrait::new(
            "Hey Jude, don't make it bad", correct_option, wrong_options,
        );

        assert(question.is_valid(), 'Question should be valid');
        assert(question.has_unique_options(), 'Options should be unique');

        let all_options = question.get_all_options();
        assert(all_options.len() == 4, 'Should have 4 options');

        // Test option retrieval
        let option_0 = question.get_option_by_index(0);
        assert(option_0 == Option::Some(correct_option), 'First option should be correct');
    }

    #[test]
    fn test_filtering_capabilities() {
        // Test comprehensive filtering
        let card1 = LyricsCardTrait::new(1, Genre::Rock, 'Beatles', 'Hey Jude', 1968, "lyrics1");
        let card2 = LyricsCardTrait::new(2, Genre::Pop, 'ABBA', 'Dancing Queen', 1976, "lyrics2");
        let card3 = LyricsCardTrait::new(
            3, Genre::Rock, 'Queen', 'Bohemian Rhapsody', 1975, "lyrics3",
        );

        // Genre filtering
        assert(card1.matches_genre(Genre::Rock), 'Card1 should match Rock');
        assert(card2.matches_genre(Genre::Pop), 'Card2 should match Pop');
        assert(!card2.matches_genre(Genre::Rock), 'Card2 should not match Rock');

        // Decade filtering
        assert(card1.is_from_decade(1960), 'Card1 from 1960s');
        assert(card2.is_from_decade(1970), 'Card2 from 1970s');
        assert(card3.is_from_decade(1970), 'Card3 from 1970s');

        // Combined filtering
        assert(card1.matches_genre_and_decade(Genre::Rock, 1960), 'Card1 Rock + 1960s');
        assert(card3.matches_genre_and_decade(Genre::Rock, 1970), 'Card3 Rock + 1970s');
        assert(!card2.matches_genre_and_decade(Genre::Rock, 1970), 'Card2 not Rock + 1970s');
    }

    #[test]
    fn test_validation_edge_cases() {
        // Test boundary year validation
        let valid_early = LyricsCardTrait::validate_card_data('Artist', 'Title', 1900, @"lyrics");
        let valid_late = LyricsCardTrait::validate_card_data('Artist', 'Title', 2030, @"lyrics");
        let invalid_early = LyricsCardTrait::validate_card_data('Artist', 'Title', 1899, @"lyrics");
        let invalid_late = LyricsCardTrait::validate_card_data('Artist', 'Title', 2031, @"lyrics");

        assert(valid_early.is_valid, 'Year 1900 should be valid');
        assert(valid_late.is_valid, 'Year 2030 should be valid');
        assert(!invalid_early.is_valid, 'Year 1899 should be invalid');
        assert(!invalid_late.is_valid, 'Year 2031 should be invalid');
    }
}
