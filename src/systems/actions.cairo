use lyricsflip::models::{Genre};

#[starknet::interface]
pub trait IActions<TContractState> {
    fn create_round(ref self: TContractState, genre: Genre) -> u256;
}

// dojo decorator
#[dojo::contract]
pub mod actions {
    use super::{IActions, Genre};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use lyricsflip::models::{GAME_ID, RoundsCount, Round, Rounds};

    use dojo::model::{ModelStorage};
    use dojo::event::EventStorage;

    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct RoundCreated {
        #[key]
        pub round_id: u256,
        pub creator: ContractAddress,
    }

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn create_round(ref self: ContractState, genre: Genre) -> u256 {
            // Get the default world.
            let mut world = self.world_default();

            // get caller address
            let caller = get_caller_address();

            // compute next round ID from round counts
            let rounds_count: RoundsCount = world.read_model(GAME_ID);
            let round_id = rounds_count.count + 1;

            // new round
            let round = Round {
                creator: caller,
                genre: genre.into(),
                wager_amount: 0, //TODO
                start_time: get_block_timestamp(), //TODO
                is_started: false,
                is_completed: false,
                end_time: 0, //TODO
                next_card_index: 0,
                players_count: 1,
            };

            // write new round to world
            world.write_model(@RoundsCount { id: GAME_ID, count: round_id });
            world.write_model(@Rounds { round_id, round });

            world.emit_event(@RoundCreated { round_id, creator: caller });

            round_id
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
