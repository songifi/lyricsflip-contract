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
            Genre::Reggae => 'Reggae',
            Genre::Blues => 'Blues',
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
        } else if self == 'Reggae' {
            Option::Some(Genre::Reggae)
        } else if self == 'Blues' {
            Option::Some(Genre::Blues)
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
