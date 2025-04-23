use lyricsflip::genre::Genre;

#[derive(Clone, Drop, Serde, Debug, PartialEq)]
#[dojo::model]
pub struct LyricsCard {
    #[key]
    pub card_id: u256,
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
    pub count: u256,
}

#[derive(Clone, Drop, Serde, Debug)]
#[dojo::model]
pub struct YearCards {
    #[key]
    pub year: u64,
    pub cards: Span<u256>,
}

#[derive(Clone, Drop, Serde, Debug)]
#[dojo::model]
pub struct ArtistCards {
    #[key]
    pub artist: felt252,
    pub cards: Span<u256>,
}

#[derive(Clone, Drop, Serde, Debug, Introspect)]
pub struct QuestionCard {
    pub lyric: ByteArray,
    pub option_one: (felt252, felt252), // (artist, title)
    pub option_two: (felt252, felt252),
    pub option_three: (felt252, felt252),
    pub option_four: (felt252, felt252),
}
