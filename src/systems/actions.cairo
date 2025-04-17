use lyricsflip::alias::ID;
use lyricsflip::genre::Genre;
use starknet::ContractAddress;
use core::array::{ArrayTrait, SpanTrait};
use dojo::model::ModelStorage;
use dojo::event::EventStorage;
use lyricsflip::models::card::{LyricsCard};
use lyricsflip::models::round::{Answer};


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
    fn next_card(ref self: TContractState, round_id: u256) -> LyricsCard;
    fn submit_answer(ref self: TContractState, round_id: u256, answer: Answer) -> bool;
}

// dojo decorator
#[dojo::contract]
pub mod actions {
    use lyricsflip::models::card::{LyricsCard, LyricsCardCount, YearCards, ArtistCards};
    use lyricsflip::constants::{GAME_ID};
    use lyricsflip::genre::{Genre};
    use lyricsflip::models::round::{
        Round, RoundState, RoundsCount, RoundPlayer, PlayerStats, Answer,
    };
    use origami_random::deck::{Deck, DeckTrait};
    use origami_random::dice::{Dice, DiceTrait};
    use lyricsflip::models::config::GameConfig;
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
        // TODO: get random cards for a round
        fn create_round(ref self: ContractState, genre: Genre) -> ID {
            // Get the default world.
            let mut world = self.world_default();

            // get caller address
            let caller = get_caller_address();

            // get the next round ID
            let round_id = self.get_round_id();

            // Get the current game config
            let mut game_config: GameConfig = world.read_model(GAME_ID);

            let cards = self._get_random_cards(game_config.cards_per_round.into());

            // new round
            let round = Round {
                round_id,
                creator: caller,
                genre: genre.into(),
                wager_amount: 0, //TODO
                start_time: get_block_timestamp(), //TODO
                state: RoundState::Pending.into(),
                end_time: 0, //TODO
                players_count: 1,
                ready_players_count: 0,
                round_cards: cards.span(),
                players: array![caller].span(),
            };

            // write new round count to world
            world.write_model(@RoundsCount { id: GAME_ID, count: round_id });
            // write new round to world
            // world.write_model(@Rounds { round_id, round });
            world.write_model(@round);
            // write round player to world
            world
                .write_model(
                    @RoundPlayer {
                        player_to_round_id: (caller, round_id),
                        joined: true,
                        ready_state: false,
                        next_card_index: 0,
                        round_completed: false,
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
            let mut round: Round = world.read_model(round_id);

            // read round player from world
            let round_player: RoundPlayer = world.read_model((caller, round_id));

            // check if round exists by checking if no player exists
            assert(round.players_count > 0, 'Round does not exist');

            // check that round is not started
            assert(round.state == RoundState::Pending.into(), 'Round has started');

            // assert that player has not joined round
            assert(!round_player.joined, 'Already joined round');

            round.players_count = round.players_count + 1;

            let round_players = round.players;
            let mut new_players: Array<ContractAddress> = ArrayTrait::new();
            for i in 0..round_players.len() {
                new_players.append(*round_players[i]);
            };
            // add caller to players
            new_players.append(caller);
            round.players = new_players.span();

            // update round in world
            world.write_model(@round);

            // write round player to world
            world
                .write_model(
                    @RoundPlayer {
                        player_to_round_id: (caller, round_id),
                        joined: true,
                        ready_state: false,
                        next_card_index: 0,
                        round_completed: false,
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

            // Input validation
            assert(!artist.is_zero(), 'Artist cannot be empty');
            assert(!title.is_zero(), 'Title cannot be empty');
            assert(year > 0, 'Year must be positive');
            assert(lyrics.len() > 0, 'Lyrics cannot be empty');

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
            let caller = get_caller_address();

            let (mut round, mut round_player) = self
                ._validate_round_participation(@world, round_id, caller);

            // Verify round is in Pending state
            assert(round.state == RoundState::Pending.into(), 'Round not in Pending state');

            // Verify caller hasn't already signaled readiness
            assert(round_player.ready_state == false, 'Already signaled readiness');

            // Update player stats
            let mut player_stats: PlayerStats = world.read_model(caller);
            player_stats.total_rounds += 1;
            world.write_model(@player_stats);

            // Mark player as ready
            round_player.ready_state = true;
            world.write_model(@round_player);

            // Update round data
            round.ready_players_count += 1;

            // Check if all players are ready
            let all_ready = round.ready_players_count == round.players_count;
            if all_ready {
                round.state = RoundState::Started.into();
            }

            // Write round
            world.write_model(@round);

            // Emit event
            world
                .emit_event(
                    @PlayerReady { round_id, player: caller, ready_time: get_block_timestamp() },
                );
        }

        fn next_card(ref self: ContractState, round_id: u256) -> LyricsCard {
            let mut world = self.world_default();
            let caller = get_caller_address();

            // Validate that the round exists and is in a valid state
            self.is_valid_round(@world, round_id);

            let (mut round, mut round_player) = self
                ._validate_round_participation(@world, round_id, caller);

            assert(round.state == RoundState::Started.into(), 'Round not started');

            assert(round_player.round_completed == false, 'Player completed round');

            let cur_index = round_player.next_card_index;
            let cards = round.round_cards;

            let next_card_id = cards.at(cur_index.into());
            let card: LyricsCard = world.read_model(*next_card_id);

            // Update next_card_index
            let next_index = cur_index + 1;
            round_player.next_card_index = next_index;
            // write round player to world

            let card_len = round.round_cards.len();
            if next_index >= card_len.try_into().unwrap() {
                // If all cards have been drawn, update the player round state
                round_player.round_completed = true;
                world.write_model(@round_player);
            } else {
                world.write_model(@round_player);
            }

            let players = round.players;
            let mut round_is_completed = true;
            for i in 0..players.len() {
                let round_player: RoundPlayer = world.read_model((*players[i], round_id));
                if !round_player.round_completed {
                    round_is_completed = false;
                    break;
                }
            };

            if round_is_completed {
                round.state = RoundState::Completed.into();
                world.write_model(@round);
            }

            card
        }

        fn submit_answer(ref self: ContractState, round_id: u256, answer: Answer) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let round: Round = world.read_model(round_id);

            // Validate that the round exists and is in a valid state
            self.is_valid_round(@world, round_id);
            let is_participant = self.is_round_player(round_id, caller);
            assert(is_participant, 'Caller is non participant');
            assert(round.state == RoundState::Started.into(), 'Round not started');

            // Get participants current card
            let mut round_player: RoundPlayer = world.read_model((caller, round_id));
            assert(round_player.round_completed == false, 'Player completed round');
            let cur_index = round_player.next_card_index;
            let cards = round.round_cards;
            let next_card_id = cards.at(cur_index.into());
            let card: LyricsCard = world.read_model(*next_card_id);

            // Check if the answer is correct
            match answer {
                Answer::Artist(value) => { value == card.artist },
                Answer::Year(value) => { value == card.year },
                Answer::Title(value) => { value == card.title },
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

        fn is_valid_round(self: @ContractState, world: @WorldStorage, round_id: u256) {
            let round: Round = world.read_model(round_id);
            assert(!round.creator.is_zero(), 'Round does not exist');
        }

        fn _get_random_cards(self: @ContractState, count: u256) -> Array<u256> {
            let mut world = self.world_default();
            let card_count: LyricsCardCount = world.read_model(GAME_ID);

            // Make sure we don't request more cards than exist
            let available_cards = card_count.count;
            assert(available_cards >= count, 'Not enough cards available');

            let mut deck = DeckTrait::new(
                get_block_timestamp().into(), available_cards.try_into().unwrap(),
            );
            let mut random_cards: Array<u256> = ArrayTrait::new();

            // Use a more structured loop
            for _ in 0..count {
                let card = deck.draw();
                random_cards.append(card.into());
            };

            random_cards
        }

        fn _validate_round_participation(
            self: @ContractState, world: @WorldStorage, round_id: u256, caller: ContractAddress,
        ) -> (Round, RoundPlayer) {
            // Validate round exists
            let round: Round = world.read_model(round_id);
            assert(!round.creator.is_zero(), 'Round does not exist');

            // Validate player participation
            let round_player: RoundPlayer = world.read_model((caller, round_id));
            assert(round_player.joined, 'Caller is non participant');

            (round, round_player)
        }
    }

    #[generate_trait]
    impl CardGroupImpl of CardGroupTrait {
        fn add_year_cards(ref world: WorldStorage, year: u64, card_id: u256) {
            let existing_year_cards: YearCards = world.read_model(year);

            let mut new_cards: Array<u256> = ArrayTrait::new();

            // Only process existing cards if year is not zero
            if existing_year_cards.year != 0 {
                // Convert span to array more safely
                let existing_span = existing_year_cards.cards;
                for i in 0..existing_span.len() {
                    new_cards.append(*existing_span[i]);
                }
            }

            // Add the new card
            new_cards.append(card_id);

            // Write updated model
            world.write_model(@YearCards { year, cards: new_cards.span() });
        }

        fn add_artist_cards(ref world: WorldStorage, artist: felt252, card_id: u256) {
            let existing_artist_cards: ArtistCards = world.read_model(artist);

            let mut new_cards: Array<u256> = ArrayTrait::new();

            if !existing_artist_cards.artist.is_zero() {
                // Convert span to array more safely
                let existing_span = existing_artist_cards.cards;
                for i in 0..existing_span.len() {
                    new_cards.append(*existing_span[i]);
                }
            }

            new_cards.append(card_id);
            world.write_model(@ArtistCards { artist, cards: new_cards.span() });
        }
    }
}

