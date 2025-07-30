#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub enum ConfigError {
    Uninitialized,
    InvalidCardsPerRound,
    InvalidAdminAddress,
    Unauthorized,
}

use starknet::{ContractAddress, get_caller_address};

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct GameConfig {
    #[key]
    pub id: felt252, // represents GAME_ID 
    pub cards_per_round: u32,
    pub admin_address: ContractAddress,
    pub config_init: bool,
}

#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub struct ConfigUpdate {
    pub cards_per_round: Option<u32>,
    pub admin_address: Option<ContractAddress>,
}

#[generate_trait]
pub impl GameConfigImpl of GameConfigTrait{
    fn new(id: felt252, cards_per_round: u32, admin_address: ContractAddress) -> Result<GameConfig, ConfigError> {
        if cards_per_round == 0 {
            return Result::Err(ConfigError::InvalidCardsPerRound);
        }
        if admin_address == 0.try_into().unwrap() {
            return Result::Err(ConfigError::InvalidAdminAddress);
        }
        Result::Ok(GameConfig {
            id,
            cards_per_round,
            admin_address,
            config_init: true,
        })
    }
    fn new_uninitialized(id: felt252, admin_address: ContractAddress) -> Result<GameConfig, ConfigError> {
        Result::Ok(GameConfig {
            id,
            cards_per_round: 0,
            admin_address,
            config_init: false,
        })
    }

    fn is_valid(self: @GameConfig) -> Result<bool, ConfigError> {
        if !*self.config_init {
            return Result::Err(ConfigError::Uninitialized);
        }
        let valid = *self.cards_per_round > 0 && *self.admin_address != 0.try_into().unwrap();
        Result::Ok(valid)
    }

    fn is_initialized(self: @GameConfig) -> Result<bool, ConfigError> {
        Result::Ok(*self.config_init)
    }

    fn set_cards_per_round(self: @GameConfig, cards_per_round: u32) -> Result<GameConfig, ConfigError> {
        if !*self.config_init {
            return Result::Err(ConfigError::Uninitialized);
        }
        let caller = get_caller_address();
        if caller != *self.admin_address {
            return Result::Err(ConfigError::Unauthorized);
        }
        if cards_per_round == 0 {
            return Result::Err(ConfigError::InvalidCardsPerRound);
        }
        let update = ConfigUpdate {
            cards_per_round: Option::Some(cards_per_round),
            admin_address: Option::None,
        };
        Self::apply_update(*self, update)
    }

    fn set_admin_address(self: @GameConfig, new_admin_address: ContractAddress) -> Result<GameConfig, ConfigError> {
        if !*self.config_init {
            return Result::Err(ConfigError::Uninitialized);
        }
        let caller = get_caller_address();
        if caller != *self.admin_address {
            return Result::Err(ConfigError::Unauthorized);
        }
        if new_admin_address == 0.try_into().unwrap() {
            return Result::Err(ConfigError::InvalidAdminAddress);
        }
        let update = ConfigUpdate {
            cards_per_round: Option::None,
            admin_address: Option::Some(new_admin_address),
        };
        Self::apply_update(*self, update)
    }

    fn initialize(self: @GameConfig) -> Result<GameConfig, ConfigError> {
        if *self.config_init {
            return Result::Err(ConfigError::Unauthorized);
        }
        let caller = get_caller_address();
        if caller != *self.admin_address {
            return Result::Err(ConfigError::Unauthorized);
        }
        let mut new_config = *self;
        new_config.config_init = true;
        Result::Ok(new_config)
    }

    fn apply_update(mut self: GameConfig, update: ConfigUpdate) -> Result<GameConfig, ConfigError> {
        if !self.config_init {
            return Result::Err(ConfigError::Uninitialized);
        }
        let caller = get_caller_address();
        if caller != self.admin_address {
            return Result::Err(ConfigError::Unauthorized);
        }
        let mut new_config = self;
        if update.cards_per_round.is_some() {
            let val = update.cards_per_round.unwrap();
            if val == 0 {
                return Result::Err(ConfigError::InvalidCardsPerRound);
            }
            new_config.cards_per_round = val;
        }
        if update.admin_address.is_some() {
            let addr = update.admin_address.unwrap();
            if addr == 0.try_into().unwrap() {
                return Result::Err(ConfigError::InvalidAdminAddress);
            }
            new_config.admin_address = addr;
        }
        Result::Ok(new_config)
    }

    fn is_admin(self: @GameConfig, address: ContractAddress) -> Result<bool, ConfigError> {
        if !*self.config_init {
            return Result::Err(ConfigError::Uninitialized);
        }
        Result::Ok(*self.admin_address == address)
    }

    fn max_cards_per_round(self: @GameConfig) -> Result<u32, ConfigError> {
        if !*self.config_init {
            return Result::Err(ConfigError::Uninitialized);
        }
        Result::Ok(*self.cards_per_round)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use starknet::ContractAddress;
    use starknet::testing::set_caller_address;

    fn admin_address() -> ContractAddress {
        starknet::contract_address_const::<'admin'>()
    }

    fn new_admin_address() -> ContractAddress {
        starknet::contract_address_const::<'new_admin'>()
    }

    #[test]
    fn test_game_config_initialization() {
        let config = GameConfigImpl::new(1, 5, admin_address()).unwrap();
        assert!(config.is_valid().unwrap(), "Config should be valid after initialization with valid values");
    }

    #[test]
    fn test_set_cards_per_round() {
        let admin = admin_address();
        set_caller_address(admin);
        let mut config = GameConfigImpl::new(1, 5, admin).unwrap();
        config = config.set_cards_per_round(10).unwrap();
        assert_eq!(config.cards_per_round, 10, "cards_per_round should be updated to 10 by admin");
    }

    #[test]
    fn test_set_admin_address() {
        let admin = admin_address();
        set_caller_address(admin);
        let mut config = GameConfigImpl::new(1, 5, admin).unwrap();
        config = config.set_admin_address(new_admin_address()).unwrap();
        assert_eq!(config.admin_address, new_admin_address(), "admin_address should be updated to new_admin_address by admin");
    }

    #[test]
    fn test_initialize_config() {
        let admin = admin_address();
        set_caller_address(admin);
        let mut config = GameConfigImpl::new_uninitialized(1, admin).unwrap();
        config = config.initialize().unwrap();
        config = config.set_cards_per_round(5).unwrap();
        assert!(config.is_initialized().unwrap(), "Config should be initialized after calling initialize");
        assert!(config.is_valid().unwrap(), "Config should be valid after initialization and setting cards_per_round");
    }

    #[test]
    fn test_apply_update() {
        let admin = admin_address();
        set_caller_address(admin);
        let mut config = GameConfigImpl::new(1, 5, admin).unwrap();
        config = config.set_cards_per_round(10).unwrap();
        assert_eq!(config.cards_per_round, 10, "cards_per_round should be updated to 10 by admin");
    }

    #[test]
    fn test_is_admin() {
        let admin = admin_address();
        set_caller_address(admin);
        let config = GameConfigImpl::new(1, 5, admin).unwrap();
        assert!(config.is_admin(admin).unwrap(), "admin should be recognized as admin");
        assert!(!config.is_admin(new_admin_address()).unwrap(), "new_admin_address should not be recognized as admin");
    }

    #[test]
    fn test_max_cards_per_round() {
        let admin = admin_address();
        set_caller_address(admin);
        let config = GameConfigImpl::new(1, 5, admin).unwrap();
        assert_eq!(config.max_cards_per_round().unwrap(), 5, "max_cards_per_round should return the correct value");
    }

    #[test]
    fn test_uninitialized_config() {
        let admin = admin_address();
        set_caller_address(admin);
        let config = GameConfigImpl::new_uninitialized(1, admin).unwrap();
        assert!(!config.is_initialized().unwrap(), "Config should not be initialized");
    }

    #[test]
    fn test_new_invalid_cards() {
        let admin = admin_address();
        let result = GameConfigImpl::new(1, 0, admin);
        assert!(result.is_err(), "new() should fail with zero cards_per_round");
    }

    #[test]
    fn test_new_invalid_admin() {
        let result = GameConfigImpl::new(1, 5, 0.try_into().unwrap());
        assert!(result.is_err(), "new() should fail with zero admin_address");
    }

    #[test]
    fn test_set_cards_per_round_zero() {
        let admin = admin_address();
        set_caller_address(admin);
        let config = GameConfigImpl::new(1, 5, admin).unwrap();
        let result = config.set_cards_per_round(0);
        assert!(result.is_err(), "set_cards_per_round should fail with zero value");
    }

    #[test]
    fn test_set_cards_per_round_non_admin() {
        let admin = admin_address();
        let not_admin = new_admin_address();
        set_caller_address(not_admin);
        let config = GameConfigImpl::new(1, 5, admin).unwrap();
        let result = config.set_cards_per_round(10);
        assert!(result.is_err(), "set_cards_per_round should fail for non-admin");
    }

    #[test]
    fn test_set_admin_address_zero() {
        let admin = admin_address();
        set_caller_address(admin);
        let config = GameConfigImpl::new(1, 5, admin).unwrap();
        let result = config.set_admin_address(0.try_into().unwrap());
        assert!(result.is_err(), "set_admin_address should fail with zero address");
    }

    #[test]
    fn test_set_admin_address_non_admin() {
        let admin = admin_address();
        let not_admin = new_admin_address();
        set_caller_address(not_admin);
        let config = GameConfigImpl::new(1, 5, admin).unwrap();
        let result = config.set_admin_address(new_admin_address());
        assert!(result.is_err(), "set_admin_address should fail for non-admin");
    }

    #[test]
    fn test_apply_update_partial() {
        let admin = admin_address();
        set_caller_address(admin);
        let config = GameConfigImpl::new(1, 5, admin).unwrap();
        let update = ConfigUpdate { cards_per_round: Option::Some(7), admin_address: Option::None };
        let updated = config.apply_update(update).unwrap();
        assert_eq!(updated.cards_per_round, 7, "apply_update should update cards_per_round");
        assert_eq!(updated.admin_address, admin, "apply_update should not change admin_address if not set");
    }

    #[test]
    fn test_apply_update_both() {
        let admin = admin_address();
        let new_admin = new_admin_address();
        set_caller_address(admin);
        let config = GameConfigImpl::new(1, 5, admin).unwrap();
        let update = ConfigUpdate { cards_per_round: Option::Some(8), admin_address: Option::Some(new_admin) };
        let updated = config.apply_update(update).unwrap();
        assert_eq!(updated.cards_per_round, 8, "apply_update should update cards_per_round");
        assert_eq!(updated.admin_address, new_admin, "apply_update should update admin_address");
    }

    #[test]
    fn test_apply_update_invalid_cards() {
        let admin = admin_address();
        set_caller_address(admin);
        let config = GameConfigImpl::new(1, 5, admin).unwrap();
        let update = ConfigUpdate { cards_per_round: Option::Some(0), admin_address: Option::None };
        let result = config.apply_update(update);
        assert!(result.is_err(), "apply_update should fail with zero cards_per_round");
    }

    #[test]
    fn test_apply_update_invalid_admin() {
        let admin = admin_address();
        set_caller_address(admin);
        let config = GameConfigImpl::new(1, 5, admin).unwrap();
        let update = ConfigUpdate { cards_per_round: Option::None, admin_address: Option::Some(0.try_into().unwrap()) };
        let result = config.apply_update(update);
        assert!(result.is_err(), "apply_update should fail with zero admin_address");
    }

    #[test]
    fn test_apply_update_non_admin() {
        let admin = admin_address();
        let not_admin = new_admin_address();
        set_caller_address(not_admin);
        let config = GameConfigImpl::new(1, 5, admin).unwrap();
        let update = ConfigUpdate { cards_per_round: Option::Some(9), admin_address: Option::None };
        let result = config.apply_update(update);
        assert!(result.is_err(), "apply_update should fail for non-admin");
    }

    #[test]
    fn test_double_initialize() {
        let admin = admin_address();
        set_caller_address(admin);
        let mut config = GameConfigImpl::new(1, 5, admin).unwrap();
        let result = config.initialize();
        assert!(result.is_err(), "initialize should fail if already initialized");
    }
}

    