use starknet::testing;
use dojo::model::ModelStorage;
use dojo::world::{WorldStorage, WorldStorageTrait};
use lyricsflip::constants::{GAME_ID};
use lyricsflip::genre::{Genre};
use lyricsflip::models::config::{GameConfig};
use lyricsflip::models::round::{Rounds, RoundsCount, RoundPlayer};
use lyricsflip::models::round::RoundState;
use lyricsflip::systems::actions::{IActionsDispatcher, IActionsDispatcherTrait, actions};
use lyricsflip::systems::config::{IGameConfigDispatcher, IGameConfigDispatcherTrait, game_config};
use lyricsflip::models::card::{LyricsCard, LyricsCardCount, YearCards, ArtistCards};

use lyricsflip::tests::test_utils::{setup};


#[test]
fn test_create_round() {
    let caller = starknet::contract_address_const::<0x0>();

    let mut world = setup();

    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };

    let round_id = actions_system.create_round(Genre::Rock.into());

    let res: Rounds = world.read_model(round_id);
    let rounds_count: RoundsCount = world.read_model(GAME_ID);

    assert(rounds_count.count == 1, 'rounds count is wrong');
    assert(res.round.creator == caller, 'round creator is wrong');
    assert(res.round.genre == Genre::Rock.into(), 'wrong round genre');
    assert(res.round.wager_amount == 0, 'wrong round wager_amount');
    assert(res.round.start_time == 0, 'wrong round start_time');
    assert(res.round.players_count == 1, 'wrong players_count');
    assert(res.round.state == RoundState::Pending.into(), 'Round state should be Pending');

    let round_id = actions_system.create_round(Genre::Pop.into());

    let res: Rounds = world.read_model(round_id);
    let rounds_count: RoundsCount = world.read_model(GAME_ID);
    let round_player: RoundPlayer = world.read_model((caller, round_id));

    assert(rounds_count.count == 2, 'rounds count should be 2');
    assert(res.round.creator == caller, 'round creator is wrong');
    assert(res.round.genre == Genre::Pop.into(), 'wrong round genre');
    assert(res.round.players_count == 1, 'wrong players_count');

    assert(round_player.joined, 'round not joined');
    assert(res.round.state == RoundState::Pending.into(), 'Round state should be Pending');
}

#[test]
fn test_join_round() {
    let caller = starknet::contract_address_const::<0x0>();
    let player = starknet::contract_address_const::<0x1>();

    let mut world = setup();

    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };

    let round_id = actions_system.create_round(Genre::Rock.into());

    let res: Rounds = world.read_model(round_id);
    assert(res.round.players_count == 1, 'wrong players_count');

    testing::set_contract_address(player);
    actions_system.join_round(round_id);

    let res: Rounds = world.read_model(round_id);
    let round_player: RoundPlayer = world.read_model((player, round_id));

    assert(res.round.players_count == 2, 'wrong players_count');
    assert(round_player.joined, 'player not joined');
}

#[test]
#[should_panic]
fn test_cannot_join_round_non_existent_round() {
    let caller = starknet::contract_address_const::<0x0>();
    let player = starknet::contract_address_const::<0x1>();

    let mut world = setup();

    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };

    testing::set_caller_address(player);
    actions_system.join_round(1);
}

#[test]
#[should_panic]
fn test_cannot_join_ongoing_round() {
    let caller = starknet::contract_address_const::<0x0>();
    let player = starknet::contract_address_const::<0x1>();

    let mut world = setup();

    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };

    let round_id = actions_system.create_round(Genre::Rock.into());

    let mut res: Rounds = world.read_model(round_id);
    assert(res.round.players_count == 1, 'wrong players_count');

    res.round.state = RoundState::Started.into();
    world.write_model(@res);

    testing::set_contract_address(player);
    actions_system.join_round(round_id);
}

#[test]
#[should_panic]
fn test_cannot_join_already_joined_round() {
    let caller = starknet::contract_address_const::<0x0>();

    let mut world = setup();

    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };

    let round_id = actions_system.create_round(Genre::Rock.into());

    let mut res: Rounds = world.read_model(round_id);
    assert(res.round.players_count == 1, 'wrong players_count');

    actions_system.join_round(round_id);
}

#[test]
fn test_set_cards_per_round() {
    let mut world = setup();

    let admin = starknet::contract_address_const::<0x1>();
    let _default_cards_per_round = 5_u32;

    world.write_model(@GameConfig { id: GAME_ID, cards_per_round: 5_u32, admin_address: admin });

    let (contract_address, _) = world.dns(@"game_config").unwrap();
    let game_config_system = IGameConfigDispatcher { contract_address };

    let new_cards_per_round = 10_u32;
    game_config_system.set_cards_per_round(new_cards_per_round);

    let config: GameConfig = world.read_model(GAME_ID);
    assert(config.cards_per_round == new_cards_per_round, 'cards_per_round not updated');
    assert(config.admin_address == admin, 'admin address changed');

    let another_value = 15_u32;
    game_config_system.set_cards_per_round(another_value);
    let config: GameConfig = world.read_model(GAME_ID);
    assert(config.cards_per_round == another_value, 'failed to update again');
}

#[test]
#[should_panic(expected: ('cards_per_round cannot be zero', 'ENTRYPOINT_FAILED'))]
fn test_set_cards_per_round_with_zero() {
    let mut world = setup();

    let admin = starknet::contract_address_const::<0x1>();
    world.write_model(@GameConfig { id: GAME_ID, cards_per_round: 5_u32, admin_address: admin });

    let (contract_address, _) = world.dns(@"game_config").unwrap();
    let game_config_system = IGameConfigDispatcher { contract_address };

    game_config_system.set_cards_per_round(0);
}

#[test]
fn test_add_lyrics_card() {
    let mut world = setup();

    // Inicializamos LyricsCardCount
    world.write_model(@LyricsCardCount { id: GAME_ID, count: 0_u256 });

    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };

    let genre = Genre::Pop;
    let artist = 'fame';
    let title = 'sounds';
    let year = 2020;
    let lyrics: ByteArray = "come to life...";

    let card_id = actions_system.add_lyrics_card(genre, artist, title, year, lyrics.clone());

    // Verificamos el LyricsCard
    let card: LyricsCard = world.read_model(card_id);
    assert(card.card_id == 1_u256, 'wrong card_id');
    assert(card.genre == 'Pop', 'wrong genre');
    assert(card.artist == artist, 'wrong artist');
    assert(card.title == title, 'wrong title');
    assert(card.year == year, 'wrong year');
    assert(card.lyrics == lyrics, 'wrong lyrics');

    // Verificamos el LyricsCardCount
    let card_count: LyricsCardCount = world.read_model(GAME_ID);
    assert(card_count.count == 1_u256, 'wrong card count');

    // Verificamos el YearCards
    let year_cards: YearCards = world.read_model(year);
    assert(year_cards.year == year, 'wrong year in YearCards');
    assert(year_cards.cards.len() == 1, 'should have 1 card');
    assert(*year_cards.cards[0] == card_id, 'wrong card_id in YearCards');

    let artist_cards: ArtistCards = world.read_model(artist);
    assert(artist_cards.artist == artist, 'wrong artist in ArtistCards');
    assert(artist_cards.cards.len() == 1, 'should have 1 card');
    assert(*artist_cards.cards[0] == card_id, 'wrong card_id in ArtistCards');
}

#[test]
fn test_add_multiple_lyrics_cards_same_year() {
    let mut world = setup();

    // Inicializamos LyricsCardCount
    world.write_model(@LyricsCardCount { id: GAME_ID, count: 0_u256 });

    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };

    let year = 2020;
    let genre1 = Genre::Pop;
    let genre2 = Genre::Rock;
    let artist1 = 'artist1';
    let artist2 = 'artist2';
    let title1 = 'title1';
    let title2 = 'title2';
    let lyrics1: ByteArray = "lyrics for card 1";
    let lyrics2: ByteArray = "lyrics for card 2";

    // Agregamos la primera tarjeta
    let card_id1 = actions_system.add_lyrics_card(genre1, artist1, title1, year, lyrics1.clone());
    // Agregamos la segunda tarjeta en el mismo año
    let card_id2 = actions_system.add_lyrics_card(genre2, artist2, title2, year, lyrics2.clone());

    // Verificamos los card_id
    assert(card_id1 == 1_u256, 'wrong card_id 1');
    assert(card_id2 == 2_u256, 'wrong card_id 2');

    // Verificamos el LyricsCardCount
    let card_count: LyricsCardCount = world.read_model(GAME_ID);
    assert(card_count.count == 2_u256, 'wrong card count');

    // Verificamos el YearCards
    let year_cards: YearCards = world.read_model(year);
    assert(year_cards.year == year, 'wrong year in YearCards');
    assert(year_cards.cards.len() == 2, 'should have 2 cards');
    assert(*year_cards.cards[0] == card_id1, 'wrong card_id 1 in YearCards');
    assert(*year_cards.cards[1] == card_id2, 'wrong card_id 2 in YearCards');
}

#[test]
fn test_add_lyrics_cards_different_years() {
    let mut world = setup();

    // Inicializamos LyricsCardCount
    world.write_model(@LyricsCardCount { id: GAME_ID, count: 0_u256 });

    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };

    let year1 = 2020;
    let year2 = 2021;
    let genre1 = Genre::Pop;
    let genre2 = Genre::Rock;
    let artist1 = 'artist1';
    let artist2 = 'artist2';
    let title1 = 'title1';
    let title2 = 'title2';
    let lyrics1: ByteArray = "lyrics for 2020";
    let lyrics2: ByteArray = "lyrics for 2021";

    // Agregamos la primera tarjeta (año 2020)
    let card_id1 = actions_system.add_lyrics_card(genre1, artist1, title1, year1, lyrics1.clone());
    // Agregamos la segunda tarjeta (año 2021)
    let card_id2 = actions_system.add_lyrics_card(genre2, artist2, title2, year2, lyrics2.clone());

    // Verificamos los card_id
    assert(card_id1 == 1_u256, 'wrong card_id 1');
    assert(card_id2 == 2_u256, 'wrong card_id 2');

    // Verificamos el LyricsCardCount
    let card_count: LyricsCardCount = world.read_model(GAME_ID);
    assert(card_count.count == 2_u256, 'wrong card count');

    // Verificamos el YearCards para el año 2020
    let year_cards1: YearCards = world.read_model(year1);
    assert(year_cards1.year == year1, 'wrong year in YearCards 1');
    assert(year_cards1.cards.len() == 1, 'should have 1 card in 2020');
    assert(*year_cards1.cards[0] == card_id1, 'wrong card_id in YearCards 1');

    // Verificamos el YearCards para el año 2021
    let year_cards2: YearCards = world.read_model(year2);
    assert(year_cards2.year == year2, 'wrong year in YearCards 2');
    assert(year_cards2.cards.len() == 1, 'should have 1 card in 2021');
    assert(*year_cards2.cards[0] == card_id2, 'wrong card_id in YearCards 2');
}

#[test]
fn test_set_admin_address() {
    let caller = starknet::contract_address_const::<0x1>();

    let mut world = setup();

    let (contract_address, _) = world.dns(@"game_config").unwrap();
    let actions_system = IGameConfigDispatcher { contract_address };

    actions_system.set_admin_address(caller);

    let config: GameConfig = world.read_model(GAME_ID);
    assert(config.admin_address == caller, 'admin_address not updated');
}

#[test]
#[should_panic(expected: ('admin_address cannot be zero', 'ENTRYPOINT_FAILED'))]
fn test_set_admin_address_panics_with_zero_address() {
    let caller = starknet::contract_address_const::<0x0>();

    let mut world = setup();

    let (contract_address, _) = world.dns(@"game_config").unwrap();
    let actions_system = IGameConfigDispatcher { contract_address };

    actions_system.set_admin_address(caller);
}

#[test]
fn test_get_round_id_initial_value() {
    let mut world = setup();

    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };

    world.write_model(@RoundsCount { id: GAME_ID, count: 5_u256 });

    let round_id = actions_system.get_round_id();

    assert(round_id == 6_u256, 'Initial round_id should be 6');

    let rounds_count: RoundsCount = world.read_model(GAME_ID);
    assert(rounds_count.count == 5_u256, 'rounds count should remain 5');
}

#[test]
fn test_round_id_consistency() {
    let mut world = setup();

    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };

    let expected_round_id = actions_system.get_round_id();

    let actual_round_id = actions_system.create_round(Genre::Jazz.into());
    assert(actual_round_id == expected_round_id, 'Round IDs should match');

    let next_expected_id = actions_system.get_round_id();

    assert(next_expected_id == expected_round_id + 1_u256, 'Next ID should increment by 1');

    let next_actual_id = actions_system.create_round(Genre::Rock.into());
    assert(next_actual_id == next_expected_id, 'Next round IDs should match');

    let rounds_count: RoundsCount = world.read_model(GAME_ID);
    assert(rounds_count.count == 2_u256, 'rounds count should be 2');
}

#[test]
fn test_is_round_player_true() {
    let caller = starknet::contract_address_const::<0x0>();
    let player = starknet::contract_address_const::<0x1>();

    let mut world = setup();

    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };

    let round_id = actions_system.create_round(Genre::Rock.into());

    testing::set_contract_address(player);
    actions_system.join_round(round_id);

    let is_round_player = actions_system.is_round_player(round_id, player);

    assert(is_round_player, 'player not joined');
}

#[test]
fn test_is_round_player_false() {
    let caller = starknet::contract_address_const::<0x0>();
    let player = starknet::contract_address_const::<0x1>();

    let mut world = setup();

    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };

    let round_id = actions_system.create_round(Genre::Rock.into());
    let is_round_player = actions_system.is_round_player(round_id, player);

    assert(!is_round_player, 'player joined');
}

