#[cfg(test)]
mod tests {
    use starknet::testing;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_cairo_test::{
        ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
        spawn_test_world,
    };
    use lyricsflip::constants::{GAME_ID, Genre};
    use lyricsflip::models::config::{GameConfig, m_GameConfig};
    use lyricsflip::models::round::{
        Rounds, RoundsCount, RoundPlayer, m_Rounds, m_RoundsCount, m_RoundPlayer,
    };
    use lyricsflip::models::round::RoundState;
    use lyricsflip::systems::actions::{IActionsDispatcher, IActionsDispatcherTrait, actions};
    use lyricsflip::systems::config::{
        IGameConfigDispatcher, IGameConfigDispatcherTrait, game_config,
    };
    use lyricsflip::models::card::{LyricsCard, m_LyricsCard};


    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "lyricsflip",
            resources: [
                TestResource::Model(m_Rounds::TEST_CLASS_HASH),
                TestResource::Model(m_RoundsCount::TEST_CLASS_HASH),
                TestResource::Model(m_RoundPlayer::TEST_CLASS_HASH),
                TestResource::Model(m_LyricsCard::TEST_CLASS_HASH),
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

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"lyricsflip", @"actions")
                .with_writer_of([dojo::utils::bytearray_hash(@"lyricsflip")].span()),
            // ContractDefTrait::new(@"lyricsflip", @"cards")
            //     .with_writer_of([dojo::utils::bytearray_hash(@"lyricsflip")].span()),
            ContractDefTrait::new(@"lyricsflip", @"game_config")
                .with_writer_of([dojo::utils::bytearray_hash(@"lyricsflip")].span()),
        ]
            .span()
    }

    #[test]
    fn test_create_round() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

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
        // Test player can join round successfully

        let caller = starknet::contract_address_const::<0x0>();
        let player = starknet::contract_address_const::<0x1>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        // create round
        let round_id = actions_system.create_round(Genre::Rock.into());

        let res: Rounds = world.read_model(round_id);
        assert(res.round.players_count == 1, 'wrong players_count');

        //join round
        testing::set_contract_address(player);
        actions_system.join_round(round_id);

        let res: Rounds = world.read_model(round_id);
        let round_player: RoundPlayer = world.read_model((player, round_id));

        // Check if player count increased by 1
        assert(res.round.players_count == 2, 'wrong players_count');
        // Check if round player has joined
        assert(round_player.joined, 'player not joined');
    }

    #[test]
    #[should_panic]
    fn test_cannot_join_round_non_existent_round() {
        // Test player cannot join round if round does not exist

        let caller = starknet::contract_address_const::<0x0>();
        let player = starknet::contract_address_const::<0x1>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        //join round
        testing::set_caller_address(player);
        actions_system.join_round(1); // should panic
    }

    #[test]
    #[should_panic]
    fn test_cannot_join_ongoing_round() {
        // Test player cannot join round if round has started

        let caller = starknet::contract_address_const::<0x0>();
        let player = starknet::contract_address_const::<0x1>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        // create round
        let round_id = actions_system.create_round(Genre::Rock.into());

        let mut res: Rounds = world.read_model(round_id);
        assert(res.round.players_count == 1, 'wrong players_count');

        // mark round as started
        res.round.state = RoundState::Started.into();

        // update round in world
        world.write_model(@res);

        //join round
        testing::set_contract_address(player);
        actions_system.join_round(round_id); // should panic
    }

    #[test]
    #[should_panic]
    fn test_cannot_join_already_joined_round() {
        // Test player cannot join round if player has already joined round.

        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        // create round
        let round_id = actions_system.create_round(Genre::Rock.into());

        let mut res: Rounds = world.read_model(round_id);
        assert(res.round.players_count == 1, 'wrong players_count');

        //join round
        actions_system.join_round(round_id); // should panic as player already created round
    }

    #[test]
    fn test_set_cards_per_round() {
        // Setup the test world
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        // Initialize GameConfig with default values
        let admin = starknet::contract_address_const::<0x1>();
        let _default_cards_per_round = 5_u32;

        world
            .write_model(@GameConfig { id: GAME_ID, cards_per_round: 5_u32, admin_address: admin });

        // Get the game_config contract
        let (contract_address, _) = world.dns(@"game_config").unwrap();
        let game_config_system = IGameConfigDispatcher { contract_address };

        // Test successful update
        let new_cards_per_round = 10_u32;
        game_config_system.set_cards_per_round(new_cards_per_round);

        // Verify the update
        let config: GameConfig = world.read_model(GAME_ID);
        assert(config.cards_per_round == new_cards_per_round, 'cards_per_round not updated');
        assert(config.admin_address == admin, 'admin address changed');

        // Test with different valid value
        let another_value = 15_u32;
        game_config_system.set_cards_per_round(another_value);
        let config: GameConfig = world.read_model(GAME_ID);
        assert(config.cards_per_round == another_value, 'failed to update again');
    }

    #[test]
    #[should_panic(expected: ('cards_per_round cannot be zero', 'ENTRYPOINT_FAILED'))]
    fn test_set_cards_per_round_with_zero() {
        // Setup the test world
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        // Initialize GameConfig with default values
        let admin = starknet::contract_address_const::<0x1>();
        world
            .write_model(@GameConfig { id: GAME_ID, cards_per_round: 5_u32, admin_address: admin });

        // Get the game_config contract
        let (contract_address, _) = world.dns(@"game_config").unwrap();
        let game_config_system = IGameConfigDispatcher { contract_address };

        // Test with zero value (should panic)
        game_config_system.set_cards_per_round(0);
    }

    #[test]
    fn test_add_lyrics_card() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        let genre = Genre::Pop;
        let artist = 'fame';
        let title = 'sounds';
        let year = 2020;
        let lyrics = format!("come to life...");

        let card_id = actions_system.add_lyrics_card(genre, artist, title, year, lyrics.clone());

        let card: LyricsCard = world.read_model(card_id);

        assert(card.genre == 'Pop', 'wrong genre');
        assert(card.artist == artist, 'wrong artist');
        assert(card.title == title, 'wrong title');
        assert(card.year == year, 'wrong year');
        assert(card.lyrics == lyrics, 'wrong lyrics');
    }

    #[test]
    fn test_set_admin_address() {
        let caller = starknet::contract_address_const::<0x1>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

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

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"game_config").unwrap();
        let actions_system = IGameConfigDispatcher { contract_address };

        actions_system.set_admin_address(caller);
    }

    #[test]
    fn test_get_round_id_initial_value() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        // Initial round_id should be 6
        world.write_model(@RoundsCount { id: GAME_ID, count: 5_u256 });

        // Get round_id using get_round_id
        let round_id = actions_system.get_round_id();

        // Should return 6 (5 + 1)
        assert(round_id == 6_u256, 'Initial round_id should be 6');

        // Verify that the counter did not change (get_round_id does not modify it)
        let rounds_count: RoundsCount = world.read_model(GAME_ID);
        assert(rounds_count.count == 5_u256, 'rounds count should remain 5');
    }

    #[test]
    fn test_round_id_consistency() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        // Get the first round ID without creating a round
        let expected_round_id = actions_system.get_round_id();

        // Create a round and verify that the ID is the same as the one obtained before
        let actual_round_id = actions_system.create_round(Genre::Jazz.into());
        assert(actual_round_id == expected_round_id, 'Round IDs should match');

        // Get the next round ID
        let next_expected_id = actions_system.get_round_id();

        // Verify that the next ID is the previous one + 1
        assert(next_expected_id == expected_round_id + 1_u256, 'Next ID should increment by 1');

        // Create another round and verify that the ID matches the expected one
        let next_actual_id = actions_system.create_round(Genre::Rock.into());
        assert(next_actual_id == next_expected_id, 'Next round IDs should match');

        // Verify the rounds counter
        let rounds_count: RoundsCount = world.read_model(GAME_ID);
        assert(rounds_count.count == 2_u256, 'rounds count should be 2');
    }

    #[test]
    fn test_is_round_player_true() {
        // Test player is a participant of the round

        let caller = starknet::contract_address_const::<0x0>();
        let player = starknet::contract_address_const::<0x1>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        // create round
        let round_id = actions_system.create_round(Genre::Rock.into());

        //join round
        testing::set_contract_address(player);
        actions_system.join_round(round_id);

        let is_round_player = actions_system.is_round_player(round_id, player);

        // Check if player is a participant of the round
        assert(is_round_player, 'player not joined');
    }

    #[test]
    fn test_is_round_player_false() {
        // Test player is not a participant of the round

        let caller = starknet::contract_address_const::<0x0>();
        let player = starknet::contract_address_const::<0x1>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        // create round
        let round_id = actions_system.create_round(Genre::Rock.into());
        let is_round_player = actions_system.is_round_player(round_id, player);

        // Check if player is not a participant of the round
        assert(!is_round_player, 'player joined');
    }
}
