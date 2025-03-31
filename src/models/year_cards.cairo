#[derive(Clone, Drop, Serde, Debug)]
#[dojo::model]
pub struct YearCards {
    #[key]
    pub year: u64, // The year as the unique key for grouping cards (u64 to match LyricsCard).
    pub cards: Span<u256> // A Span of card_ids associated with this year (u256 to match card_id).
}
