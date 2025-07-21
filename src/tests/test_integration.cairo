// use starknet::{testing};
// use dojo::model::ModelStorage;
// use lyricsflip::models::genre::Genre;
// use lyricsflip::models::round::{Round, RoundPlayer, Answer};
// use lyricsflip::models::player::{PlayerStats};
// use lyricsflip::models::round::{RoundState, Mode};
// use lyricsflip::systems::actions::{IActionsDispatcherTrait};

// use lyricsflip::tests::test_utils::{setup_with_config, get_answers, create_genre_round};

// #[test]
// #[available_gas(20000000000)]
// fn test_full_game_flow_two_players() {
//     // Setup players
//     let player_1 = starknet::contract_address_const::<0x1>();
//     let player_2 = starknet::contract_address_const::<0x2>();

//     let (mut world, mut actions_system) = setup_with_config();

//     // 1. Player 1 creates a round
//     testing::set_contract_address(player_1);
//     let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Pop);

//     // 2. Player 2 joins the round
//     testing::set_contract_address(player_2);
//     actions_system.join_round(round_id);

//     // Verify both players are in the round
//     let round: Round = world.read_model(round_id);
//     assert(round.players_count == 2, 'Should have 2 players');

//     // 3. Both players signal readiness
//     testing::set_contract_address(player_1);
//     actions_system.start_round(round_id);

//     testing::set_contract_address(player_2);
//     actions_system.start_round(round_id);

//     // Verify round started
//     let round: Round = world.read_model(round_id);
//     assert(round.state == RoundState::Started.into(), 'Round should be started');

//     // 4. Player 1 gets card and answers
//     testing::set_contract_address(player_1);
//     let question_card = actions_system.next_card(round_id);

//     let (correct_option, wrong_option) = get_answers(ref world, round_id, player_1,
//     @question_card);

//     // Submit correct answer
//     let is_correct = actions_system.submit_answer(round_id, correct_option.unwrap());
//     assert(is_correct, 'Answer should be correct');

//     // Verify player stats updated
//     let player_1_data: RoundPlayer = world.read_model((player_1, round_id));
//     assert(player_1_data.correct_answers == 1, 'Should have 1 correct answer');
//     assert(player_1_data.total_score > 0, 'Should have score > 0');

//     // 5. Player 2 gets the same card and answers incorrectly
//     testing::set_contract_address(player_2);
//     actions_system.next_card(round_id);

//     // Submit incorrect answer
//     let is_correct = actions_system.submit_answer(round_id, wrong_option);
//     assert(!is_correct, 'Answer should be incorrect');

//     // 6. Both players get second card
//     testing::set_contract_address(player_1);
//     let question_card = actions_system.next_card(round_id);
//     let (correct_option, _) = get_answers(ref world, round_id, player_1, @question_card);

//     let is_correct = actions_system.submit_answer(round_id, correct_option.unwrap());
//     assert(is_correct, 'Answer should be correct');

//     testing::set_contract_address(player_2);
//     actions_system.next_card(round_id);

//     let is_correct = actions_system.submit_answer(round_id, correct_option.unwrap());
//     assert(is_correct, 'Answer should be correct');

//     // Player_1 plays
//     // fast forward to end of round
//     testing::set_contract_address(player_1);
//     for _ in 0..13_u64 {
//         actions_system.next_card(round_id);
//         actions_system.submit_answer(round_id, Answer::OptionOne);
//     };
//     // Player_2 plays
//     // fast forward to end of round
//     testing::set_contract_address(player_2);
//     for _ in 0..13_u64 {
//         actions_system.next_card(round_id);
//         actions_system.submit_answer(round_id, Answer::OptionOne);
//     };

//     // 7. Verify round completed and winner determined
//     let round: Round = world.read_model(round_id);
//     assert(round.state == RoundState::Completed.into(), 'Round should be completed');

//     // Player 1 should be winner (more correct answers)
//     let player_1_stats: PlayerStats = world.read_model(player_1);
//     assert(player_1_stats.rounds_won == 1, 'Player 1 should win');
//     assert(player_1_stats.current_streak == 1, 'Player 1 should have streak');

//     let player_2_stats: PlayerStats = world.read_model(player_2);
//     assert(player_2_stats.rounds_won == 0, 'Player 2 should not win');
//     assert(player_2_stats.current_streak == 0, 'Player 2 should have no streak');
// }

// #[test]
// fn test_timeout_mechanics() {
//     // Setup players
//     let player_1 = starknet::contract_address_const::<0x1>();
//     let player_2 = starknet::contract_address_const::<0x2>();
//     let original_timestamp = 1000;

//     let (mut world, mut actions_system) = setup_with_config();

//     // Create and setup round
//     testing::set_contract_address(player_1);
//     let round_id = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::HipHop);

//     testing::set_contract_address(player_2);
//     actions_system.join_round(round_id);

//     // Start round
//     testing::set_contract_address(player_1);
//     actions_system.start_round(round_id);
//     testing::set_contract_address(player_2);
//     actions_system.start_round(round_id);

//     // Player 1 gets card
//     testing::set_contract_address(player_1);
//     testing::set_block_timestamp(original_timestamp);
//     actions_system.next_card(round_id);

//     // Set timestamp to simulate timeout (60 seconds + 1)
//     testing::set_block_timestamp(original_timestamp + 61);
//     // Answer after timeout
//     let is_correct = actions_system.submit_answer(round_id, Answer::OptionOne);

//     // Even though answer is correct, it should be marked incorrect due to timeout
//     assert!(!is_correct, "Timed out answer should be incorrect");

//     // Player 2 gets card and answers quickly
//     testing::set_contract_address(player_2);
//     testing::set_block_timestamp(original_timestamp);
//     actions_system.next_card(round_id);

//     // Answer within timeout (reset timestamp)
//     let is_correct = actions_system.submit_answer(round_id, Answer::OptionOne);
//     assert!(is_correct, "Answer within time should be correct");

//     // Compare scores - player 2 should have higher score
//     let player_1_data: RoundPlayer = world.read_model((player_1, round_id));
//     let player_2_data: RoundPlayer = world.read_model((player_2, round_id));

//     assert!(
//         player_2_data.total_score > player_1_data.total_score,
//         "Player answering within time should have higher score",
//     );
// }

// #[test]
// #[available_gas(20000000000)]
// fn test_multi_round_streaks() {
//     // Setup players
//     let player_1 = starknet::contract_address_const::<0x1>();
//     let player_2 = starknet::contract_address_const::<0x2>();

//     let (mut world, mut actions_system) = setup_with_config();

//     // First round - player 1 wins
//     testing::set_contract_address(player_1);
//     let round_id_1 = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

//     testing::set_contract_address(player_2);
//     actions_system.join_round(round_id_1);

//     // Start round
//     testing::set_contract_address(player_1);
//     actions_system.start_round(round_id_1);
//     testing::set_contract_address(player_2);
//     actions_system.start_round(round_id_1);

//     // Player 1 gets card and answers correctly
//     testing::set_contract_address(player_1);
//     let question_card = actions_system.next_card(round_id_1);
//     let (correct_option, wrong_option) = get_answers(
//         ref world, round_id_1, player_1, @question_card,
//     );

//     actions_system.submit_answer(round_id_1, correct_option.unwrap());

//     // Player 2 gets card and answers incorrectly
//     testing::set_contract_address(player_2);
//     actions_system.next_card(round_id_1);
//     actions_system.submit_answer(round_id_1, wrong_option);

//     // Player_1 plays
//     // fast forward to end of round
//     testing::set_contract_address(player_1);
//     for _ in 0..14_u64 {
//         actions_system.next_card(round_id_1);
//         actions_system.submit_answer(round_id_1, Answer::OptionOne);
//     };

//     // Player_2 plays
//     // fast forward to end of round
//     testing::set_contract_address(player_2);
//     for _ in 0..14_u64 {
//         actions_system.next_card(round_id_1);
//         actions_system.submit_answer(round_id_1, Answer::OptionOne);
//     };

//     // Verify player 1 wins round 1
//     let player_1_stats: PlayerStats = world.read_model(player_1);
//     assert(player_1_stats.rounds_won == 1, 'Player 1 should win round 1');
//     assert(player_1_stats.current_streak == 1, 'Player 1 should have streak 1');

//     // Second round - player 1 wins again
//     testing::set_contract_address(player_1);
//     let round_id_2 = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

//     testing::set_contract_address(player_2);
//     actions_system.join_round(round_id_2);

//     // Start round
//     testing::set_contract_address(player_1);
//     actions_system.start_round(round_id_2);
//     testing::set_contract_address(player_2);
//     actions_system.start_round(round_id_2);

//     // Player 1 gets card and answers correctly
//     testing::set_contract_address(player_1);
//     let question_card = actions_system.next_card(round_id_2);
//     let (correct_option, wrong_option) = get_answers(
//         ref world, round_id_2, player_1, @question_card,
//     );

//     actions_system.submit_answer(round_id_2, correct_option.unwrap());

//     // Player 2 gets card and answers incorrectly
//     testing::set_contract_address(player_2);
//     actions_system.next_card(round_id_2);
//     actions_system.submit_answer(round_id_2, wrong_option);

//     // Player_1 plays
//     // fast forward to end of round
//     testing::set_contract_address(player_1);
//     for _ in 0..14_u64 {
//         actions_system.next_card(round_id_2);
//         actions_system.submit_answer(round_id_2, Answer::OptionOne);
//     };

//     // Player_2 plays
//     // fast forward to end of round
//     testing::set_contract_address(player_2);
//     for _ in 0..14_u64 {
//         actions_system.next_card(round_id_2);
//         actions_system.submit_answer(round_id_2, Answer::OptionOne);
//     };

//     // Verify player 1's streak increases
//     let player_1_stats: PlayerStats = world.read_model(player_1);
//     assert(player_1_stats.rounds_won == 2, 'Player 1 should win round 2');
//     assert(player_1_stats.current_streak == 2, 'Player 1 streak should be 2');
//     assert(player_1_stats.max_streak == 2, 'Player 1 max streak should be 2');

//     // Third round - player 2 wins
//     testing::set_contract_address(player_1);
//     let round_id_3 = create_genre_round(ref actions_system, Mode::MultiPlayer, Genre::Rock);

//     testing::set_contract_address(player_2);
//     actions_system.join_round(round_id_3);

//     // Start round
//     testing::set_contract_address(player_1);
//     actions_system.start_round(round_id_3);
//     testing::set_contract_address(player_2);
//     actions_system.start_round(round_id_3);

//     // This time player 1 answers incorrectly
//     testing::set_contract_address(player_1);
//     let question_card = actions_system.next_card(round_id_3);
//     let (correct_option, wrong_option) = get_answers(
//         ref world, round_id_3, player_1, @question_card,
//     );

//     actions_system.submit_answer(round_id_3, wrong_option);

//     // Player 2 answers correctly
//     testing::set_contract_address(player_2);
//     actions_system.next_card(round_id_3);
//     actions_system.submit_answer(round_id_3, correct_option.unwrap());

//     // Player_1 plays
//     // fast forward to end of round
//     testing::set_contract_address(player_1);
//     for _ in 0..14_u64 {
//         actions_system.next_card(round_id_3);
//         actions_system.submit_answer(round_id_3, Answer::OptionOne);
//     };

//     // Player_2 plays
//     // fast forward to end of round
//     testing::set_contract_address(player_2);
//     for _ in 0..14_u64 {
//         actions_system.next_card(round_id_3);
//         actions_system.submit_answer(round_id_3, Answer::OptionOne);
//     };

//     // Verify player 1's streak resets but max_streak remains
//     let player_1_stats: PlayerStats = world.read_model(player_1);
//     assert(player_1_stats.rounds_won == 2, 'Player 1 wins unchanged');
//     assert(player_1_stats.current_streak == 0, 'Player 1 streak reset to 0');
//     assert(player_1_stats.max_streak == 2, 'Player 1 max streak remains 2');

//     // Verify player 2's stats
//     let player_2_stats: PlayerStats = world.read_model(player_2);
//     assert(player_2_stats.rounds_won == 1, 'Player 2 should win round 3');
//     assert(player_2_stats.current_streak == 1, 'Player 2 streak should be 1');
//     assert(player_2_stats.max_streak == 1, 'Player 2 max streak should be 1');
// }

// #[test]
// #[available_gas(20000000000)]
// fn test_full_game_flow_solo_mode() {
//     // Setup players
//     let player_1 = starknet::contract_address_const::<0x1>();

//     let (mut world, mut actions_system) = setup_with_config();

//     // 1. Player 1 creates a round
//     testing::set_contract_address(player_1);
//     let round_id = create_genre_round(ref actions_system, Mode::Solo, Genre::Pop);

//     // Verify one players are in round
//     let round: Round = world.read_model(round_id);
//     assert(round.players_count == 1, 'Should have 1 player');

//     // Verify round started
//     let round: Round = world.read_model(round_id);
//     assert(round.state == RoundState::Started.into(), 'Round should be started');

//     // 4. Player 1 gets card and answers
//     testing::set_contract_address(player_1);
//     let question_card = actions_system.next_card(round_id);

//     let (correct_option, _) = get_answers(ref world, round_id, player_1, @question_card);

//     // Submit correct answer
//     let is_correct = actions_system.submit_answer(round_id, correct_option.unwrap());
//     assert(is_correct, 'Answer should be correct');

//     // Verify player stats updated
//     let player_1_data: RoundPlayer = world.read_model((player_1, round_id));
//     assert(player_1_data.correct_answers == 1, 'Should have 1 correct answer');
//     assert(player_1_data.total_score > 0, 'Should have score > 0');

//     // 6. player gets second card
//     testing::set_contract_address(player_1);
//     let question_card = actions_system.next_card(round_id);
//     let (correct_option, _) = get_answers(ref world, round_id, player_1, @question_card);

//     let is_correct = actions_system.submit_answer(round_id, correct_option.unwrap());
//     assert(is_correct, 'Answer should be correct');

//     // Player_1 plays
//     // fast forward to end of round
//     testing::set_contract_address(player_1);
//     for _ in 0..13_u64 {
//         actions_system.next_card(round_id);
//         actions_system.submit_answer(round_id, Answer::OptionOne);
//     };

//     // 7. Verify round completed and winner determined
//     let round: Round = world.read_model(round_id);
//     assert(round.state == RoundState::Completed.into(), 'Round should be completed');

//     // Player 1 should be winner (more correct answers)
//     let player_1_stats: PlayerStats = world.read_model(player_1);
//     assert(player_1_stats.rounds_won == 1, 'Player 1 should win');
//     assert(player_1_stats.current_streak == 1, 'Player 1 should have streak');
// }
