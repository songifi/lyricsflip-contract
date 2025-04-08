use starknet::testing;
use dojo::model::ModelStorage;
use dojo_cairo_test::{
    ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
    spawn_test_world,
};
use dojo::world::{WorldStorage, WorldStorageTrait};

use lyricsflip::constants::{GAME_ID, Genre};
use lyricsflip::models::config::{GameConfig, m_GameConfig};
use lyricsflip::models::round::{
    Rounds, RoundsCount, RoundPlayer, m_Rounds, m_RoundsCount, m_RoundPlayer,
};
use lyricsflip::models::round::RoundState;
use lyricsflip::systems::actions::{IActionsDispatcher, IActionsDispatcherTrait, actions};
use lyricsflip::systems::config::{IGameConfigDispatcher, IGameConfigDispatcherTrait, game_config};
use lyricsflip::models::card::{
    LyricsCard, LyricsCardCount, m_LyricsCard, m_LyricsCardCount, YearCards, m_YearCards,
};

pub fn namespace_def() -> NamespaceDef {
    let ndef = NamespaceDef {
        namespace: "lyricsflip",
        resources: [
            TestResource::Model(m_Rounds::TEST_CLASS_HASH),
            TestResource::Model(m_RoundsCount::TEST_CLASS_HASH),
            TestResource::Model(m_RoundPlayer::TEST_CLASS_HASH),
            TestResource::Model(m_LyricsCard::TEST_CLASS_HASH),
            TestResource::Model(m_LyricsCardCount::TEST_CLASS_HASH),
            TestResource::Model(m_YearCards::TEST_CLASS_HASH),
            TestResource::Model(m_GameConfig::TEST_CLASS_HASH),
            TestResource::Event(actions::e_RoundCreated::TEST_CLASS_HASH),
            TestResource::Event(actions::e_RoundJoined::TEST_CLASS_HASH),
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
    let mut world = spawn_test_world([ndef].span());
    world.sync_perms_and_inits(contract_defs());

    world
}
