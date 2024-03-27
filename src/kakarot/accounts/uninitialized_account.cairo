// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address, replace_class, library_call

const INITIALIZE_SELECTOR = 0x79dc0da7c54b95f10aa182ad0a46400db63156920adb65eca2654c0945a463;  // sn_keccak('initialize')

@storage_var
func Account_evm_address() -> (evm_address: felt) {
}

@storage_var
func Account_kakarot_address() -> (kakarot_address: felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    kakarot_address: felt, evm_address: felt
) {
    Account_kakarot_address.write(kakarot_address);
    Account_evm_address.write(evm_address);
    return ();
}

// @title Uninitialized Contract Account. Used to get a deterministic address for an account, no
// matter the actual implementation class used.

// @notice Initializes the account with the Kakarot and EVM addresses it was deployed with.
// @param implementation_class The address of the main Kakarot contract.
@external
func initialize{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(implementation_class: felt) {
    let (caller) = get_caller_address();
    let (kakarot_address) = Account_kakarot_address.read();
    with_attr error_message("Only Kakarot") {
        assert kakarot_address = caller;
    }
    replace_class(implementation_class);
    let (evm_address) = Account_evm_address.read();
    let (calldata) = alloc();
    assert [calldata] = kakarot_address;
    assert [calldata + 1] = evm_address;
    assert [calldata + 2] = implementation_class;
    library_call(
        class_hash=implementation_class,
        function_selector=INITIALIZE_SELECTOR,
        calldata_size=3,
        calldata=calldata,
    );
    return ();
}
