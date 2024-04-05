%lang starknet

from openzeppelin.access.ownable.library import Ownable, Ownable_owner
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import unsigned_div_rem, split_int, split_felt
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256, uint256_not, uint256_le
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import (
    StorageRead,
    StorageWrite,
    STORAGE_READ_SELECTOR,
    STORAGE_WRITE_SELECTOR,
    storage_read,
    storage_write,
    StorageReadRequest,
    CallContract,
    get_tx_info,
    get_contract_address,
    get_caller_address,
    replace_class,
)
from starkware.cairo.common.memset import memset

from kakarot.interfaces.interfaces import IERC20, IKakarot
from kakarot.errors import Errors
from kakarot.constants import Constants
from utils.eth_transaction import EthTransaction
from utils.uint256 import uint256_add

// @dev: should always be zero for EOAs
@storage_var
func Account_bytecode_len() -> (res: felt) {
}

@storage_var
func Account_storage(key: Uint256) -> (value: Uint256) {
}

@storage_var
func Account_is_initialized() -> (res: felt) {
}

@storage_var
func Account_nonce() -> (nonce: felt) {
}

@storage_var
func Account_implementation() -> (address: felt) {
}

// //////////////// DO NOT MODIFY //////////////////
// We are intentionally causing a storage_slot collision here,
// by defining these variables in both `uninitialized_account` and `account_contract`.
@storage_var
func Account_evm_address() -> (evm_address: felt) {
}

@storage_var
func Account_kakarot_address() -> (kakarot_address: felt) {
}
// /////////////////////////////////////////////////

@event
func transaction_executed(response_len: felt, response: felt*, success: felt, gas_used: felt) {
}

const BYTES_PER_FELT = 31;

// @title Account main library file.
// @notice This file contains the EVM account representation logic.
// @dev: Both EOAs and Contract Accounts are represented by this contract.
namespace AccountContract {
    // 000.001.000
    const VERSION = 000001000;

    // @notice This function is used to initialize the smart contract account.
    // @dev The `evm_address` and `kakarot_address` were set during the uninitialized_account creation.
    // Reading them from state ensures that they always match the ones the account was created for.
    func initialize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(implementation_class: felt) {
        alloc_locals;
        let (is_initialized) = Account_is_initialized.read();
        assert is_initialized = 0;
        let (kakarot_address) = Account_kakarot_address.read();
        let (evm_address) = Account_evm_address.read();
        Account_is_initialized.write(1);
        Ownable.initializer(kakarot_address);
        Account_evm_address.write(evm_address);
        Account_implementation.write(implementation_class);

        // Give infinite ETH transfer allowance to Kakarot
        let (native_token_address) = IKakarot.get_native_token(kakarot_address);
        let infinite = Uint256(Constants.UINT128_MAX, Constants.UINT128_MAX);
        IERC20.approve(native_token_address, kakarot_address, infinite);
        return ();
    }

    // @notice Upgrade the implementation of the account.
    // @param new_class The new class of the account.
    func upgrade{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(new_class: felt) {
        alloc_locals;
        // Access control check. Only the EOA owner should be able to upgrade its contract.
        Internals.assert_only_self();
        assert_not_zero(new_class);
        replace_class(new_class);
        Account_implementation.write(new_class);
        return ();
    }

    func get_implementation{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        implementation: felt
    ) {
        let (implementation) = Account_implementation.read();
        return (implementation=implementation);
    }

    // @return address The EVM address of the account
    func get_evm_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        address: felt
    ) {
        let (address) = Account_evm_address.read();
        return (address=address);
    }

    // @notice This function checks if the account was initialized.
    // @return is_initialized 1 if the account has been initialized 0 otherwise.
    func is_initialized{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() -> (is_initialized: felt) {
        let is_initialized: felt = Account_is_initialized.read();
        return (is_initialized=is_initialized);
    }

    // EOA functions

    struct Call {
        to: felt,
        selector: felt,
        calldata_len: felt,
        calldata: felt*,
    }

    // Struct introduced to pass `[Call]` to __execute__
    struct CallArray {
        to: felt,
        selector: felt,
        data_offset: felt,
        data_len: felt,
    }

    // @notice Validate the signature of every call in the call array.
    // @dev Recursively validates if tx is signed and valid for each call -> see utils/eth_transaction.cairo
    // @param call_array_len The length of the call array.
    // @param call_array The call array.
    // @param calldata_len The length of the calldata.
    // @param calldata The calldata.
    func validate{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(call_array_len: felt, call_array: CallArray*, calldata_len: felt, calldata: felt*) -> () {
        alloc_locals;
        if (call_array_len == 0) {
            // Validates that this account doesn't have code. Check only once at the end of the recursion.
            let (bytecode_len) = Account_bytecode_len.read();
            with_attr error_message("EOAs cannot have code") {
                assert bytecode_len = 0;
            }

            return ();
        }

        let (address) = Account_evm_address.read();
        let (tx_info) = get_tx_info();

        // Assert signature field is of length 5: r_low, r_high, s_low, s_high, v
        assert tx_info.signature_len = 5;
        let r = Uint256(tx_info.signature[0], tx_info.signature[1]);
        let s = Uint256(tx_info.signature[2], tx_info.signature[3]);
        let v = tx_info.signature[4];
        let (_, chain_id) = unsigned_div_rem(tx_info.chain_id, 2 ** 64);

        EthTransaction.validate(
            address,
            tx_info.nonce,
            chain_id,
            r,
            s,
            v,
            [call_array].data_len,
            calldata + [call_array].data_offset,
        );

        validate(
            call_array_len=call_array_len - 1,
            call_array=call_array + CallArray.SIZE,
            calldata_len=calldata_len,
            calldata=calldata,
        );

        return ();
    }

    // @notice Execute the transaction.
    // @param call_array_len The length of the call array.
    // @param call_array The call array.
    // @param calldata_len The length of the calldata.
    // @param calldata The calldata.
    // @param response The response data array to be updated.
    // @return response_len The total length of the response data array.
    func execute{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(
        call_array_len: felt,
        call_array: CallArray*,
        calldata_len: felt,
        calldata: felt*,
        response: felt*,
    ) -> (response_len: felt) {
        alloc_locals;
        if (call_array_len == 0) {
            return (response_len=0);
        }

        let tx = EthTransaction.decode([call_array].data_len, calldata + [call_array].data_offset);

        // No matter the status of the execution in EVM terms (success - failure - rejected), the nonce of the
        // transaction sender must be incremented, as the protocol nonce is.  While we use the protocol nonce for the
        // transaction validation, we don't make the distinction between CAs and EOAs in their
        // Starknet contract representation. As such, the stored nonce of an EOA account must always match the
        // protocol nonce, increased by one right before each transaction execution.
        //
        // In the official specification, this nonce increment is done right after the tx validation checks.
        // Since we can only perform these checks in __execute__, which increments the protocol nonce by one,
        // we need to increment the stored nonce here as well.
        //
        // The protocol nonce is updated once per __execute__ call, while the EVM nonce is updated once per
        // transaction. If we were to execute more than one transaction in a single __execute__ call, we would
        // need to change the nonce incrementation logic.
        let (current_nonce) = Account_nonce.read();
        Account_nonce.write(current_nonce + 1);

        let (kakarot_address) = Ownable_owner.read();
        let (block_gas_limit) = IKakarot.get_block_gas_limit(kakarot_address);
        let tx_gas_fits_in_block = is_le(tx.gas_limit, block_gas_limit);

        let (base_fee) = IKakarot.get_base_fee(kakarot_address);
        let (native_token_address) = IKakarot.get_native_token(kakarot_address);
        let (contract_address) = get_contract_address();
        let (balance) = IERC20.balanceOf(native_token_address, contract_address);

        // ensure that the user was willing to at least pay the base fee
        let enough_fee = is_le(base_fee, tx.max_fee_per_gas);
        let max_fee_greater_priority_fee = is_le(tx.max_priority_fee_per_gas, tx.max_fee_per_gas);
        let max_gas_fee = tx.gas_limit * tx.max_fee_per_gas;
        let (max_fee_high, max_fee_low) = split_felt(max_gas_fee);
        let (tx_cost, carry) = uint256_add(tx.amount, Uint256(low=max_fee_low, high=max_fee_high));
        assert carry = 0;
        let (is_balance_enough) = uint256_le(tx_cost, balance);

        if (enough_fee * max_fee_greater_priority_fee * is_balance_enough * tx_gas_fits_in_block == 0) {
            let (return_data_len, return_data) = Errors.eth_validation_failed();
            tempvar range_check_ptr = range_check_ptr;
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar return_data_len = return_data_len;
            tempvar return_data = return_data;
            tempvar success = FALSE;
            tempvar gas_used = 0;
        } else {
            // priority fee is capped because the base fee is filled first
            let possible_priority_fee = tx.max_fee_per_gas - base_fee;
            let priority_fee_is_max_priority_fee = is_le(
                tx.max_priority_fee_per_gas, possible_priority_fee
            );
            let priority_fee_per_gas = priority_fee_is_max_priority_fee *
                tx.max_priority_fee_per_gas + (1 - priority_fee_is_max_priority_fee) *
                possible_priority_fee;
            // signer pays both the priority fee and the base fee
            let effective_gas_price = priority_fee_per_gas + base_fee;

            let (return_data_len, return_data, success, gas_used) = IKakarot.eth_send_transaction(
                contract_address=kakarot_address,
                to=tx.destination,
                gas_limit=tx.gas_limit,
                gas_price=effective_gas_price,
                value=tx.amount,
                data_len=tx.payload_len,
                data=tx.payload,
                access_list_len=tx.access_list_len,
                access_list=tx.access_list,
            );
            tempvar range_check_ptr = range_check_ptr;
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar return_data_len = return_data_len;
            tempvar return_data = return_data;
            tempvar success = success;
            tempvar gas_used = gas_used;
        }
        let range_check_ptr = [ap - 7];
        let syscall_ptr = cast([ap - 6], felt*);
        let pedersen_ptr = cast([ap - 5], HashBuiltin*);
        let return_data_len = [ap - 4];
        let return_data = cast([ap - 3], felt*);
        let success = [ap - 2];
        let gas_used = [ap - 1];

        memcpy(response, return_data, return_data_len);

        // See Argent account
        // https://github.com/argentlabs/argent-contracts-starknet/blob/c6d3ee5e05f0f4b8a5c707b4094446c3bc822427/contracts/account/ArgentAccount.cairo#L132
        transaction_executed.emit(
            response_len=return_data_len, response=return_data, success=success, gas_used=gas_used
        );

        let (response_len) = execute(
            call_array_len - 1,
            call_array + CallArray.SIZE,
            calldata_len,
            calldata,
            response + return_data_len,
        );

        return (response_len=return_data_len + response_len);
    }

    // Contract Account functions

    // @notice Store the bytecode of the contract.
    // @param bytecode_len The length of the bytecode.
    // @param bytecode The bytecode of the contract.
    func write_bytecode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(bytecode_len: felt, bytecode: felt*) {
        alloc_locals;
        // Access control check.
        Ownable.assert_only_owner();
        // Recursively store the bytecode.
        Account_bytecode_len.write(bytecode_len);
        Internals.write_bytecode(bytecode_len=bytecode_len, bytecode=bytecode);
        return ();
    }

    // @notice This function is used to get the bytecode_len of the smart contract.
    // @return bytecode_len The length of the bytecode.
    func bytecode_len{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        res: felt
    ) {
        return Account_bytecode_len.read();
    }

    // @notice This function is used to get the bytecode of the smart contract.
    // @return bytecode_len The length of the bytecode.
    // @return bytecode The bytecode of the smart contract.
    func bytecode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() -> (bytecode_len: felt, bytecode: felt*) {
        alloc_locals;
        let (bytecode_len) = Account_bytecode_len.read();
        let (bytecode_) = Internals.load_bytecode(bytecode_len);
        return (bytecode_len, bytecode_);
    }

    // @notice This function is used to read the storage at a key.
    // @param key The storage key, which is hash_felts(cast(Uint256, felt*)) of the Uint256 storage key.
    // @return value The store value.
    func storage{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(storage_addr: felt) -> (value: Uint256) {
        let (low) = storage_read(address=storage_addr + 0);
        let (high) = storage_read(address=storage_addr + 1);
        let value = Uint256(low, high);
        return (value,);
    }

    // @notice This function is used to write to the storage of the account.
    // @param key The storage key, which is hash_felts(cast(Uint256, felt*)) of the Uint256 storage key.
    // @param value The value to store.
    func write_storage{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(storage_addr: felt, value: Uint256) {
        // Access control check.
        Ownable.assert_only_owner();
        // Write State
        storage_write(address=storage_addr + 0, value=value.low);
        storage_write(address=storage_addr + 1, value=value.high);
        return ();
    }

    // @notice This function is used to read the nonce from storage
    // @return nonce The current nonce of the contract account
    func get_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        nonce: felt
    ) {
        return Account_nonce.read();
    }

    // @notice This function set the account nonce
    func set_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        new_nonce: felt
    ) {
        // Access control check.
        Ownable.assert_only_owner();
        Account_nonce.write(new_nonce);
        return ();
    }
}

namespace Internals {
    // @notice asserts that the caller is the account itself
    func assert_only_self{syscall_ptr: felt*}() {
        let (this) = get_contract_address();
        let (caller) = get_caller_address();
        with_attr error_message("Only the account itself can call this function") {
            assert caller = this;
        }
        return ();
    }

    // @notice Store the bytecode of the contract.
    // @param index The current free index in the bytecode_ storage.
    // @param bytecode_len The length of the bytecode.
    // @param bytecode The bytecode of the contract.
    func write_bytecode{syscall_ptr: felt*}(bytecode_len: felt, bytecode: felt*) {
        alloc_locals;

        if (bytecode_len == 0) {
            return ();
        }

        tempvar value = 0;
        tempvar address = 0;
        tempvar syscall_ptr = syscall_ptr;
        tempvar bytecode_len = bytecode_len;
        tempvar count = BYTES_PER_FELT;

        body:
        let value = [ap - 5];
        let address = [ap - 4];
        let syscall_ptr = cast([ap - 3], felt*);
        let bytecode_len = [ap - 2];
        let count = [ap - 1];
        let initial_bytecode_len = [fp - 4];
        let bytecode = cast([fp - 3], felt*);

        tempvar value = value * 256 + bytecode[initial_bytecode_len - bytecode_len];
        tempvar address = address;
        tempvar syscall_ptr = syscall_ptr;
        tempvar bytecode_len = bytecode_len - 1;
        tempvar count = count - 1;

        jmp cond if bytecode_len != 0;
        jmp store;

        cond:
        jmp body if count != 0;

        store:
        assert [cast(syscall_ptr, StorageWrite*)] = StorageWrite(
            selector=STORAGE_WRITE_SELECTOR, address=address, value=value
        );
        %{ syscall_handler.storage_write(segments=segments, syscall_ptr=ids.syscall_ptr) %}
        tempvar value = 0;
        tempvar address = address + 1;
        tempvar syscall_ptr = syscall_ptr + StorageWrite.SIZE;
        tempvar bytecode_len = bytecode_len;
        tempvar count = BYTES_PER_FELT;

        jmp body if bytecode_len != 0;

        return ();
    }

    // @notice Load the bytecode of the contract in the specified array.
    // @param index The index in the bytecode.
    // @param bytecode_len The length of the bytecode.
    // @param bytecode The bytecode of the contract.
    func load_bytecode{syscall_ptr: felt*, range_check_ptr}(bytecode_len: felt) -> (
        bytecode: felt*
    ) {
        alloc_locals;

        let (local bytecode: felt*) = alloc();
        local bound = 256;
        local base = 256;

        if (bytecode_len == 0) {
            return (bytecode=bytecode);
        }

        let (local chunk_counts, local remainder) = unsigned_div_rem(bytecode_len, BYTES_PER_FELT);

        tempvar remaining_bytes = bytecode_len;
        tempvar range_check_ptr = range_check_ptr;
        tempvar address = 0;
        tempvar syscall_ptr = syscall_ptr;
        tempvar value = 0;
        tempvar count = 0;

        read:
        let remaining_bytes = [ap - 6];
        let range_check_ptr = [ap - 5];
        let address = [ap - 4];
        let syscall_ptr = cast([ap - 3], felt*);
        let value = [ap - 2];
        let count = [ap - 1];

        let syscall = [cast(syscall_ptr, StorageRead*)];
        assert syscall.request = StorageReadRequest(
            selector=STORAGE_READ_SELECTOR, address=address
        );
        %{ syscall_handler.storage_read(segments=segments, syscall_ptr=ids.syscall_ptr) %}
        let response = syscall.response;

        let remainder = [fp + 4];
        let chunk_counts = [fp + 3];
        tempvar remaining_chunk = chunk_counts - address;
        jmp full_chunk if remaining_chunk != 0;
        tempvar count = remainder;
        jmp next;

        full_chunk:
        tempvar count = BYTES_PER_FELT;

        next:
        tempvar remaining_bytes = remaining_bytes;
        tempvar range_check_ptr = range_check_ptr;
        tempvar address = address + 1;
        tempvar syscall_ptr = syscall_ptr + StorageRead.SIZE;
        tempvar value = response.value;
        tempvar count = count;

        body:
        let remaining_bytes = [ap - 6];
        let range_check_ptr = [ap - 5];
        let address = [ap - 4];
        let syscall_ptr = cast([ap - 3], felt*);
        let value = [ap - 2];
        let count = [ap - 1];

        let base = [fp + 1];
        let bound = [fp + 2];
        let bytecode = cast([fp], felt*);
        tempvar offset = (address - 1) * BYTES_PER_FELT + count - 1;
        let output = bytecode + offset;

        // Put byte in output and assert that 0 <= byte < bound
        // See math.split_int
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar a = [output];
        %{
            from starkware.cairo.common.math_utils import assert_integer
            assert_integer(ids.a)
            assert 0 <= ids.a % PRIME < range_check_builtin.bound, f'a = {ids.a} is out of range.'
        %}
        assert a = [range_check_ptr];
        tempvar a = bound - 1 - a;
        %{
            from starkware.cairo.common.math_utils import assert_integer
            assert_integer(ids.a)
            assert 0 <= ids.a % PRIME < range_check_builtin.bound, f'a = {ids.a} is out of range.'
        %}
        assert a = [range_check_ptr + 1];

        tempvar value = (value - [output]) / base;
        tempvar remaining_bytes = remaining_bytes - 1;
        tempvar range_check_ptr = range_check_ptr + 2;
        tempvar address = address;
        tempvar syscall_ptr = syscall_ptr;
        tempvar value = value;
        tempvar count = count - 1;

        jmp cond if remaining_bytes != 0;

        let bytecode = cast([fp], felt*);
        return (bytecode=bytecode);

        cond:
        jmp body if count != 0;
        jmp read;
    }
}
