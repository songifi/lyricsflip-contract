use lyricsflip::constants::Genre;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IGameConfig<TContractState> {
    //TODO
    fn set_game_config(ref self: TContractState, admin_address: ContractAddress);
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

    #[abi(embed_v0)]
    impl GameConfigImpl of IGameConfig<ContractState> {
        //TODO
        fn set_game_config(ref self: ContractState, admin_address: ContractAddress) {}
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
