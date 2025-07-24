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


