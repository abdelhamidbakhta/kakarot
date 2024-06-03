// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.uint256 import Uint256

@storage_var
func Kakarot_cairo1_helpers_class_hash() -> (res: felt) {
}

@storage_var
func Kakarot_native_token_address() -> (res: felt) {
}

@storage_var
func Kakarot_account_contract_class_hash() -> (value: felt) {
}

@storage_var
func Kakarot_uninitialized_account_class_hash() -> (res: felt) {
}

@storage_var
func Kakarot_evm_to_starknet_address(evm_address: felt) -> (starknet_address: felt) {
}

@storage_var
func Kakarot_coinbase() -> (res: felt) {
}

@storage_var
func Kakarot_base_fee() -> (res: felt) {
}

@storage_var
func Kakarot_prev_randao() -> (res: Uint256) {
}

@storage_var
func Kakarot_block_gas_limit() -> (res: felt) {
}

@storage_var
func Kakarot_patched_addresses(evm_address: felt) -> (patch: felt) {
}

@storage_var
func Kakarot_original_patched_addresses(patch: felt) -> (original: felt) {
}
