use crate::components::upgradeable::{upgradeable_component};

use upgradeable_component::{UpgradeableImpl};

#[starknet::interface]
pub trait IMockContractUpgradeable<TContractState> {
    fn version(self: @TContractState) -> felt252;
}

#[starknet::contract]
pub mod MockContractUpgradeableV0 {
    use crate::components::upgradeable::{upgradeable_component};
    use super::IMockContractUpgradeable;
    component!(path: upgradeable_component, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl UpgradeableImpl = upgradeable_component::Upgradeable<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        upgradeable: upgradeable_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        UpgradeableEvent: upgradeable_component::Event
    }

    #[abi(embed_v0)]
    impl MockContractUpgradeableImpl of IMockContractUpgradeable<ContractState> {
        fn version(self: @ContractState) -> felt252 {
            0
        }
    }
}

#[starknet::contract]
pub mod MockContractUpgradeableV1 {
    use crate::components::upgradeable::{upgradeable_component};
    use super::IMockContractUpgradeable;
    component!(path: upgradeable_component, storage: upgradeable, event: upgradeableEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        upgradeable: upgradeable_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        upgradeableEvent: upgradeable_component::Event
    }

    #[abi(embed_v0)]
    impl MockContractUpgradeableImpl of IMockContractUpgradeable<ContractState> {
        fn version(self: @ContractState) -> felt252 {
            1
        }
    }
}

#[cfg(test)]
mod tests {
    use core::starknet::syscalls::{deploy_syscall};
    use crate::components::upgradeable::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
    use snforge_std::{declare, DeclareResultTrait};
    use starknet::{ClassHash};
    use super::{IMockContractUpgradeableDispatcher, IMockContractUpgradeableDispatcherTrait};

    #[test]
    fn test_upgradeable_update_contract() {
        let mock_contract_upgradeable_v0_class_hash = (*declare("MockContractUpgradeableV0")
            .unwrap()
            .contract_class()
            .class_hash);
        let (contract_address, _) = deploy_syscall(
            mock_contract_upgradeable_v0_class_hash, 0, [].span(), false
        )
            .unwrap();

        let version = IMockContractUpgradeableDispatcher { contract_address: contract_address }
            .version();

        assert(version == 0, 'version is not 0');

        let mock_contract_upgradeable_v1_class_hash = (*declare("MockContractUpgradeableV1")
            .unwrap()
            .contract_class()
            .class_hash);
        let new_class_hash: ClassHash = mock_contract_upgradeable_v1_class_hash;

        IUpgradeableDispatcher { contract_address: contract_address }
            .upgrade_contract(new_class_hash);

        let version = IMockContractUpgradeableDispatcher { contract_address: contract_address }
            .version();
        assert(version == 1, 'version is not 1');
    }
}
