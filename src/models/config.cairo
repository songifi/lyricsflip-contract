use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct GameConfig {
    #[key]
    pub id: felt252, // represents GAME_ID 
    pub cards_per_round: u32,
    pub admin_address: ContractAddress,
    pub config_init: bool,
}
