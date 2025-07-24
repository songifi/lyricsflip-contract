//! Card Models & Game Content Management System
//!
//! Comprehensive card models for managing music game content including lyrics cards,
//! question cards, and card counting systems. Provides core content infrastructure
//! for the music trivia game, handling card storage, validation, filtering, and
//! question generation.

use lyricsflip::models::genre::Genre;

// Type aliases
pub type CardId = u64;

// Core Data Models

/// Primary game content with music metadata and lyrics
#[derive(Clone, Drop, Serde, Debug, PartialEq)]
#[dojo::model]
pub struct LyricsCard {
    #[key]
    pub card_id: CardId,
    pub genre: felt252,  // Serialized Genre enum
    pub artist: felt252,
    pub title: felt252,
    pub year: u64,
    pub lyrics: ByteArray,
}

/// Global card counter and ID management
#[derive(Clone, Drop, Serde, Debug, PartialEq)]
#[dojo::model]
pub struct LyricsCardCount {
    #[key]
    pub id: felt252,  // Game identifier (e.g., 'lyricsflip')
    pub count: u64,
}

// Supporting Structures

/// Multiple-choice questions generated from lyrics
#[derive(Clone, Drop, Serde, Debug, Introspect)]
pub struct QuestionCard {
    pub lyric: ByteArray,
    pub option_one: (felt252, felt252),    // (artist, title)
    pub option_two: (felt252, felt252),
    pub option_three: (felt252, felt252),
    pub option_four: (felt252, felt252),
}

/// Data transfer object for card creation
#[derive(Clone, Drop, Serde, Debug)]
pub struct CardData {
    pub genre: Genre,
    pub artist: felt252,
    pub title: felt252,
    pub year: u64,
    pub lyrics: ByteArray,
}

/// Comprehensive data validation results
#[derive(Clone, Drop, Serde, Debug)]
pub struct CardValidation {
    pub is_valid: bool,
    pub error_message: ByteArray,
}

/// Quick lookup structure with derived data
#[derive(Copy, Drop, Serde, Debug)]
pub struct CardMetadata {
    pub decade: u64,
    pub genre: Option<Genre>,
    pub artist: felt252,
    pub title: felt252,
}


#[generate_trait]
pub impl LyricsCardImpl of LyricsCardTrait {
    /// Creates a new LyricsCard
    fn new(card_id: CardId, genre: Genre, artist: felt252, title: felt252, year: u64, lyrics: ByteArray) -> LyricsCard {
        LyricsCard {
            card_id,
            genre: genre.into(),
            artist,
            title,
            year,
            lyrics,
        }
    }

    /// Creates a LyricsCard from CardData
    fn from_data(card_id: CardId, data: CardData) -> LyricsCard {
        Self::new(card_id, data.genre, data.artist, data.title, data.year, data.lyrics)
    }

    /// Validates card data according to business rules
    fn validate_card_data(artist: felt252, title: felt252, year: u64, lyrics: @ByteArray) -> CardValidation {
        // Check for empty fields
        if artist == 0 {
            return CardValidation {
                is_valid: false,
                error_message: "Artist cannot be empty"
            };
        }
        
        if title == 0 {
            return CardValidation {
                is_valid: false,
                error_message: "Title cannot be empty"
            };
        }

        if lyrics.len() == 0 {
            return CardValidation {
                is_valid: false,
                error_message: "Lyrics cannot be empty"
            };
        }

        // Year range validation (1900-2030)
        if year < 1900 || year > 2030 {
            return CardValidation {
                is_valid: false,
                error_message: "Year must be between 1900 and 2030"
            };
        }

        // Lyrics length validation (reasonable limits)
        if lyrics.len() > 1000 {
            return CardValidation {
                is_valid: false,
                error_message: "Lyrics too long (max 1000 characters)"
            };
        }

        CardValidation {
            is_valid: true,
            error_message: ""
        }
    }

    /// Gets the genre as an Option<Genre>
    fn get_genre(self: @LyricsCard) -> Option<Genre> {
        (*self.genre).try_into()
    }

    /// Calculates the decade from the year
    fn get_decade(self: @LyricsCard) -> u64 {
        (*self.year / 10) * 10
    }

    /// Checks if card matches given genre
    fn matches_genre(self: @LyricsCard, genre: Genre) -> bool {
        match Self::get_genre(self) {
            Option::Some(card_genre) => card_genre == genre,
            Option::None => false,
        }
    }

    /// Checks if card matches given artist
    fn matches_artist(self: @LyricsCard, artist: felt252) -> bool {
        *self.artist == artist
    }

    /// Checks if card is from given year
    fn is_from_year(self: @LyricsCard, year: u64) -> bool {
        *self.year == year
    }

    /// Checks if card is from given decade
    fn is_from_decade(self: @LyricsCard, decade: u64) -> bool {
        Self::get_decade(self) == decade
    }

    /// Checks if card matches both genre and decade
    fn matches_genre_and_decade(self: @LyricsCard, genre: Genre, decade: u64) -> bool {
        Self::matches_genre(self, genre) && Self::is_from_decade(self, decade)
    }

    /// Gets card metadata
    fn get_metadata(self: @LyricsCard) -> CardMetadata {
        CardMetadata {
            decade: Self::get_decade(self),
            genre: Self::get_genre(self),
            artist: *self.artist,
            title: *self.title,
        }
    }

    /// Returns artist and title as tuple
    fn to_option(self: @LyricsCard) -> (felt252, felt252) {
        (*self.artist, *self.title)
    }

    /// Validates the card instance
    fn is_valid(self: @LyricsCard) -> bool {
        let validation = Self::validate_card_data(*self.artist, *self.title, *self.year, self.lyrics);
        validation.is_valid && *self.card_id != 0 && *self.genre != 0
    }
}

#[generate_trait]
pub impl LyricsCardCountImpl of LyricsCardCountTrait {
    /// Creates a new LyricsCardCount
    fn new(id: felt252) -> LyricsCardCount {
        LyricsCardCount {
            id,
            count: 0,
        }
    }

    /// Increments the card count
    fn increment(mut self: LyricsCardCount) -> LyricsCardCount {
        self.count += 1;
        self
    }

    /// Gets the next card ID
    fn next_card_id(self: @LyricsCardCount) -> CardId {
        *self.count + 1
    }

    /// Checks if there are any cards
    fn has_cards(self: @LyricsCardCount) -> bool {
        *self.count > 0
    }

    /// Checks if the system can provide the requested number of cards
    fn can_provide(self: @LyricsCardCount, requested: u64) -> bool {
        *self.count >= requested
    }

    /// Gets the total number of cards
    fn total(self: @LyricsCardCount) -> u64 {
        *self.count
    }
}

#[generate_trait]
pub impl CardDataImpl of CardDataTrait {
    /// Creates new CardData
    fn new(genre: Genre, artist: felt252, title: felt252, year: u64, lyrics: ByteArray) -> CardData {
        CardData {
            genre,
            artist,
            title,
            year,
            lyrics,
        }
    }

    /// Validates the CardData
    fn validate(self: @CardData) -> CardValidation {
        LyricsCardTrait::validate_card_data(*self.artist, *self.title, *self.year, self.lyrics)
    }

    /// Checks if CardData is valid
    fn is_valid(self: @CardData) -> bool {
        let validation = self.validate();
        validation.is_valid
    }

    /// Converts CardData to LyricsCard
    fn to_card(self: CardData, card_id: CardId) -> LyricsCard {
        LyricsCardTrait::from_data(card_id, self)
    }
}

#[generate_trait]
pub impl QuestionCardImpl of QuestionCardTrait {
    /// Creates a new QuestionCard with unique options
    fn new(lyric: ByteArray, correct_option: (felt252, felt252), wrong_options: Array<(felt252, felt252)>) -> QuestionCard {
        // Ensure we have exactly 3 wrong options
        assert(wrong_options.len() >= 3, 'Need at least 3 wrong options');
        
        QuestionCard {
            lyric,
            option_one: correct_option,
            option_two: *wrong_options[0],
            option_three: *wrong_options[1],
            option_four: *wrong_options[2],
        }
    }

    /// Gets all options as an array
    fn get_all_options(self: @QuestionCard) -> Array<(felt252, felt252)> {
        array![
            *self.option_one,
            *self.option_two,
            *self.option_three,
            *self.option_four,
        ]
    }

    /// Gets option by index (0-3)
    fn get_option_by_index(self: @QuestionCard, index: u8) -> Option<(felt252, felt252)> {
        match index {
            0 => Option::Some(*self.option_one),
            1 => Option::Some(*self.option_two),
            2 => Option::Some(*self.option_three),
            3 => Option::Some(*self.option_four),
            _ => Option::None,
        }
    }

    /// Checks if all options are unique
    fn has_unique_options(self: @QuestionCard) -> bool {
        let options = Self::get_all_options(self);
        let mut i = 0;
        let mut unique = true;
        
        while i < options.len() && unique {
            let mut j = i + 1;
            while j < options.len() && unique {
                if *options[i] == *options[j] {
                    unique = false;
                }
                j += 1;
            };
            i += 1;
        };
        
        unique
    }

    /// Validates the question card
    fn is_valid(self: @QuestionCard) -> bool {
        // Check that lyric is not empty
        if self.lyric.len() == 0 {
            return false;
        }

        // Check that all options are not empty
        let options = Self::get_all_options(self);
        let mut i = 0;
        let mut valid = true;
        while i < options.len() && valid {
            let (artist, title) = *options[i];
            if artist == 0 || title == 0 {
                valid = false;
            }
            i += 1;
        };

        // Check that options are unique
        valid && Self::has_unique_options(self)
    }
}

#[cfg(test)]
mod tests {
    use super::{
        LyricsCard, LyricsCardCount, QuestionCard, CardData, CardValidation, CardMetadata,
        LyricsCardTrait, LyricsCardCountTrait, CardDataTrait, QuestionCardTrait,
        CardId
    };
    use lyricsflip::models::genre::Genre;

    // Test data constants
    const VALID_ARTIST: felt252 = 'The Beatles';
    const VALID_TITLE: felt252 = 'Hey Jude';
    const VALID_YEAR: u64 = 1968;
    
    fn valid_lyrics() -> ByteArray {
        "Hey Jude, don't make it bad"
    }

    #[test]
    fn test_lyrics_card_creation() {
        let card = LyricsCardTrait::new(
            1,
            Genre::Rock,
            VALID_ARTIST,
            VALID_TITLE,
            VALID_YEAR,
            valid_lyrics()
        );

        assert(card.card_id == 1, 'Wrong card ID');
        assert(card.artist == VALID_ARTIST, 'Wrong artist');
        assert(card.title == VALID_TITLE, 'Wrong title');
        assert(card.year == VALID_YEAR, 'Wrong year');
        assert(card.genre == Genre::Rock.into(), 'Wrong genre');
    }

    #[test]
    fn test_card_from_data() {
        let data = CardDataTrait::new(
            Genre::Pop,
            VALID_ARTIST,
            VALID_TITLE,
            VALID_YEAR,
            valid_lyrics()
        );

        let card = LyricsCardTrait::from_data(2, data);
        assert(card.card_id == 2, 'Wrong card ID');
        assert(card.genre == Genre::Pop.into(), 'Wrong genre');
    }

    #[test]
    fn test_card_validation_valid() {
        let validation = LyricsCardTrait::validate_card_data(
            VALID_ARTIST,
            VALID_TITLE,
            VALID_YEAR,
            @valid_lyrics()
        );

        assert(validation.is_valid, 'Should be valid');
    }

    #[test]
    fn test_card_validation_empty_artist() {
        let validation = LyricsCardTrait::validate_card_data(
            0,
            VALID_TITLE,
            VALID_YEAR,
            @valid_lyrics()
        );

        assert(!validation.is_valid, 'Should be invalid');
    }

    #[test]
    fn test_card_validation_empty_title() {
        let validation = LyricsCardTrait::validate_card_data(
            VALID_ARTIST,
            0,
            VALID_YEAR,
            @valid_lyrics()
        );

        assert(!validation.is_valid, 'Should be invalid');
    }

    #[test]
    fn test_card_validation_invalid_year_low() {
        let validation = LyricsCardTrait::validate_card_data(
            VALID_ARTIST,
            VALID_TITLE,
            1800,
            @valid_lyrics()
        );

        assert(!validation.is_valid, 'Should be invalid');
    }

    #[test]
    fn test_card_validation_invalid_year_high() {
        let validation = LyricsCardTrait::validate_card_data(
            VALID_ARTIST,
            VALID_TITLE,
            2040,
            @valid_lyrics()
        );

        assert(!validation.is_valid, 'Should be invalid');
    }

    #[test]
    fn test_card_validation_empty_lyrics() {
        let empty_lyrics = "";
        let validation = LyricsCardTrait::validate_card_data(
            VALID_ARTIST,
            VALID_TITLE,
            VALID_YEAR,
            @empty_lyrics
        );

        assert(!validation.is_valid, 'Should be invalid');
    }

    #[test]
    fn test_get_genre() {
        let card = LyricsCardTrait::new(
            1,
            Genre::Jazz,
            VALID_ARTIST,
            VALID_TITLE,
            VALID_YEAR,
            valid_lyrics()
        );

        let genre = card.get_genre();
        assert(genre == Option::Some(Genre::Jazz), 'Wrong genre');
    }

    #[test]
    fn test_get_decade() {
        let card = LyricsCardTrait::new(
            1,
            Genre::Rock,
            VALID_ARTIST,
            VALID_TITLE,
            1968,
            valid_lyrics()
        );

        assert(card.get_decade() == 1960, 'Wrong decade');
    }

    #[test]
    fn test_matches_genre() {
        let card = LyricsCardTrait::new(
            1,
            Genre::Blues,
            VALID_ARTIST,
            VALID_TITLE,
            VALID_YEAR,
            valid_lyrics()
        );

        assert(card.matches_genre(Genre::Blues), 'Should match Blues');
        assert(!card.matches_genre(Genre::Rock), 'Should not match Rock');
    }

    #[test]
    fn test_matches_artist() {
        let card = LyricsCardTrait::new(
            1,
            Genre::Rock,
            VALID_ARTIST,
            VALID_TITLE,
            VALID_YEAR,
            valid_lyrics()
        );

        assert(card.matches_artist(VALID_ARTIST), 'Should match artist');
        assert(!card.matches_artist('Different Artist'), 'Should not match diff artist');
    }

    #[test]
    fn test_is_from_year() {
        let card = LyricsCardTrait::new(
            1,
            Genre::Rock,
            VALID_ARTIST,
            VALID_TITLE,
            1975,
            valid_lyrics()
        );

        assert(card.is_from_year(1975), 'Should match year');
        assert(!card.is_from_year(1980), 'Should not match different year');
    }

    #[test]
    fn test_is_from_decade() {
        let card = LyricsCardTrait::new(
            1,
            Genre::Rock,
            VALID_ARTIST,
            VALID_TITLE,
            1975,
            valid_lyrics()
        );

        assert(card.is_from_decade(1970), 'Should match decade');
        assert(!card.is_from_decade(1980), 'Should not match diff decade');
    }

    #[test]
    fn test_matches_genre_and_decade() {
        let card = LyricsCardTrait::new(
            1,
            Genre::Rock,
            VALID_ARTIST,
            VALID_TITLE,
            1975,
            valid_lyrics()
        );

        assert(card.matches_genre_and_decade(Genre::Rock, 1970), 'Should match both');
        assert(!card.matches_genre_and_decade(Genre::Pop, 1970), 'Should not match wrong genre');
        assert(!card.matches_genre_and_decade(Genre::Rock, 1980), 'Should not match wrong decade');
    }

    #[test]
    fn test_get_metadata() {
        let card = LyricsCardTrait::new(
            1,
            Genre::Classical,
            VALID_ARTIST,
            VALID_TITLE,
            1985,
            valid_lyrics()
        );

        let metadata = card.get_metadata();
        assert(metadata.decade == 1980, 'Wrong decade in metadata');
        assert(metadata.genre == Option::Some(Genre::Classical), 'Wrong genre in metadata');
        assert(metadata.artist == VALID_ARTIST, 'Wrong artist in metadata');
        assert(metadata.title == VALID_TITLE, 'Wrong title in metadata');
    }

    #[test]
    fn test_to_option() {
        let card = LyricsCardTrait::new(
            1,
            Genre::Rock,
            VALID_ARTIST,
            VALID_TITLE,
            VALID_YEAR,
            valid_lyrics()
        );

        let (artist, title) = card.to_option();
        assert(artist == VALID_ARTIST, 'Wrong artist in option');
        assert(title == VALID_TITLE, 'Wrong title in option');
    }

    #[test]
    fn test_card_is_valid() {
        let card = LyricsCardTrait::new(
            1,
            Genre::Rock,
            VALID_ARTIST,
            VALID_TITLE,
            VALID_YEAR,
            valid_lyrics()
        );

        assert(card.is_valid(), 'Valid card should return true');
    }

    #[test]
    fn test_lyrics_card_count_creation() {
        let count = LyricsCardCountTrait::new('lyricsflip');
        assert(count.id == 'lyricsflip', 'Wrong ID');
        assert(count.count == 0, 'Should start at 0');
    }

    #[test]
    fn test_card_count_increment() {
        let mut count = LyricsCardCountTrait::new('test');
        count = count.increment();
        assert(count.count == 1, 'Should be 1 after increment');
    }

    #[test]
    fn test_next_card_id() {
        let count = LyricsCardCountTrait::new('test');
        assert(count.next_card_id() == 1, 'First ID should be 1');
    }

    #[test]
    fn test_has_cards() {
        let mut count = LyricsCardCountTrait::new('test');
        assert(!count.has_cards(), 'Should not have cards initially');
        
        count = count.increment();
        assert(count.has_cards(), 'Should have cards after inc');
    }

    #[test]
    fn test_can_provide() {
        let mut count = LyricsCardCountTrait::new('test');
        count = count.increment();
        count = count.increment();
        count = count.increment(); // count = 3

        assert(count.can_provide(2), 'Should be able to provide 2');
        assert(count.can_provide(3), 'Should be able to provide 3');
        assert(!count.can_provide(4), 'Should not be able to provide 4');
    }

    #[test]
    fn test_total() {
        let mut count = LyricsCardCountTrait::new('test');
        count = count.increment();
        count = count.increment();
        
        assert(count.total() == 2, 'Total should be 2');
    }

    #[test]
    fn test_card_data_creation() {
        let data = CardDataTrait::new(
            Genre::Electronic,
            VALID_ARTIST,
            VALID_TITLE,
            VALID_YEAR,
            valid_lyrics()
        );

        assert(data.genre == Genre::Electronic, 'Wrong genre');
        assert(data.artist == VALID_ARTIST, 'Wrong artist');
    }

    #[test]
    fn test_card_data_validate() {
        let data = CardDataTrait::new(
            Genre::Folk,
            VALID_ARTIST,
            VALID_TITLE,
            VALID_YEAR,
            valid_lyrics()
        );

        let validation = data.validate();
        assert(validation.is_valid, 'Should be valid');
    }

    #[test]
    fn test_card_data_is_valid() {
        let data = CardDataTrait::new(
            Genre::Gospel,
            VALID_ARTIST,
            VALID_TITLE,
            VALID_YEAR,
            valid_lyrics()
        );

        assert(data.is_valid(), 'Should be valid');
    }

    #[test]
    fn test_card_data_to_card() {
        let data = CardDataTrait::new(
            Genre::Country,
            VALID_ARTIST,
            VALID_TITLE,
            VALID_YEAR,
            valid_lyrics()
        );

        let card = data.to_card(5);
        assert(card.card_id == 5, 'Wrong card ID');
        assert(card.genre == Genre::Country.into(), 'Wrong genre');
    }

    #[test]
    fn test_question_card_creation() {
        let correct = (VALID_ARTIST, VALID_TITLE);
        let wrong_options = array![
            ('Artist2', 'Title2'),
            ('Artist3', 'Title3'),
            ('Artist4', 'Title4'),
        ];

        let question = QuestionCardTrait::new(
            valid_lyrics(),
            correct,
            wrong_options
        );

        assert(question.option_one == correct, 'Wrong correct option');
        assert(question.lyric == valid_lyrics(), 'Wrong lyric');
    }

    #[test]
    fn test_question_card_get_all_options() {
        let correct = (VALID_ARTIST, VALID_TITLE);
        let wrong_options = array![
            ('Artist2', 'Title2'),
            ('Artist3', 'Title3'),
            ('Artist4', 'Title4'),
        ];

        let question = QuestionCardTrait::new(
            valid_lyrics(),
            correct,
            wrong_options
        );

        let all_options = question.get_all_options();
        assert(all_options.len() == 4, 'Should have 4 options');
        assert(*all_options[0] == correct, 'First option should be correct');
    }

    #[test]
    fn test_question_card_get_option_by_index() {
        let correct = (VALID_ARTIST, VALID_TITLE);
        let wrong_options = array![
            ('Artist2', 'Title2'),
            ('Artist3', 'Title3'),
            ('Artist4', 'Title4'),
        ];

        let question = QuestionCardTrait::new(
            valid_lyrics(),
            correct,
            wrong_options
        );

        let option_0 = question.get_option_by_index(0);
        assert(option_0 == Option::Some(correct), 'Wrong option 0');

        let option_invalid = question.get_option_by_index(5);
        assert(option_invalid == Option::None, 'Should return None for invalid');
    }

    #[test]
    fn test_question_card_has_unique_options() {
        let correct = (VALID_ARTIST, VALID_TITLE);
        let wrong_options = array![
            ('Artist2', 'Title2'),
            ('Artist3', 'Title3'),
            ('Artist4', 'Title4'),
        ];

        let question = QuestionCardTrait::new(
            valid_lyrics(),
            correct,
            wrong_options
        );

        assert(question.has_unique_options(), 'Should have unique options');
    }

    #[test]
    fn test_question_card_is_valid() {
        let correct = (VALID_ARTIST, VALID_TITLE);
        let wrong_options = array![
            ('Artist2', 'Title2'),
            ('Artist3', 'Title3'),
            ('Artist4', 'Title4'),
        ];

        let question = QuestionCardTrait::new(
            valid_lyrics(),
            correct,
            wrong_options
        );

        assert(question.is_valid(), 'Should be valid');
    }

    #[test]
    fn test_question_card_invalid_empty_lyric() {
        let correct = (VALID_ARTIST, VALID_TITLE);
        let wrong_options = array![
            ('Artist2', 'Title2'),
            ('Artist3', 'Title3'),
            ('Artist4', 'Title4'),
        ];

        let question = QuestionCardTrait::new(
            "",
            correct,
            wrong_options
        );

        assert(!question.is_valid(), 'Should be invalid with empty');
    }
}
