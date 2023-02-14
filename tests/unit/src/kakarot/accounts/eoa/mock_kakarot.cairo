// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// @dev mock kakarot contract that returns inputs for execute_at_address and deploy_contract_account
@external
func execute_at_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(address: felt, value: felt, gas_limit: felt, calldata_len: felt, calldata: felt*) -> (
    address: felt, value: felt, gas_limit: felt, calldata_len: felt, calldata: felt*
) {
    return (address, value, gas_limit, calldata_len, calldata);
}

// @dev mock kakarot contract that returns inputs for execute_at_address
@external
func deploy_contract_account{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(gas_limit: felt, bytecode_len: felt, bytecode: felt*) -> (
    gas_limit: felt, bytecode_len: felt, bytecode: felt*
) {
    return (gas_limit, bytecode_len, bytecode);
}
