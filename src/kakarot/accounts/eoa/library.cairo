// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// OpenZeppelin dependencies
from openzeppelin.access.ownable.library import Ownable

// @title ExternallyOwnedAccount main library file.
// @notice This file contains the EVM EOA account representation logic.
// @author @abdelhamidbakhta
// @custom:namespace ExternallyOwnedAccount

namespace ExternallyOwnedAccount {
    func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(kakarot_address: felt) {
        Ownable.initializer(kakarot_address);
        return ();
    }
}
