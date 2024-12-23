// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import (
    uint256_and,
    uint256_lt,
    uint256_mul,
    uint256_not,
    uint256_or,
    uint256_shl,
    uint256_xor,
    Uint256,
    SHIFT,
    ALL_ONES,
)

from kakarot.constants import Constants, opcodes_label
from kakarot.model import model
from kakarot.evm import EVM
from kakarot.stack import Stack
from kakarot.gas import Gas
from kakarot.state import State
from kakarot.errors import Errors
from utils.uint256 import (
    uint256_fast_exp,
    uint256_signextend,
    uint256_sub,
    uint256_add,
    uint256_unsigned_div_rem,
    uint256_mul_div_mod,
    uint256_signed_lt,
    uint256_shr,
    uint256_signed_div_rem,
    uint256_eq,
)
from utils.utils import Helpers

// @title Stop and Math operations opcodes.
// @notice Math operations gathers Arithmetic and Comparison operations
namespace StopAndMathOperations {
    func exec_stop{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        // return_data stored the return_data for the last executed sub context
        // see CALLs opcodes. When we run the STOP opcode, we stop the current
        // execution context with *no* return data (unlike RETURN and REVERT).
        // hence we just clear the return_data and stop.
        let (return_data: felt*) = alloc();
        let evm = EVM.stop(evm, 0, return_data, FALSE);
        return evm;
    }

    func exec_math_operation{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        local opcode: model.Opcode*;

        // See evm.cairo, pc is increased before entering the opcode
        let opcode_number = [evm.message.bytecode + evm.program_counter];

        // To cast the codeoffset opcodes_label to a model.Opcode*, we need to use it to offset
        // the current pc. We get the pc from the `get_fp_and_pc` util and assign a codeoffset (pc_label) to it.
        // In short, this boils down to: opcode = pc + offset - pc = offset
        let (_, pc) = get_fp_and_pc();

        pc_label:
        assert opcode = cast(
            pc + (opcodes_label - pc_label) + opcode_number * model.Opcode.SIZE, model.Opcode*
        );

        let (popped) = Stack.pop_n(opcode.stack_input);
        local stack: model.Stack* = stack;

        // offset is 1 (new line) + 2 (jmp + label) per opcode
        // opcode is offset by 0x1 (index of the first opcode)
        tempvar offset = 2 * (opcode_number - 0x01) + 1;

        tempvar range_check_ptr = range_check_ptr;
        tempvar popped = popped;

        jmp rel offset;

        jmp ADD;  // 0x1
        jmp MUL;  // 0x2
        jmp SUB;  // 0x3
        jmp DIV;  // 0x4
        jmp SDIV;  // 0x5
        jmp MOD;  // 0x6
        jmp SMOD;  // 0x7
        jmp ADDMOD;  // 0x8
        jmp MULMOD;  // 0x9
        jmp EXP;  // 0xa
        jmp SIGNEXTEND;  // 0xb
        jmp INVALID;  // 0xc
        jmp INVALID;  // 0xd
        jmp INVALID;  // 0xe
        jmp INVALID;  // 0xf
        jmp LT;  // 0x10
        jmp GT;  // 0x11
        jmp SLT;  // 0x12
        jmp SGT;  // 0x13
        jmp EQ;  // 0x14
        jmp ISZERO;  // 0x15
        jmp AND;  // 0x16
        jmp OR;  // 0x17
        jmp XOR;  // 0x18
        jmp NOT;  // 0x19
        jmp BYTE;  // 0x1a
        jmp SHL;  // 0x1b
        jmp SHR;  // 0x1c
        jmp SAR;  // 0x1d

        end:
        // Parse results
        // All the jumps share the same return signature, which is bitwise_ptr
        // and range_check_ptr in implicit args and a Uint256 for the value
        let bitwise_ptr = cast([ap - 4], BitwiseBuiltin*);
        let range_check_ptr = [ap - 3];
        let result = Uint256([ap - 2], [ap - 1]);

        // Rebind args with fp
        // Function args are in [fp - n - 2: fp - 2]
        // locals are retrieved from [fp] in the order they are defined
        let syscall_ptr = cast([fp - 10], felt*);
        let pedersen_ptr = cast([fp - 9], HashBuiltin*);
        let memory = cast([fp - 5], model.Memory*);
        let state = cast([fp - 4], model.State*);
        let evm = cast([fp - 3], model.EVM*);
        let stack = cast([fp + 1], model.Stack*);

        // Finalize opcode
        Stack.push_uint256(result);
        return evm;

        ADD:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (result, _) = uint256_add(popped[0], popped[1]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(result.low, result.high);
        jmp end;

        MUL:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (result, _) = uint256_mul(popped[0], popped[1]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(result.low, result.high);
        jmp end;

        SUB:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (result) = uint256_sub(popped[0], popped[1]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(result.low, result.high);
        jmp end;

        DIV:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (quotient, _) = uint256_unsigned_div_rem(popped[0], popped[1]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(quotient.low, quotient.high);
        jmp end;

        SDIV:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (quotient, _) = uint256_signed_div_rem(popped[0], popped[1]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(quotient.low, quotient.high);
        jmp end;

        MOD:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (_, remainder) = uint256_unsigned_div_rem(popped[0], popped[1]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(remainder.low, remainder.high);
        jmp end;

        SMOD:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (_, remainder) = uint256_signed_div_rem(popped[0], popped[1]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(remainder.low, remainder.high);
        jmp end;

        ADDMOD:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        tempvar mod_is_not_zero = popped[2].low + popped[2].high;
        jmp addmod_not_zero if mod_is_not_zero != 0;

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(0, 0);
        jmp end;

        addmod_not_zero:
        // (a + b) mod n  = (a mod n + b mod n) mod n
        let (_, x) = uint256_unsigned_div_rem(popped[0], popped[2]);
        let (_, y) = uint256_unsigned_div_rem(popped[1], popped[2]);
        // x, y in range [0, n-1] thus:
        // if x + y < n then x + y mod n = x + y
        // if x + y >= n then x + y mod n = x + y - n
        let (sum, carry) = uint256_add(x, y);

        if (carry != 0) {
            // result = (2**256) - (n - overflown_sum)
            // <=> result = (2**256 - 1) - (n - overflown_sum - 1)
            // as n > overflown_sum we can't have an underflow
            let max_u256 = Uint256(ALL_ONES, ALL_ONES);
            let (overflown_part) = uint256_sub(popped[2], sum);
            let (to_remove) = uint256_sub(overflown_part, Uint256(1, 0));
            let (result) = uint256_sub(max_u256, to_remove);
            tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
            tempvar range_check_ptr = range_check_ptr;
            tempvar result = result;
            jmp end;
        }

        let (is_sum_lt_n) = uint256_lt(sum, popped[2]);
        if (is_sum_lt_n != 0) {
            tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
            tempvar range_check_ptr = range_check_ptr;
            tempvar result = sum;
            jmp end;
        }

        let (result) = uint256_sub(sum, popped[2]);
        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = result;
        jmp end;

        MULMOD:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        tempvar mod_is_not_zero = popped[2].low + popped[2].high;
        jmp mulmod_not_zero if mod_is_not_zero != 0;

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(0, 0);
        jmp end;

        mulmod_not_zero:
        let (_, _, result) = uint256_mul_div_mod(popped[0], popped[1], popped[2]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(result.low, result.high);
        jmp end;

        EXP:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);
        let exponent = popped[1];

        // Gas
        local bytes_used: felt;
        if (exponent.high == 0) {
            let bytes_used_low = Helpers.bytes_used_128(exponent.low);
            assert bytes_used = bytes_used_low;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            let bytes_used_high = Helpers.bytes_used_128(exponent.high);
            assert bytes_used = bytes_used_high + 16;
            tempvar range_check_ptr = range_check_ptr;
        }
        let range_check_ptr = [ap - 1];

        let syscall_ptr = cast([fp - 10], felt*);
        let pedersen_ptr = cast([fp - 9], HashBuiltin*);
        let bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        let memory = cast([fp - 5], model.Memory*);
        let state = cast([fp - 4], model.State*);
        let evm = cast([fp - 3], model.EVM*);
        let stack = cast([fp + 1], model.Stack*);

        let evm = EVM.charge_gas(evm, Gas.EXPONENTIATION_PER_BYTE * bytes_used);
        if (evm.reverted != FALSE) {
            return evm;
        }

        let result = uint256_fast_exp(popped[0], exponent);

        Stack.push_uint256(result);
        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        return evm;

        SIGNEXTEND:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let result = uint256_signextend(popped[1], popped[0]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = result;
        jmp end;

        INVALID:
        let range_check_ptr = [ap - 2];
        // Rebind args with fp
        // Function args are in [fp - n - 2: fp - 2]
        // locals are retrieved from [fp] in the order they are defined
        let syscall_ptr = cast([fp - 10], felt*);
        let pedersen_ptr = cast([fp - 9], HashBuiltin*);
        let bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        let memory = cast([fp - 5], model.Memory*);
        let state = cast([fp - 4], model.State*);
        let evm = cast([fp - 3], model.EVM*);
        let stack = cast([fp + 1], model.Stack*);

        let (revert_reason_len, revert_reason) = Errors.unknownOpcode();
        let evm = EVM.stop(evm, revert_reason_len, revert_reason, Errors.EXCEPTIONAL_HALT);
        return evm;

        LT:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (res) = uint256_lt(popped[0], popped[1]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(res, 0);
        jmp end;

        GT:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (res) = uint256_lt(popped[1], popped[0]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(res, 0);
        jmp end;

        SLT:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (res) = uint256_signed_lt(popped[0], popped[1]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(res, 0);
        jmp end;

        SGT:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (res) = uint256_signed_lt(popped[1], popped[0]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(res, 0);
        jmp end;

        EQ:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (res) = uint256_eq(popped[0], popped[1]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(res, 0);
        jmp end;

        ISZERO:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (res) = uint256_eq(popped[0], Uint256(0, 0));

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(res, 0);
        jmp end;

        AND:
        let bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (result) = uint256_and(popped[0], popped[1]);

        tempvar bitwise_ptr = bitwise_ptr;
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(result.low, result.high);
        jmp end;

        OR:
        let bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (result) = uint256_or(popped[0], popped[1]);

        tempvar bitwise_ptr = bitwise_ptr;
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(result.low, result.high);
        jmp end;

        XOR:
        let bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (result) = uint256_xor(popped[0], popped[1]);

        tempvar bitwise_ptr = bitwise_ptr;
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(result.low, result.high);
        jmp end;

        BYTE:
        let bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        // compute y = (x >> (248 - i * 8)) & 0xFF
        let i = popped[0];
        let (is_inf_32) = uint256_lt(i, Uint256(32, 0));
        jmp byte_i if is_inf_32 != 0;

        tempvar bitwise_ptr = bitwise_ptr;
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(0, 0);
        jmp end;

        // here i < 32 so we can use field ops
        byte_i:
        let right = Uint256(248 - i.low * 8, 0);
        let (shift_right) = uint256_shr(popped[1], right);
        let (result) = uint256_and(shift_right, Uint256(0xFF, 0));

        tempvar bitwise_ptr = bitwise_ptr;
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(result.low, result.high);
        jmp end;

        SHL:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (result) = uint256_shl(popped[1], popped[0]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(result.low, result.high);
        jmp end;

        SHR:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (result) = uint256_shr(popped[1], popped[0]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(result.low, result.high);
        jmp end;

        SAR:
        let bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        // In C, SAR would be something like that (on a 4 bytes int):
        // ```
        // int sign = -((unsigned) x >> 31);
        // int sar = (sign^x) >> n ^ sign;
        // ```
        // This is the cairo adaptation
        let shift = popped[0];
        let value = popped[1];
        // (unsigned) x >> 31 : extract the left-most bit (i.e. the sign).
        let (_sign) = uint256_shr(value, Uint256(255, 0));

        // Declare low and high as tempvar because we can't declare a Uint256 as tempvar.
        tempvar low;
        tempvar high;
        if (_sign.low == 0) {
            // If sign is positive, set it to 0.
            low = 0;
            high = 0;
        } else {
            // If sign is negative, set the number to -1.
            low = Constants.UINT128_MAX;
            high = Constants.UINT128_MAX;
        }

        // Rebuild the `sign` variable from `low` and `high`.
        let sign = Uint256(low, high);

        // `sign ^ x`
        let (step1) = uint256_xor(sign, value);
        // `sign ^ x >> n`
        let (step2) = uint256_shr(step1, shift);
        // `sign & x >> n ^ sign`
        let (result) = uint256_xor(step2, sign);

        tempvar bitwise_ptr = bitwise_ptr;
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(result.low, result.high);
        jmp end;

        NOT:
        let range_check_ptr = [ap - 2];
        let popped = cast([ap - 1], Uint256*);

        let (result) = uint256_not(popped[0]);

        tempvar bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        tempvar range_check_ptr = range_check_ptr;
        tempvar result = Uint256(result.low, result.high);
        jmp end;
    }
}
