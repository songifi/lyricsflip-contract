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
            && player_stats.total_score == 0 {
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
                    },
                );
        }
    }
}
