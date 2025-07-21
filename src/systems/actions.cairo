use lyricsflip::alias::ID;
use lyricsflip::models::card::{CardData, QuestionCard};
use lyricsflip::models::genre::Genre;
use lyricsflip::models::round::{Answer, ChallengeType, Mode};
use lyricsflip::models::daily_challenge::{DailyChallenge, PlayerDailyProgress};
use starknet::ContractAddress;


#[starknet::interface]
pub trait IActions<TContractState> {
    fn create_round(
        ref self: TContractState,
        mode: Mode,
        challenge_type: Option<ChallengeType>,
        challenge_param1: Option<felt252>, // Primary parameter (year, artist, genre, decade)
        challenge_param2: Option<felt252> // Secondary parameter (for GenreAndDecade)
    ) -> ID;
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

    fn get_daily_challenge(self: @TContractState) -> DailyChallenge;
    fn get_daily_progress(self: @TContractState, player: ContractAddress) -> PlayerDailyProgress;
    fn check_daily_challenge_completion(
        self: @TContractState, player: ContractAddress, score: u64, accuracy: u64,
    ) -> bool;
    fn force_complete_daily_challenge(ref self: TContractState, player: ContractAddress) -> bool;
}

#[dojo::contract]
pub mod actions {
    use core::num::traits::Zero;
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo::world::WorldStorage;
    use lyricsflip::constants::{CARD_TIMEOUT, GAME_ID, MAX_PLAYERS, WAIT_PERIOD_BEFORE_FORCE_START};
    use lyricsflip::models::card::{
        CardData, CardGroupTrait, CardTrait, LyricsCard, LyricsCardCount, QuestionCard,
        QuestionCardTrait,
    };
    use lyricsflip::models::config::GameConfig;
    use lyricsflip::models::genre::Genre;
    use lyricsflip::models::player::{PlayerStats, PlayerTrait};
    use lyricsflip::models::round::{
        Answer, ChallengeType, Mode, Round, RoundPlayer, RoundState, RoundTrait, RoundsCount,
    };
    use lyricsflip::models::daily_challenge::{
        DailyChallenge, PlayerDailyProgress, DailyChallengeTrait,
    };
    use lyricsflip::systems::config::game_config::{assert_caller_is_admin, check_caller_is_admin};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use super::{IActions, ID};

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

    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct DailyChallengeProgress {
        #[key]
        pub player: ContractAddress,
        #[key]
        pub date: u64,
        pub attempts: u64,
        pub best_score: u64,
        pub best_accuracy: u64,
        pub completed: bool,
    }

    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct DailyChallengeCompleted {
        #[key]
        pub player: ContractAddress,
        #[key]
        pub date: u64,
        pub challenge_type: felt252,
        pub reward_amount: u64,
        pub reward_type: felt252,
        pub difficulty: u8,
        pub final_score: u64,
        pub final_accuracy: u64,
    }


    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn create_round(
            ref self: ContractState,
            mode: Mode,
            challenge_type: Option<ChallengeType>,
            challenge_param1: Option<felt252>,
            challenge_param2: Option<felt252>,
        ) -> ID {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let round_id = RoundTrait::get_round_id(@world);
            let game_config: GameConfig = world.read_model(GAME_ID);
            let cards_per_round: u64 = game_config.cards_per_round.into();

            // Determine challenge type and get cards accordingly
            let (final_challenge_type, cards) = match challenge_type {
                Option::Some(ct) => {
                    let param1 = challenge_param1.expect('Challenge param1 required');
                    let selected_cards = self
                        .get_cards_by_challenge_type(
                            ref world, ct, param1, challenge_param2, cards_per_round,
                        );
                    (ct, selected_cards)
                },
                Option::None => {
                    let random_cards = CardTrait::get_random_cards(ref world, cards_per_round);
                    (ChallengeType::Random, random_cards)
                },
            };

            // Pre-generate all question cards
            let question_cards = self.generate_question_cards(ref world, cards.span());

            // Create the round
            let round = Round {
                round_id,
                creator: caller,
                wager_amount: 0,
                start_time: 0,
                state: RoundState::Pending.into(),
                end_time: 0,
                players_count: 1,
                ready_players_count: 0,
                round_cards: cards.span(),
                players: array![caller].span(),
                question_cards: question_cards.span(),
                mode: mode.into(),
                challenge_type: final_challenge_type.into(),
                creation_time: get_block_timestamp(),
            };

            // Write to world storage
            world.write_model(@RoundsCount { id: GAME_ID, count: round_id });
            world.write_model(@round);

            // Create round player entry
            self.create_round_player_entry(ref world, caller, round_id);

            // Initialize player stats if needed
            PlayerTrait::initialize_player_stats(ref world, caller);

            // Emit event
            world.emit_event(@RoundCreated { round_id, creator: caller });

            // Auto-start solo mode
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
            PlayerTrait::initialize_player_stats(ref world, caller);

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

            let (mut round, mut round_player) = RoundTrait::validate_round_participation(
                @world, round_id, caller,
            );

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
            let (round, mut round_player) = RoundTrait::validate_round_participation(
                @world, round_id, caller,
            );
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
            let (round, mut round_player) = RoundTrait::validate_round_participation(
                @world, round_id, caller,
            );
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
                RoundTrait::check_round_completion(ref world, round_id);
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

            // Calculate current round metrics for daily challenge
            let round_accuracy = if round_player.total_answers > 0 {
                (round_player.correct_answers * 100) / round_player.total_answers
            } else {
                0
            };

            // Check daily challenge progress after each answer
            self
                .check_and_update_daily_challenge_progress(
                    ref world, caller, round_player.total_score, round_accuracy,
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

        /// Get today's daily challenge
        fn get_daily_challenge(self: @ContractState) -> DailyChallenge {
            let mut world = self.world_default();

            // Ensure today's challenge exists
            DailyChallengeTrait::ensure_daily_challenge_exists(ref world);

            let today = DailyChallengeTrait::get_todays_date();
            world.read_model(today)
        }

        /// Get player's daily progress
        fn get_daily_progress(
            self: @ContractState, player: ContractAddress,
        ) -> PlayerDailyProgress {
            let world = self.world_default();
            let today = DailyChallengeTrait::get_todays_date();
            world.read_model((player, today))
        }

        /// Check if performance meets daily challenge criteria
        fn check_daily_challenge_completion(
            self: @ContractState, player: ContractAddress, score: u64, accuracy: u64,
        ) -> bool {
            let mut world = self.world_default();

            let challenge = DailyChallengeTrait::generate_daily_challenge(
                ref world, get_block_timestamp(),
            );

            DailyChallengeTrait::check_challenge_completion_criteria(challenge, score, accuracy)
        }

        ///TODO: Force complete daily challenge for testing/admin purposes
        fn force_complete_daily_challenge(
            ref self: ContractState, player: ContractAddress,
        ) -> bool {
            let mut world = self.world_default();
            let today = DailyChallengeTrait::get_todays_date();

            // Ensure challenge exists
            DailyChallengeTrait::ensure_daily_challenge_exists(ref world);
            let challenge: DailyChallenge = world.read_model(today);

            // Get or initialize progress
            let mut progress: PlayerDailyProgress = world.read_model((player, today));
            if progress.attempts == 0 {
                self.initialize_daily_progress(ref world, player, today);
                progress = world.read_model((player, today));
            }

            if !progress.challenge_completed {
                progress.challenge_completed = true;
                progress.best_score = challenge.target_score;
                progress.best_accuracy = challenge.target_accuracy;

                world.write_model(@progress);

                // Award completion
                self
                    .award_daily_challenge_completion(
                        ref world,
                        player,
                        challenge,
                        challenge.target_score,
                        challenge.target_accuracy,
                    );

                return true;
            }

            false
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Use the default namespace "dojo_starter". This function is handy since the ByteArray
        /// can't be const.
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"lyricsflip")
        }

        fn get_cards_by_challenge_type(
            ref self: ContractState,
            ref world: WorldStorage,
            challenge_type: ChallengeType,
            challenge_param1: felt252,
            challenge_param2: Option<felt252>,
            cards_per_round: u64,
        ) -> Array<u64> {
            match challenge_type {
                ChallengeType::Random => {
                    CardTrait::get_random_cards(ref world, cards_per_round)
                },
                ChallengeType::Year => {
                    let year: u64 = challenge_param1.try_into().expect('Invalid year parameter');
                    assert(year > 0, 'Year must be positive');
                    CardTrait::get_cards_by_year(ref world, year, cards_per_round)
                },
                ChallengeType::Artist => {
                    assert(!challenge_param1.is_zero(), 'Artist cannot be empty');
                    CardTrait::get_cards_by_artist(ref world, challenge_param1, cards_per_round)
                },
                ChallengeType::Genre => {
                    let genre: felt252 = challenge_param1
                        .try_into()
                        .expect('Invalid genre parameter');
                    CardTrait::get_cards_by_genre(ref world, genre, cards_per_round)
                },
                ChallengeType::Decade => {
                    let decade: u64 = challenge_param1
                        .try_into()
                        .expect('Invalid decade parameter');
                    assert(decade % 10 == 0, 'Must be a valid decade');
                    assert(decade >= 1900 && decade <= 2020, 'Decade out of range');
                    CardTrait::get_cards_by_decade(ref world, decade, cards_per_round)
                },
                ChallengeType::GenreAndDecade => {
                    let genre: felt252 = challenge_param1
                        .try_into()
                        .expect('Invalid genre parameter');
                    let decade: u64 = challenge_param2
                        .expect('Decade parameter required')
                        .try_into()
                        .expect('Invalid decade parameter');
                    assert(decade % 10 == 0, 'Must be a valid decade');
                    assert(decade >= 1900 && decade <= 2020, 'Decade out of range');
                    CardTrait::get_cards_by_genre_and_decade(
                        ref world, genre, decade, cards_per_round,
                    )
                },
            }
        }

        fn generate_question_cards(
            ref self: ContractState, ref world: WorldStorage, cards: Span<u64>,
        ) -> Array<QuestionCard> {
            let mut question_cards: Array<QuestionCard> = ArrayTrait::new();
            for i in 0..cards.len() {
                let card_id = *cards[i];
                let card: LyricsCard = world.read_model(card_id);
                let question_card = QuestionCardTrait::generate_question_card(ref world, card);
                question_cards.append(question_card);
            };
            question_cards
        }

        fn create_round_player_entry(
            ref self: ContractState, ref world: WorldStorage, player: ContractAddress, round_id: ID,
        ) {
            world
                .write_model(
                    @RoundPlayer {
                        player_to_round_id: (player, round_id),
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
        }

        /// Check and update daily challenge progress (TODO: NO STREAKS)
        fn check_and_update_daily_challenge_progress(
            ref self: ContractState,
            ref world: WorldStorage,
            player: ContractAddress,
            round_score: u64,
            round_accuracy: u64,
        ) -> bool {
            let today = DailyChallengeTrait::get_todays_date();

            // Ensure today's challenge exists
            DailyChallengeTrait::ensure_daily_challenge_exists(ref world);

            // Get today's challenge
            let challenge: DailyChallenge = world.read_model(today);
            if !challenge.is_active {
                return false;
            }

            // Get or initialize player progress
            let mut progress: PlayerDailyProgress = world.read_model((player, today));
            if progress.attempts == 0 {
                self.initialize_daily_progress(ref world, player, today);
                progress = world.read_model((player, today));
            }

            // Update progress tracking
            progress.attempts += 1;
            progress.last_attempt_time = get_block_timestamp();

            // Update best performance
            if round_score > progress.best_score {
                progress.best_score = round_score;
            }
            if round_accuracy > progress.best_accuracy {
                progress.best_accuracy = round_accuracy;
            }

            // Check if challenge is completed
            let challenge_completed = DailyChallengeTrait::check_challenge_completion_criteria(
                challenge, round_score, round_accuracy,
            );

            if challenge_completed && !progress.challenge_completed {
                progress.challenge_completed = true;

                // Award completion rewards
                self
                    .award_daily_challenge_completion(
                        ref world, player, challenge, round_score, round_accuracy,
                    );

                // Update challenge statistics
                let mut updated_challenge = challenge;
                updated_challenge.completion_count += 1;
                world.write_model(@updated_challenge);
            }

            // Save progress
            world.write_model(@progress);

            world
                .emit_event(
                    @DailyChallengeProgress {
                        player,
                        date: today,
                        attempts: progress.attempts,
                        best_score: progress.best_score,
                        best_accuracy: progress.best_accuracy,
                        completed: progress.challenge_completed,
                    },
                );

            challenge_completed
        }

        /// Initialize daily progress for a player
        fn initialize_daily_progress(
            ref self: ContractState,
            ref world: WorldStorage,
            player: ContractAddress,
            challenge_date: u64,
        ) {
            let initial_progress = PlayerDailyProgress {
                player_date_id: (player, challenge_date),
                challenge_completed: false,
                best_score: 0,
                best_accuracy: 0,
                attempts: 0,
                last_attempt_time: 0,
                reward_claimed: false,
            };

            world.write_model(@initial_progress);

            // Update challenge participation count
            let mut challenge: DailyChallenge = world.read_model(challenge_date);
            challenge.participants_count += 1;
            world.write_model(@challenge);
        }

        /// Award completion rewards and update player stats
        fn award_daily_challenge_completion(
            ref self: ContractState,
            ref world: WorldStorage,
            player: ContractAddress,
            challenge: DailyChallenge,
            final_score: u64,
            final_accuracy: u64,
        ) {
            world
                .emit_event(
                    @DailyChallengeCompleted {
                        player,
                        date: challenge.date,
                        challenge_type: challenge.challenge_type,
                        reward_amount: challenge.reward_amount,
                        reward_type: challenge.reward_type,
                        difficulty: challenge.difficulty,
                        final_score,
                        final_accuracy,
                    },
                );
            // TODO: Add reward distribution
        }
    }
}
