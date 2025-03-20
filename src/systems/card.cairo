use lyricsflip::constants::{Genre};

#[starknet::interface]
pub trait ICardActions<TContractState> {}

// dojo decorator
#[dojo::contract]
pub mod cards {
    use super::{ICardActions};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    // use lyricsflip::models::card::{Card};
    use lyricsflip::constants::{GAME_ID, Genre};

    use dojo::model::{ModelStorage};
    use dojo::event::EventStorage;

    #[abi(embed_v0)]
    impl CardActionsImpl of ICardActions<ContractState> {}


    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Use the default namespace "dojo_starter". This function is handy since the ByteArray
        /// can't be const.
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"lyricsflip")
        }
    }
}
