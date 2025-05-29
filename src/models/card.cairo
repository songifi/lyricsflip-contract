use lyricsflip::models::genre::Genre;
use lyricsflip::alias::ID;
use dojo::world::WorldStorage;
use dojo::model::ModelStorage;
use core::num::traits::Zero;
use lyricsflip::constants::{GAME_ID};
use starknet::{get_block_timestamp};


use origami_random::deck::{DeckTrait};
use origami_random::dice::{DiceTrait};


#[derive(Clone, Drop, Serde, Debug, PartialEq)]
#[dojo::model]
pub struct LyricsCard {
    #[key]
    pub card_id: ID,
    pub genre: felt252,
    pub artist: felt252,
    pub title: felt252,
    pub year: u64,
    pub lyrics: ByteArray,
}

#[derive(Clone, Drop, Serde, Debug, PartialEq)]
pub struct CardData {
    pub genre: Genre,
    pub artist: felt252,
    pub title: felt252,
    pub year: u64,
    pub lyrics: ByteArray,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct LyricsCardCount {
    #[key]
    pub id: felt252, // represents GAME_ID
    pub count: u64,
}

#[derive(Clone, Drop, Serde, Debug)]
#[dojo::model]
pub struct YearCards {
    #[key]
    pub year: u64,
    pub cards: Span<u64>,
}

#[derive(Clone, Drop, Serde, Debug)]
#[dojo::model]
pub struct ArtistCards {
    #[key]
    pub artist: felt252,
    pub cards: Span<u64>,
}

#[derive(Clone, Drop, Serde, Debug)]
#[dojo::model]
pub struct GenreCards {
    #[key]
    pub genre: felt252,
    pub cards: Span<u64>,
}

#[derive(Clone, Drop, Serde, Debug, Introspect)]
pub struct QuestionCard {
    pub lyric: ByteArray,
    pub option_one: (felt252, felt252), // (artist, title)
    pub option_two: (felt252, felt252),
    pub option_three: (felt252, felt252),
    pub option_four: (felt252, felt252),
}

#[generate_trait]
pub impl CardGroupImpl of CardGroupTrait {
    fn add_year_cards(ref world: WorldStorage, year: u64, card_id: ID) {
        let existing_year_cards: YearCards = world.read_model(year);

        let mut new_cards: Array<u64> = ArrayTrait::new();

        // Only process existing cards if year is not zero
        if existing_year_cards.year != 0 {
            let existing_span = existing_year_cards.cards;
            for i in 0..existing_span.len() {
                new_cards.append(*existing_span[i]);
            }
        }

        // Add the new card
        new_cards.append(card_id);

        // Write updated model
        world.write_model(@YearCards { year, cards: new_cards.span() });
    }

    fn add_artist_cards(ref world: WorldStorage, artist: felt252, card_id: ID) {
        let existing_artist_cards: ArtistCards = world.read_model(artist);

        let mut new_cards: Array<u64> = ArrayTrait::new();

        if !existing_artist_cards.artist.is_zero() {
            let existing_span = existing_artist_cards.cards;
            for i in 0..existing_span.len() {
                new_cards.append(*existing_span[i]);
            }
        }

        new_cards.append(card_id);
        world.write_model(@ArtistCards { artist, cards: new_cards.span() });
    }

    fn add_genre_cards(ref world: WorldStorage, genre: felt252, card_id: ID) {
        let existing_genre_cards: GenreCards = world.read_model(genre);

        let mut new_cards: Array<u64> = ArrayTrait::new();

        if !existing_genre_cards.genre.is_zero() {
            let existing_span = existing_genre_cards.cards;
            for i in 0..existing_span.len() {
                new_cards.append(*existing_span[i]);
            }
        }

        new_cards.append(card_id);
        world.write_model(@GenreCards { genre, cards: new_cards.span() });
    }
}

#[generate_trait]
pub impl CardImpl of CardTrait {
    /// Retrieves a random selection of cards for a round
    /// Ensures we don't request more cards than are available
    fn get_random_cards(ref world: WorldStorage, count: u64) -> Array<u64> {
        let card_count: LyricsCardCount = world.read_model(GAME_ID);

        // Make sure we don't request more cards than exist
        let available_cards = card_count.count;
        assert(available_cards >= count, 'Not enough cards available');

        let mut deck = DeckTrait::new(
            get_block_timestamp().into(), available_cards.try_into().unwrap(),
        );
        let mut random_cards: Array<u64> = ArrayTrait::new();

        for _ in 0..count {
            let card = deck.draw();
            random_cards.append(card.into());
        };

        random_cards
    }
}


#[generate_trait]
pub impl QuestionCardImpl of QuestionCardTrait {
    /// Generates a multiple-choice question from a lyrics card
    /// Creates one correct option and three incorrect options in random positions
    fn generate_question_card(ref world: WorldStorage, correct_card: LyricsCard) -> QuestionCard {
        let card_count: LyricsCardCount = world.read_model(GAME_ID);

        // Create a random number generator
        let mut dice = DiceTrait::new(
            card_count.count.try_into().unwrap(), get_block_timestamp().into(),
        );

        // Get three different incorrect cards
        let mut wrong_cards: Array<LyricsCard> = ArrayTrait::new();
        let mut attempt_count = 0_u8;
        let max_attempts = 10_u8; // Prevent infinite loops

        while wrong_cards.len() < 3 && attempt_count < max_attempts {
            // Generate a random card ID (between 1 and available_cards)
            let random_card_id = dice.roll().into();

            // Skip if we randomly selected the correct card
            if random_card_id == correct_card.card_id {
                attempt_count += 1;
                continue;
            }

            // Skip if we already selected this card
            let mut duplicate = false;
            for i in 0..wrong_cards.len() {
                if *wrong_cards[i].card_id == random_card_id {
                    duplicate = true;
                    break;
                }
            };

            if !duplicate {
                let wrong_card: LyricsCard = world.read_model(random_card_id);
                wrong_cards.append(wrong_card);
            }

            attempt_count += 1;
        };

        let mut dice = DiceTrait::new(4, get_block_timestamp().into());

        // Randomly position the correct answer
        let correct_position = dice.roll(); // 1-4

        // Create the question card
        let mut options: Array<(felt252, felt252)> = ArrayTrait::new();
        for i in 1..5_u8 {
            if i == correct_position {
                options.append((correct_card.artist, correct_card.title));
            } else {
                let wrong_index = if i > correct_position {
                    i - 2
                } else {
                    i - 1
                };
                options
                    .append(
                        (
                            *wrong_cards.at(wrong_index.into()).artist,
                            *wrong_cards.at(wrong_index.into()).title,
                        ),
                    );
            };
        };

        QuestionCard {
            lyric: correct_card.lyrics,
            option_one: *options[0],
            option_two: *options[1],
            option_three: *options[2],
            option_four: *options[3],
        }
    }
}
