// SPDX-License-Identifier: MIT

// StarkWare dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_le, split_felt, assert_nn_le, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.pow import pow
from starkware.cairo.common.uint256 import Uint256, uint256_check
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.hash_state import hash_finalize, hash_init, hash_update

from utils.bytes import uint256_to_bytes32

// @title Helper Functions
// @notice This file contains a selection of helper function that simplify tasks such as type conversion and bit manipulation
namespace Helpers {
    func to_uint256{range_check_ptr}(val: felt) -> Uint256* {
        let (high, low) = split_felt(val);
        tempvar res = new Uint256(low, high);
        return res;
    }

    // @notice This helper converts a felt straight to BigInt3
    // @param val: felt value to be converted
    // @return res: BigInt3 representation of the given input
    func to_bigint{range_check_ptr}(val: felt) -> BigInt3 {
        let val_uint256: Uint256 = to_uint256(val);
        let (res: BigInt3) = uint256_to_bigint(val_uint256);
        return res;
    }

    // @notice This helper converts a BigInt3 straight to felt
    // @param val: BigInt3 value to be converted
    // @return res: felt representation of the given input
    func bigint_to_felt{range_check_ptr}(val: BigInt3) -> felt {
        let (val_uint256: Uint256) = bigint_to_uint256(val);
        let res = uint256_to_felt(val_uint256);
        return res;
    }

    // @notice This function is used to convert a sequence of 32 bytes to Uint256.
    // @param val: pointer to the first byte of the 32.
    // @return res: Uint256 representation of the given input in bytes32.
    func bytes32_to_uint256(val: felt*) -> Uint256 {
        let low = [val + 16] * 256 ** 15;
        let low = low + [val + 17] * 256 ** 14;
        let low = low + [val + 18] * 256 ** 13;
        let low = low + [val + 19] * 256 ** 12;
        let low = low + [val + 20] * 256 ** 11;
        let low = low + [val + 21] * 256 ** 10;
        let low = low + [val + 22] * 256 ** 9;
        let low = low + [val + 23] * 256 ** 8;
        let low = low + [val + 24] * 256 ** 7;
        let low = low + [val + 25] * 256 ** 6;
        let low = low + [val + 26] * 256 ** 5;
        let low = low + [val + 27] * 256 ** 4;
        let low = low + [val + 28] * 256 ** 3;
        let low = low + [val + 29] * 256 ** 2;
        let low = low + [val + 30] * 256 ** 1;
        let low = low + [val + 31];
        let high = [val] * 256 ** 1 * 256 ** 14;
        let high = high + [val + 1] * 256 ** 14;
        let high = high + [val + 2] * 256 ** 13;
        let high = high + [val + 3] * 256 ** 12;
        let high = high + [val + 4] * 256 ** 11;
        let high = high + [val + 5] * 256 ** 10;
        let high = high + [val + 6] * 256 ** 9;
        let high = high + [val + 7] * 256 ** 8;
        let high = high + [val + 8] * 256 ** 7;
        let high = high + [val + 9] * 256 ** 6;
        let high = high + [val + 10] * 256 ** 5;
        let high = high + [val + 11] * 256 ** 4;
        let high = high + [val + 12] * 256 ** 3;
        let high = high + [val + 13] * 256 ** 2;
        let high = high + [val + 14] * 256;
        let high = high + [val + 15];
        let res = Uint256(low=low, high=high);
        return res;
    }
    // @notice This function is used to convert a sequence of i bytes to Uint256.
    // @param val: pointer to the first byte.
    // @param i: sequence size.
    // @return res: Uint256 representation of the given input in bytes.
    func bytes_i_to_uint256{range_check_ptr}(val: felt*, i: felt) -> Uint256 {
        alloc_locals;

        if (i == 0) {
            let res = Uint256(0, 0);
            return res;
        }

        let is_sequence_32_bytes_or_less = is_le(i, 32);
        with_attr error_message("number must be shorter than 32 bytes") {
            assert is_sequence_32_bytes_or_less = 1;
        }

        let is_sequence_16_bytes_or_less = is_le(i, 16);

        // 1 - 16 bytes
        if (is_sequence_16_bytes_or_less != FALSE) {
            let (low) = compute_half_uint256(val=val, i=i, res=0);
            let res = Uint256(low=low, high=0);

            return res;
        }

        // 17 - 32 bytes
        let (low) = compute_half_uint256(val=val + i - 16, i=16, res=0);
        let (high) = compute_half_uint256(val=val, i=i - 16, res=0);
        let res = Uint256(low=low, high=high);

        return res;
    }

    // @notice This helper is used to convert a sequence of 32 bytes straight to BigInt3.
    // @param val: pointer to the first byte of the 32.
    // @return res: BigInt3 representation of the given input in bytes32.
    func bytes32_to_bigint{range_check_ptr}(val: felt*) -> BigInt3 {
        alloc_locals;

        let val_uint256: Uint256 = bytes32_to_uint256(val);
        let (res: BigInt3) = uint256_to_bigint(val_uint256);
        return res;
    }

    // @notice This function is used to convert a BigInt3 to straight to a bytes array represented by an array of felts (1 felt represents 1 byte).
    // @param value: BigInt3 value to convert.
    // @return: array length and felt array representation of the value.
    func bigint_to_bytes_array{range_check_ptr}(val: BigInt3) -> (
        bytes_array_len: felt, bytes_array: felt*
    ) {
        alloc_locals;
        let (val_uint256: Uint256) = bigint_to_uint256(val);
        let (bytes: felt*) = alloc();
        uint256_to_bytes32(bytes, val_uint256);
        return (32, bytes);
    }

    // @notice: This helper returns the minimal number of EVM words for a given bytes length
    // @param length: a given bytes length
    // @return res: the minimal number of EVM words
    func minimum_word_count{range_check_ptr}(length: felt) -> (res: felt) {
        let (quotient, remainder) = unsigned_div_rem(length + 31, 32);
        return (res=quotient);
    }

    func compute_half_uint256{range_check_ptr}(val: felt*, i: felt, res: felt) -> (res: felt) {
        if (i == 1) {
            return (res=res + [val]);
        }
        let (temp_pow) = pow(256, i - 1);
        let (res) = compute_half_uint256(val + 1, i - 1, res + [val] * temp_pow);
        return (res=res);
    }

    // @notice This function is used to convert a sequence of 8 bytes to a felt.
    // @param val: pointer to the first byte.
    // @return: felt representation of the input.
    func bytes_to_64_bits_little_felt(bytes: felt*) -> felt {
        let res = [bytes + 7] * 256 ** 7;
        let res = res + [bytes + 6] * 256 ** 6;
        let res = res + [bytes + 5] * 256 ** 5;
        let res = res + [bytes + 4] * 256 ** 4;
        let res = res + [bytes + 3] * 256 ** 3;
        let res = res + [bytes + 2] * 256 ** 2;
        let res = res + [bytes + 1] * 256;
        let res = res + [bytes];
        return res;
    }

    // @notice This function is used to convert a uint256 to a felt.
    // @param val: value to convert.
    // @return: felt representation of the input.
    func uint256_to_felt{range_check_ptr}(val: Uint256) -> felt {
        uint256_check(val);
        return val.low + val.high * 2 ** 128;
    }

    // @notice Loads a sequence of bytes into a single felt in big-endian.
    // @param len: number of bytes.
    // @param ptr: pointer to bytes array.
    // @return: packed felt.
    func load_word(len: felt, ptr: felt*) -> felt {
        if (len == 0) {
            return 0;
        }
        tempvar current = 0;

        // len, ptr, ?, ?, current
        loop:
        let len = [ap - 5];
        let ptr = cast([ap - 4], felt*);
        let current = [ap - 1];

        tempvar len = len - 1;
        tempvar ptr = ptr + 1;
        tempvar loaded = [ptr - 1];
        tempvar tmp = current * 256;
        tempvar current = tmp + loaded;

        static_assert len == [ap - 5];
        static_assert ptr == [ap - 4];
        static_assert current == [ap - 1];
        jmp loop if len != 0;

        return current;
    }

    // @notice Load sequences of 8 bytes little endian into an array of felts
    // @param len: final length of the output.
    // @param input: pointer to bytes array input.
    // @param output: pointer to bytes array output.
    func load_64_bits_array(len: felt, input: felt*, output: felt*) {
        if (len == 0) {
            return ();
        }
        let loaded = bytes_to_64_bits_little_felt(input);
        assert [output] = loaded;
        return load_64_bits_array(len - 1, input + 8, output + 1);
    }

    // @notice Divides a 128-bit number with remainder.
    // @dev This is almost identical to cairo.common.math.unsigned_dev_rem, but supports the case
    // @dev of div == 2**128 as well.
    // @param value: 128bit value to divide.
    // @param div: divisor.
    // @return: quotient and remainder.
    func div_rem{range_check_ptr}(value, div) -> (q: felt, r: felt) {
        if (div == 2 ** 128) {
            return (0, value);
        }

        // Copied from unsigned_div_rem.
        let r = [range_check_ptr];
        let q = [range_check_ptr + 1];
        let range_check_ptr = range_check_ptr + 2;
        %{
            from starkware.cairo.common.math_utils import assert_integer
            assert_integer(ids.div)
            assert 0 < ids.div <= PRIME // range_check_builtin.bound, \
                f'div={hex(ids.div)} is out of the valid range.'
            ids.q, ids.r = divmod(ids.value, ids.div)
        %}
        assert_le(r, div - 1);

        assert value = q * div + r;
        return (q, r);
    }

    // @notice Computes 256 ** (16 - i) for 0 <= i <= 16.
    func pow256_rev(i: felt) -> felt {
        let (pow256_rev_address) = get_label_location(pow256_rev_table);
        return pow256_rev_address[i];

        pow256_rev_table:
        dw 340282366920938463463374607431768211456;
        dw 1329227995784915872903807060280344576;
        dw 5192296858534827628530496329220096;
        dw 20282409603651670423947251286016;
        dw 79228162514264337593543950336;
        dw 309485009821345068724781056;
        dw 1208925819614629174706176;
        dw 4722366482869645213696;
        dw 18446744073709551616;
        dw 72057594037927936;
        dw 281474976710656;
        dw 1099511627776;
        dw 4294967296;
        dw 16777216;
        dw 65536;
        dw 256;
        dw 1;
    }

    // @notice Splits a felt into `len` bytes, big-endian, and outputs to `dst`.
    func split_word{range_check_ptr}(value: felt, len: felt, dst: felt*) {
        if (len == 0) {
            assert value = 0;
            return ();
        }
        tempvar len = len - 1;
        let output = &dst[len];
        let base = 256;
        let bound = 256;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar low_part = [output];
        assert_nn_le(low_part, 255);
        return split_word((value - low_part) / 256, len, dst);
    }

    // @notice Splits a felt into `len` bytes, little-endian, and outputs to `dst`.
    func split_word_little{range_check_ptr}(value: felt, len: felt, dst: felt*) {
        if (len == 0) {
            assert value = 0;
            return ();
        }
        let output = &dst[0];
        let base = 256;
        let bound = 256;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar low_part = [output];
        assert_nn_le(low_part, 255);
        return split_word_little((value - low_part) / 256, len - 1, dst + 1);
    }

    // @notice Splits a felt into 16 bytes, big-endian, and outputs to `dst`.
    func split_word_128{range_check_ptr}(start_value: felt, dst: felt*) {
        // Fill dst using only hints with no opcodes.
        let value = start_value;
        let offset = 15;
        tempvar base = 256;
        let bound = 256;
        tempvar max = 255;

        // 0.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 1.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 2.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 3.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 0.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 1.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 2.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 3.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 0.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 1.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 2.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 3.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 0.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 1.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 2.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 3.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;

        assert value = 0;
        return ();
    }

    // @notice transform multiple bytes into a single felt
    // @param data_len The length of the bytes
    // @param data The pointer to the bytes array
    // @param n used for recursion, set to 0
    // @return n the resultant felt
    func bytes_to_felt{range_check_ptr}(data_len: felt, data: felt*, n: felt) -> (n: felt) {
        if (data_len == 0) {
            return (n=n);
        }
        let e: felt = data_len - 1;
        let byte: felt = data[0];
        let (res) = pow(256, e);
        return bytes_to_felt(data_len=data_len - 1, data=data + 1, n=n + byte * res);
    }

    // @notice transform multiple bytes into words of 32 bits (big endian)
    // @dev the input data must have length in multiples of 4
    // @param data_len The length of the bytes
    // @param data The pointer to the bytes array
    // @param n_len used for recursion, set to 0
    // @param n used for recursion, set to pointer
    // @return n_len the resulting array length
    // @return n the resulting array
    func bytes_to_bytes4_array{range_check_ptr}(
        data_len: felt, data: felt*, n_len: felt, n: felt*
    ) -> (n_len: felt, n: felt*) {
        alloc_locals;
        if (data_len == 0) {
            return (n_len=n_len, n=n);
        }

        let (_, r) = unsigned_div_rem(data_len, 4);
        with_attr error_message("data length must be multiple of 4") {
            assert r = 0;
        }

        // Load sequence of 4 bytes into a single 32-bit word (big endian)
        let res = load_word(4, data);
        assert n[n_len] = res;
        return bytes_to_bytes4_array(data_len=data_len - 4, data=data + 4, n_len=n_len + 1, n=n);
    }

    // @notice transform array of 32-bit words (big endian) into a bytes array
    // @param data_len The length of the 32-bit array
    // @param data The pointer to the 32-bit array
    // @param bytes_len used for recursion, set to 0
    // @param bytes used for recursion, set to pointer
    // @return bytes_len the resulting array length
    // @return bytes the resulting array
    func bytes4_array_to_bytes{range_check_ptr}(
        data_len: felt, data: felt*, bytes_len: felt, bytes: felt*
    ) -> (bytes_len: felt, bytes: felt*) {
        alloc_locals;
        if (data_len == 0) {
            return (bytes_len=bytes_len, bytes=bytes);
        }

        // Split a 32-bit big endian word into 4 bytes
        // Store result in a temporary array
        let (temp: felt*) = alloc();
        split_word([data], 4, temp);

        // Append temp array to bytes array
        let (local res: felt*) = alloc();
        memcpy(res, bytes, bytes_len);
        memcpy(res + bytes_len, temp, 4);

        return bytes4_array_to_bytes(
            data_len=data_len - 1, data=data + 1, bytes_len=bytes_len + 4, bytes=res
        );
    }
}
