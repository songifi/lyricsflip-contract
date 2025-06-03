use starknet::{ContractAddress};

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct TopPlayer {
    #[key]
    pub player: ContractAddress,
    pub total_score: u64,
    pub total_wins: u64,
    pub last_updated: u64,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct LeaderboardConfig {
    #[key]
    pub id: felt252, // represents GAME_ID
    pub min_score_to_qualify: u64, // Minimum score needed to be in top 50
    pub current_player_count: u32,
}


#[generate_trait]
pub impl LeaderboardImpl of LeaderboardTrait {}
