use dojo_cairo_test::{
    ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
    spawn_test_world,
};
use dojo::model::ModelStorage;
use dojo::world::{WorldStorage, WorldStorageTrait};
use starknet::{contract_address_const, ContractAddress};
use lyricsflip::systems::config::{IGameConfigDispatcher, IGameConfigDispatcherTrait, game_config};
use starknet::{testing};

use lyricsflip::models::config::{GameConfig, m_GameConfig};
use lyricsflip::models::round::{m_Round, m_RoundsCount, m_RoundPlayer, m_PlayerStats};
use lyricsflip::systems::actions::{actions};
use lyricsflip::constants::{GAME_ID};
use lyricsflip::models::card::{m_LyricsCard, m_LyricsCardCount, m_YearCards, m_ArtistCards};

fn ADMIN() -> ContractAddress {
    contract_address_const::<'admin'>()
}

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
            TestResource::Model(m_PlayerStats::TEST_CLASS_HASH),
            TestResource::Event(actions::e_RoundCreated::TEST_CLASS_HASH),
            TestResource::Event(actions::e_RoundJoined::TEST_CLASS_HASH),
            TestResource::Event(actions::e_PlayerReady::TEST_CLASS_HASH),
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

pub fn setup_with_config() -> WorldStorage {
    let ndef = namespace_def();
    let mut world: WorldStorage = spawn_test_world([ndef].span());
    world.sync_perms_and_inits(contract_defs());

    world.write_model(@GameConfig { id: GAME_ID, cards_per_round: 15_u32, admin_address: ADMIN() });

    world
}
