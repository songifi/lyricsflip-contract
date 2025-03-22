use lyricsflip::constants::{Genre};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IGameConfig<TContractState> {
    //TODO
    fn set_game_config(ref self: TContractState, admin_address: ContractAddress);
    fn set_cards_per_round(ref self: TContractState, cards_per_round: u32);
}

// dojo decorator
#[dojo::contract]
pub mod game_config {
    use super::{IGameConfig};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use lyricsflip::models::config::{GameConfig};
    use lyricsflip::constants::{GAME_ID};

    use core::num::traits::zero::Zero;

    use dojo::model::{Model, ModelStorage};
    use dojo::world::WorldStorage;
    use dojo::world::{IWorldDispatcherTrait};
    use dojo::event::EventStorage;

    #[abi(embed_v0)]
    impl GameConfigImpl of IGameConfig<ContractState> {
        //TODO
        fn set_game_config(ref self: ContractState, admin_address: ContractAddress) {}
        
        fn set_cards_per_round(ref self: ContractState, cards_per_round: u32) {
            // Check that the value being set is non-zero
            assert(cards_per_round != 0, 'cards_per_round cannot be zero');
            
            // Get the world dispatcher
            let mut world = self.world_default();
            
            // Get the current game config
            let mut game_config: GameConfig = world.read_model(GAME_ID);
            
            // Update the cards_per_round field
            game_config.cards_per_round = cards_per_round;
            
            // Save the updated game config back to the world
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
