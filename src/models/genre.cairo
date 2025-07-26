//! Genre Model
//!
//! Defines music genres available in the game.
//! Pure enum with conversion traits for felt252 serialization.

#[derive(Drop, Copy, Serde, PartialEq, Introspect, Debug)]
pub enum Genre {
    HipHop,
    Pop,
    Rock,
    RnB,
    Electronic,
    Classical,
    Jazz,
    Country,
    Blues,
    Reggae,
    Afrobeat,
    Gospel,
    Folk,
}

impl GenreIntoFelt252 of Into<Genre, felt252> {
    fn into(self: Genre) -> felt252 {
        match self {
            Genre::HipHop => 'HipHop',
            Genre::Pop => 'Pop',
            Genre::Rock => 'Rock',
            Genre::RnB => 'RnB',
            Genre::Electronic => 'Electronic',
            Genre::Classical => 'Classical',
            Genre::Jazz => 'Jazz',
            Genre::Country => 'Country',
            Genre::Blues => 'Blues',
            Genre::Reggae => 'Reggae',
            Genre::Afrobeat => 'Afrobeat',
            Genre::Gospel => 'Gospel',
            Genre::Folk => 'Folk',
        }
    }
}

impl Felt252TryIntoGenre of TryInto<felt252, Genre> {
    fn try_into(self: felt252) -> Option<Genre> {
        if self == 'HipHop' {
            Option::Some(Genre::HipHop)
        } else if self == 'Pop' {
            Option::Some(Genre::Pop)
        } else if self == 'Rock' {
            Option::Some(Genre::Rock)
        } else if self == 'RnB' {
            Option::Some(Genre::RnB)
        } else if self == 'Electronic' {
            Option::Some(Genre::Electronic)
        } else if self == 'Classical' {
            Option::Some(Genre::Classical)
        } else if self == 'Jazz' {
            Option::Some(Genre::Jazz)
        } else if self == 'Country' {
            Option::Some(Genre::Country)
        } else if self == 'Blues' {
            Option::Some(Genre::Blues)
        } else if self == 'Reggae' {
            Option::Some(Genre::Reggae)
        } else if self == 'Afrobeat' {
            Option::Some(Genre::Afrobeat)
        } else if self == 'Gospel' {
            Option::Some(Genre::Gospel)
        } else if self == 'Folk' {
            Option::Some(Genre::Folk)
        } else {
            Option::None
        }
    }
}

#[generate_trait]
pub impl GenreImpl of GenreTrait {
    /// Returns all available genres as an array
    fn all() -> Array<Genre> {
        array![
            Genre::HipHop,
            Genre::Pop,
            Genre::Rock,
            Genre::RnB,
            Genre::Electronic,
            Genre::Classical,
            Genre::Jazz,
            Genre::Country,
            Genre::Blues,
            Genre::Reggae,
            Genre::Afrobeat,
            Genre::Gospel,
            Genre::Folk,
        ]
    }

    /// Validates if a felt252 represents a valid genre
    fn is_valid(genre_felt: felt252) -> bool {
        let genre_result: Option<Genre> = genre_felt.try_into();
        genre_result.is_some()
    }

    /// Returns the string representation of the genre
    fn to_string(self: Genre) -> ByteArray {
        let genre_felt: felt252 = self.into();
        format!("{}", genre_felt)
    }
}

#[cfg(test)]
mod tests {
    use super::{Genre, GenreTrait};

    #[test]
    fn test_genre_conversion_roundtrip() {
        let original = Genre::HipHop;
        let felt_val: felt252 = original.into();
        let converted_back: Option<Genre> = felt_val.try_into();

        assert(converted_back.is_some(), 'Conversion should succeed');
        assert(converted_back.unwrap() == original, 'Should match original');
    }

    #[test]
    fn test_all_genres_convert() {
        let all_genres = GenreTrait::all();

        let mut i = 0;

        while i != all_genres.len() {
            let genre = *all_genres[i];
            let felt_val: felt252 = genre.into();
            let converted_back: Option<Genre> = felt_val.try_into();

            assert(converted_back.is_some(), 'All genres should convert');
            assert(converted_back.unwrap() == genre, 'Should match original');
            i += 1;
        }
    }

    #[test]
    fn test_invalid_felt_conversion() {
        let invalid_felt: felt252 = 'InvalidGenre';
        let result: Option<Genre> = invalid_felt.try_into();

        assert(result.is_none(), 'Invalid felt should return None');
    }

    #[test]
    fn test_genre_validation() {
        assert(GenreTrait::is_valid('Rock'), 'Rock should be valid');
        assert(GenreTrait::is_valid('Pop'), 'Pop should be valid');
        assert(!GenreTrait::is_valid('InvalidGenre'), 'Invalid should be false');
    }

    #[test]
    fn test_genre_string_representation() {
        let rock = Genre::Rock;
        let rock_string = rock.to_string();
        // Note: Exact string comparison depends on Cairo's format implementation
        assert(rock_string.len() > 0, 'String should not be empty');
    }

    #[test]
    fn test_genre_equality() {
        assert(Genre::Rock == Genre::Rock, 'Same genres should be equal');
        assert!(Genre::Rock != Genre::Pop, "Different genres should not be equal");
    }

    #[test]
    fn test_all_genres_count() {
        let all_genres = GenreTrait::all();
        assert(all_genres.len() == 13, 'Should have 13 genres');
    }

    #[test]
    fn test_specific_genre_conversions() {
        // Test a few specific conversions
        assert(Genre::HipHop.into() == 'HipHop', 'HipHop conversion');
        assert(Genre::RnB.into() == 'RnB', 'RnB conversion');
        assert(Genre::Electronic.into() == 'Electronic', 'Electronic conversion');
    }
}
