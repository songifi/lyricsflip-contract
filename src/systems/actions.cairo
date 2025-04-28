use lyricsflip::alias::ID;
use lyricsflip::genre::Genre;
use starknet::ContractAddress;
use lyricsflip::models::card::{QuestionCard, CardData};
use lyricsflip::models::round::{Answer, Mode};


#[starknet::interface]
pub trait IActions<TContractState> {
    fn create_round(ref self: TContractState, genre: Genre, mode: Mode) -> ID;
    fn join_round(ref self: TContractState, round_id: ID);
    fn add_lyrics_card(
        ref self: TContractState,
        genre: Genre,
        artist: felt252,
        title: felt252,
        year: u64,
        lyrics: ByteArray,
    );
    fn add_batch_lyrics_card(ref self: TContractState, cards: Span<CardData>);
    fn is_round_player(self: @TContractState, round_id: ID, player: ContractAddress) -> bool;
    fn start_round(ref self: TContractState, round_id: ID);
    fn next_card(ref self: TContractState, round_id: ID) -> QuestionCard;
    fn submit_answer(ref self: TContractState, round_id: ID, answer: Answer) -> bool;
    fn force_start_round(ref self: TContractState, round_id: ID);
}

#[dojo::contract]
pub mod actions {
    use lyricsflip::models::card::{
        LyricsCard, LyricsCardCount, YearCards, ArtistCards, QuestionCard, CardData, GenreCards,
    };
    use lyricsflip::constants::{GAME_ID, CARD_TIMEOUT, WAIT_PERIOD_BEFORE_FORCE_START, MAX_PLAYERS};
    use lyricsflip::genre::{Genre};
    use lyricsflip::models::round::{
        Round, RoundState, RoundsCount, RoundPlayer, PlayerStats, Answer, Mode,
    };
    use origami_random::deck::{DeckTrait};
    use origami_random::dice::{DiceTrait};
    use lyricsflip::models::config::GameConfig;
    use core::num::traits::Zero;

    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo::world::WorldStorage;
    use core::array::{ArrayTrait, SpanTrait};
    use starknet::{
        ContractAddress, get_block_timestamp, get_caller_address, contract_address_const,
    };
    use super::{IActions, ID};
    use lyricsflip::systems::config::game_config::{assert_caller_is_admin, check_caller_is_admin};


    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct RoundCreated {
        #[key]
        pub round_id: ID,
        pub creator: ContractAddress,
    }

    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct RoundJoined {
        #[key]
        pub round_id: ID,
        pub player: ContractAddress,
    }

    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct PlayerReady {
        #[key]
        pub round_id: ID,
        #[key]
        pub player: ContractAddress,
        pub ready_time: u64,
    }

    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct RoundWinner {
        #[key]
        pub round_id: ID,
        #[key]
        pub winner: ContractAddress,
        pub score: u64,
    }

    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct PlayerAnswer {
        #[key]
        pub round_id: ID,
        #[key]
        pub player: ContractAddress,
        pub card_id: ID,
        pub is_correct: bool,
        pub time_taken: u64,
    }

    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct RoundForceStarted {
        #[key]
        pub round_id: ID,
        pub admin: ContractAddress,
        pub timestamp: u64,
    }

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        /// Creates a new game round with the specified parameters
        /// Generates question cards upfront to ensure all players see the same questions
        fn create_round(ref self: ContractState, genre: Genre, mode: Mode) -> ID {
            // Get the default world.
            let mut world = self.world_default();

            // get caller address
            let caller = get_caller_address();

            // get the next round ID
            let round_id = self._get_round_id();

            // Get the current game config
            let mut game_config: GameConfig = world.read_model(GAME_ID);

            let cards = self._get_random_cards(game_config.cards_per_round.into());

            // Pre-generate all question cards
            let mut question_cards: Array<QuestionCard> = ArrayTrait::new();
            for i in 0..cards.len() {
                let card_id = *cards[i];
                let card: LyricsCard = world.read_model(card_id);
                let question_card = self._generate_question_card(card);
                question_cards.append(question_card);
            };

            // new round
            let round = Round {
                round_id,
                creator: caller,
                genre: genre.into(),
                wager_amount: 0, //TODO
                start_time: 0,
                state: RoundState::Pending.into(),
                end_time: 0, //TODO
                players_count: 1,
                ready_players_count: 0,
                round_cards: cards.span(),
                players: array![caller].span(),
                question_cards: question_cards.span(),
                mode: mode.into(),
                creation_time: get_block_timestamp(),
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
                        current_card_start_time: 0,
                        card_timeout: CARD_TIMEOUT,
                        correct_answers: 0,
                        total_answers: 0,
                        total_score: 0,
                        best_time: 0,
                    },
                );

            // Initialize player stats if needed
            self._initialize_player_stats(ref world, caller);

            world.emit_event(@RoundCreated { round_id, creator: caller });

            if mode == Mode::Solo.into() {
                self.start_round(round_id);
            }

            round_id
        }

        /// Allows a player to join an existing round
        /// Will fail for Solo mode or if round has already started
        fn join_round(ref self: ContractState, round_id: ID) {
            // Get the default world.
            let mut world = self.world_default();

            // get caller address
            let caller = get_caller_address();

            // read the model from the world
            let mut round: Round = world.read_model(round_id);

            assert(round.mode != Mode::Solo.into(), 'Cannot join solo mode');

            // read round player from world
            let round_player: RoundPlayer = world.read_model((caller, round_id));

            // check if round exists by checking if no player exists
            assert(round.players_count > 0, 'Round does not exist');

            // check that round is not started
            assert(round.state == RoundState::Pending.into(), 'Round has started');

            // assert that player has not joined round
            assert(!round_player.joined, 'Already joined round');

            assert(round.players_count < MAX_PLAYERS.into(), 'Max players reached');

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
                        current_card_start_time: 0,
                        card_timeout: CARD_TIMEOUT,
                        correct_answers: 0,
                        total_answers: 0,
                        total_score: 0,
                        best_time: 0,
                    },
                );

            // Initialize player stats if needed
            self._initialize_player_stats(ref world, caller);

            // emit round created event
            world.emit_event(@RoundJoined { round_id, player: caller });
        }

        /// Adds a single lyrics card to the game (admin only)
        fn add_lyrics_card(
            ref self: ContractState,
            genre: Genre,
            artist: felt252,
            title: felt252,
            year: u64,
            lyrics: ByteArray,
        ) {
            let mut world = self.world_default();

            assert_caller_is_admin(world);

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
            CardGroupTrait::add_genre_cards(ref world, genre.into(), card_id);
        }

        /// Adds multiple lyrics cards in a single transaction (admin only)
        fn add_batch_lyrics_card(ref self: ContractState, cards: Span<CardData>) {
            let mut world = self.world_default();

            assert_caller_is_admin(world);
            assert(cards.len() > 0, 'Cards cannot be empty');

            for i in 0..cards.len() {
                let card = cards[i].clone();

                self.add_lyrics_card(card.genre, card.artist, card.title, card.year, card.lyrics);
            };
        }

        /// Checks if a player is participating in a specific round
        fn is_round_player(self: @ContractState, round_id: ID, player: ContractAddress) -> bool {
            // Get the default world.
            let world = self.world_default();
            // Get the round player
            let round_player: RoundPlayer = world.read_model((player, round_id));

            // Return the joined boolean which signifies if the player is a participant of the round
            // or not
            round_player.joined
        }


        /// Signals player readiness to start a round
        /// Round begins when all players are ready
        fn start_round(ref self: ContractState, round_id: ID) {
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
            round.start_time = get_block_timestamp();

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


        /// Retrieves the next question card for the player
        /// Advances the player's position in the round
        fn next_card(ref self: ContractState, round_id: ID) -> QuestionCard {
            let mut world = self.world_default();
            let caller = get_caller_address();

            // Validate round and player
            let (round, mut round_player) = self
                ._validate_round_participation(@world, round_id, caller);
            assert(round.state == RoundState::Started.into(), 'Round not started');
            assert(round_player.round_completed == false, 'Player completed round');

            // Get the current card index
            let cur_index = round_player.next_card_index;

            // Check if there are any cards left
            let card_len = round.question_cards.len();
            assert(cur_index < card_len.try_into().unwrap(), 'No more cards available');

            let round: Round = world.read_model(round_id);

            // Get the pre-generated question card
            let question_card = round.question_cards[cur_index.into()];

            // Update player state
            round_player.next_card_index += 1;
            round_player.current_card_start_time = get_block_timestamp();
            world.write_model(@round_player);

            question_card.clone()
        }

        /// Validates and processes a player's answer to the current question
        /// Calculates score based on correctness and time taken
        /// Updates player statistics and checks for round completion
        fn submit_answer(ref self: ContractState, round_id: ID, answer: Answer) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();

            // Validate round and player
            let (round, mut round_player) = self
                ._validate_round_participation(@world, round_id, caller);
            assert(round.state == RoundState::Started.into(), 'Round not started');
            assert(round_player.round_completed == false, 'Player completed round');

            // Check timing
            let current_time = get_block_timestamp();
            let time_elapsed = current_time - round_player.current_card_start_time;
            let timed_out = time_elapsed > round_player.card_timeout;

            // Get current card index (previous card since next_card increments it)
            let cur_index = round_player.next_card_index - 1;

            // Get the stored question card for this index
            let question_card = round.question_cards[cur_index.into()];

            // Get the original card ID to access the correct card
            let cards = round.round_cards;
            let card_id = cards.at(cur_index.into());
            let card: LyricsCard = world.read_model(*card_id);

            // Check answer
            let mut is_correct = false;
            if !timed_out {
                // Get the selected option based on the enum variant
                let selected_option = match answer {
                    Answer::OptionOne => question_card.option_one,
                    Answer::OptionTwo => question_card.option_two,
                    Answer::OptionThree => question_card.option_three,
                    Answer::OptionFour => question_card.option_four,
                };

                let (artist, title) = selected_option;
                // Check if the selected option matches the correct card's artist and title
                is_correct = *artist == card.artist && *title == card.title;
            }

            // Update performance metrics
            round_player.total_answers += 1;

            if is_correct {
                round_player.correct_answers += 1;

                // Calculate score based on time taken
                let time_score = if timed_out {
                    50
                } else {
                    100
                        + ((round_player.card_timeout - time_elapsed) * 100)
                            / round_player.card_timeout
                };

                round_player.total_score += time_score;

                // Track best answer time
                if !timed_out
                    && (round_player.best_time == 0 || time_elapsed < round_player.best_time) {
                    round_player.best_time = time_elapsed;
                }
            }

            // Save the updated player state
            world.write_model(@round_player);

            // Check if this was the last card
            let card_len = round.round_cards.len();
            if cur_index >= card_len.try_into().unwrap() - 1 {
                round_player.round_completed = true;
                world.write_model(@round_player);
                // Check if all players have completed
                self._check_round_completion(ref world, round_id);
            }

            // Emit answer event
            world
                .emit_event(
                    @PlayerAnswer {
                        round_id,
                        player: caller,
                        card_id: *card_id,
                        is_correct,
                        time_taken: time_elapsed,
                    },
                );

            is_correct
        }

        fn force_start_round(ref self: ContractState, round_id: ID) {
            let mut world = self.world_default();
            let caller = get_caller_address();

            // Get the round
            let mut round: Round = world.read_model(round_id);

            // Only admin or creator can force start rounds
            assert!(
                check_caller_is_admin(world) || caller == round.creator,
                "Only admin or creator can force start",
            );

            // Validate round state
            assert(round.state == RoundState::Pending.into(), 'Round not in Pending state');

            // Check if waiting period has passed
            let current_time = get_block_timestamp();
            let time_elapsed = current_time - round.creation_time;
            assert(time_elapsed >= WAIT_PERIOD_BEFORE_FORCE_START, 'Waiting period not over');

            // Ensure there are at least 2 players for multiplayer modes
            if round.mode != Mode::Solo.into() {
                assert(round.players_count >= 2, 'Need at least 2 players');
            }

            // Mark all players as ready
            for i in 0..round.players.len() {
                let player = *round.players[i];
                let mut player_round: RoundPlayer = world.read_model((player, round_id));

                if !player_round.ready_state {
                    player_round.ready_state = true;
                    world.write_model(@player_round);

                    // Emit ready event
                    world.emit_event(@PlayerReady { round_id, player, ready_time: current_time });
                }
            };

            // Start the round
            round.ready_players_count = round.players_count;
            round.state = RoundState::Started.into();
            round.start_time = current_time;
            world.write_model(@round);

            // Emit event
            world
                .emit_event(
                    @RoundForceStarted { round_id, admin: caller, timestamp: current_time },
                );
        }
    }


    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Use the default namespace "dojo_starter". This function is handy since the ByteArray
        /// can't be const.
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"lyricsflip")
        }

        /// Retrieves the next available round ID
        fn _get_round_id(self: @ContractState) -> ID {
            // Get the default world
            let world = self.world_default();

            // compute next round ID from round counts
            let rounds_count: RoundsCount = world.read_model(GAME_ID);
            rounds_count.count + 1
        }

        fn is_valid_round(self: @ContractState, world: @WorldStorage, round_id: ID) {
            let round: Round = world.read_model(round_id);
            assert(!round.creator.is_zero(), 'Round does not exist');
        }

        /// Retrieves a random selection of cards for a round
        /// Ensures we don't request more cards than are available
        fn _get_random_cards(self: @ContractState, count: u64) -> Array<u64> {
            let mut world = self.world_default();
            let card_count: LyricsCardCount = world.read_model(GAME_ID);

            // Make sure we don't request more cards than exist
            let available_cards = card_count.count;
            assert(available_cards >= count, 'Not enough cards available');

            let mut deck = DeckTrait::new(
                get_block_timestamp().into(), available_cards.try_into().unwrap(),
            );
            let mut random_cards: Array<u64> = ArrayTrait::new();

            // Use a more structured loop
            for _ in 0..count {
                let card = deck.draw();
                random_cards.append(card.into());
            };

            random_cards
        }

        fn _validate_round_participation(
            self: @ContractState, world: @WorldStorage, round_id: ID, caller: ContractAddress,
        ) -> (Round, RoundPlayer) {
            // Validate round exists
            let round: Round = world.read_model(round_id);
            assert(!round.creator.is_zero(), 'Round does not exist');

            // Validate player participation
            let round_player: RoundPlayer = world.read_model((caller, round_id));
            assert(round_player.joined, 'Caller is non participant');

            (round, round_player)
        }

        /// Checks if all players have completed the round
        /// If so, marks the round as completed and determines the winner
        fn _check_round_completion(ref self: ContractState, ref world: WorldStorage, round_id: ID) {
            let mut round: Round = world.read_model(round_id);
            let players = round.players;

            // Check if all players have completed the round
            let mut all_completed = true;
            for i in 0..players.len() {
                let round_player: RoundPlayer = world.read_model((*players[i], round_id));
                if !round_player.round_completed {
                    all_completed = false;
                    break;
                }
            };

            // If all players have completed, finish the round
            if all_completed {
                // Mark round as completed
                round.state = RoundState::Completed.into();
                round.end_time = get_block_timestamp();
                world.write_model(@round);

                // Determine the winner
                self._determine_round_winner(ref world, round_id);
            }
        }

        /// Determines the winner of a completed round
        /// Updates player stats including streaks and emits winner event
        fn _determine_round_winner(ref self: ContractState, ref world: WorldStorage, round_id: ID) {
            let round: Round = world.read_model(round_id);
            let players = round.players;

            // Find the player with the highest score
            let mut highest_score = 0;
            let mut winner = contract_address_const::<0>();

            for i in 0..players.len() {
                let player = *players[i];
                let round_player: RoundPlayer = world.read_model((player, round_id));

                if round_player.total_score > highest_score {
                    highest_score = round_player.total_score;
                    winner = player;
                }
            };

            // Update winner's stats
            if !winner.is_zero() {
                let mut winner_stats: PlayerStats = world.read_model(winner);
                winner_stats.rounds_won += 1;
                winner_stats.current_streak += 1;

                // Update max streak if current streak is higher
                if winner_stats.current_streak > winner_stats.max_streak {
                    winner_stats.max_streak = winner_stats.current_streak;
                }

                world.write_model(@winner_stats);

                // Reset streaks for non-winners
                for i in 0..players.len() {
                    let player = *players[i];
                    if player != winner {
                        let mut player_stats: PlayerStats = world.read_model(player);
                        player_stats.current_streak = 0;
                        world.write_model(@player_stats);
                    }
                }
            }

            // Emit winner event
            world.emit_event(@RoundWinner { round_id, winner, score: highest_score });
        }

        fn _initialize_player_stats(
            ref self: ContractState, ref world: WorldStorage, player: ContractAddress,
        ) {
            // Try to read existing player stats
            let player_stats: PlayerStats = world.read_model(player);

            // If this is a new player, initialize their stats
            if player_stats.total_rounds == 0
                && player_stats.rounds_won == 0
                && player_stats.current_streak == 0
                && player_stats.max_streak == 0 {
                // Initialize with default values
                world
                    .write_model(
                        @PlayerStats {
                            player,
                            total_rounds: 0,
                            rounds_won: 0,
                            current_streak: 0,
                            max_streak: 0,
                        },
                    );
            }
        }

        /// Generates a multiple-choice question from a lyrics card
        /// Creates one correct option and three incorrect options in random positions
        fn _generate_question_card(self: @ContractState, correct_card: LyricsCard) -> QuestionCard {
            let mut world = self.world_default();
            let card_count: LyricsCardCount = world.read_model(GAME_ID);

            // Create a random number generator
            let mut dice = DiceTrait::new(
                card_count.count.try_into().unwrap(), get_block_timestamp().into(),
            );

            // Get three different incorrect cards
            let mut wrong_cards: Array<LyricsCard> = ArrayTrait::new();
            let mut attempt_count = 0_u8;
            let max_attempts = 10_u8; // Prevent infinite loops

            while wrong_cards.len() < 3 && attempt_count < max_attempts {
                // Generate a random card ID (between 1 and available_cards)
                let random_card_id = dice.roll().into();

                // Skip if we randomly selected the correct card
                if random_card_id == correct_card.card_id {
                    attempt_count += 1;
                    continue;
                }

                // Skip if we already selected this card
                let mut duplicate = false;
                for i in 0..wrong_cards.len() {
                    if *wrong_cards[i].card_id == random_card_id {
                        duplicate = true;
                        break;
                    }
                };

                if !duplicate {
                    let wrong_card: LyricsCard = world.read_model(random_card_id);
                    wrong_cards.append(wrong_card);
                }

                attempt_count += 1;
            };

            let mut dice = DiceTrait::new(4, get_block_timestamp().into());

            // Randomly position the correct answer
            let correct_position = dice.roll(); // 1-4

            // Create the question card
            let mut options: Array<(felt252, felt252)> = ArrayTrait::new();
            for i in 1..5_u8 {
                if i == correct_position {
                    options.append((correct_card.artist, correct_card.title));
                } else {
                    let wrong_index = if i > correct_position {
                        i - 2
                    } else {
                        i - 1
                    };
                    options
                        .append(
                            (
                                *wrong_cards.at(wrong_index.into()).artist,
                                *wrong_cards.at(wrong_index.into()).title,
                            ),
                        );
                };
            };

            QuestionCard {
                lyric: correct_card.lyrics,
                option_one: *options[0],
                option_two: *options[1],
                option_three: *options[2],
                option_four: *options[3],
            }
        }
    }

    #[generate_trait]
    impl CardGroupImpl of CardGroupTrait {
        fn add_year_cards(ref world: WorldStorage, year: u64, card_id: ID) {
            let existing_year_cards: YearCards = world.read_model(year);

            let mut new_cards: Array<u64> = ArrayTrait::new();

            // Only process existing cards if year is not zero
            if existing_year_cards.year != 0 {
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

        fn add_artist_cards(ref world: WorldStorage, artist: felt252, card_id: ID) {
            let existing_artist_cards: ArtistCards = world.read_model(artist);

            let mut new_cards: Array<u64> = ArrayTrait::new();

            if !existing_artist_cards.artist.is_zero() {
                let existing_span = existing_artist_cards.cards;
                for i in 0..existing_span.len() {
                    new_cards.append(*existing_span[i]);
                }
            }

            new_cards.append(card_id);
            world.write_model(@ArtistCards { artist, cards: new_cards.span() });
        }

        fn add_genre_cards(ref world: WorldStorage, genre: felt252, card_id: ID) {
            let existing_genre_cards: GenreCards = world.read_model(genre);

            let mut new_cards: Array<u64> = ArrayTrait::new();

            if !existing_genre_cards.genre.is_zero() {
                let existing_span = existing_genre_cards.cards;
                for i in 0..existing_span.len() {
                    new_cards.append(*existing_span[i]);
                }
            }

            new_cards.append(card_id);
            world.write_model(@GenreCards { genre, cards: new_cards.span() });
        }
    }
}

