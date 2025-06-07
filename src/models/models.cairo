use dojo::world::WorldStorage;
use dojo::model::ModelStorage;
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct PlayerStats {
    #[key]
    pub player: ContractAddress,
    pub total_rounds: u64,
    pub rounds_won: u64,
    pub current_streak: u64,
    pub max_streak: u64,
    pub total_score: u64,
    pub average_score: u64,
    pub best_score: u64,
    pub total_correct_answers: u64,
    pub total_answers: u64,
    pub accuracy_rate: u64, // Stored as percentage (0-100)
}


#[generate_trait]
pub impl PlayerImpl of PlayerTrait {
    fn initialize_player_stats(ref world: WorldStorage, player: ContractAddress) {
        // Try to read existing player stats
        let player_stats: PlayerStats = world.read_model(player);

        // If this is a new player, initialize their stats
        if player_stats.total_rounds == 0
            && player_stats.rounds_won == 0
            && player_stats.current_streak == 0
            && player_stats.max_streak == 0
            && player_stats.total_score == 0
            && player_stats.average_score == 0
            && player_stats.best_score == 0
            && player_stats.total_correct_answers == 0
            && player_stats.total_answers == 0
            && player_stats.accuracy_rate == 0 {
            // Initialize with default values
            world
                .write_model(
                    @PlayerStats {
                        player,
                        total_rounds: 0,
                        rounds_won: 0,
                        current_streak: 0,
                        max_streak: 0,
                        total_score: 0,
                        average_score: 0,
                        best_score: 0,
                        total_correct_answers: 0,
                        total_answers: 0,
                        accuracy_rate: 0,
                    },
                );
        }
    }

    /// Updates player stats after a round completion
    fn update_player_stats(
        ref world: WorldStorage,
        player: ContractAddress,
        round_score: u64,
        correct_answers: u64,
        total_answers: u64,
    ) {
        let mut player_stats: PlayerStats = world.read_model(player);
        
        // Update basic stats
        player_stats.total_score += round_score;
        player_stats.total_correct_answers += correct_answers;
        player_stats.total_answers += total_answers;
        
        // Update best score if current round score is higher
        if round_score > player_stats.best_score {
            player_stats.best_score = round_score;
        }
        
        // Update average score
        player_stats.average_score = player_stats.total_score / (player_stats.total_rounds + 1);
        
        // Update accuracy rate (as percentage)
        if player_stats.total_answers > 0 {
            player_stats.accuracy_rate = (player_stats.total_correct_answers * 100) / player_stats.total_answers;
        }
        
        world.write_model(@player_stats);
    }
}

