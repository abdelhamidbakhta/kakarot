// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.evm import EVM
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.constants import Constants
from tests.utils.helpers import TestHelpers

@external
func test__exec_pc__should_update_after_incrementing{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(increment) {
    // Given
    alloc_locals;

    let (bytecode) = alloc();
    let evm: model.EVM* = TestHelpers.init_context(0, bytecode);
    let evm = EVM.increment_program_counter(evm, increment);

    // When
    let result = MemoryOperations.exec_pc(evm);

    // Then
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = increment;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_pop_should_pop_an_item_from_execution_context{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let evm: model.EVM* = TestHelpers.init_context(0, bytecode);
    // Given
    let stack = Stack.init();

    tempvar item_1 = new Uint256(1, 0);
    tempvar item_0 = new Uint256(2, 0);

    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let evm = EVM.update_stack(evm, stack);

    // When
    let result = MemoryOperations.exec_pop(evm);

    // Then
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert_uint256_eq([index0], Uint256(1, 0));
    return ();
}

@external
func test__exec_mload_should_load_a_value_from_memory{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let evm: model.EVM* = TestHelpers.init_context(0, bytecode);
    // Given
    let stack = Stack.init();

    tempvar item_1 = new Uint256(1, 0);
    tempvar item_0 = new Uint256(0, 0);

    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);

    let evm = EVM.update_stack(evm, stack);
    let evm = MemoryOperations.exec_mstore(evm);

    tempvar item_0 = new Uint256(0, 0);
    let stack = Stack.push(evm.stack, item_0);
    let evm = EVM.update_stack(evm, stack);

    // When
    let result = MemoryOperations.exec_mload(evm);

    // Then
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert_uint256_eq([index0], Uint256(1, 0));
    return ();
}

@external
func test__exec_mload_should_load_a_value_from_memory_with_memory_expansion{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let evm: model.EVM* = TestHelpers.init_context(0, bytecode);
    let test_offset = 16;
    // Given
    let stack = Stack.init();

    tempvar item_1 = new Uint256(1, 0);
    tempvar item_0 = new Uint256(0, 0);

    let stack: model.Stack* = Stack.push(stack, item_1);
    let stack: model.Stack* = Stack.push(stack, item_0);

    let evm = EVM.update_stack(evm, stack);
    let evm = MemoryOperations.exec_mstore(evm);

    tempvar offset = new Uint256(test_offset, 0);
    let stack = Stack.push(evm.stack, offset);
    let evm = EVM.update_stack(evm, stack);

    // When
    let result = MemoryOperations.exec_mload(evm);

    // Then
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert_uint256_eq([index0], Uint256(0, 1));
    assert result.memory.words_len = 2;
    return ();
}

@external
func test__exec_mload_should_load_a_value_from_memory_with_offset_larger_than_msize{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let evm: model.EVM* = TestHelpers.init_context(0, bytecode);
    let test_offset = 684;
    // Given
    let stack = Stack.init();

    tempvar item_1 = new Uint256(1, 0);
    tempvar item_0 = new Uint256(0, 0);

    let stack: model.Stack* = Stack.push(stack, item_1);
    let stack: model.Stack* = Stack.push(stack, item_0);

    let evm = EVM.update_stack(evm, stack);
    let evm = MemoryOperations.exec_mstore(evm);
    tempvar offset = new Uint256(test_offset, 0);
    let stack = Stack.push(evm.stack, offset);
    let evm = EVM.update_stack(evm, stack);

    // When
    let result = MemoryOperations.exec_mload(evm);

    // Then
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert_uint256_eq([index0], Uint256(0, 0));
    assert result.memory.words_len = 23;
    return ();
}
