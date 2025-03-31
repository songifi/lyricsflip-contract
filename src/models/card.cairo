#[derive(Clone, Drop, Serde, Debug)]
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

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct LyricsCardCount {
    #[key]
    pub id: felt252, // represents GAME_ID
    pub count: u256,
}

#[derive(Clone, Drop, Serde, Debug)]
#[dojo::model]
pub struct GenreCard {
    #[key]
    pub genre: felt252,
    pub card_ids: Array<u256>, 
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct GenreCardCount {
    #[key]
    pub genre: felt252,
    pub count: u256,
}
