use lyricsflip::alias::ID;
use lyricsflip::genre::Genre;
use starknet::ContractAddress;
use core::array::{ArrayTrait, SpanTrait};
use dojo::model::ModelStorage;
use dojo::event::EventStorage;

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
    fn is_round_player(self: @TContractState, round_id: u256, player: ContractAddress) -> bool;
    fn start_round(ref self: TContractState, round_id: u256);
}

// dojo decorator
#[dojo::contract]
pub mod actions {
    use lyricsflip::models::card::{LyricsCard, LyricsCardCount, YearCards, ArtistCards};
    use lyricsflip::constants::{GAME_ID};
    use lyricsflip::genre::{Genre};
    use lyricsflip::models::round::{
        Round, RoundState, Rounds, RoundsCount, RoundPlayer, PlayerStats,
    };

    use core::num::traits::Zero;

    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo::world::WorldStorage;
    use core::array::{ArrayTrait, SpanTrait};
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

    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct PlayerReady {
        #[key]
        pub round_id: u256,
        #[key]
        pub player: ContractAddress,
        pub ready_time: u64,
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
                ready_players_count: 0,
            };

            // write new round count to world
            world.write_model(@RoundsCount { id: GAME_ID, count: round_id });
            // write new round to world
            world.write_model(@Rounds { round_id, round });
            // write round player to world
            world
                .write_model(
                    @RoundPlayer {
                        player_to_round_id: (caller, round_id), joined: true, ready_state: false,
                    },
                );

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
                .write_model(
                    @RoundPlayer {
                        player_to_round_id: (caller, round_id), joined: true, ready_state: false,
                    },
                );

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
            let mut world = self.world_default();

            let card_count: LyricsCardCount = world.read_model(GAME_ID);
            let card_id = card_count.count + 1;

            let new_card = LyricsCard { card_id, genre: genre.into(), artist, title, year, lyrics };
            world.write_model(@new_card);

            world.write_model(@LyricsCardCount { id: GAME_ID, count: card_id });

            CardGroupTrait::add_year_cards(ref world, year, card_id);
            CardGroupTrait::add_artist_cards(ref world, artist, card_id);

            card_id
        }

        fn is_round_player(self: @ContractState, round_id: u256, player: ContractAddress) -> bool {
            // Get the default world.
            let world = self.world_default();
            // Get the round player
            let round_player: RoundPlayer = world.read_model((player, round_id));

            // Return the joined boolean which signifies if the player is a participant of the round
            // or not
            round_player.joined
        }

        /// Initiates a game round after a player signals readiness.
        ///
        /// This function handles the process of a player signaling they are ready to start the
        /// round.
        /// It validates the player's participation, updates their ready state, and checks if all
        /// players are ready to begin the round.
        ///
        /// @param round_id - The unique identifier for the round
        fn start_round(ref self: ContractState, round_id: u256) {
            // Get access to the world state
            let mut world = self.world_default();

            // Validate that the round exists and is in a valid state
            self.is_valid_round(@world, round_id);

            // Load the round data from the world state
            let rounds: Rounds = world.read_model(round_id);
            let mut round = rounds.round;

            // Get the address of the caller (the player signaling readiness)
            let caller = get_caller_address();

            // Check if caller is authorized - must be either the creator or a participant
            let is_creator = round.creator == caller;
            let is_participant = self.is_round_player(round_id, caller);
            assert(is_creator || is_participant, 'Caller is non participant');

            // Verify caller hasn't already signaled readiness
            let mut round_player: RoundPlayer = world.read_model((caller, round_id));
            assert(round_player.ready_state == false, 'Already signaled readiness');

            // Update the player's statistics to reflect participation in this round
            let mut player_stats: PlayerStats = world.read_model(caller);
            player_stats.total_rounds = player_stats.total_rounds + 1;
            world.write_model(@player_stats);

            // Mark the player as ready
            round_player.ready_state = true;
            world.write_model(@round_player);

            // Increment the count of ready players in the round
            round.ready_players_count = round.ready_players_count + 1;
            world.write_model(@Rounds { round_id, round });

            // Emit an event to log that the player is ready
            world
                .emit_event(
                    @PlayerReady { round_id, player: caller, ready_time: get_block_timestamp() },
                );

            // Check if all players are now ready
            let mut rounds: Rounds = world.read_model(round_id);
            if rounds.round.ready_players_count == rounds.round.players_count {
                // If all players are ready, update the round state to Started
                rounds.round.state = RoundState::Started.into();
                world.write_model(@rounds);
            }
        }
    }


    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Use the default namespace "dojo_starter". This function is handy since the ByteArray
        /// can't be const.
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"lyricsflip")
        }

        fn is_valid_round(self: @ContractState, world: @WorldStorage, round_id: u256) -> bool {
            let round: Rounds = world.read_model(round_id);
            !round.round.creator.is_zero()
        }
    }

    #[generate_trait]
    impl CardGroupImpl of CardGroupTrait {
        fn add_year_cards(ref world: WorldStorage, year: u64, card_id: u256) {
            let mut year_cards = YearCards { year, cards: ArrayTrait::new().span() };
            let existing_year_cards: YearCards = world.read_model(year);
            if existing_year_cards.year != 0 {
                year_cards = existing_year_cards;
            }

            let mut new_cards: Array<u256> = ArrayTrait::new();
            let mut i = 0;
            loop {
                if i >= year_cards.cards.len() {
                    break;
                }
                new_cards.append(*year_cards.cards[i]);
                i += 1;
            };
            new_cards.append(card_id);

            let updated_year_cards = YearCards { year, cards: new_cards.span() };
            world.write_model(@updated_year_cards);
        }

        fn add_artist_cards(ref world: WorldStorage, artist: felt252, card_id: u256) {
            let mut artist_cards = ArtistCards { artist, cards: ArrayTrait::new().span() };
            let existing_artist_cards: ArtistCards = world.read_model(artist);
            if existing_artist_cards.artist.is_zero() {
                artist_cards = existing_artist_cards;
            }

            let mut new_cards: Array<u256> = ArrayTrait::new();
            let mut i = 0;
            loop {
                if i >= artist_cards.cards.len() {
                    break;
                }
                new_cards.append(*artist_cards.cards[i]);
                i += 1;
            };
            new_cards.append(card_id);

            let updated_artist_cards = ArtistCards { artist, cards: new_cards.span() };
            world.write_model(@updated_artist_cards);
        }
    }
}

