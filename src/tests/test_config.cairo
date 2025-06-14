use starknet::{testing};
use dojo::model::ModelStorage;
use dojo::world::WorldStorageTrait;
use lyricsflip::constants::{GAME_ID};
use lyricsflip::models::config::GameConfig;
use lyricsflip::systems::config::{IGameConfigDispatcher, IGameConfigDispatcherTrait};
use lyricsflip::tests::test_utils::{setup};
// use lyricsflip::tests::test_utils;

#[test]
#[should_panic(expected: ('caller not admin', 'ENTRYPOINT_FAILED'))]
fn test_set_cards_per_round_non_admin() {
    let mut world = setup();

    let admin = starknet::contract_address_const::<0x1>();
    let _default_cards_per_round = 5_u32;

    world
        .write_model(
            @GameConfig {
                id: GAME_ID, cards_per_round: 5_u32, admin_address: admin, config_init: true,
            },
        );

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

    world
        .write_model(
            @GameConfig {
                id: GAME_ID, cards_per_round: 5_u32, admin_address: admin, config_init: true,
            },
        );

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
    world
        .write_model(
            @GameConfig {
                id: GAME_ID, cards_per_round: 5_u32, admin_address: admin, config_init: true,
            },
        );

    testing::set_contract_address(admin);

    let (contract_address, _) = world.dns(@"game_config").unwrap();
    let game_config_system = IGameConfigDispatcher { contract_address };

    game_config_system.set_cards_per_round(0);
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
#[should_panic(expected: ('admin address cannot be zero', 'ENTRYPOINT_FAILED'))]
fn test_set_admin_address_panics_with_zero_address() {
    let caller = starknet::contract_address_const::<0x0>();

    let mut world = setup();

    let (contract_address, _) = world.dns(@"game_config").unwrap();
    let actions_system = IGameConfigDispatcher { contract_address };

    actions_system.set_admin_address(caller);
}

#[test]
fn test_set_game_config() {
    let caller = starknet::contract_address_const::<0x1>();

    let mut world = setup();

    let (contract_address, _) = world.dns(@"game_config").unwrap();
    let actions_system = IGameConfigDispatcher { contract_address };

    testing::set_contract_address(caller);
    actions_system.set_game_config(15);

    let config: GameConfig = world.read_model(GAME_ID);
    assert(config.cards_per_round == 15, 'cards_per_round not set');
    assert(config.admin_address == caller, 'admin_address not set');
    assert(config.config_init, 'config_init not set');
}

#[test]
#[should_panic(expected: ('game config initialized', 'ENTRYPOINT_FAILED'))]
fn test_set_game_config_when_init_true() {
    let caller = starknet::contract_address_const::<0x1>();

    let mut world = setup();

    let (contract_address, _) = world.dns(@"game_config").unwrap();
    let actions_system = IGameConfigDispatcher { contract_address };

    testing::set_contract_address(caller);
    actions_system.set_game_config(15);

    // Attempt to set the game config again, which should panic
    testing::set_contract_address(caller);
    actions_system.set_game_config(15);
}

#[test]
#[should_panic(expected: ('caller not admin', 'ENTRYPOINT_FAILED'))]
fn test_set_admin_address_by_non_admin_when_init_true() {
    let caller = starknet::contract_address_const::<0x1>();
    let new_admin = starknet::contract_address_const::<0x2>();

    let mut world = setup();

    let (contract_address, _) = world.dns(@"game_config").unwrap();
    let actions_system = IGameConfigDispatcher { contract_address };

    testing::set_contract_address(caller);
    actions_system.set_game_config(15);

    testing::set_contract_address(new_admin);
    actions_system.set_admin_address(new_admin);
}
