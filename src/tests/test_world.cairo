use dojo::model::ModelStorage;
use dojo::world::WorldStorageTrait;
use lyricsflip::constants::{GAME_ID, MAX_PLAYERS, WAIT_PERIOD_BEFORE_FORCE_START};
use lyricsflip::models::card::{
    ArtistCards, CardData, CardTrait, GenreCards, LyricsCard, LyricsCardCount, YearCards,
};
use lyricsflip::models::genre::Genre;
use lyricsflip::models::player::PlayerStats;
use lyricsflip::models::round::{Answer, Mode, Round, RoundPlayer, RoundState, RoundsCount};
use lyricsflip::systems::actions::{IActionsDispatcher, IActionsDispatcherTrait};
use lyricsflip::tests::test_utils::{
    ADMIN, CARDS_PER_ROUND, get_answers, setup, setup_with_config, create_genre_round,
    create_random_round, create_year_round, contains,
};
use starknet::{ContractAddress, testing};


#[test]
fn test_create_round_ok() {
    let caller = starknet::contract_address_const::<0x0>();

    let (mut world, mut actions_system) = setup_with_config();

    testing::set_contract_address(caller);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    let round: Round = world.read_model(round_id);
    let rounds_count: RoundsCount = world.read_model(GAME_ID);

    assert(rounds_count.count == 1, 'rounds count is wrong');
    assert(round.creator == caller, 'round creator is wrong');
    assert(round.wager_amount == 0, 'wrong round wager_amount');
    assert(round.start_time == 0, 'wrong round start_time');
    assert(round.players_count == 1, 'wrong players_count');
    assert(round.state == RoundState::Pending.into(), 'Round state should be Pending');

    testing::set_contract_address(caller);
    let round_id = create_random_round(ref actions_system, Mode::MultiPlayer);

    let round: Round = world.read_model(round_id);
    let rounds_count: RoundsCount = world.read_model(GAME_ID);
    let round_player: RoundPlayer = world.read_model((caller, round_id));

    assert(rounds_count.count == 2, 'rounds count should be 2');
    assert(round.creator == caller, 'round creator is wrong');
    assert(round.players_count == 1, 'wrong players_count');

    assert(round_player.joined, 'round not joined');
    assert(round.state == RoundState::Pending.into(), 'Round state should be Pending');
}

#[test]
fn test_join_round() {
    let player = starknet::contract_address_const::<0x1>();

    let (mut world, mut actions_system) = setup_with_config();

    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

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

    let (mut world, mut actions_system) = setup_with_config();

    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

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
    let (mut world, mut actions_system) = setup_with_config();

    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    let mut round: Round = world.read_model(round_id);
    assert(round.players_count == 1, 'wrong players_count');

    actions_system.join_round(round_id);
}

#[test]
#[available_gas(20000000000)]
#[should_panic(expected: ('Max players reached', 'ENTRYPOINT_FAILED'))]
fn test_join_round_max_players_reached() {
    let player_1 = starknet::contract_address_const::<'player_1'>();
    let player_2 = starknet::contract_address_const::<'player_2'>();

    let (mut world, mut actions_system) = setup_with_config();

    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

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
fn test_add_lyrics_card() {
    let mut world = setup();

    // Inicializamos LyricsCardCount
    world.write_model(@LyricsCardCount { id: GAME_ID, count: 0_u64 });

    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };

    let genre = Genre::Pop;
    let artist = 'fame';
    let title = 'sounds';
    let year = 2020;
    let lyrics: ByteArray = "come to life...";

    actions_system.add_lyrics_card(genre, artist, title, year, lyrics.clone());

    // Verificamos el LyricsCard
    let card: LyricsCard = world.read_model(1);
    assert(card.card_id == 1, 'wrong card_id');
    assert(card.genre == 'Pop', 'wrong genre');
    assert(card.artist == artist, 'wrong artist');
    assert(card.title == title, 'wrong title');
    assert(card.year == year, 'wrong year');
    assert(card.lyrics == lyrics, 'wrong lyrics');

    // Verificamos el LyricsCardCount
    let card_count: LyricsCardCount = world.read_model(GAME_ID);
    assert(card_count.count == 1, 'wrong card count');

    // Verificamos el YearCards
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

    // Inicializamos LyricsCardCount
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

    // Agregamos la primera tarjeta
    actions_system.add_lyrics_card(genre1, artist1, title1, year, lyrics1.clone());
    // Agregamos la segunda tarjeta en el mismo año
    actions_system.add_lyrics_card(genre2, artist2, title2, year, lyrics2.clone());

    // Verificamos el LyricsCardCount
    let card_count: LyricsCardCount = world.read_model(GAME_ID);
    assert(card_count.count == 2, 'wrong card count');

    // Verificamos el YearCards
    let year_cards: YearCards = world.read_model(year);
    assert(year_cards.year == year, 'wrong year in YearCards');
    assert(year_cards.cards.len() == 2, 'should have 2 cards');
    assert(*year_cards.cards[0] == 1, 'wrong card_id 1 in YearCards');
    assert(*year_cards.cards[1] == 2, 'wrong card_id 2 in YearCards');
}

#[test]
fn test_add_lyrics_cards_different_years() {
    let mut world = setup();

    // Inicializamos LyricsCardCount
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

    // Agregamos la primera tarjeta (año 2020)
    actions_system.add_lyrics_card(genre1, artist1, title1, year1, lyrics1.clone());
    // Agregamos la segunda tarjeta (año 2021)
    actions_system.add_lyrics_card(genre2, artist2, title2, year2, lyrics2.clone());

    // Verificamos el LyricsCardCount
    let card_count: LyricsCardCount = world.read_model(GAME_ID);
    assert(card_count.count == 2, 'wrong card count');

    // Verificamos el YearCards para el año 2020
    let year_cards1: YearCards = world.read_model(year1);
    assert(year_cards1.year == year1, 'wrong year in YearCards 1');
    assert(year_cards1.cards.len() == 1, 'should have 1 card in 2020');
    assert(*year_cards1.cards[0] == 1, 'wrong card_id in YearCards 1');

    // Verificamos el YearCards para el año 2021
    let year_cards2: YearCards = world.read_model(year2);
    assert(year_cards2.year == year2, 'wrong year in YearCards 2');
    assert(year_cards2.cards.len() == 1, 'should have 1 card in 2021');
    assert(*year_cards2.cards[0] == 2, 'wrong card_id in YearCards 2');
}

#[test]
fn test_is_round_player_true() {
    let player = starknet::contract_address_const::<0x1>();

    let (mut _world, mut actions_system) = setup_with_config();

    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    testing::set_contract_address(player);
    actions_system.join_round(round_id);

    let is_round_player = actions_system.is_round_player(round_id, player);

    assert(is_round_player, 'player not joined');
}

#[test]
fn test_is_round_player_false() {
    let player = starknet::contract_address_const::<0x1>();

    let (mut _world, mut actions_system) = setup_with_config();

    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);
    let is_round_player = actions_system.is_round_player(round_id, player);

    assert(!is_round_player, 'player joined');
}


/// Test case: Attempting to start a round as a non-participant should fail
///
/// This test verifies that only participants (including the creator) can signal readiness.
/// The test should panic with the message "Caller is non participant".
#[test]
#[should_panic(expected: ('Caller is non participant', 'ENTRYPOINT_FAILED'))]
fn test_start_round_non_participant() {
    // Define test addresses
    let caller = starknet::contract_address_const::<0x0>(); // Non-participant address
    let player_1 = starknet::contract_address_const::<0x1>(); // Round creator 
    let player_2 = starknet::contract_address_const::<0x2>(); // Round participant

    // Initialize the test environment
    let (mut world, mut actions_system) = setup_with_config();

    // Set player_1 as the current caller and create a new round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Set player_2 as the current caller and have them join the round
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);

    // Verify that the round has 2 players
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'wrong players_count');

    // Set a non-participant address as the caller and attempt to start the round
    // This should fail with "Caller is non participant"
    testing::set_contract_address(caller);
    actions_system.start_round(round_id);
}


/// Test case: A player cannot signal readiness twice
///
/// This test verifies that a player cannot signal readiness more than once for the same round.
/// The test should panic with the message "Already signaled readiness".
#[test]
#[should_panic(expected: ('Already signaled readiness', 'ENTRYPOINT_FAILED'))]
fn test_start_round_already_ready() {
    // Define test addresses
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();

    // Initialize the test environment
    let (mut world, mut actions_system) = setup_with_config();

    // Set player_1 as the current caller and create a new round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Set player_2 as the current caller and have them join the round
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);

    // Verify that the round has 2 players
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'wrong players_count');

    // Player_2 signals readiness
    actions_system.start_round(round_id);

    // Player_2 tries to signal readiness again (should fail with "Already signaled readiness")
    actions_system.start_round(round_id);
}

/// Test case: Successfully starting a round when all players are ready
///
/// This test verifies the complete flow of starting a round:
/// 1. Two players join a round
/// 2. Both players signal readiness
/// 3. The round state changes to Started
/// 4. Player statistics are updated correctly
#[test]
fn test_start_round_ok() {
    // Define test addresses
    let player_1 = starknet::contract_address_const::<0x1>(); // Round creator
    let player_2 = starknet::contract_address_const::<0x2>(); // Round participant

    // Initialize the test environment
    let (mut world, mut actions_system) = setup_with_config();

    // Set player_1 as the current caller and create a new round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Set player_2 as the current caller and have them join the round
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);

    // Verify that the round has 2 players
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'wrong players_count');

    // Player_1 signals readiness
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id);

    // Player_2 signals readiness
    testing::set_contract_address(player_2);
    actions_system.start_round(round_id);

    // Verify the round is now in the Started state
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Started.into(), 'Round state should be Started');
    assert(round.ready_players_count == 2, 'wrong ready_players_count');

    // Verify player_1's ready state and statistics
    let round_player_1: RoundPlayer = world.read_model((player_1, round_id));
    assert(round_player_1.ready_state, 'player_1 should be ready');

    // Verify player_2's ready state and statistics
    let round_player_2: RoundPlayer = world.read_model((player_2, round_id));
    assert(round_player_2.ready_state, 'player_2 should be ready');

    // Verify player_1's total rounds count has been incremented
    let player_stat_1: PlayerStats = world.read_model(player_1);
    assert(player_stat_1.total_rounds == 1, 'player_1 total_rounds == 1');

    // Verify player_2's total rounds count has been incremented
    let player_stat_2: PlayerStats = world.read_model(player_2);
    assert(player_stat_2.total_rounds == 1, 'player_2 total_rounds == 1');
}

#[test]
#[should_panic(expected: ('Round does not exist', 'ENTRYPOINT_FAILED'))]
fn test_next_card_invalid_round() {
    // Initialize the test environment
    let (mut _world, actions_system) = setup_with_config();

    actions_system.next_card(1);
}

#[test]
#[should_panic(expected: ('Caller is non participant', 'ENTRYPOINT_FAILED'))]
fn test_next_card_non_participant() {
    // Define test addresses
    let caller = starknet::contract_address_const::<0x0>();
    let player_1 = starknet::contract_address_const::<0x1>(); // Round creator
    let player_2 = starknet::contract_address_const::<0x2>(); // Round participant

    // Initialize the test environment
    let (mut world, mut actions_system) = setup_with_config();

    // Set player_1 as the current caller and create a new round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Set player_2 as the current caller and have them join the round
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);

    // Player_1 signals readiness
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id);

    // Player_2 signals readiness
    testing::set_contract_address(player_2);
    actions_system.start_round(round_id);

    // Verify the round is now in the Started state
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Started.into(), 'Round state should be Started');
    assert(round.ready_players_count == 2, 'wrong ready_players_count');

    testing::set_contract_address(caller);
    actions_system.next_card(round_id);
}

#[test]
#[should_panic(expected: ('Round not started', 'ENTRYPOINT_FAILED'))]
fn test_next_card_round_not_started() {
    // Define test addresses
    let player_1 = starknet::contract_address_const::<0x1>(); // Round creator
    let player_2 = starknet::contract_address_const::<0x2>(); // Round participant

    // Initialize the test environment
    let (mut _world, mut actions_system) = setup_with_config();

    // Set player_1 as the current caller and create a new round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Set player_2 as the current caller and have them join the round
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);

    testing::set_contract_address(player_1);
    actions_system.next_card(round_id);
}

#[test]
fn test_next_card_ok() {
    // Define test addresses
    let player_1 = starknet::contract_address_const::<0x1>(); // Round creator

    // Initialize the test environment
    let (mut world, mut actions_system) = setup_with_config();

    // Set player_1 as the current caller and create a new round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Player_1 signals readiness
    actions_system.start_round(round_id);

    // Verify the round is now in the Started state
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Started.into(), 'Round state should be Started');

    let card_1 = actions_system.next_card(round_id);
    actions_system.submit_answer(round_id, Answer::OptionOne);

    let card_2 = actions_system.next_card(round_id);
    actions_system.submit_answer(round_id, Answer::OptionTwo);

    let card_3 = actions_system.next_card(round_id);
    actions_system.submit_answer(round_id, Answer::OptionThree);

    // Check that the lyrics are different (which means they come from different cards)
    assert(card_1.lyric != card_2.lyric || card_2.lyric != card_3.lyric, 'lyrics not unique');
}

#[test]
fn test_next_card_ok_multiple_players() {
    // Define test addresses
    let player_1 = starknet::contract_address_const::<0x1>(); // Round creator
    let player_2 = starknet::contract_address_const::<0x2>(); // Round participant

    // Initialize the test environment
    let (mut world, mut actions_system) = setup_with_config();

    // Set player_1 as the current caller and create a new round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Set player_2 as the current caller and have them join the round
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);

    // Player_1 signals readiness
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id);

    // Player_2 signals readiness
    testing::set_contract_address(player_2);
    actions_system.start_round(round_id);

    // Verify the round is now in the Started state
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

    // Check that both players got the same lyrics
    assert!(player_1_card_1.lyric == player_2_card_1.lyric, "card_1 lyrics should be the same");
    assert!(player_1_card_2.lyric == player_2_card_2.lyric, "card_2 lyrics should be the same");

    // Check that both players got the same options (in the same order)
    assert(player_1_card_1.option_one == player_2_card_1.option_one, 'option_one should match');
    assert(player_1_card_1.option_two == player_2_card_1.option_two, 'option_two should match');
    assert(
        player_1_card_1.option_three == player_2_card_1.option_three, 'option_three should match',
    );
    assert(player_1_card_1.option_four == player_2_card_1.option_four, 'option_four should match');
}

#[test]
#[available_gas(20000000000)]
#[should_panic(expected: ('Player completed round', 'ENTRYPOINT_FAILED'))]
fn test_next_card_when_all_cards_exhausted() {
    // Define test addresses
    let player_1 = starknet::contract_address_const::<0x1>(); // Round creator
    let player_2 = starknet::contract_address_const::<0x2>(); // Round participant

    // Initialize the test environment
    let (mut world, mut actions_system) = setup_with_config();

    // Set player_1 as the current caller and create a new round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Set player_2 as the current caller and have them join the round
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);

    // Player_1 signals readiness
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id);

    // Player_2 signals readiness
    testing::set_contract_address(player_2);
    actions_system.start_round(round_id);

    // Verify the round is now in the Started state
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Started.into(), 'Round state should be Started');
    assert(round.ready_players_count == 2, 'wrong ready_players_count');
    for _ in 0..CARDS_PER_ROUND {
        actions_system.next_card(round_id);
        actions_system.submit_answer(round_id, Answer::OptionOne);
    };

    // Attempting to get another card should panic with "All cards exhausted"
    actions_system.next_card(round_id);
}

#[test]
#[available_gas(20000000000)]
fn test_next_card_when_all_players_exhaust_all_cards() {
    // Define test addresses
    let player_1 = starknet::contract_address_const::<0x1>(); // Round creator
    let player_2 = starknet::contract_address_const::<0x2>(); // Round participant

    // Initialize the test environment
    let (mut world, mut actions_system) = setup_with_config();

    // Set player_1 as the current caller and create a new round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Set player_2 as the current caller and have them join the round
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);

    // Player_1 signals readiness
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id);

    // Player_2 signals readiness
    testing::set_contract_address(player_2);
    actions_system.start_round(round_id);

    // Verify the round is now in the Started state
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Started.into(), 'Round state should be Started');
    assert(round.ready_players_count == 2, 'wrong ready_players_count');

    // Player_1 plays
    testing::set_contract_address(player_1);
    for _ in 0..CARDS_PER_ROUND {
        actions_system.next_card(round_id);
        actions_system.submit_answer(round_id, Answer::OptionOne);
    };

    // Player_2 plays
    testing::set_contract_address(player_2);
    for _ in 0..CARDS_PER_ROUND {
        actions_system.next_card(round_id);
        actions_system.submit_answer(round_id, Answer::OptionOne);
    };

    // Verify the round is now in the completed state
    let round: Round = world.read_model(round_id);
    assert(round.state == RoundState::Completed.into(), 'Round should be completed');
}

#[test]
fn test_submit_answer_ok() {
    // Define test addresses
    let player_1 = starknet::contract_address_const::<0x1>();

    let (mut world, mut actions_system) = setup_with_config();

    // Create round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Start round
    actions_system.start_round(round_id);

    // Get card and submit answers
    let question_card = actions_system.next_card(round_id);

    // Since we don't know which option is correct, we'll need to find it

    let (correct_option, wrong_option) = get_answers(ref world, round_id, player_1, @question_card);

    // Test correct answer
    let is_correct = actions_system.submit_answer(round_id, correct_option.unwrap());
    assert!(is_correct, "Correct answer should be correct");

    // Get next card and test wrong answer
    actions_system.next_card(round_id);
    let is_correct = actions_system.submit_answer(round_id, wrong_option);
    assert!(!is_correct, "answer should be incorrect");
}

#[test]
fn test_question_card_generation() {
    // Define test addresses
    let player_1 = starknet::contract_address_const::<0x1>();

    // Initialize the test environment
    let (mut world, mut actions_system) = setup_with_config();

    // Create a round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Start the round
    actions_system.start_round(round_id);

    // Get the question card
    let question_card = actions_system.next_card(round_id);

    // Verify the question card structure
    assert(question_card.lyric.len() > 0, 'Lyric should not be empty');

    // Verify one option is correct
    let (correct_answer, _) = get_answers(ref world, round_id, player_1, @question_card);
    assert(correct_answer.is_some(), 'Should have a correct answer');

    // Submit the correct answer and verify it works
    let is_correct = actions_system.submit_answer(round_id, correct_answer.unwrap());
    assert(is_correct, 'Should be correct answer');
    // Check that the options are all different
    let mut options = array![
        question_card.option_one,
        question_card.option_two,
        question_card.option_three,
        question_card.option_four,
    ];

    // Check for duplicates
    for i in 0..4_u32 {
        for j in (i + 1)..4 {
            let (artist1, title1) = options.at(i);
            let (artist2, title2) = options.at(j);
            assert!(artist1 != artist2 || title1 != title2, "Options should be unique");
        }
    }
}

#[test]
#[should_panic(expected: ('Cannot join solo mode', 'ENTRYPOINT_FAILED'))]
fn test_join_round_for_solo_mode() {
    // Setup players
    let player_1 = starknet::contract_address_const::<0x1>();
    let player_2 = starknet::contract_address_const::<0x2>();

    let (mut _world, mut actions_system) = setup_with_config();

    // 1. Player 1 creates a round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::Solo, Genre::Pop);

    // player 2 tries to join the round
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);
}

#[test]
fn test_add_batch_lyrics_card() {
    let mut world = setup();

    let (contract_address, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address };

    let card = CardData {
        genre: Genre::Pop, artist: 'artist', title: 'title', year: 2020, lyrics: "lyrics",
    };

    let cards = array![card.clone(), card.clone(), card.clone()];

    actions_system.add_batch_lyrics_card(cards.span());

    let card_count: LyricsCardCount = world.read_model(GAME_ID);

    assert(card_count.count == 3, 'wrong card count');
}

#[test]
#[should_panic(expected: ("Only admin or creator can force start", 'ENTRYPOINT_FAILED'))]
fn test_force_start_round_non_admin_or_creator() {
    // Define test addresses
    let player_1 = starknet::contract_address_const::<0x1>(); // Round creator
    let player_2 = starknet::contract_address_const::<0x2>(); // Round participant

    // Initialize the test environment
    let (mut world, mut actions_system) = setup_with_config();

    // Set player_1 as the current caller and create a new round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Set player_2 as the current caller and have them join the round
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);

    // Verify that the round has 2 players
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'wrong players_count');

    testing::set_contract_address(player_2);
    actions_system.force_start_round(round_id);
}

#[test]
#[should_panic(expected: ('Round not in Pending state', 'ENTRYPOINT_FAILED'))]
fn test_force_start_round_non_pending_round() {
    // Define test addresses
    let player_1 = starknet::contract_address_const::<0x1>(); // Round creator
    let player_2 = starknet::contract_address_const::<0x2>(); // Round participant

    // Initialize the test environment
    let (mut world, mut actions_system) = setup_with_config();

    // Set player_1 as the current caller and create a new round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Set player_2 as the current caller and have them join the round
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);

    // Verify that the round has 2 players
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'wrong players_count');

    // Player_1 signals readiness
    testing::set_contract_address(player_1);
    actions_system.start_round(round_id);

    // Player_2 signals readiness
    testing::set_contract_address(player_2);
    actions_system.start_round(round_id);

    testing::set_contract_address(ADMIN());
    actions_system.force_start_round(round_id);
}

#[test]
#[should_panic(expected: ('Waiting period not over', 'ENTRYPOINT_FAILED'))]
fn test_force_start_round_before_waiting_period() {
    // Define test addresses
    let player_1 = starknet::contract_address_const::<0x1>(); // Round creator
    let player_2 = starknet::contract_address_const::<0x2>(); // Round participant

    // Initialize the test environment
    let (mut world, mut actions_system) = setup_with_config();

    // Set player_1 as the current caller and create a new round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Set player_2 as the current caller and have them join the round
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);

    // Verify that the round has 2 players
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'wrong players_count');

    testing::set_contract_address(ADMIN());
    actions_system.force_start_round(round_id);
}

#[test]
#[should_panic(expected: ('Need at least 2 players', 'ENTRYPOINT_FAILED'))]
fn test_force_start_round_one_player() {
    // Define test addresses
    let player_1 = starknet::contract_address_const::<0x1>(); // Round creator

    // Initialize the test environment
    let (mut world, mut actions_system) = setup_with_config();

    testing::set_block_timestamp(0);

    // Set player_1 as the current caller and create a new round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Verify that the round has 1 player
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 1, 'wrong players_count');

    testing::set_block_timestamp(WAIT_PERIOD_BEFORE_FORCE_START + 1);

    testing::set_contract_address(ADMIN());
    actions_system.force_start_round(round_id);
}

#[test]
fn test_force_start_round_admin_ok() {
    // Define test addresses
    let player_1 = starknet::contract_address_const::<0x1>(); // Round creator
    let player_2 = starknet::contract_address_const::<0x2>(); // Round participant

    // Initialize the test environment
    let (mut world, mut actions_system) = setup_with_config();

    testing::set_block_timestamp(0);

    // Set player_1 as the current caller and create a new round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Set player_2 as the current caller and have them join the round
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);

    // Verify that the round has 2 players
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'wrong players_count');

    testing::set_block_timestamp(WAIT_PERIOD_BEFORE_FORCE_START + 1);

    testing::set_contract_address(ADMIN());
    actions_system.force_start_round(round_id);
}

#[test]
fn test_force_start_round_creator_ok() {
    // Define test addresses
    let player_1 = starknet::contract_address_const::<0x1>(); // Round creator
    let player_2 = starknet::contract_address_const::<0x2>(); // Round participant

    // Initialize the test environment
    let (mut world, mut actions_system) = setup_with_config();

    testing::set_block_timestamp(0);

    // Set player_1 as the current caller and create a new round
    testing::set_contract_address(player_1);
    let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

    // Set player_2 as the current caller and have them join the round
    testing::set_contract_address(player_2);
    actions_system.join_round(round_id);

    // Verify that the round has 2 players
    let round: Round = world.read_model(round_id);
    assert(round.players_count == 2, 'wrong players_count');

    testing::set_block_timestamp(WAIT_PERIOD_BEFORE_FORCE_START + 1);

    testing::set_contract_address(player_1);
    actions_system.force_start_round(round_id);
}

#[test]
fn test_get_cards_by_year_ok() {
    let mut world = setup();

    let year = 2024_u64;
    let card_ids: Array<u64> = array![101_u64, 102_u64, 103_u64, 104_u64];

    let year_cards = YearCards { year, cards: card_ids.span().clone() };
    world.write_model(@year_cards);

    let count = 2_u64;
    let selected_cards = CardTrait::get_cards_by_year(ref world, year, count);

    assert(selected_cards.len() == count.try_into().unwrap(), 'wrong no of cards');

    let mut i = 0;
    loop {
        if i >= selected_cards.len() {
            break;
        }

        let card_id = selected_cards[i];
        assert(contains(card_ids.clone(), *card_id), 'Returned unknown card');
        i += 1;
    }
}


#[test]
#[should_panic]
fn test_get_cards_by_year_not_enough_cards() {
    let mut world = setup();

    let year = 2024_u64;
    let year_cards = YearCards { year, cards: array![101_u64].span().clone() };
    world.write_model(@year_cards);

    CardTrait::get_cards_by_year(ref world, year, 5_u64);
}

#[test]
fn test_get_cards_by_genre_and_decade_ok() {
    let mut world = setup();

    let rock_genre = Genre::Rock.into();
    let decade = 1990_u64;

    let rock_card_1991 = LyricsCard {
        card_id: 1,
        genre: rock_genre,
        artist: 'Nirvana',
        title: 'Smells Like Teen Spirit',
        year: 1991,
        lyrics: "Load up on guns",
    };

    let rock_card_1995 = LyricsCard {
        card_id: 2,
        genre: rock_genre,
        artist: 'Foo Fighters',
        title: 'This Is a Call',
        year: 1995,
        lyrics: "Fingernails are pretty",
    };

    let rock_card_1999 = LyricsCard {
        card_id: 3,
        genre: rock_genre,
        artist: 'Red Hot Chili Peppers',
        title: 'Californication',
        year: 1999,
        lyrics: "Psychic spies from China",
    };

    let rock_card_2001 = LyricsCard {
        card_id: 4,
        genre: rock_genre,
        artist: 'Linkin Park',
        title: 'In the End',
        year: 2001,
        lyrics: "I tried so hard",
    };

    world.write_model(@rock_card_1991);
    world.write_model(@rock_card_1995);
    world.write_model(@rock_card_1999);
    world.write_model(@rock_card_2001);

    let genre_card_ids: Array<u64> = array![1_u64, 2_u64, 3_u64, 4_u64];
    let genre_cards = GenreCards { genre: rock_genre, cards: genre_card_ids.span().clone() };
    world.write_model(@genre_cards);

    let count = 2_u64;
    let selected_cards = CardTrait::get_cards_by_genre_and_decade(
        ref world, rock_genre, decade, count,
    );

    assert(selected_cards.len() == count.try_into().unwrap(), 'wrong no of cards');

    let expected_cards: Array<u64> = array![1_u64, 2_u64, 3_u64];

    let mut i = 0;
    loop {
        if i >= selected_cards.len() {
            break;
        }
        let card_id = selected_cards[i];
        assert(contains(expected_cards.clone(), *card_id), 'Returned card not in 1990s');

        let card: LyricsCard = world.read_model(*card_id);
        assert(card.year >= 1990 && card.year <= 1999, 'Card not from 1990s');
        assert(card.genre == rock_genre, 'Card not rock genre');

        i += 1;
    }
}

#[test]
fn test_get_cards_by_genre_and_decade_all_available() {
    let mut world = setup();

    let pop_genre = Genre::Pop.into();
    let decade = 1990_u64;

    let pop_card_1992 = LyricsCard {
        card_id: 5,
        genre: pop_genre,
        artist: 'Whitney Houston',
        title: 'I Will Always Love You',
        year: 1992,
        lyrics: "And I will always love you",
    };

    let pop_card_1996 = LyricsCard {
        card_id: 6,
        genre: pop_genre,
        artist: 'Spice Girls',
        title: 'Wannabe',
        year: 1996,
        lyrics: "I'll tell you what I want",
    };

    let pop_card_1998 = LyricsCard {
        card_id: 7,
        genre: pop_genre,
        artist: 'Britney Spears',
        title: 'Baby One More Time',
        year: 1998,
        lyrics: "Oh baby baby",
    };

    world.write_model(@pop_card_1992);
    world.write_model(@pop_card_1996);
    world.write_model(@pop_card_1998);

    let genre_card_ids: Array<u64> = array![5_u64, 6_u64, 7_u64];
    let genre_cards = GenreCards { genre: pop_genre, cards: genre_card_ids.span().clone() };
    world.write_model(@genre_cards);

    let count = 3_u64;
    let selected_cards = CardTrait::get_cards_by_genre_and_decade(
        ref world, pop_genre, decade, count,
    );

    assert(selected_cards.len() == count.try_into().unwrap(), 'wrong no of cards');

    let mut i = 0;
    loop {
        if i >= selected_cards.len() {
            break;
        }
        let card_id = selected_cards[i];
        assert(contains(genre_card_ids.clone(), *card_id), 'Returned unknown card');
        i += 1;
    }
}

#[test]
fn test_get_cards_by_genre_and_decade_boundary_years() {
    let mut world = setup();

    let rock_genre = Genre::Rock.into();
    let decade = 1990_u64;

    let card_1990 = LyricsCard {
        card_id: 10,
        genre: rock_genre,
        artist: 'TestArtist',
        title: 'TestTitle1990',
        year: 1990,
        lyrics: "Test 1990",
    };

    let card_1999 = LyricsCard {
        card_id: 11,
        genre: rock_genre,
        artist: 'TestArtist',
        title: 'TestTitle1999',
        year: 1999, // End of decade
        lyrics: "Test 1999",
    };

    world.write_model(@card_1990);
    world.write_model(@card_1999);

    let genre_card_ids: Array<u64> = array![10_u64, 11_u64];
    let genre_cards = GenreCards { genre: rock_genre, cards: genre_card_ids.span().clone() };
    world.write_model(@genre_cards);

    let count = 2_u64;
    let selected_cards = CardTrait::get_cards_by_genre_and_decade(
        ref world, rock_genre, decade, count,
    );

    assert(selected_cards.len() == count.try_into().unwrap(), 'wrong no of cards');

    let mut i = 0;
    loop {
        if i >= selected_cards.len() {
            break;
        }
        let card_id = selected_cards[i];
        assert(contains(genre_card_ids.clone(), *card_id), 'Boundary card not returned');
        i += 1;
    }
}

#[test]
#[should_panic]
fn test_get_cards_by_genre_and_decade_invalid_count() {
    let mut world = setup();

    let rock_genre = Genre::Rock.into();
    let genre_card_ids: Array<u64> = array![1_u64];
    let genre_cards = GenreCards { genre: rock_genre, cards: genre_card_ids.span().clone() };
    world.write_model(@genre_cards);

    CardTrait::get_cards_by_genre_and_decade(ref world, rock_genre, 1990_u64, 0_u64);
}

#[test]
#[should_panic]
fn test_get_cards_by_genre_and_decade_invalid_decade() {
    let mut world = setup();

    let rock_genre = Genre::Rock.into();
    let genre_card_ids: Array<u64> = array![1_u64];
    let genre_cards = GenreCards { genre: rock_genre, cards: genre_card_ids.span().clone() };
    world.write_model(@genre_cards);

    CardTrait::get_cards_by_genre_and_decade(ref world, rock_genre, 1995_u64, 1_u64);
}

#[test]
#[should_panic]
fn test_get_cards_by_genre_and_decade_no_genre_cards() {
    let mut world = setup();

    CardTrait::get_cards_by_genre_and_decade(ref world, 'NonExistentGenre', 1990_u64, 1_u64);
}

#[test]
#[should_panic]
fn test_get_cards_by_genre_and_decade_no_decade_match() {
    let mut world = setup();

    let rock_genre = Genre::Rock.into();

    let rock_card_2001 = LyricsCard {
        card_id: 1,
        genre: rock_genre,
        artist: 'Test Artist',
        title: 'Test Title',
        year: 2001,
        lyrics: "Test lyrics",
    };
    world.write_model(@rock_card_2001);

    let genre_card_ids: Array<u64> = array![1_u64];
    let genre_cards = GenreCards { genre: rock_genre, cards: genre_card_ids.span().clone() };
    world.write_model(@genre_cards);

    CardTrait::get_cards_by_genre_and_decade(ref world, rock_genre, 1990_u64, 1_u64);
}

#[test]
#[should_panic]
fn test_get_cards_by_genre_and_decade_not_enough_cards() {
    let mut world = setup();

    let rock_genre = Genre::Rock.into();

    let rock_card_1995 = LyricsCard {
        card_id: 1,
        genre: rock_genre,
        artist: 'Test Artist',
        title: 'Test Title',
        year: 1995,
        lyrics: "Test lyrics",
    };
    world.write_model(@rock_card_1995);

    let genre_card_ids: Array<u64> = array![1_u64];
    let genre_cards = GenreCards { genre: rock_genre, cards: genre_card_ids.span().clone() };
    world.write_model(@genre_cards);

    CardTrait::get_cards_by_genre_and_decade(ref world, rock_genre, 1990_u64, 5_u64);
}


#[test]
fn test_get_cards_by_genre_ok() {
    let mut world = setup();

    let rock_genre = Genre::Rock.into();

    let rock_card_1991 = LyricsCard {
        card_id: 1,
        genre: rock_genre,
        artist: 'Nirvana',
        title: 'Smells Like Teen Spirit',
        year: 1991,
        lyrics: "Load up on guns",
    };

    let rock_card_1995 = LyricsCard {
        card_id: 2,
        genre: rock_genre,
        artist: 'Foo Fighters',
        title: 'This Is a Call',
        year: 1995,
        lyrics: "Fingernails are pretty",
    };

    let rock_card_1999 = LyricsCard {
        card_id: 3,
        genre: rock_genre,
        artist: 'Red Hot Chili Peppers',
        title: 'Californication',
        year: 1999,
        lyrics: "Psychic spies from China",
    };

    let rock_card_2001 = LyricsCard {
        card_id: 4,
        genre: rock_genre,
        artist: 'Linkin Park',
        title: 'In the End',
        year: 2001,
        lyrics: "I tried so hard",
    };

    world.write_model(@rock_card_1991);
    world.write_model(@rock_card_1995);
    world.write_model(@rock_card_1999);
    world.write_model(@rock_card_2001);

    let genre_card_ids: Array<u64> = array![1_u64, 2_u64, 3_u64, 4_u64];
    let genre_cards = GenreCards { genre: rock_genre, cards: genre_card_ids.span().clone() };
    world.write_model(@genre_cards);

    let count = 2_u64;
    let selected_cards = CardTrait::get_cards_by_genre(ref world, rock_genre, count);

    assert(selected_cards.len() == count.try_into().unwrap(), 'wrong no of cards');

    let expected_cards: Array<u64> = array![1_u64, 2_u64, 3_u64, 4_u64];

    let mut i = 0;
    loop {
        if i >= selected_cards.len() {
            break;
        }
        let card_id = selected_cards[i];
        assert(contains(expected_cards.clone(), *card_id), 'Returned card not in set');

        let card: LyricsCard = world.read_model(*card_id);
        assert(card.genre == rock_genre, 'Card not rock genre');

        i += 1;
    }
}

#[test]
#[should_panic]
fn test_get_cards_by_genre_no_genre_cards() {
    let mut world = setup();

    CardTrait::get_cards_by_genre(ref world, 'NonExistentGenre', 1_u64);
}

#[test]
fn test_get_cards_by_artist_ok() {
    let mut world = setup();

    let artist = 'Bob Marley';
    let card_ids: Array<u64> = array![101_u64, 102_u64, 103_u64, 104_u64];

    let artist_cards = ArtistCards { artist, cards: card_ids.span().clone() };
    world.write_model(@artist_cards);

    let count = 2_u64;
    let selected_cards = CardTrait::get_cards_by_artist(ref world, artist, count);

    assert(selected_cards.len() == count.try_into().unwrap(), 'wrong no of cards');

    let mut i = 0;
    loop {
        if i >= selected_cards.len() {
            break;
        }

        let card_id = selected_cards[i];
        assert(contains(card_ids.clone(), *card_id), 'Returned unknown card');
        i += 1;
    }
}

#[test]
#[should_panic]
fn test_get_cards_by_artist_no_cards() {
    let mut world = setup();

    CardTrait::get_cards_by_artist(ref world, 'NonExistentArtist', 1_u64);
}

#[test]
fn test_get_cards_by_decade_ok() {
    let mut world = setup();

    // Initialize LyricsCardCount
    world.write_model(@LyricsCardCount { id: GAME_ID, count: 3 });

    let decade = 1990_u64;

    let card_1991 = LyricsCard {
        card_id: 1,
        genre: Genre::Rock.into(),
        artist: 'Nirvana',
        title: 'Smells Like Teen Spirit',
        year: 1991,
        lyrics: "Load up on guns",
    };

    let card_1995 = LyricsCard {
        card_id: 2,
        genre: Genre::Rock.into(),
        artist: 'Foo Fighters',
        title: 'This Is a Call',
        year: 1995,
        lyrics: "Fingernails are pretty",
    };

    let card_2001 = LyricsCard {
        card_id: 3,
        genre: Genre::Rock.into(),
        artist: 'Linkin Park',
        title: 'In the End',
        year: 2001,
        lyrics: "I tried so hard",
    };

    world.write_model(@card_1991);
    world.write_model(@card_1995);
    world.write_model(@card_2001);

    let count = 2_u64;
    let selected_cards = CardTrait::get_cards_by_decade(ref world, decade, count);

    assert(selected_cards.len() == count.try_into().unwrap(), 'wrong no of cards');

    // Verify all returned cards are from the 1990s decade
    let mut i = 0;
    loop {
        if i >= selected_cards.len() {
            break;
        }
        let card_id = selected_cards[i];
        let card: LyricsCard = world.read_model(*card_id);
        assert(card.year >= 1990 && card.year <= 1999, 'Card not from 1990s');
        i += 1;
    }
}

#[test]
#[should_panic]
fn test_get_cards_by_decade_invalid_decade() {
    let mut world = setup();

    world.write_model(@LyricsCardCount { id: GAME_ID, count: 1 });

    CardTrait::get_cards_by_decade(ref world, 1995_u64, 1_u64);
}

#[test]
#[should_panic(expected: ('Year must be positive', 'ENTRYPOINT_FAILED'))]
fn test_create_challenge_round_invalid_year() {
    let caller = starknet::contract_address_const::<0x0>();

    let (mut _world, mut actions_system) = setup_with_config();

    testing::set_contract_address(caller);

    create_year_round(ref actions_system, Mode::MultiPlayer, 0);
}
