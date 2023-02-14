// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy

// Internal dependencies
from utils.utils import Helpers
from utils.modexp.modexp_utils import ModExpHelpers

// @title ModExpMVP Precompile related functions.
// @notice This file contains the logic required to run the modexp precompile MVP
// @notice It is an MVP implementation since it only supports uint256 numbers and not bigint.
// @author @dragan2234
// @custom:namespace PrecompileModExpMVP
namespace PrecompileModExpMVP {
    const PRECOMPILE_ADDRESS = 0x05;
    const MOD_EXP_BYTES_LEN = 32;

    // @notice Run the precompile.
    // @param input_len The length of input array.
    // @param input The input array.
    // @return The output length, output array, and gas usage of precompile.
    func run{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(_address: felt, input_len: felt, input: felt*) -> (
        output_len: felt, output: felt*, gas_used: felt
    ) {
        alloc_locals;

        let b_size: Uint256 = Helpers.bytes32_to_uint256(input);
        let e_size: Uint256 = Helpers.bytes32_to_uint256(input + MOD_EXP_BYTES_LEN);
        let m_size: Uint256 = Helpers.bytes32_to_uint256(input + MOD_EXP_BYTES_LEN * 2);
        let b: Uint256 = Helpers.bytes_i_to_uint256(input + MOD_EXP_BYTES_LEN * 3, b_size.low);
        let e: Uint256 = Helpers.bytes_i_to_uint256(
            input + MOD_EXP_BYTES_LEN * 3 + b_size.low, e_size.low
        );
        let m: Uint256 = Helpers.bytes_i_to_uint256(
            input + MOD_EXP_BYTES_LEN * 3 + b_size.low + e_size.low, m_size.low
        );
        with_attr error_message("Kakarot: modexp failed") {
            let (result) = ModExpHelpers.uint256_mod_exp(b, e, m);
        }
        let bytes: felt* = alloc();
        let (bytes_len_low) = Helpers.felt_to_bytes(result.low, 0, bytes);
        let (bytes_len_high) = Helpers.felt_to_bytes(result.high, 0, bytes + bytes_len_low);
        local bytes_len: felt;
        if (result.high != 0) {
            bytes_len = bytes_len_low + bytes_len_high;
        } else {
            bytes_len = bytes_len_low;
        }
        return (output_len=bytes_len, output=bytes, gas_used=0);
    }
}
