use starknet::ContractAddress;

#[starknet::interface]
pub trait IGameConfig<TContractState> {
    fn set_game_config(ref self: TContractState, cards_per_round: u32);
    fn set_cards_per_round(ref self: TContractState, cards_per_round: u32);
    fn set_admin_address(ref self: TContractState, admin_address: ContractAddress);
}

#[dojo::contract]
pub mod game_config {
    use dojo::model::{ModelStorage};
    use dojo::world::{WorldStorage};
    use lyricsflip::constants::GAME_ID;
    use lyricsflip::models::config::GameConfig;
    use starknet::{ContractAddress, get_caller_address, contract_address_const};
    use super::IGameConfig;

    pub fn check_caller_is_admin(world: WorldStorage) -> bool {
        let mut game_config: GameConfig = world.read_model(GAME_ID);
        let mut admin_address = game_config.admin_address;
        get_caller_address() == admin_address
    }

    pub fn assert_caller_is_admin(world: WorldStorage) {
        assert(check_caller_is_admin(world), 'caller not admin');
    }


    #[abi(embed_v0)]
    impl GameConfigImpl of IGameConfig<ContractState> {
        fn set_game_config(ref self: ContractState, cards_per_round: u32) {
            let mut world = self.world_default();
            let caller = get_caller_address();

            let game_config: GameConfig = world.read_model(GAME_ID);

            assert(!game_config.config_init, 'game config initialized');

            self.set_cards_per_round(cards_per_round);
            self.set_admin_address(caller);

            let mut game_config: GameConfig = world.read_model(GAME_ID);

            game_config.config_init = true;
            world.write_model(@game_config);
        }

        fn set_cards_per_round(ref self: ContractState, cards_per_round: u32) {
            // Get the world dispatcher
            let mut world = self.world_default();
            // Get the current game config
            let mut game_config: GameConfig = world.read_model(GAME_ID);

            if game_config.config_init {
                assert_caller_is_admin(world);
            }

            // Check that the value being set is non-zero
            assert(cards_per_round != 0, 'cards_per_round cannot be zero');

            // Update the cards_per_round field
            game_config.cards_per_round = cards_per_round;

            // Save the updated game config back to the world
            world.write_model(@game_config);
        }

        fn set_admin_address(ref self: ContractState, admin_address: ContractAddress) {
            let mut world = self.world_default();

            let mut game_config: GameConfig = world.read_model(GAME_ID);

            assert(admin_address != contract_address_const::<0>(), 'admin address cannot be zero');

            if game_config.config_init {
                assert_caller_is_admin(world);
            }

            game_config.admin_address = admin_address;
            world.write_model(@game_config);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Use the default namespace "dojo_starter". This function is handy since the ByteArray
        /// can't be const.
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"lyricsflip")
        }
    }
}
