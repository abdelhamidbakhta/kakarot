from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_eq,
    uint256_le,
    uint256_sub,
    uint256_mul,
    uint256_lt,
    uint256_add,
    uint256_pow2,
    uint256_unsigned_div_rem,
    uint256_and,
    uint256_or,
    uint256_not,
)
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

// @notice Internal exponentiation of two 256-bit integers.
// @dev The result is modulo 2^256.
// @param a The base.
// @param b The exponent.
// @return The result of the exponentiation.
func uint256_exp{range_check_ptr}(a: Uint256, b: Uint256) -> Uint256 {
    let one_uint = Uint256(1, 0);
    let zero_uint = Uint256(0, 0);

    let (is_b_zero) = uint256_eq(b, zero_uint);
    if (is_b_zero != FALSE) {
        return one_uint;
    }
    let (b_minus_one) = uint256_sub(b, one_uint);
    let pow = uint256_exp(a, b_minus_one);
    let (res, _) = uint256_mul(a, pow);
    return res;
}

// @notice Extend a signed number which fits in N bytes to 32 bytes.
// @param x The number to be sign extended.
// @param byte_num The size in bytes minus one of x to consider.
// @return The result of sign extending x from position b.
// If b > 31, the result is x. Otherwise, the sign bit is extended from position b.
func uint256_signextend{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    x: Uint256, byte_num: Uint256
) -> Uint256 {
    alloc_locals;
    let (byte_num_gt_word_size) = uint256_le(Uint256(32, 0), byte_num);
    if (byte_num_gt_word_size != 0) {
        return x;
    }

    let sign_bit_position = byte_num.low * 8 + 7;

    let (s) = uint256_pow2(Uint256(sign_bit_position, 0));
    let (sign_bit, _) = uint256_unsigned_div_rem(x, s);
    let (x_is_negative) = uint256_and(sign_bit, Uint256(1, 0));
    let (mask) = uint256_sub(s, Uint256(1, 0));
    let (x_is_positive) = uint256_eq(x_is_negative, Uint256(0, 0));

    // If x is positive (i.e. its sign bit is 0), then the result is x & mask and not x,
    // Because if b is smaller than the actual size of x, we "truncate" x.
    // Said another way, b is the source of truth on the size in bytes of x.
    // e.g. if x = 01111111 01111111 and b = 1, then the result is 00000000 01111111.
    if (x_is_positive == 1) {
        let (value) = uint256_and(x, mask);
        return value;
    }

    let (not_mask) = uint256_not(mask);
    let (value) = uint256_or(x, not_mask);
    return value;
}
