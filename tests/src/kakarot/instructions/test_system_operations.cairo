// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.math import split_felt, assert_not_zero, assert_le
from starkware.cairo.common.uint256 import Uint256, uint256_sub
from starkware.starknet.common.syscalls import deploy, get_contract_address

// Third party dependencies
from openzeppelin.token.erc20.library import ERC20

// Local dependencies
from kakarot.constants import Constants
from kakarot.storages import (
    Constants,
    native_token_address,
    contract_account_class_hash,
    account_proxy_class_hash,
)
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.system_operations import SystemOperations, CallHelper, CreateHelper
from kakarot.interfaces.interfaces import IContractAccount, IKakarot, IAccount, IERC20
from kakarot.library import Kakarot
from kakarot.account import Account
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.state import State
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

// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          MOCK FUNCTIONS                                                      //
// The Kakarot, EOA, Contract Account and ETH contracts often times require communication between each other.   //
// Instead of deploying each contract for every test-case we mock the required functions in this contract.      //
// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

//
// Kakarot
//

// @dev The contract account initialization includes a call to the Kakarot contract
// in order to get the native token address. As the Kakarot contract is not deployed within this test, we make a call to this contract instead.
@view
func get_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    native_token_address: felt
) {
    return Kakarot.get_native_token();
}

// @dev mock function that returns the computed starknet address from an evm address
@external
func compute_starknet_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) -> (contract_address: felt) {
    let (contract_address_) = Account.compute_starknet_address(evm_address);
    return (contract_address=contract_address_);
}

//
// Contract Account
//

// @dev We are using a storage var, so that we can set custom nonces
// whilst still being able to increment them during the create execution.
@storage_var
func mock_nonce() -> (nonce: felt) {
}

// @notice the current nonce of the mocked contract account
@view
func get_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (nonce: felt) {
    return mock_nonce.read();
}

// @notice This function increases the account nonce by 1
@external
func increment_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (current_nonce: felt) = mock_nonce.read();
    mock_nonce.write(current_nonce + 1);
    return ();
}

// ///////////////////
//    Test Cases    //
// ///////////////////

@external
func test__exec_return_should_return_context_with_updated_return_data{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(return_data: felt) {
    // Given
    alloc_locals;
    let bytecode: felt* = alloc();
    let stack: model.Stack* = Stack.init();

    // When
    let stack: model.Stack* = Stack.push_uint128(stack, return_data);
    let stack: model.Stack* = Stack.push_uint128(stack, 0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);
    let ctx: model.ExecutionContext* = MemoryOperations.exec_mstore(ctx);

    // Then
    let stack: model.Stack* = Stack.push_uint128(ctx.stack, 32);
    let stack: model.Stack* = Stack.push_uint128(stack, 0);
    let ctx: model.ExecutionContext* = ExecutionContext.update_stack(ctx, stack);
    let ctx: model.ExecutionContext* = SystemOperations.exec_return(ctx);

    // Then
    let returned_data = Helpers.load_word(32, ctx.return_data);
    assert return_data = returned_data;

    return ();
}

@external
func test__exec_revert{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(reason_low: felt, reason_high: felt, size: felt) -> (
    revert_reason_len: felt, revert_reason: felt*
) {
    // Given
    alloc_locals;
    tempvar reason_uint256 = new Uint256(low=reason_low, high=reason_high);
    tempvar offset = new Uint256(32, 0);

    let (bytecode) = alloc();
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, reason_uint256);  // value
    let stack: model.Stack* = Stack.push(stack, offset);  // offset
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);
    let ctx: model.ExecutionContext* = MemoryOperations.exec_mstore(ctx);

    let stack: model.Stack* = Stack.push_uint128(ctx.stack, size);  // size
    let stack: model.Stack* = Stack.push_uint128(stack, 0);  // offset is 0 to have the reason at 0x20

    let ctx: model.ExecutionContext* = ExecutionContext.update_stack(ctx, stack);

    // When
    let ctx = SystemOperations.exec_revert(ctx);
    let is_reverted = ExecutionContext.is_reverted(ctx);

    // Then
    assert is_reverted = 1;
    assert ctx.return_data_len = size;
    return (ctx.return_data_len, ctx.return_data);
}

@external
func test__exec_call__should_return_a_new_context_based_on_calling_ctx_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Deploy two empty contract
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (caller_evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (caller_starknet_contract_address) = Account.deploy(
        contract_account_class_hash_, caller_evm_contract_address
    );
    let (callee_evm_contract_address) = CreateHelper.get_create_address(1, 0);
    let (callee_starknet_contract_address) = Account.deploy(
        contract_account_class_hash_, callee_evm_contract_address
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(callee_evm_contract_address);
    tempvar address = new Uint256(address_low, address_high);
    tempvar value = new Uint256(2, 0);
    tempvar args_offset = new Uint256(3, 0);
    tempvar args_size = new Uint256(4, 0);
    tempvar ret_offset = new Uint256(5, 0);
    tempvar ret_size = new Uint256(6, 0);
    let stack = Stack.push(stack, ret_size);
    let stack = Stack.push(stack, ret_offset);
    let stack = Stack.push(stack, args_size);
    let stack = Stack.push(stack, args_offset);
    let stack = Stack.push(stack, value);
    let stack = Stack.push(stack, address);
    let stack = Stack.push(stack, gas);
    // Put some value in memory as it is used for calldata with args_size and args_offset
    // Word is 0x 11 22 33 44 55 66 77 88 00 00 ... 00
    // calldata should be 0x 44 55 66 77
    tempvar memory_word = new Uint256(low=0, high=0x11223344556677880000000000000000);
    tempvar memory_offset = new Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let (bytecode) = alloc();
    let ctx = TestHelpers.init_context_at_address_with_stack(
        caller_starknet_contract_address, caller_evm_contract_address, 0, bytecode, stack
    );
    let ctx = MemoryOperations.exec_mstore(ctx);

    // When
    let sub_ctx = SystemOperations.exec_call(ctx);

    // Then

    // assert than sub_context is well initialized
    assert sub_ctx.call_context.bytecode_len = 0;
    assert sub_ctx.call_context.calldata_len = 4;
    assert [sub_ctx.call_context.calldata] = 0x44;
    assert [sub_ctx.call_context.calldata + 1] = 0x55;
    assert [sub_ctx.call_context.calldata + 2] = 0x66;
    assert [sub_ctx.call_context.calldata + 3] = 0x77;
    assert sub_ctx.call_context.value = value.low;
    assert sub_ctx.program_counter = 0;
    assert sub_ctx.stopped = 0;
    assert sub_ctx.return_data_len = 0;
    assert sub_ctx.gas_used = 0;
    assert sub_ctx.call_context.gas_price = 0;
    assert sub_ctx.call_context.address.starknet = callee_starknet_contract_address;
    assert sub_ctx.call_context.address.evm = callee_evm_contract_address;
    TestHelpers.assert_execution_context_equal(sub_ctx.call_context.calling_context, ctx);

    // Fake a RETURN in sub_ctx then teardow, see note in evm.codes:
    // If the size of the return data is not known, it can also be retrieved after the call with
    // the instructions RETURNDATASIZE and RETURNDATACOPY (since the Byzantium fork).
    let (local return_data: felt*) = alloc();
    assert [return_data] = 0x11;
    let sub_ctx = ExecutionContext.stop(sub_ctx, 1, return_data, FALSE);
    let summary = ExecutionContext.finalize(sub_ctx);
    let ctx = CallHelper.finalize_calling_context(summary);

    // Then
    let (stack, success) = Stack.peek(ctx.stack, 0);
    assert success.low = 1;
    let (local loaded_return_data: felt*) = alloc();
    Memory.load_n(ctx.memory, ret_size.low, loaded_return_data, ret_offset.low);
    assert [loaded_return_data] = 0x11;

    return ();
}

@external
func test__exec_call__should_transfer_value{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Deploy two empty contract
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (caller_evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (caller_starknet_contract_address) = Account.deploy(
        contract_account_class_hash_, caller_evm_contract_address
    );
    tempvar caller_address = new model.Address(
        caller_starknet_contract_address, caller_evm_contract_address
    );
    let (callee_evm_contract_address) = CreateHelper.get_create_address(1, 0);
    let (callee_starknet_contract_address) = Account.deploy(
        contract_account_class_hash_, callee_evm_contract_address
    );
    tempvar callee_address = new model.Address(
        callee_starknet_contract_address, callee_evm_contract_address
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(callee_evm_contract_address);
    tempvar address = new Uint256(address_low, address_high);
    tempvar value = new Uint256(2, 0);
    tempvar args_offset = new Uint256(3, 0);
    tempvar args_size = new Uint256(4, 0);
    tempvar ret_offset = new Uint256(5, 0);
    tempvar ret_size = new Uint256(6, 0);
    let stack = Stack.push(stack, ret_size);
    let stack = Stack.push(stack, ret_offset);
    let stack = Stack.push(stack, args_size);
    let stack = Stack.push(stack, args_offset);
    let stack = Stack.push(stack, value);
    let stack = Stack.push(stack, address);
    let stack = Stack.push(stack, gas);
    tempvar memory_word = new Uint256(low=0, high=22774453838368691922685013100469420032);
    tempvar memory_offset = new Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let (bytecode) = alloc();
    local bytecode_len = 0;
    let ctx = TestHelpers.init_context_at_address_with_stack(
        caller_starknet_contract_address, caller_evm_contract_address, bytecode_len, bytecode, stack
    );
    let ctx = MemoryOperations.exec_mstore(ctx);
    // Get the balance of caller pre-call
    let (state, caller_balance_prev) = State.read_balance(ctx.state, caller_address);
    let ctx = ExecutionContext.update_state(ctx, state);

    // When
    let sub_ctx = SystemOperations.exec_call(ctx);

    // Then
    // get balances of caller and callee post-call
    let state = sub_ctx.state;
    let (state, callee_balance) = State.read_balance(state, callee_address);
    let (state, caller_balance_new) = State.read_balance(state, caller_address);
    let (caller_diff_balance) = uint256_sub(caller_balance_prev, caller_balance_new);

    assert callee_balance = Uint256(2, 0);
    assert caller_diff_balance = Uint256(2, 0);
    return ();
}

@external
func test__exec_callcode__should_return_a_new_context_based_on_calling_ctx_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Deploy two empty contract
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (caller_evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (caller_starknet_contract_address) = Account.deploy(
        contract_account_class_hash_, caller_evm_contract_address
    );
    let (callee_evm_contract_address) = CreateHelper.get_create_address(1, 0);
    let (_) = Account.deploy(contract_account_class_hash_, callee_evm_contract_address);

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(callee_evm_contract_address);
    tempvar address = new Uint256(address_low, address_high);
    tempvar value = new Uint256(2, 0);
    tempvar args_offset = new Uint256(3, 0);
    tempvar args_size = new Uint256(4, 0);
    tempvar ret_offset = new Uint256(5, 0);
    tempvar ret_size = new Uint256(6, 0);
    let stack = Stack.push(stack, ret_size);
    let stack = Stack.push(stack, ret_offset);
    let stack = Stack.push(stack, args_size);
    let stack = Stack.push(stack, args_offset);
    let stack = Stack.push(stack, value);
    let stack = Stack.push(stack, address);
    let stack = Stack.push(stack, gas);
    // Put some value in memory as it is used for calldata with args_size and args_offset
    // Word is 0x 11 22 33 44 55 66 77 88 00 00 ... 00
    // calldata should be 0x 44 55 66 77
    tempvar memory_word = new Uint256(low=0, high=22774453838368691922685013100469420032);
    tempvar memory_offset = new Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let (bytecode) = alloc();
    local bytecode_len = 0;
    let ctx = TestHelpers.init_context_at_address_with_stack(
        caller_starknet_contract_address, caller_evm_contract_address, bytecode_len, bytecode, stack
    );
    let ctx = MemoryOperations.exec_mstore(ctx);

    // When
    let sub_ctx = SystemOperations.exec_callcode(ctx);

    // Then
    assert sub_ctx.call_context.bytecode_len = 0;
    assert sub_ctx.call_context.calldata_len = 4;
    assert [sub_ctx.call_context.calldata] = 0x44;
    assert [sub_ctx.call_context.calldata + 1] = 0x55;
    assert [sub_ctx.call_context.calldata + 2] = 0x66;
    assert [sub_ctx.call_context.calldata + 3] = 0x77;
    assert sub_ctx.call_context.value = value.low;
    assert sub_ctx.program_counter = 0;
    assert sub_ctx.stopped = 0;
    assert sub_ctx.gas_used = 0;
    assert sub_ctx.call_context.gas_price = 0;
    assert sub_ctx.call_context.address.starknet = caller_starknet_contract_address;
    assert sub_ctx.call_context.address.evm = caller_evm_contract_address;
    TestHelpers.assert_execution_context_equal(sub_ctx.call_context.calling_context, ctx);

    // Fake a RETURN in sub_ctx then teardow, see note in evm.codes:
    // If the size of the return data is not known, it can also be retrieved after the call with
    // the instructions RETURNDATASIZE and RETURNDATACOPY (since the Byzantium fork).
    // So it's expected that the RETURN of the sub_ctx does set proper values for return_data_len and return_data
    let sub_ctx = ExecutionContext.stop(sub_ctx, 0, sub_ctx.return_data, FALSE);
    let summary = ExecutionContext.finalize(sub_ctx);
    let ctx = CallHelper.finalize_calling_context(summary);

    // Then
    let (stack, success) = Stack.peek(ctx.stack, 0);
    assert success.low = 1;

    return ();
}

@external
func test__exec_callcode__should_transfer_value{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Deploy two empty contract
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (caller_evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (caller_starknet_contract_address) = Account.deploy(
        contract_account_class_hash_, caller_evm_contract_address
    );
    tempvar caller_address = new model.Address(
        caller_starknet_contract_address, caller_evm_contract_address
    );
    let (callee_evm_contract_address) = CreateHelper.get_create_address(1, 0);
    let (callee_starknet_contract_address) = Account.deploy(
        contract_account_class_hash_, callee_evm_contract_address
    );
    tempvar callee_address = new model.Address(
        callee_starknet_contract_address, callee_evm_contract_address
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(callee_evm_contract_address);
    tempvar address = new Uint256(address_low, address_high);
    tempvar value = new Uint256(2, 0);
    tempvar args_offset = new Uint256(3, 0);
    tempvar args_size = new Uint256(4, 0);
    tempvar ret_offset = new Uint256(5, 0);
    tempvar ret_size = new Uint256(6, 0);
    let stack = Stack.push(stack, ret_size);
    let stack = Stack.push(stack, ret_offset);
    let stack = Stack.push(stack, args_size);
    let stack = Stack.push(stack, args_offset);
    let stack = Stack.push(stack, value);
    let stack = Stack.push(stack, address);
    let stack = Stack.push(stack, gas);
    tempvar memory_word = new Uint256(low=0, high=22774453838368691922685013100469420032);
    tempvar memory_offset = new Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let (bytecode) = alloc();
    local bytecode_len = 0;
    let ctx = TestHelpers.init_context_at_address_with_stack(
        caller_starknet_contract_address, caller_evm_contract_address, bytecode_len, bytecode, stack
    );
    let ctx = MemoryOperations.exec_mstore(ctx);

    // Get the balance of caller pre-call
    let (state, caller_pre_balance) = State.read_balance(ctx.state, caller_address);
    let ctx = ExecutionContext.update_state(ctx, state);

    // When
    let sub_ctx = SystemOperations.exec_callcode(ctx);

    // Then
    // get balances of caller and callee post-call
    let state = sub_ctx.state;
    let (state, caller_post_balance) = State.read_balance(state, caller_address);
    let (state, callee_balance) = State.read_balance(state, callee_address);
    let (caller_diff_balance) = uint256_sub(caller_pre_balance, caller_post_balance);

    assert caller_post_balance = caller_pre_balance;
    return ();
}

@external
func test__exec_staticcall__should_return_a_new_context_based_on_calling_ctx_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Deploy another contract
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Account.deploy(
        contract_account_class_hash_, evm_contract_address
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(evm_contract_address);
    tempvar address = new Uint256(address_low, address_high);
    tempvar args_offset = new Uint256(3, 0);
    tempvar args_size = new Uint256(4, 0);
    tempvar ret_offset = new Uint256(5, 0);
    tempvar ret_size = new Uint256(6, 0);
    let stack = Stack.push(stack, ret_size);
    let stack = Stack.push(stack, ret_offset);
    let stack = Stack.push(stack, args_size);
    let stack = Stack.push(stack, args_offset);
    let stack = Stack.push(stack, address);
    let stack = Stack.push(stack, gas);
    // Put some value in memory as it is used for calldata with args_size and args_offset
    // Word is 0x 11 22 33 44 55 66 77 88 00 00 ... 00
    // calldata should be 0x 44 55 66 77
    tempvar memory_word = new Uint256(low=0, high=22774453838368691922685013100469420032);
    tempvar memory_offset = new Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let (bytecode) = alloc();
    local bytecode_len = 0;
    let ctx = TestHelpers.init_context_with_stack(bytecode_len, bytecode, stack);
    let ctx = MemoryOperations.exec_mstore(ctx);

    // When
    let sub_ctx = SystemOperations.exec_staticcall(ctx);

    // Then
    assert sub_ctx.call_context.bytecode_len = 0;
    assert sub_ctx.call_context.calldata_len = 4;
    assert [sub_ctx.call_context.calldata] = 0x44;
    assert [sub_ctx.call_context.calldata + 1] = 0x55;
    assert [sub_ctx.call_context.calldata + 2] = 0x66;
    assert [sub_ctx.call_context.calldata + 3] = 0x77;
    assert sub_ctx.call_context.value = 0;
    assert sub_ctx.program_counter = 0;
    assert sub_ctx.stopped = 0;
    assert sub_ctx.gas_used = 0;
    assert sub_ctx.call_context.gas_price = 0;
    assert sub_ctx.call_context.address.starknet = starknet_contract_address;
    assert sub_ctx.call_context.address.evm = evm_contract_address;
    TestHelpers.assert_execution_context_equal(sub_ctx.call_context.calling_context, ctx);

    // Fake a RETURN in sub_ctx then teardow, see note in evm.codes:
    // If the size of the return data is not known, it can also be retrieved after the call with
    // the instructions RETURNDATASIZE and RETURNDATACOPY (since the Byzantium fork).
    // So it's expected that the RETURN of the sub_ctx does set proper values for return_data_len and return_data
    let sub_ctx = ExecutionContext.stop(sub_ctx, 0, sub_ctx.return_data, FALSE);
    let summary = ExecutionContext.finalize(sub_ctx);
    let ctx = CallHelper.finalize_calling_context(summary);

    // Then
    let (stack, success) = Stack.peek(ctx.stack, 0);
    assert success.low = 1;

    return ();
}

@external
func test__exec_delegatecall__should_return_a_new_context_based_on_calling_ctx_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Deploy another contract
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Account.deploy(
        contract_account_class_hash_, evm_contract_address
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(evm_contract_address);
    tempvar address = new Uint256(address_low, address_high);
    tempvar args_offset = new Uint256(3, 0);
    tempvar args_size = new Uint256(4, 0);
    tempvar ret_offset = new Uint256(5, 0);
    tempvar ret_size = new Uint256(6, 0);
    let stack = Stack.push(stack, ret_size);
    let stack = Stack.push(stack, ret_offset);
    let stack = Stack.push(stack, args_size);
    let stack = Stack.push(stack, args_offset);
    let stack = Stack.push(stack, address);
    let stack = Stack.push(stack, gas);
    // Put some value in memory as it is used for calldata with args_size and args_offset
    // Word is 0x 11 22 33 44 55 66 77 88 00 00 ... 00
    // calldata should be 0x 44 55 66 77
    tempvar memory_word = new Uint256(low=0, high=22774453838368691922685013100469420032);
    tempvar memory_offset = new Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let (bytecode) = alloc();
    local bytecode_len = 0;
    let ctx = TestHelpers.init_context_with_stack(bytecode_len, bytecode, stack);
    let ctx = MemoryOperations.exec_mstore(ctx);

    // When
    let sub_ctx = SystemOperations.exec_delegatecall(ctx);

    // Then
    assert sub_ctx.call_context.bytecode_len = 0;
    assert sub_ctx.call_context.calldata_len = 4;
    assert [sub_ctx.call_context.calldata] = 0x44;
    assert [sub_ctx.call_context.calldata + 1] = 0x55;
    assert [sub_ctx.call_context.calldata + 2] = 0x66;
    assert [sub_ctx.call_context.calldata + 3] = 0x77;
    assert sub_ctx.call_context.value = 0;
    assert sub_ctx.program_counter = 0;
    assert sub_ctx.stopped = 0;
    assert sub_ctx.gas_used = 0;
    assert sub_ctx.call_context.gas_price = 0;
    assert sub_ctx.call_context.address.starknet = ctx.call_context.address.starknet;
    assert sub_ctx.call_context.address.evm = ctx.call_context.address.evm;
    TestHelpers.assert_execution_context_equal(sub_ctx.call_context.calling_context, ctx);

    // Fake a RETURN in sub_ctx then teardow, see note in evm.codes:
    // If the size of the return data is not known, it can also be retrieved after the call with
    // the instructions RETURNDATASIZE and RETURNDATACOPY (since the Byzantium fork).
    // So it's expected that the RETURN of the sub_ctx does set proper values for return_data_len and return_data
    let sub_ctx = ExecutionContext.stop(sub_ctx, 0, sub_ctx.return_data, FALSE);
    let summary = ExecutionContext.finalize(sub_ctx);
    let ctx = CallHelper.finalize_calling_context(summary);

    // Then
    let (stack, success) = Stack.peek(ctx.stack, 0);
    assert success.low = 1;

    return ();
}

@external
func test__exec_create__should_return_a_new_context_with_bytecode_from_memory_at_expected_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(evm_caller_address: felt, nonce_: felt, expected_create_address: felt) {
    alloc_locals;

    // Fill the stack with exec_create args
    let stack: model.Stack* = Stack.init();
    tempvar value = new Uint256(1, 0);
    tempvar offset = new Uint256(3, 0);
    tempvar size = new Uint256(4, 0);
    let stack = Stack.push(stack, size);
    let stack = Stack.push(stack, offset);
    let stack = Stack.push(stack, value);

    // Put some value in memory as it is used for bytecode with size and offset
    // Word is 0x 11 22 33 44 55 66 77 88 00 00 ... 00
    // bytecode should be 0x 44 55 66 77
    tempvar memory_word = new Uint256(low=0, high=0x11223344556677880000000000000000);
    tempvar memory_offset = new Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let bytecode_len = 0;
    let (bytecode: felt*) = alloc();
    // As this test contract is mocking the contract account we have to set this contract address as the starknet_contract_address.
    let (contract_address: felt) = get_contract_address();
    let ctx = TestHelpers.init_context_at_address_with_stack(
        contract_address, evm_caller_address, bytecode_len, bytecode, stack
    );

    let ctx = MemoryOperations.exec_mstore(ctx);

    // We set the nonce of the mocked contract account
    mock_nonce.write(nonce_);

    // When
    let sub_ctx = SystemOperations.exec_create(ctx);

    // Then
    assert sub_ctx.call_context.bytecode_len = 4;
    assert sub_ctx.call_context.calldata_len = 0;
    assert [sub_ctx.call_context.bytecode] = 0x44;
    assert [sub_ctx.call_context.bytecode + 1] = 0x55;
    assert [sub_ctx.call_context.bytecode + 2] = 0x66;
    assert [sub_ctx.call_context.bytecode + 3] = 0x77;
    assert sub_ctx.call_context.value = value.low;
    assert sub_ctx.program_counter = 0;
    assert sub_ctx.stopped = 0;
    assert sub_ctx.return_data_len = 0;
    assert sub_ctx.gas_used = 0;
    assert sub_ctx.call_context.gas_limit = ctx.call_context.gas_limit;
    assert sub_ctx.call_context.gas_price = ctx.call_context.gas_price;
    assert_not_zero(sub_ctx.call_context.address.starknet);
    assert_not_zero(sub_ctx.call_context.address.evm);
    TestHelpers.assert_execution_context_equal(ctx, sub_ctx.call_context.calling_context);

    // Fake a RETURN in sub_ctx then finalize
    let return_data_len = 65;
    TestHelpers.array_fill(sub_ctx.return_data, return_data_len, 0xff);
    let sub_ctx = ExecutionContext.stop(sub_ctx, return_data_len, sub_ctx.return_data, FALSE);
    let summary = ExecutionContext.finalize(sub_ctx);
    let ctx = CreateHelper.finalize_calling_context(summary);

    // Then
    let (stack, address) = Stack.peek(ctx.stack, 0);
    let evm_contract_address = Helpers.uint256_to_felt([address]);
    assert evm_contract_address = sub_ctx.call_context.address.evm;
    assert sub_ctx.call_context.address.evm = expected_create_address;
    let (state, account) = State.get_account(ctx.state, sub_ctx.call_context.address);
    TestHelpers.assert_array_equal(
        account.code_len, account.code, return_data_len, sub_ctx.return_data
    );

    return ();
}

@external
func test__get_create_address_should_construct_address_deterministically{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(evm_caller_address: felt, nonce: felt, expected_create_address: felt) {
    let (evm_contract_address) = CreateHelper.get_create_address(evm_caller_address, nonce);

    assert evm_contract_address = expected_create_address;

    return ();
}

@external
func test__exec_create2__should_return_a_new_context_with_bytecode_from_memory_at_expected_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    evm_caller_address: felt,
    bytecode_offset: felt,
    bytecode_size: felt,
    nonce: felt,
    memory_word: Uint256,
    expected_create2_address: felt,
) {
    alloc_locals;

    // Fill the stack with exec_create2 args
    let stack: model.Stack* = Stack.init();
    tempvar value = new Uint256(1, 0);
    let stack = Stack.push_uint128(stack, nonce);
    let stack = Stack.push_uint128(stack, bytecode_size);
    let stack = Stack.push_uint128(stack, bytecode_offset);
    let stack = Stack.push(stack, value);

    // Put some value in memory as it is used for byte
    tempvar word = new Uint256(memory_word.low, memory_word.high);
    tempvar memory_offset = new Uint256(0, 0);
    let stack = Stack.push(stack, word);
    let stack = Stack.push(stack, memory_offset);
    let bytecode_len = 0;
    let (bytecode: felt*) = alloc();
    let (contract_address: felt) = get_contract_address();
    let ctx = TestHelpers.init_context_at_address_with_stack(
        contract_address, evm_caller_address, bytecode_len, bytecode, stack
    );

    assert ctx.call_context.address.evm = evm_caller_address;
    let ctx = MemoryOperations.exec_mstore(ctx);

    // When
    let sub_ctx = SystemOperations.exec_create2(ctx);

    // Then
    assert sub_ctx.call_context.bytecode_len = 4;
    assert sub_ctx.call_context.calldata_len = 0;
    assert [sub_ctx.call_context.bytecode] = 0x44;
    assert [sub_ctx.call_context.bytecode + 1] = 0x55;
    assert [sub_ctx.call_context.bytecode + 2] = 0x66;
    assert [sub_ctx.call_context.bytecode + 3] = 0x77;
    assert sub_ctx.call_context.value = value.low;
    assert sub_ctx.program_counter = 0;
    assert sub_ctx.stopped = 0;
    assert sub_ctx.return_data_len = 0;
    assert sub_ctx.gas_used = 0;
    assert sub_ctx.call_context.gas_limit = ctx.call_context.gas_limit;
    assert sub_ctx.call_context.gas_price = ctx.call_context.gas_price;
    assert_not_zero(sub_ctx.call_context.address.starknet);
    assert_not_zero(sub_ctx.call_context.address.evm);
    TestHelpers.assert_execution_context_equal(ctx, sub_ctx.call_context.calling_context);

    // Fake a RETURN in sub_ctx then finalize
    let return_data_len = 65;
    TestHelpers.array_fill(sub_ctx.return_data, return_data_len, 0xff);
    let sub_ctx = ExecutionContext.stop(sub_ctx, return_data_len, sub_ctx.return_data, FALSE);
    let summary = ExecutionContext.finalize(sub_ctx);
    let ctx = CreateHelper.finalize_calling_context(summary);

    // Then
    let (stack, address) = Stack.peek(ctx.stack, 0);
    let evm_contract_address = Helpers.uint256_to_felt([address]);
    assert evm_contract_address = sub_ctx.call_context.address.evm;
    assert sub_ctx.call_context.address.evm = expected_create2_address;
    let state = ctx.state;
    let (state, account) = State.get_account(state, sub_ctx.call_context.address);
    TestHelpers.assert_array_equal(
        account.code_len, account.code, return_data_len, sub_ctx.return_data
    );

    return ();
}
