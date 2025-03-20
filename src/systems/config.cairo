use lyricsflip::constants::{Genre};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IGameConfig<TContractState> {
    //TODO
    fn set_game_config(ref self: TContractState, admin_address: ContractAddress);
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
