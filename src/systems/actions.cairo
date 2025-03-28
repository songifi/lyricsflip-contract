use lyricsflip::alias::ID;
use lyricsflip::constants::Genre;

#[starknet::interface]
pub trait IActions<TContractState> {
    fn create_round(ref self: TContractState, genre: Genre) -> ID;
    fn join_round(ref self: TContractState, round_id: u256);
    fn get_round_id(self: @TContractState) -> ID;
    fn add_lyrics_card(
        ref self: TContractState,
        genre: Genre,
        artist: felt252,
        title: felt252,
        year: u64,
        lyrics: ByteArray,
    ) -> u256;
}

// dojo decorator
#[dojo::contract]
pub mod actions {
    use lyricsflip::models::card::{LyricsCard, LyricsCardCount};
    use lyricsflip::constants::{GAME_ID, Genre};

    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use lyricsflip::models::round::{Round, RoundState, Rounds, RoundsCount, RoundPlayer};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use super::{IActions, ID};

    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct RoundCreated {
        #[key]
        pub round_id: u256,
        pub creator: ContractAddress,
    }

    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct RoundJoined {
        #[key]
        pub round_id: u256,
        pub player: ContractAddress,
    }

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn create_round(ref self: ContractState, genre: Genre) -> ID {
            // Get the default world.
            let mut world = self.world_default();

            // get caller address
            let caller = get_caller_address();

            // get the next round ID
            let round_id = self.get_round_id();

            // new round
            let round = Round {
                creator: caller,
                genre: genre.into(),
                wager_amount: 0, //TODO
                start_time: get_block_timestamp(), //TODO
                state: RoundState::Pending.into(),
                end_time: 0, //TODO
                next_card_index: 0,
                players_count: 1,
            };

            // write new round count to world
            world.write_model(@RoundsCount { id: GAME_ID, count: round_id });
            // write new round to world
            world.write_model(@Rounds { round_id, round });
            // write round player to world
            world
                .write_model(@RoundPlayer { player_to_round_id: (caller, round_id), joined: true });

            world.emit_event(@RoundCreated { round_id, creator: caller });

            round_id
        }

        fn join_round(ref self: ContractState, round_id: u256) {
            // Get the default world.
            let mut world = self.world_default();

            // get caller address
            let caller = get_caller_address();

            // read the model from the world
            let mut rounds: Rounds = world.read_model(round_id);

            // read round player from world
            let round_player: RoundPlayer = world.read_model((caller, round_id));

            // check if round exists by checking if no player exists
            assert(rounds.round.players_count > 0, 'Round does not exist');

            // check that round is not started
            assert(rounds.round.state == RoundState::Pending.into(), 'Round has started');

            // assert that player has not joined round
            assert(!round_player.joined, 'Already joined round');

            rounds.round.players_count = rounds.round.players_count + 1;

            // update round in world
            world.write_model(@rounds);

            // write round player to world
            world
                .write_model(@RoundPlayer { player_to_round_id: (caller, round_id), joined: true });

            // emit round created event
            world.emit_event(@RoundJoined { round_id, player: caller });
        }

        fn get_round_id(self: @ContractState) -> ID {
            // Get the default world
            let world = self.world_default();

            // compute next round ID from round counts
            let rounds_count: RoundsCount = world.read_model(GAME_ID);
            rounds_count.count + 1
        }

        fn add_lyrics_card(
            ref self: ContractState,
            genre: Genre,
            artist: felt252,
            title: felt252,
            year: u64,
            lyrics: ByteArray,
        ) -> u256 {
            // Get the default world.
            let mut world = self.world_default();

            let card_count: LyricsCardCount = world.read_model(GAME_ID);
            let card_id = card_count.count + 1;

            let new_card = LyricsCard { card_id, genre: genre.into(), artist, title, year, lyrics };

            // write new round to world
            world.write_model(@new_card);

            card_id
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
