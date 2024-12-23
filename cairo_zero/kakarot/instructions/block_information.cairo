// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import split_felt
from starkware.cairo.common.math_cmp import is_in_range
from starkware.cairo.common.uint256 import Uint256

from kakarot.constants import Constants
from kakarot.evm import EVM
from kakarot.interfaces.interfaces import ICairo1Helpers
from kakarot.storages import Kakarot_cairo1_helpers_class_hash
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from utils.utils import Helpers

// @title BlockInformation opcodes.
// @notice This file contains the functions to execute for block information opcodes.
namespace BlockInformation {
    func exec_block_information{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        let opcode_number = [evm.message.bytecode + evm.program_counter];

        tempvar offset = 2 * (opcode_number - 0x40) + 1;

        jmp rel offset;
        jmp blockhash;
        jmp coinbase;
        jmp timestamp;
        jmp number;
        jmp prevrandao;
        jmp gaslimit;
        jmp chainid;
        jmp selfbalance;
        jmp basefee;
        jmp blobhash;
        jmp blobbasefee;

        blockhash:
        let syscall_ptr = cast([fp - 10], felt*);
        let pedersen_ptr = cast([fp - 9], HashBuiltin*);
        let range_check_ptr = [fp - 8];
        let stack = cast([fp - 6], model.Stack*);
        let evm = cast([fp - 3], model.EVM*);
        Internals.blockhash(evm);

        // Rebind unused args with fp
        let bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        let memory = cast([fp - 5], model.Memory*);
        let state = cast([fp - 4], model.State*);
        return evm;

        coinbase:
        let evm = cast([fp - 3], model.EVM*);
        let stack = cast([fp - 6], model.Stack*);
        let range_check_ptr = [fp - 8];
        let (coinbase_high, coinbase_low) = split_felt(evm.message.env.coinbase);
        tempvar coinbase_u256 = Uint256(low=coinbase_low, high=coinbase_high);
        Stack.push_uint256(coinbase_u256);

        // Rebind unused args with fp
        let syscall_ptr = cast([fp - 10], felt*);
        let pedersen_ptr = cast([fp - 9], HashBuiltin*);
        let bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        let memory = cast([fp - 5], model.Memory*);
        let state = cast([fp - 4], model.State*);
        return evm;

        timestamp:
        let evm = cast([fp - 3], model.EVM*);
        let stack = cast([fp - 6], model.Stack*);
        Stack.push_uint128(evm.message.env.block_timestamp);
        jmp end;

        number:
        let evm = cast([fp - 3], model.EVM*);
        let stack = cast([fp - 6], model.Stack*);
        Stack.push_uint128(evm.message.env.block_number);
        jmp end;

        prevrandao:
        let evm = cast([fp - 3], model.EVM*);
        let stack = cast([fp - 6], model.Stack*);
        Stack.push_uint256(evm.message.env.prev_randao);
        jmp end;

        gaslimit:
        let evm = cast([fp - 3], model.EVM*);
        let stack = cast([fp - 6], model.Stack*);
        Stack.push_uint128(evm.message.env.block_gas_limit);
        jmp end;

        chainid:
        let evm = cast([fp - 3], model.EVM*);
        let stack = cast([fp - 6], model.Stack*);
        Stack.push_uint128(evm.message.env.chain_id);
        jmp end;

        selfbalance:
        let syscall_ptr = cast([fp - 10], felt*);
        let pedersen_ptr = cast([fp - 9], HashBuiltin*);
        let range_check_ptr = [fp - 8];
        let stack = cast([fp - 6], model.Stack*);
        let state = cast([fp - 4], model.State*);
        let evm = cast([fp - 3], model.EVM*);
        Internals.selfbalance(evm);

        // Rebind unused args with fp
        let bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        let memory = cast([fp - 5], model.Memory*);
        return evm;

        basefee:
        let evm = cast([fp - 3], model.EVM*);
        let stack = cast([fp - 6], model.Stack*);
        Stack.push_uint128(evm.message.env.base_fee);
        jmp end;

        blobhash:
        let stack = cast([fp - 6], model.Stack*);
        Stack.pop();
        Stack.push_uint128(0);
        jmp end;

        blobbasefee:
        let stack = cast([fp - 6], model.Stack*);
        Stack.push_uint128(Constants.MIN_BASE_FEE_PER_BLOB_GAS);
        jmp end;

        end:
        // Rebind unused args with fp
        let syscall_ptr = cast([fp - 10], felt*);
        let pedersen_ptr = cast([fp - 9], HashBuiltin*);
        let range_check_ptr = [fp - 8];
        let bitwise_ptr = cast([fp - 7], BitwiseBuiltin*);
        let memory = cast([fp - 5], model.Memory*);
        let state = cast([fp - 4], model.State*);
        let evm = cast([fp - 3], model.EVM*);

        // Rebind used args with ap
        let stack = cast([ap - 1], model.Stack*);

        return evm;
    }
}

namespace Internals {
    func blockhash{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, stack: model.Stack*
    }(evm: model.EVM*) {
        let (block_number) = Stack.pop();
        if (block_number.high != 0) {
            Stack.push_uint256(Uint256(0, 0));
            return ();
        }

        let lower_bound = Helpers.saturated_sub(evm.message.env.block_number, 256);
        let in_range = is_in_range(block_number.low, lower_bound, evm.message.env.block_number - 9);

        if (in_range == FALSE) {
            Stack.push_uint256(Uint256(0, 0));
            return ();
        }

        let (implementation) = Kakarot_cairo1_helpers_class_hash.read();
        let (blockhash) = ICairo1Helpers.library_call_get_block_hash(
            implementation, block_number.low
        );
        let (blockhash_high, blockhash_low) = split_felt(blockhash);
        Stack.push_uint256(Uint256(low=blockhash_low, high=blockhash_high));
        return ();
    }

    func selfbalance{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        stack: model.Stack*,
        state: model.State*,
    }(evm: model.EVM*) {
        let account = State.get_account(evm.message.address.evm);
        Stack.push(account.balance);
        return ();
    }
}
