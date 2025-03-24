#[cfg(test)]
mod tests {
    use starknet::testing;
    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
    };

    use lyricsflip::systems::actions::{actions, IActionsDispatcher, IActionsDispatcherTrait};
    use lyricsflip::systems::config::{
        game_config, IGameConfigDispatcher, IGameConfigDispatcherTrait,
    };
    use lyricsflip::models::round::{
        Rounds, m_Rounds, RoundsCount, m_RoundsCount, RoundPlayer, m_RoundPlayer,
    };
    // use lyricsflip::models::card::{Card, m_Card};
    use lyricsflip::models::config::{GameConfig, m_GameConfig};
    use lyricsflip::constants::{GAME_ID};
    use lyricsflip::constants::{Genre};


    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "lyricsflip",
            resources: [
                TestResource::Model(m_Rounds::TEST_CLASS_HASH),
                TestResource::Model(m_RoundsCount::TEST_CLASS_HASH),
                TestResource::Model(m_RoundPlayer::TEST_CLASS_HASH),
                TestResource::Model(m_GameConfig::TEST_CLASS_HASH),
                TestResource::Event(actions::e_RoundCreated::TEST_CLASS_HASH),
                TestResource::Event(actions::e_RoundJoined::TEST_CLASS_HASH),
                TestResource::Contract(actions::TEST_CLASS_HASH),
                // TestResource::Contract(cards::TEST_CLASS_HASH),
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
        assert(!res.round.is_started, 'is_started should be false');
        assert(!res.round.is_completed, 'is_completed should be false');
        assert(res.round.players_count == 1, 'wrong players_count');

        let round_id = actions_system.create_round(Genre::Pop.into());

        let res: Rounds = world.read_model(round_id);
        let rounds_count: RoundsCount = world.read_model(GAME_ID);
        let round_player: RoundPlayer = world.read_model((caller, round_id));

        assert(rounds_count.count == 2, 'rounds count should be 2');
        assert(res.round.creator == caller, 'round creator is wrong');
        assert(res.round.genre == Genre::Pop.into(), 'wrong round genre');
        assert(res.round.players_count == 1, 'wrong players_count');

        assert(round_player.joined, 'round not joined');
    }

    #[test]
    fn test_join_round() {
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
        testing::set_caller_address(player);
        actions_system.join_round(round_id);

        // check if the round player count increased
        let rounds: Rounds = world.read_model(round_id);
        assert(rounds.round.players_count > 1, 'player has not joined');

        // check whether RoundPlayer model exists and is joined
        let round_player: RoundPlayer = world.read_model((caller, round_id));
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
        res.round.is_started = true;

        // update round in world
        world.write_model(@res);

        //join round
        testing::set_caller_address(player);
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
}
