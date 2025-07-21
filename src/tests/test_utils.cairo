use dojo_cairo_test::{
    ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
    spawn_test_world,
};
use dojo::model::ModelStorage;
use dojo::world::{WorldStorage, WorldStorageTrait};
use starknet::{contract_address_const, ContractAddress};
use starknet::{testing};

use lyricsflip::systems::config::{game_config};
use lyricsflip::alias::ID;
use lyricsflip::models::round::{Mode, ChallengeType};
use lyricsflip::models::player::{m_PlayerStats};
use lyricsflip::models::genre::Genre;
use lyricsflip::systems::actions::{IActionsDispatcher, IActionsDispatcherTrait, actions};
use lyricsflip::models::config::{GameConfig, m_GameConfig};
use lyricsflip::models::round::{m_Round, m_RoundsCount, m_RoundPlayer, Answer, Round, RoundPlayer};
use lyricsflip::constants::{GAME_ID};
use lyricsflip::models::card::{
    m_LyricsCard, m_LyricsCardCount, m_YearCards, m_ArtistCards, QuestionCard, LyricsCard,
    m_GenreCards,
};
use lyricsflip::models::daily_challenge::{
    m_DailyChallenge, m_PlayerDailyProgress, m_DailyChallengeStreak,
};

pub fn ADMIN() -> ContractAddress {
    contract_address_const::<'admin'>()
}

pub const CARDS_PER_ROUND: u32 = 15;
pub const ARTIST: felt252 = 'Bob Marley';
pub const TITLE: felt252 = 'something great';
pub const YEAR: u64 = 2000;

pub fn namespace_def() -> NamespaceDef {
    let ndef = NamespaceDef {
        namespace: "lyricsflip",
        resources: [
            TestResource::Model(m_Round::TEST_CLASS_HASH),
            TestResource::Model(m_RoundsCount::TEST_CLASS_HASH),
            TestResource::Model(m_RoundPlayer::TEST_CLASS_HASH),
            TestResource::Model(m_LyricsCard::TEST_CLASS_HASH),
            TestResource::Model(m_LyricsCardCount::TEST_CLASS_HASH),
            TestResource::Model(m_YearCards::TEST_CLASS_HASH),
            TestResource::Model(m_GameConfig::TEST_CLASS_HASH),
            TestResource::Model(m_ArtistCards::TEST_CLASS_HASH),
            TestResource::Model(m_GenreCards::TEST_CLASS_HASH),
            TestResource::Model(m_PlayerStats::TEST_CLASS_HASH),
            TestResource::Model(m_DailyChallenge::TEST_CLASS_HASH),
            TestResource::Model(m_PlayerDailyProgress::TEST_CLASS_HASH),
            TestResource::Model(m_DailyChallengeStreak::TEST_CLASS_HASH),
            TestResource::Event(actions::e_RoundCreated::TEST_CLASS_HASH),
            TestResource::Event(actions::e_RoundJoined::TEST_CLASS_HASH),
            TestResource::Event(actions::e_PlayerReady::TEST_CLASS_HASH),
            TestResource::Event(actions::e_RoundWinner::TEST_CLASS_HASH),
            TestResource::Event(actions::e_PlayerAnswer::TEST_CLASS_HASH),
            TestResource::Event(actions::e_RoundForceStarted::TEST_CLASS_HASH),
            TestResource::Event(actions::e_DailyChallengeProgress::TEST_CLASS_HASH),
            TestResource::Event(actions::e_DailyChallengeCompleted::TEST_CLASS_HASH),
            TestResource::Contract(actions::TEST_CLASS_HASH),
            TestResource::Contract(game_config::TEST_CLASS_HASH),
        ]
            .span(),
    };

    ndef
}

pub fn contract_defs() -> Span<ContractDef> {
    [
        ContractDefTrait::new(@"lyricsflip", @"actions")
            .with_writer_of([dojo::utils::bytearray_hash(@"lyricsflip")].span()),
        ContractDefTrait::new(@"lyricsflip", @"game_config")
            .with_writer_of([dojo::utils::bytearray_hash(@"lyricsflip")].span()),
    ]
        .span()
}


pub fn setup() -> WorldStorage {
    let ndef = namespace_def();
    let mut world: WorldStorage = spawn_test_world([ndef].span());
    world.sync_perms_and_inits(contract_defs());

    world
}

pub fn setup_with_config() -> (WorldStorage, IActionsDispatcher) {
    let ndef = namespace_def();
    let mut world: WorldStorage = spawn_test_world([ndef].span());
    world.sync_perms_and_inits(contract_defs());

    world
        .write_model(
            @GameConfig {
                id: GAME_ID,
                cards_per_round: CARDS_PER_ROUND,
                admin_address: ADMIN(),
                config_init: true,
            },
        );

    let (contract_address, _) = world.dns(@"actions").unwrap();
    let mut actions_system = IActionsDispatcher { contract_address };

    let hiphop_genre = Genre::HipHop;
    let pop_genre = Genre::Pop;
    let rock_genre = Genre::Rock;
    let year = YEAR;
    let lyrics: ByteArray = "Lorem Ipsum";

    // Create cards with unique artists and titles
    let base_artist: felt252 = 'Artist ';
    let base_title: felt252 = 'Song ';

    testing::set_contract_address(ADMIN());

    for i in 0..30_u32 {
        // Create unique values for each card
        let unique_id: felt252 = i.into();
        let unique_artist = base_artist + unique_id;
        let unique_title = base_title + unique_id;
        let unique_lyrics = format!("{} {}", lyrics, unique_id);

        // Add card with unique values
        actions_system
            .add_lyrics_card(hiphop_genre, unique_artist, unique_title, year, unique_lyrics);
    };

    for i in 0..30_u32 {
        // Create unique values for each card
        let unique_id: felt252 = i.into();
        let unique_artist = base_artist + unique_id;
        let unique_title = base_title + unique_id;
        let unique_lyrics = format!("{} {}", lyrics, unique_id);

        // Add card with unique values
        actions_system.add_lyrics_card(pop_genre, unique_artist, unique_title, year, unique_lyrics);
    };

    for i in 0..30_u32 {
        // Create unique values for each card
        let unique_id: felt252 = i.into();
        let unique_artist = base_artist + unique_id;
        let unique_title = base_title + unique_id;
        let unique_lyrics = format!("{} {}", lyrics, unique_id);

        // Add card with unique values
        actions_system
            .add_lyrics_card(rock_genre, unique_artist, unique_title, year, unique_lyrics);
    };

    // Set a known timestamp for consistent testing
    let test_timestamp = 1751328000; // July 1, 2025 00:00:00 UTC (midnight)
    testing::set_block_timestamp(test_timestamp);

    (world, actions_system)
}

pub fn get_answers(
    ref world: WorldStorage, round_id: u64, player: ContractAddress, question_card: @QuestionCard,
) -> (Option<Answer>, Answer) {
    // Get the player's current card index (subtract 1 since next_card increments it)
    let round_player: RoundPlayer = world.read_model((player, round_id));
    let cur_index = if round_player.next_card_index > 0 {
        round_player.next_card_index - 1
    } else {
        0
    };

    // Get the round and card info
    let round: Round = world.read_model(round_id);
    let card_id = round.round_cards.at(cur_index.into());
    let card: LyricsCard = world.read_model(*card_id);

    // Extract options from question card
    let (artist1, title1) = question_card.option_one;
    let (artist2, title2) = question_card.option_two;
    let (artist3, title3) = question_card.option_three;
    let (artist4, title4) = question_card.option_four;

    // Check which option matches the correct card
    let correct_option = if *artist1 == card.artist && *title1 == card.title {
        Option::Some(Answer::OptionOne)
    } else if *artist2 == card.artist && *title2 == card.title {
        Option::Some(Answer::OptionTwo)
    } else if *artist3 == card.artist && *title3 == card.title {
        Option::Some(Answer::OptionThree)
    } else if *artist4 == card.artist && *title4 == card.title {
        Option::Some(Answer::OptionFour)
    } else {
        Option::None
    };

    let wrong_option = match correct_option.unwrap() {
        Answer::OptionOne => Answer::OptionTwo,
        Answer::OptionTwo => Answer::OptionThree,
        Answer::OptionThree => Answer::OptionFour,
        Answer::OptionFour => Answer::OptionOne,
    };

    (correct_option, wrong_option)
}

pub fn create_random_round(ref actions_system: IActionsDispatcher, mode: Mode) -> ID {
    actions_system.create_round(mode, Option::None, Option::None, Option::None)
}

/// Helper function to create a genre challenge round
pub fn create_genre_round(ref actions_system: IActionsDispatcher, mode: Mode, genre: Genre) -> ID {
    actions_system
        .create_round(
            mode, Option::Some(ChallengeType::Genre), Option::Some(genre.into()), Option::None,
        )
}

/// Helper function to create a year challenge round
pub fn create_year_round(ref actions_system: IActionsDispatcher, mode: Mode, year: u64) -> ID {
    actions_system
        .create_round(
            mode,
            Option::Some(ChallengeType::Year),
            Option::Some(year.try_into().expect('Invalid year')),
            Option::None,
        )
}

/// Helper function to create an artist challenge round
pub fn create_artist_round(
    ref actions_system: IActionsDispatcher, mode: Mode, artist: felt252,
) -> ID {
    actions_system
        .create_round(mode, Option::Some(ChallengeType::Artist), Option::Some(artist), Option::None)
}

/// Helper function to create a decade challenge round
pub fn create_decade_round(ref actions_system: IActionsDispatcher, mode: Mode, decade: u64) -> ID {
    actions_system
        .create_round(
            mode,
            Option::Some(ChallengeType::Decade),
            Option::Some(decade.try_into().expect('Invalid decade')),
            Option::None,
        )
}

/// Helper function to create a genre and decade challenge round
pub fn create_genre_and_decade_round(
    ref actions_system: IActionsDispatcher, mode: Mode, genre: Genre, decade: u64,
) -> ID {
    actions_system
        .create_round(
            mode,
            Option::Some(ChallengeType::GenreAndDecade),
            Option::Some(genre.into()),
            Option::Some(decade.try_into().expect('Invalid decade')),
        )
}

/// Helper function to create a solo round
pub fn create_solo_round(ref actions_system: IActionsDispatcher, genre: Option<Genre>) -> ID {
    match genre {
        Option::Some(g) => create_genre_round(ref actions_system, Mode::Solo, g),
        Option::None => create_random_round(ref actions_system, Mode::Solo),
    }
}

pub fn contains(arr: Array<u64>, value: u64) -> bool {
    let mut i = 0;
    let mut found = false;

    loop {
        if i >= arr.len() {
            break;
        }
        if *arr[i] == value {
            found = true;
            break;
        }
        i += 1;
    };

    found
}
