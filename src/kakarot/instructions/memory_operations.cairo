// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_unsigned_div_rem
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.dict import DictAccess, dict_new, dict_read, dict_write
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.math_cmp import is_le

from kakarot.errors import Errors
from kakarot.execution_context import ExecutionContext
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from utils.utils import Helpers
from kakarot.constants import Constants

// @title Exchange operations opcodes.
// @notice This file contains the functions to execute for memory operations opcodes.
// @author @LucasLvy @abdelhamidbakhta
// @custom:namespace MemoryOperations
namespace MemoryOperations {
    const GAS_COST_MLOAD = 3;
    const GAS_COST_MSTORE = 3;
    const GAS_COST_PC = 2;
    const GAS_COST_MSIZE = 2;
    const GAS_COST_JUMP = 8;
    const GAS_COST_JUMPI = 10;
    const GAS_COST_JUMPDEST = 1;
    const GAS_COST_POP = 2;
    const GAS_COST_MSTORE8 = 3;
    const GAS_COST_SSTORE = 100;
    const GAS_COST_SLOAD = 100;
    const GAS_COST_GAS = 2;

    // @notice MLOAD operation
    // @dev Load word from memory and push to stack.
    // @custom:since Frontier
    // @custom:group Stack Memory and Flow operations.
    // @custom:gas 3 + dynamic gas
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_mload{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let fp_and_pc = get_fp_and_pc();
        local __fp__: felt* = fp_and_pc.fp_val;

        if (ctx.stack.size == 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the word we read.
        let (stack, offset) = Stack.pop(stack);

        // Read word from memory at offset
        let (new_memory, local value, cost) = Memory.load(self=ctx.memory, offset=offset.low);

        // Push word to the stack
        let stack: model.Stack* = Stack.push(stack, &value);

        // Update context memory.
        let ctx = ExecutionContext.update_memory(ctx, new_memory);
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_MLOAD + cost);

        return ctx;
    }

    // @notice MSTORE operation
    // @dev Save word to memory.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3 + dynamic gas
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_mstore{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack_underflow = is_le(ctx.stack.size, 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the work we save.
        // 1 - value: value to store in memory.
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let offset = popped[0];
        let value = popped[1];

        let memory: model.Memory* = Memory.store(self=ctx.memory, element=value, offset=offset.low);

        // Update context memory.
        let ctx = ExecutionContext.update_memory(ctx, memory);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_MSTORE);
        return ctx;
    }

    // @notice PC operation
    // @dev Get the value of the program counter prior to the increment.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_produced_elements 1
    // @return ExecutionContext Updated execution context.
    func exec_pc{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        if (ctx.stack.size == Constants.STACK_MAX_DEPTH) {
            let (revert_reason_len, revert_reason) = Errors.stackOverflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack: model.Stack* = Stack.push_uint128(ctx.stack, ctx.program_counter - 1);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_PC);
        return ctx;
    }

    // @notice MSIZE operation
    // @dev Get the value of memory size.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_msize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        if (ctx.stack.size == Constants.STACK_MAX_DEPTH) {
            let (revert_reason_len, revert_reason) = Errors.stackOverflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = Stack.push_uint128(ctx.stack, ctx.memory.bytes_len);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_MSIZE);
        return ctx;
    }

    // @notice JUMP operation
    // @dev The JUMP instruction changes the pc counter. The new pc target has to be a JUMPDEST opcode.
    // @custom:since Frontier
    // @custom:group Stack Memory and Flow operations.
    // @custom:gas 8
    // @custom:stack_consumed_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_jump{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        if (ctx.stack.size == 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: offset in the deployed code where execution will continue from
        let (stack, offset) = Stack.pop(stack);

        let ctx = ExecutionContext.jump(ctx, offset.low);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_JUMP);
        return ctx;
    }

    // @notice JUMPI operation
    // @dev Change the pc counter under a provided certain condition.
    //      The new pc target has to be a JUMPDEST opcode.
    // @custom:since Frontier
    // @custom:group Stack Memory and Flow operations.
    // @custom:gas 10
    // @custom:stack_consumed_elements 2
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_jumpi{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack_underflow = is_le(ctx.stack.size, 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: offset in the deployed code where execution will continue from
        // 1 - skip_condition: condition that will trigger a jump if not FALSE
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let offset = popped[0];
        let skip_condition = popped[1];

        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_JUMPI);

        // If skip_condition is 0, then don't jump
        let (skip_condition_is_zero) = uint256_eq(Uint256(0, 0), skip_condition);
        if (skip_condition_is_zero != FALSE) {
            return ctx;
        }

        let ctx = ExecutionContext.jump(ctx, offset.low);
        return ctx;
    }

    // @notice JUMPDEST operation
    // @dev Serves as a check that JUMP or JUMPI was executed correctly. We only update gas used.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_jumpdest{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_JUMPDEST);

        return ctx;
    }

    // @notice POP operation
    // @dev Pops the first item on the stack (top of the stack).
    // @custom: since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_pop{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        if (ctx.stack.size == 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        // Get stack from context.
        let stack: model.Stack* = ctx.stack;

        let (stack, _) = Stack.pop(stack);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);

        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_POP);
        return ctx;
    }

    // @notice MSTORE8 operation
    // @dev Save single byte to memory
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_mstore8{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack_underflow = is_le(ctx.stack.size, 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the work we save.
        // 1 - value: value from which the last byte will be extracted and stored in memory.
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let offset = popped[0];
        let value = popped[1];

        // Extract last byte from stack value
        let (_, remainder) = uint256_unsigned_div_rem(value, Uint256(256, 0));
        let (value_pointer: felt*) = alloc();
        assert [value_pointer] = remainder.low;

        // Store byte to memory at offset
        let memory: model.Memory* = Memory.store_n(
            self=ctx.memory, element_len=1, element=value_pointer, offset=offset.low
        );

        // Update context memory.
        let ctx = ExecutionContext.update_memory(ctx, memory);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_MSTORE8);
        return ctx;
    }

    // @notice SSTORE operation
    // @dev Save word to storage.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_sstore{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        if (ctx.call_context.read_only != FALSE) {
            let (revert_reason_len, revert_reason) = Errors.stateModificationError();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack_underflow = is_le(ctx.stack.size, 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let (stack, popped) = Stack.pop_n(self=ctx.stack, n=2);

        let key = popped;  // Uint256*
        let value = popped + Uint256.SIZE;  // Uint256*
        let state = State.write_storage(ctx.state, ctx.call_context.address, key, value);
        let ctx = ExecutionContext.update_state(ctx, state);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_SSTORE);
        return ctx;
    }

    // @notice SLOAD operation
    // @dev Load from storage.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_sload{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        if (ctx.stack.size == 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let (stack, key) = Stack.pop(ctx.stack);
        let (state, value) = State.read_storage(ctx.state, ctx.call_context.address, key);
        let stack = Stack.push(stack, value);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.update_state(ctx, state);
        return ctx;
    }

    // @notice GAS operation
    // @dev Get the amount of available gas, including the corresponding reduction for the cost of this instruction.
    // @custom: since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_gas{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        if (ctx.stack.size == Constants.STACK_MAX_DEPTH) {
            let (revert_reason_len, revert_reason) = Errors.stackOverflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        // Get stack from context.
        let stack: model.Stack* = ctx.stack;

        // Compute remaining gas.
        let remaining_gas = ctx.call_context.gas_limit - ctx.gas_used - GAS_COST_GAS;
        let stack: model.Stack* = Stack.push_uint128(ctx.stack, remaining_gas);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);

        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_GAS);
        return ctx;
    }
}
