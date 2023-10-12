// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.evm import EVM
from tests.utils.helpers import TestHelpers

@external
func test__unknown_opcode{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (revert_reason_len: felt, revert_reason: felt*) {
    alloc_locals;
    let (bytecode) = alloc();
    let ctx: model.ExecutionContext* = TestHelpers.init_context(0, bytecode);
    let ctx = EVM.unknown_opcode(ctx);

    return (ctx.return_data_len, ctx.return_data);
}
