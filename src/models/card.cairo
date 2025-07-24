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
