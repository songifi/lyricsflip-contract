use starknet::{testing, ContractAddress};
use dojo::model::ModelStorage;
use dojo::world::{WorldStorageTrait};
use lyricsflip::constants::{GAME_ID, WAIT_PERIOD_BEFORE_FORCE_START, MAX_PLAYERS};
use lyricsflip::models::genre::Genre;
use lyricsflip::models::config::{GameConfig};
use lyricsflip::models::round::{Round, RoundsCount, RoundPlayer, Answer, Mode};
use lyricsflip::models::player::{PlayerStats};
use lyricsflip::models::round::RoundState;
use lyricsflip::systems::actions::{IActionsDispatcher, IActionsDispatcherTrait};
use lyricsflip::systems::config::{IGameConfigDispatcher, IGameConfigDispatcherTrait};
use lyricsflip::models::card::{
    LyricsCard, LyricsCardCount, YearCards, ArtistCards, CardData, GenreCards, CardTrait
};
use lyricsflip::tests::test_utils::{setup, setup_with_config, CARDS_PER_ROUND, get_answers, ADMIN};
use array::ArrayTrait;
use array::SpanTrait;

#[test]
fn test_get_cards_by_artist() {
    let mut world = setup();
    // Initialize LyricsCardCount
    world.write_model(@LyricsCardCount { id: GAME_ID, count: 5_u64 });
    // Set up an artist with associated card IDs
    let artist = 'artist1';
    let card_ids = array![1_u64, 2_u64, 3_u64, 4_u64, 5_u64];
    world.write_model(@ArtistCards { artist, cards: card_ids.span() });
    // Test retrieving 3 cards
    let result = CardTrait::get_cards_by_artist(ref world, artist, 3);
    assert(result.len() == 3, 'Should return 3 cards');
    let mut i = 0;
    while i < result.len() {
        assert(card_ids.contains(*result[i]), 'Invalid card ID');
        i += 1;
    };
    // Test retrieving all 5 cards
    let result = CardTrait::get_cards_by_artist(ref world, artist, 5);
    assert(result.len() == 5, 'Should return 5 cards');
    // Test with invalid artist (should panic)
    let invalid_artist = 'invalid_artist';
    let result = panic::catch_panic(|| CardTrait::get_cards_by_artist(ref world, invalid_artist, 1));
    assert(*result[0] == 'Artist not found', 'Should panic with artist not found');
    // Test requesting more cards than available (should panic)
    let result = panic::catch_panic(|| CardTrait::get_cards_by_artist(ref world, artist, 6));
    assert(*result[0] == 'Insufficient cards available', 'Should panic with insufficient cards');
}

#[test]
fn test_create_round_ok() {
    let caller = starknet::contract_address_const::<0x0>();
    let mut world = setup();
    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };
    let round_id = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);
    let round: Round = world.read_model(round_id);
    let rounds_count: RoundsCount = world.read_model(GAME_ID);
    assert(rounds_count.count == 1, 'rounds count is wrong');
    assert(round.creator == caller, 'round creator is wrong');
    assert(round.genre == Genre::Rock.into(), 'wrong round genre');
    assert(round.wager_amount == 0, 'wrong round wager_amount');
    assert(round.start_time == 0, 'wrong round start_time');
    assert(round.players_count == 1, 'wrong players_count');
    assert(round.state == RoundState::Pending.into(), 'Round state should be Pending');
    let round_id = actions_system.create_round(Genre::Pop.into(), Mode::MultiPlayer);
    let round: Round = world.read_model(round_id);
    let rounds_count: RoundsCount = world.read_model(GAME_ID);
    let round_player: RoundPlayer = world.read_model((caller, round_id));
    assert(rounds_count.count == 2, 'rounds count should be 2');
    assert(round.creator == caller, 'round creator is wrong');
    assert(round.genre == Genre::Pop.into(), 'wrong round genre');
    assert(round.players_count == 1, 'wrong players_count');
    assert(round_player.joined, 'round not joined');
    assert(round.state == RoundState::Pending.into(), 'Round state should be Pending');
}

#[test]
fn test_join_round() {
    let player = starknet::contract_address_const::<0x1>();
    let mut world = setup();
    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };
    let round_id = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 1, 'wrong players_count');
    testing::set_contract_address(player);
    actions_system.join_round(round_id);
    let round: Round = world.read_model(round_id);
    let round_player: RoundPlayer = world.read_model((player, round_id));
    assert(round.players_count == 2, 'wrong players_count');
    assert(round_player.joined, 'player not joined');
}

#[test]
#[should_panic]
fn test_cannot_join_round_non_existent_round() {
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
    let player = starknet::contract_address_const::<0x1>();
    let mut world = setup();
    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };
    let round_id = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);
    let mut round: Round = world.read_model(round_id);
    assert(round.players_count == 1, 'wrong players_count');
    round.state = RoundState::Started.into();
    world.write_model(@round);
    testing::set_contract_address(player);
    actions_system.join_round(round_id);
}

#[test]
#[should_panic]
fn test_cannot_join_already_joined_round() {
    let mut world = setup();
    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };
    let round_id = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);
    let mut round: Round = world.read_model(round_id);
    assert(round.players_count == 1, 'wrong players_count');
    actions_system.join_round(round_id);
}

#[test]
#[should_panic(expected: ('Max players reached', 'ENTRYPOINT_FAILED'))]
fn test_join_round_max_players_reached() {
    let player_1 = starknet::contract_address_const::<'player_1'>();
    let player_2 = starknet::contract_address_const::<'player_2'>();
    let mut world = setup();
    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);
    let mut round: Round = world.read_model(round_id);
    assert(round.players_count == 1, 'wrong players_count');
    let mut i = 0;
    while i != MAX_PLAYERS {
        let k: felt252 = i.into();
        let player: ContractAddress = k.try_into().unwrap();
        testing::set_contract_address(player);
        actions_system.join_round(round_id);
        i += 1;
    };
    for i in 0..MAX_PLAYERS {
        let k: felt252 = i.into();
        testing::set_contract_address(k.try_into().unwrap());
        actions_system.join_round(round_id);
    };
    let mut round: Round = world.read_model(round_id);
    assert!(round.players_count == MAX_PLAYERS.into(), "players count should be MAX_PLAYERS");
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);
}

#[test]
#[should_panic(expected: ('caller not admin', 'ENTRYPOINT_FAILED'))]
fn test_set_cards_per_round_non_admin() {
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
fn test_set_cards_per_round() {
    let mut world = setup();
    let admin = starknet::contract_address_const::<0x1>();
    let _default_cards_per_round = 5_u32;
    world.write_model(@GameConfig { id: GAME_ID, cards_per_round: 5_u32, admin_address: admin });
    let (contract_address, _) = world.dns(@"game_config").unwrap();
    let game_config_system = IGameConfigDispatcher { contract_address };
    testing::set_contract_address(admin);
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
    testing::set_contract_address(admin);
    let (contract_address, _) = world.dns(@"game_config").unwrap();
    let game_config_system = IGameConfigDispatcher { contract_address };
    game_config_system.set_cards_per_round(0);
}

#[test]
fn test_add_lyrics_card() {
    let mut world = setup();
    world.write_model(@LyricsCardCount { id: GAME_ID, count: 0_u64 });
    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };
    let genre = Genre::Pop;
    let artist = 'fame';
    let title = 'sounds';
    let year = 2020;
    let lyrics: ByteArray = "come to life...";
    actions_system.add_lyrics_card(genre, artist, title, year, lyrics.clone());
    let card: LyricsCard = world.read_model(1);
    assert(card.card_id == 1, 'wrong card_id');
    assert(card.genre == 'Pop', 'wrong genre');
    assert(card.artist == artist, 'wrong artist');
    assert(card.title == title, 'wrong title');
    assert(card.year == year, 'wrong year');
    assert(card.lyrics == lyrics, 'wrong lyrics');
    let card_count: LyricsCardCount = world.read_model(GAME_ID);
    assert(card_count.count == 1, 'wrong card count');
    let year_cards: YearCards = world.read_model(year);
    assert(year_cards.year == year, 'wrong year in YearCards');
    assert(year_cards.cards.len() == 1, 'should have 1 card');
    assert(*year_cards.cards[0] == 1, 'wrong card_id in YearCards');
    let artist_cards: ArtistCards = world.read_model(artist);
    assert(artist_cards.artist == artist, 'wrong artist in ArtistCards');
    assert(artist_cards.cards.len() == 1, 'should have 1 card');
    assert(*artist_cards.cards[0] == 1, 'wrong card_id in ArtistCards');
    let genre_felt: felt252 = genre.into();
    let genre_cards: GenreCards = world.read_model(genre_felt);
    assert(genre_cards.genre == genre.into(), 'wrong genre in GenreCards');
    assert(genre_cards.cards.len() == 1, 'should have 1 card');
    assert(*genre_cards.cards[0] == 1, 'wrong card_id in GenreCards');
}

#[test]
fn test_add_multiple_lyrics_cards_same_year() {
    let mut world = setup();
    world.write_model(@LyricsCardCount { id: GAME_ID, count: 0 });
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
    actions_system.add_lyrics_card(genre1, artist1, title1, year, lyrics1.clone());
    actions_system.add_lyrics_card(genre2, artist2, title2, year, lyrics2.clone());
    let card_count: LyricsCardCount = world.read_model(GAME_ID);
    assert(card_count.count == 2, 'wrong card count');
    let year_cards: YearCards = world.read_model(year);
    assert(year_cards.year == year, 'wrong year in YearCards');
    assert(year_cards.cards.len() == 2, 'should have 2 cards');
    assert(*year_cards.cards[0] == 1, 'wrong card_id 1 in YearCards');
    assert(*year_cards.cards[1] == 2, 'wrong card_id 2 in YearCards');
}

#[test]
fn test_add_lyrics_cards_different_years() {
    let mut world = setup();
    world.write_model(@LyricsCardCount { id: GAME_ID, count: 0 });
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
    actions_system.add_lyrics_card(genre1, artist1, title1, year1, lyrics1.clone());
    actions_system.add_lyrics_card(genre2, artist2, title2, year2, lyrics2.clone());
    let card_count: LyricsCardCount = world.read_model(GAME_ID);
    assert(card_count.count == 2, 'wrong card count');
    let year_cards1: YearCards = world.read_model(year1);
    assert(year_cards1.year == year1, 'wrong year in YearCards 1');
    assert(year_cards1.cards.len() == 1, 'should have 1 card in 2020');
    assert(*year_cards1.cards[0] == 1, 'wrong card_id in YearCards 1');
    let year_cards2: YearCards = world.read_model(year2);
    assert(year_cards2.year == year2, 'wrong year in YearCards 2');
    assert(year_cards2.cards.len() == 1, 'should have 1 card in 2021');
    assert(*year_cards2.cards[0] == 2, 'wrong card_id in YearCards 2');
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
fn test_is_round_player_true() {
    let player = starknet::contract_address_const::<0x1>();
    let mut world = setup();
    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };
    let round_id = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);
    testing::set_contract_address(player);
    actions_system.join_round(round_id);
    let is_round_player = actions_system.is_round_player(round_id, player);
    assert(is_round_player, 'player not joined');
}

#[test]
fn test_is_round_player_false() {
    let player = starknet::contract_address_const::<0x1>();
    let mut world = setup();
    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };
    let round_id = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);
    let is_round_player = actions_system.is_round_player(round_id, player);
    assert(!is_round_player, 'player joined');
}

#[test]
#[should_panic(expected: ('Caller is non participant', 'ENTRYPOINT_FAILED'))]
fn test_start_round_non_participant() {
    let caller = starknet::contract_address_const::<0x0>();
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();
    let mut world = setup();
    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'wrong players_count');
    testing::set_contract_address(caller);
    actions_system.start_round(round_id);
}

#[test]
#[should_panic(expected: ('Already signaled readiness', 'ENTRYPOINT_FAILED'))]
fn test_start_round_already_ready() {
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();
    let mut world = setup();
    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'wrong players_count');
    actions_system.start_round(round_id);
    actions_system.start_round(round_id);
}

#[test]
fn test_start_round_ok() {
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();
    let mut world = setup();
    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'wrong players_count');
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id);
    testing::set_contract_address(player_2);
    actions_system.start_round(round_id);
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Started.into(), 'Round state should be Started');
    assert(round.ready_players_count == 2, 'wrong ready_players_count');
    let round_player_1: RoundPlayer = world.read_model((player_1, round_id));
    assert(round_player_1.ready_state, 'player_1 should be ready');
    let round_player_2: RoundPlayer = world.read_model((player_2, round_id));
    assert(round_player_2.ready_state, 'player_2 should be ready');
    let player_stat_1: PlayerStats = world.read_model(player_1);
    assert(player_stat_1.total_rounds == 1, 'player_1 total_rounds == 1');
    let player_stat_2: PlayerStats = world.read_model(player_2);
    assert(player_stat_2.total_rounds == 1, 'player_2 total_rounds == 1');
}

#[test]
#[should_panic(expected: ('Round does not exist', 'ENTRYPOINT_FAILED'))]
fn test_next_card_invalid_round() {
    let (mut _world, actions_system) = setup_with_config();
    actions_system.next_card(1);
}

#[test]
#[should_panic(expected: ('Caller is non participant', 'ENTRYPOINT_FAILED'))]
fn test_next_card_non_participant() {
    let caller = starknet::contract_address_const::<0x0>();
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();
    let (mut world, actions_system) = setup_with_config();
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id);
    testing::set_contract_address(player_2);
    actions_system.start_round(round_id);
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Started.into(), 'Round state should be Started');
    assert(round.ready_players_count == 2, 'wrong ready_players_count');
    testing::set_contract_address(caller);
    actions_system.next_card(round_id);
}

#[test]
#[should_panic(expected: ('Round not started', 'ENTRYPOINT_FAILED'))]
fn test_next_card_round_not_started() {
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();
    let (mut _world, actions_system) = setup_with_config();
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);
    testing::set_contract_address(player_1);
    actions_system.next_card(round_id);
}

#[test]
fn test_next_card_ok() {
    let player_1 = starknet::contract_address_const::<0x1>();
    let (mut world, actions_system) = setup_with_config();
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);
    actions_system.start_round(round_id);
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Started.into(), 'Round state should be Started');
    let card_1 = actions_system.next_card(round_id);
    actions_system.submit_answer(round_id, Answer::OptionOne);
    let card_2 = actions_system.next_card(round_id);
    actions_system.submit_answer(round_id, Answer::OptionTwo);
    let card_3 = actions_system.next_card(round_id);
    actions_system.submit_answer(round_id, Answer::OptionThree);
    assert(card_1.lyric != card_2.lyric || card_2.lyric != card_3.lyric, 'lyrics not unique');
}

#[test]
fn test_next_card_ok_multiple_players() {
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();
    let (mut world, actions_system) = setup_with_config();
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id);
    testing::set_contract_address(player_2);
    actions_system.start_round(round_id);
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Started.into(), 'Round state should be Started');
    assert(round.ready_players_count == 2, 'wrong ready_players_count');
    testing::set_contract_address(player_1);
    let player_1_card_1 = actions_system.next_card(round_id);
    actions_system.submit_answer(round_id, Answer::OptionOne);
    testing::set_contract_address(player_2);
    let player_2_card_1 = actions_system.next_card(round_id);
    actions_system.submit_answer(round_id, Answer::OptionOne);
    testing::set_contract_address(player_1);
    let player_1_card_2 = actions_system.next_card(round_id);
    actions_system.submit_answer(round_id, Answer::OptionTwo);
    testing::set_contract_address(player_2);
    let player_2_card_2 = actions_system.next_card(round_id);
    actions_system.submit_answer(round_id, Answer::OptionTwo);
    assert!(player_1_card_1.lyric == player_2_card_1.lyric, "card_1 lyrics should be the same");
    assert!(player_1_card_2.lyric == player_2_card_2.lyric, "card_2 lyrics should be the same");
    assert(player_1_card_1.option_one == player_2_card_1.option_one, 'option_one should match');
    assert(player_1_card_1.option_two == player_2_card_1.option_two, 'option_two should match');
    assert(player_1_card_1.option_three == player_2_card_1.option_three, 'option_three should match');
    assert(player_1_card_1.option_four == player_2_card_1.option_four, 'option_four should match');
}

#[test]
#[should_panic(expected: ('Player completed round', 'ENTRYPOINT_FAILED'))]
fn test_next_card_when_all_cards_exhausted() {
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();
    let (mut world, actions_system) = setup_with_config();
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, Mode::MultiPlayer);
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id);
    testing::set_contract_address(player_2);
    actions_system.start_round(round_id);
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Started.into(), 'Round state should be Started');
    assert(round.ready_players_count == 2, 'wrong ready_players_count');
    for _ in 0..CARDS_PER_ROUND {
        actions_system.next_card(round_id);
        actions_system.submit_answer(round_id, Answer::OptionOne);
    };
    actions_system.next_card(round_id);
}

#[test]
#[available_gas(20000000000)]
fn test_next_card_when_all_players_exhaust_all_cards() {
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();
    let (mut world, actions_system) = setup_with_config();
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, 1);
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id);
    testing::set_contract_address(player_2);
    actions_system.start_round(round_id);
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Started.into(), 'Round state should be Started');
    assert(round.ready_players_count == 2, 'wrong ready_players_count');
    testing::set_contract_address(player_1);
    for _ in 0..CARDS_PER_ROUND {
        actions_system.next_card(round_id);
        actions_system.submit_answer(round_id, Answer::OptionOne);
    };
    testing::set_contract_address(player_2);
    for _ in 0..CARDS_PER_ROUND {
        actions_system.next_card(round_id);
        actions_system.submit_answer(round_id, Answer::OptionOne);
    };
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Completed.into(), 'Round should be completed');
}

#[test]
fn test_submit_answer_ok() {
    let player_1 = starknet::contract_address_const::<0x1>();
    let (mut world, actions_system) = setup_with_config();
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, 1);
    actions_system.start_round(round_id);
    let question_card = actions_system.next_card(round_id);
    let (correct_option, wrong_option) = get_answers(ref world, round_id, player_1, @question_card);
    let is_correct = actions_system.submit_answer(round_id, correct_option.unwrap());
    assert!(is_correct, "Correct answer should be correct");
    actions_system.next_card(round_id);
    let is_correct = actions_system.submit_answer(round_id, wrong_option);
    assert!(!is_correct, "answer should be incorrect");
}

#[test]
fn test_question_card_generation() {
    let player_1 = starknet::contract_address_const::<0x1>();
    let (mut world, actions_system) = setup_with_config();
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, 1);
    actions_system.start_round(round_id);
    let question_card = actions_system.next_card(round_id);
    assert(question_card.lyric.len() > 0, 'Lyric should not be empty');
    let (correct_answer, _) = get_answers(ref world, round_id, player_1, @question_card);
    assert(correct_answer.is_some(), 'Should have a correct answer');
    let is_correct = actions_system.submit_answer(round_id, correct_answer.unwrap());
    assert(is_correct, 'Should be correct answer');
    let mut options = array![
        question_card.option_one,
        question_card.option_two,
        question_card.option_three,
        question_card.option_four,
    ];
    for i in 0..4_u32 {
        for j in (i + 1)..4 {
            let (artist1, title1) = *options.at(i);
            let (artist2, title2) = *options.at(j);
            assert!(artist1 != artist2 || title1 != title2, "Options should be unique");
        };
    }
}

#[test]
#[should_panic(expected: ('Cannot join solo mode', 'ENTRYPOINT_FAILED'))]
fn test_join_round_for_solo_mode() {
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();
    let (mut _, actions_system) = setup_with_config();
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Pop, false);
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);
}

#[test]
fn test_add_batch_lyrics_card() {
    let mut world = setup();
    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };
    let card = CardData {
        genre: Genre::Pop,
        artist: 'artist',
        title: 'title',
        year: 2020,
        lyrics: "lyrics",
    };
    let cards = array![card.clone(), card.clone(), card.clone()];
    actions_system.add_batch_lyrics_card(cards.span());
    let card_count: LyricsCardCount = world.read_model(GAME_ID);
    assert(card_count.count == 3, 'card count wrong');
}

#[test]
#[should_panic(expected: ("Only admin_or creator can force start", 'ENTRYPOINT_FAILED'))]
fn test_force_start_round_non_admin_or_creator() {
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();
    let (mut world, actions_system) = setup_with_config();
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, 1);
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'wrong players_count');
    testing::set_contract_address(player_2);
    actions_system.force_start_round(round_id);
}

#[test]
#[should_panic(expected: ('Round not in Pending state', 'ENTRYPOINT_FAILED'))]
fn test_force_start_round_non_pending_round() {
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();
    let (mut world, actions_system) = setup_with_config();
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, 1);
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'wrong players_count');
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id);
    testing::set_contract_address(player_2);
    actions_system.start_round(round_id);
    testing::set_contract_address(ADMIN());
    actions_system.force_start_round(round_id);
}

#[test]
#[should_panic(expected: ('Waiting period not over', 'should fail'))]
fn test_force_start_round_before_waiting_period() {
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();
    let (mut world, actions_system) = setup_with_config();
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, 1);
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'wrong players_count');
    testing::set_contract_address(ADMIN());
    actions_system.force_start_round(round_id);
}

#[test]
#[should_panic(expected: ('Need at least 2 players', 'ENTRYPOINT_FAILED'))]
fn test_force_start_round_one_player() {
    let player_1 = starknet::contract_address_const::<0x1>();
    testing::set_block_timestamp(0);
    let (mut _, actions_system) = setup_with_config();
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, 1);
    let round: actions_system.world.read_model(round_id);
    assert(round.players_count == 1, 'wrong players_count');
    testing::set_block_timestamp(WAIT_PERIOD_BEFORE_FORCE_START + 1);
    testing::set_contract_address(ADMIN());
    actions_system.force_start_round(round_id);
}

#[test]
fn test_force_start_round_admin_ok() {
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();
    testing::set_block_timestamp(0);
    let (mut world, actions_system) = setup_with_config();
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, 2);
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'players_count wrong');
    testing::set_block_timestamp(WAIT_PERIOD_BEFORE_FORCE_START + 1);
    testing::set_contract_address(ADMIN());
    actions_system.force_start_round(round_id);
}

#[test]
fn test_force_start_round_creator_ok() {
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();
    testing::set_block_timestamp(0);
    let (mut world, actions_system) = setup_with_config();
    testing::set_contract_address(player_1);
    let round_id = actions_system.create_round(Genre::Rock, 2);
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'players_count wrong');
    testing::set_block_timestamp(WAIT_PERIOD_BEFORE_FORCE_START + 1);
    testing::set_contract_address(player_1);
    actions_system.force_start_round(round_id);
}

