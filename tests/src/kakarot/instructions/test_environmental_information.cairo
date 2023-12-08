// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import split_felt
from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.memset import memset

// Third party dependencies
from openzeppelin.token.erc20.library import ERC20

// Local dependencies
from data_availability.starknet import Starknet
from kakarot.account import Account
from kakarot.constants import Constants
from kakarot.storages import (
    contract_account_class_hash,
    account_proxy_class_hash,
    native_token_address,
)
from kakarot.evm import EVM
from kakarot.instructions.environmental_information import EnvironmentalInformation
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.system_operations import CreateHelper
from kakarot.interfaces.interfaces import IKakarot, IContractAccount
from kakarot.library import Kakarot
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from tests.utils.helpers import TestHelpers
from utils.utils import Helpers

@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(native_token_address_: felt, contract_account_class_hash_: felt, account_proxy_class_hash_) {
    native_token_address.write(native_token_address_);
    account_proxy_class_hash.write(account_proxy_class_hash_);
    contract_account_class_hash.write(contract_account_class_hash_);
    return ();
}

// @dev The contract account initialization includes a call to the Kakarot contract
// in order to get the native token address. As the Kakarot contract is not deployed within this test, we make a call to this contract instead.
@view
func get_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    native_token_address: felt
) {
    return Kakarot.get_native_token();
}

// @dev The contract account initialization includes a call to an ERC20 contract to set an infitite transfer allowance to Kakarot.
// As the ERC20 contract is not deployed within this test, we make a call to this contract instead.
@external
func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, amount: Uint256
) -> (success: felt) {
    return ERC20.approve(spender, amount);
}

func init_context{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> model.EVM* {
    alloc_locals;

    // Initialize Message
    let (bytecode) = alloc();
    assert [bytecode] = 00;
    tempvar bytecode_len = 1;
    let (calldata) = alloc();
    assert [calldata] = '';
    let parent = EVM.init_empty();
    tempvar address = new model.Address(0, 420);
    local message: model.Message* = new model.Message(
        bytecode=bytecode,
        bytecode_len=bytecode_len,
        calldata=calldata,
        calldata_len=1,
        value=0,
        gas_price=0,
        origin=address,
        parent=parent,
        address=address,
        read_only=FALSE,
        is_create=FALSE,
        depth=0,
    );

    // Initialize EVM
    let evm = EVM.init(message, Constants.TRANSACTION_GAS_LIMIT);
    return evm;
}

@view
func test__exec_address__should_push_address_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let evm: model.EVM* = init_context();

    // When
    let result = EnvironmentalInformation.exec_address(evm);

    // The
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 420;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_extcodesize__should_handle_address_with_no_code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Starknet.deploy(
        contract_account_class_hash_, evm_contract_address
    );
    let address = Helpers.to_uint256(evm_contract_address);

    let stack = Stack.init();
    let stack = Stack.push(stack, address);

    let bytecode_len = 0;
    let (bytecode) = alloc();
    let evm: model.EVM* = TestHelpers.init_context_with_stack(bytecode_len, bytecode, stack);

    // When
    let evm = EnvironmentalInformation.exec_extcodesize(evm);

    // Then
    let (stack, extcodesize) = Stack.peek(evm.stack, 0);
    assert extcodesize.low = 0;
    assert extcodesize.high = 0;

    return ();
}

@external
func test__exec_extcodecopy__should_handle_address_with_code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(bytecode_len: felt, bytecode: felt*, size: felt, offset: felt, dest_offset: felt) -> (
    memory_len: felt, memory: felt*
) {
    // Given
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Starknet.deploy(
        contract_account_class_hash_, evm_contract_address
    );
    IContractAccount.write_bytecode(starknet_contract_address, bytecode_len, bytecode);
    let evm_contract_address_uint256 = Helpers.to_uint256(evm_contract_address);

    // make a deployed registry contract available
    tempvar item_3 = new Uint256(size, 0);  // size
    tempvar item_2 = new Uint256(offset, 0);  // offset
    tempvar item_1 = new Uint256(dest_offset, 0);  // dest_offset
    tempvar item_0 = evm_contract_address_uint256;  // address

    let stack = Stack.init();
    let stack = Stack.push(stack, item_3);  // size
    let stack = Stack.push(stack, item_2);  // offset
    let stack = Stack.push(stack, item_1);  // dest_offset
    let stack = Stack.push(stack, item_0);  // address

    let evm: model.EVM* = TestHelpers.init_context_with_stack(bytecode_len, bytecode, stack);

    // When
    let result = EnvironmentalInformation.exec_extcodecopy(evm);

    // Then
    assert result.stack.size = 0;

    let (output_array) = alloc();
    Memory.load_n(result.memory, size, output_array, dest_offset);

    return (memory_len=size, memory=output_array);
}

@external
func test__exec_extcodecopy__should_handle_address_with_no_code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;

    // make a deployed registry contract available

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Starknet.deploy(
        contract_account_class_hash_, evm_contract_address
    );
    let evm_contract_address_uint256 = Helpers.to_uint256(evm_contract_address);

    tempvar item_3 = new Uint256(3, 0);  // size
    tempvar item_2 = new Uint256(1, 0);  // offset
    tempvar item_1 = new Uint256(32, 0);  // dest_offset
    tempvar item_0 = evm_contract_address_uint256;  // address

    let stack = Stack.init();
    let stack = Stack.push(stack, item_3);  // size
    let stack = Stack.push(stack, item_2);  // offset
    let stack = Stack.push(stack, item_1);  // dest_offset
    let stack = Stack.push(stack, item_0);  // address

    let (bytecode) = alloc();
    let bytecode_len = 0;

    let evm: model.EVM* = TestHelpers.init_context_with_stack(bytecode_len, bytecode, stack);

    // When
    let result = EnvironmentalInformation.exec_extcodecopy(evm);
    let (output_array) = alloc();
    Memory.load_n(result.memory, 3, output_array, 32);

    // Then
    // ensure stack is consumed/updated
    assert result.stack.size = 0;

    assert [output_array] = 0;
    assert [output_array + 1] = 0;
    assert [output_array + 2] = 0;

    return ();
}

@external
func test__exec_gasprice{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    assert [bytecode] = 00;
    tempvar bytecode_len = 1;
    let stack = Stack.init();
    let evm: model.EVM* = TestHelpers.init_context_with_stack(bytecode_len, bytecode, stack);

    let expected_gas_price_uint256 = Helpers.to_uint256(evm.message.gas_price);

    let result = EnvironmentalInformation.exec_gasprice(evm);
    let (stack, gasprice) = Stack.peek(result.stack, 0);

    // The
    assert_uint256_eq([gasprice], [expected_gas_price_uint256]);

    return ();
}

@view
func test__returndatacopy{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;

    let (bytecode) = alloc();
    let (return_data) = alloc();
    let return_data_len: felt = 32;

    memset(return_data, 0xFF, return_data_len);
    let evm: model.EVM* = TestHelpers.init_context_with_return_data(
        0, bytecode, return_data_len, return_data
    );

    // Pushing parameters needed by RETURNDATACOPY in the stack
    // size: byte size to copy.
    // offset: byte offset in the return data from the last executed sub context to copy.
    // destOffset: byte offset in the memory where the result will be copied.
    tempvar item_2 = new Uint256(32, 0);
    tempvar item_1 = new Uint256(0, 0);
    tempvar item_0 = new Uint256(0, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);

    let evm = EVM.update_stack(evm, stack);

    // When
    let evm: model.EVM* = EnvironmentalInformation.exec_returndatacopy(evm);

    // Then
    let (memory, data) = Memory.load(evm.memory, 0);
    assert_uint256_eq(
        data, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
    );

    // Pushing parameters for another RETURNDATACOPY
    tempvar item_2 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(31, 0);
    tempvar item_0 = new Uint256(32, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);

    let evm: model.EVM* = EVM.update_stack(evm, stack);
    let evm: model.EVM* = EVM.update_memory(evm, memory);

    // When
    let result: model.EVM* = EnvironmentalInformation.exec_returndatacopy(evm);

    // Then
    // check first 32 bytes
    let (memory, data) = Memory.load(result.memory, 0);
    assert_uint256_eq(
        data, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
    );
    // check 1 byte more at offset 32
    let (output_array) = alloc();
    Memory.load_n(memory, 1, output_array, 32);
    assert [output_array] = 0xFF;

    return ();
}

@external
func test__exec_extcodehash__should_handle_invalid_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;

    let bytecode_len = 0;
    let (bytecode) = alloc();
    tempvar address = new Uint256(0xDEAD, 0);
    let stack = Stack.init();
    let stack = Stack.push(stack, address);

    let evm: model.EVM* = TestHelpers.init_context_with_stack(bytecode_len, bytecode, stack);

    // When
    let result = EnvironmentalInformation.exec_extcodehash(evm);

    // Then
    let (stack, extcodehash) = Stack.peek(result.stack, 0);
    assert extcodehash.low = 0;
    assert extcodehash.high = 0;

    return ();
}

@external
func test__exec_extcodehash__should_handle_address_with_code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(bytecode_len: felt, bytecode: felt*, expected_hash_low: felt, expected_hash_high: felt) {
    // Given
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Starknet.deploy(
        contract_account_class_hash_, evm_contract_address
    );
    IContractAccount.write_bytecode(starknet_contract_address, bytecode_len, bytecode);
    let address = Helpers.to_uint256(evm_contract_address);
    let stack = Stack.init();
    let stack = Stack.push(stack, address);

    let evm: model.EVM* = TestHelpers.init_context_with_stack(bytecode_len, bytecode, stack);

    // When
    let result = EnvironmentalInformation.exec_extcodehash(evm);

    // Then
    let (stack, extcodehash) = Stack.peek(result.stack, 0);
    assert extcodehash.low = expected_hash_low;
    assert extcodehash.high = expected_hash_high;

    return ();
}
