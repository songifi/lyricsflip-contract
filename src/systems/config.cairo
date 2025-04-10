use lyricsflip::genre::Genre;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IGameConfig<TContractState> {
    //TODO
    fn set_game_config(ref self: TContractState, admin_address: ContractAddress);
    fn set_cards_per_round(ref self: TContractState, cards_per_round: u32);
    fn set_admin_address(ref self: TContractState, admin_address: ContractAddress);
}

// dojo decorator
#[dojo::contract]
pub mod game_config {
    use core::num::traits::zero::Zero;
    use dojo::event::EventStorage;
    use dojo::model::{Model, ModelStorage};
    use dojo::world::{IWorldDispatcherTrait, WorldStorage};
    use lyricsflip::constants::GAME_ID;
    use lyricsflip::models::config::GameConfig;
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
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
        //TODO
        fn set_game_config(ref self: ContractState, admin_address: ContractAddress) {}

        fn set_cards_per_round(ref self: ContractState, cards_per_round: u32) {
            // Get the world dispatcher
            let mut world = self.world_default();

            assert_caller_is_admin(world);

            // Check that the value being set is non-zero
            assert(cards_per_round != 0, 'cards_per_round cannot be zero');

            // Get the current game config
            let mut game_config: GameConfig = world.read_model(GAME_ID);

            // Update the cards_per_round field
            game_config.cards_per_round = cards_per_round;

            // Save the updated game config back to the world
            world.write_model(@game_config);
        }

        fn set_admin_address(ref self: ContractState, admin_address: ContractAddress) {
            assert(
                admin_address != Zero::<ContractAddress>::zero(), 'admin_address cannot be zero',
            );

            let mut world = self.world_default();
            let mut game_config: GameConfig = world.read_model(GAME_ID);

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
