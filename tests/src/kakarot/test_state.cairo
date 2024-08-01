%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.dict import dict_read, dict_write
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.memcpy import memcpy

from kakarot.model import model
from backend.starknet import Starknet
from kakarot.state import State, Internals
from kakarot.account import Account
from kakarot.storages import Kakarot_native_token_address
from utils.dict import dict_keys

func test__init__should_return_state_with_default_dicts() {
    // When
    let state = State.init();

    // Then
    assert state.accounts - state.accounts_start = 0;
    assert state.events_len = 0;
    assert state.transfers_len = 0;

    let accounts = state.accounts;
    let (value) = dict_read{dict_ptr=accounts}(0xdead);
    assert value = 0;

    return ();
}

func test__copy__should_return_new_state_with_same_attributes{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    // Given

    // 1. Create empty State
    let state = State.init();

    // 2. Put two accounts with some storage
    tempvar address_0 = new model.Address(1, 2);
    tempvar address_1 = new model.Address(3, 4);
    tempvar key_0 = new Uint256(1, 2);
    tempvar key_1 = new Uint256(3, 4);
    tempvar value = new Uint256(3, 4);
    with state {
        State.write_storage(address_0.evm, key_0, value);
        State.write_storage(address_1.evm, key_0, value);
        State.write_storage(address_1.evm, key_1, value);

        // 3. Put some events
        let (local topics: felt*) = alloc();
        let (local data: felt*) = alloc();
        let event = model.Event(topics_len=0, topics=topics, data_len=0, data=data);
        State.add_event(event);

        // 4. Add transfers
        // State.add_transfer requires a native token contract deployed so we just push.
        let amount = Uint256(0xa, 0xb);
        tempvar transfer = model.Transfer(address_0, address_1, amount);
        assert state.transfers[0] = transfer;
        tempvar state = new model.State(
            accounts_start=state.accounts_start,
            accounts=state.accounts,
            events_len=state.events_len,
            events=state.events,
            transfers_len=1,
            transfers=state.transfers,
        );

        // When
        let state_copy = State.copy();
    }

    // Then

    // Storage
    let value_copy = State.read_storage{state=state_copy}(address_0.evm, key_0);
    assert_uint256_eq([value], [value_copy]);
    let value_copy = State.read_storage{state=state_copy}(address_1.evm, key_0);
    assert_uint256_eq([value], [value_copy]);
    let value_copy = State.read_storage{state=state_copy}(address_1.evm, key_1);
    assert_uint256_eq([value], [value_copy]);

    // Events
    assert state_copy.events_len = state.events_len;

    // Transfers
    assert state_copy.transfers_len = state.transfers_len;
    let transfer_copy = state_copy.transfers;
    assert transfer.sender.starknet = transfer_copy.sender.starknet;
    assert transfer.sender.evm = transfer_copy.sender.evm;
    assert transfer.recipient.starknet = transfer_copy.recipient.starknet;
    assert transfer.recipient.evm = transfer_copy.recipient.evm;
    assert_uint256_eq(transfer.amount, transfer_copy.amount);

    return ();
}

func test__is_account_alive__account_alive_in_state{
    pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr
}() -> felt {
    alloc_locals;
    local nonce: felt;
    local balance_low: felt;
    local code_len: felt;
    let (code) = alloc();
    let (code_hash_ptr) = alloc();
    %{
        from tests.utils.uint256 import int_to_uint256

        ids.nonce = program_input["nonce"]
        ids.balance_low = program_input["balance_low"]
        ids.code_len = len(program_input["code"])
        segments.write_arg(ids.code, program_input["code"])
        segments.write_arg(ids.code_hash_ptr, int_to_uint256(program_input["code_hash"]))
    %}

    let evm_address = 'alive';
    let starknet_address = Account.compute_starknet_address(evm_address);
    tempvar address = new model.Address(starknet_address, evm_address);
    tempvar balance = new Uint256(balance_low, 0);
    let account = Account.init(
        address, code_len, code, cast(code_hash_ptr, Uint256*), nonce, balance
    );
    let state = State.init();

    with state {
        State.update_account(account);
        let is_alive = State.is_account_alive(evm_address);
    }

    return is_alive;
}

func test__is_account_alive__account_alive_not_in_state{
    pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr
}() {
    // As the account is not in the local state, data is fetched from
    // Starknet, which is mocked by pytest.
    let state = State.init();
    with state {
        let is_alive = State.is_account_alive(0xabde1);
    }

    assert is_alive = 1;
    return ();
}

func test__is_account_alive__account_not_alive_not_in_state{
    pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr
}() {
    let state = State.init();
    with state {
        let is_alive = State.is_account_alive(0xdead);
    }

    assert is_alive = 0;
    return ();
}

func test___copy_accounts__should_handle_null_pointers{range_check_ptr}() {
    alloc_locals;
    let (accounts) = default_dict_new(0);
    tempvar accounts_start = accounts;
    tempvar address = new model.Address(1, 2);
    tempvar balance = new Uint256(1, 0);
    let (code) = alloc();
    tempvar code_hash = new Uint256(
        304396909071904405792975023732328604784, 262949717399590921288928019264691438528
    );
    let account = Account.init(address, 0, code, code_hash, 1, balance);
    dict_write{dict_ptr=accounts}(address.evm, cast(account, felt));
    let empty_address = 'empty address';
    dict_read{dict_ptr=accounts}(empty_address);
    let (local accounts_copy: DictAccess*) = default_dict_new(0);
    Internals._copy_accounts{accounts=accounts_copy}(accounts_start, accounts);

    let (pointer) = dict_read{dict_ptr=accounts_copy}(address.evm);
    tempvar existing_account = cast(pointer, model.Account*);

    assert existing_account.address.starknet = address.starknet;
    assert existing_account.address.evm = address.evm;
    assert existing_account.balance.low = 1;
    assert existing_account.balance.high = 0;
    assert existing_account.code_len = 0;

    return ();
}

func test__is_account_warm__account_in_state{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    let evm_address = 'alive';
    let starknet_address = 'starknet_alive';
    tempvar address = new model.Address(starknet_address, evm_address);
    tempvar balance = new Uint256(1, 0);
    let (code) = alloc();
    tempvar code_hash = new Uint256(
        304396909071904405792975023732328604784, 262949717399590921288928019264691438528
    );
    let account = Account.init(address, 0, code, code_hash, 1, balance);
    tempvar state = State.init();

    with state {
        State.update_account(account);
        let is_warm = State.is_account_warm(evm_address);
    }

    assert is_warm = 1;
    return ();
}

func test__is_account_warm__account_not_in_state{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    let state = State.init();
    let evm_address = 'alive';
    with state {
        let is_warm = State.is_account_warm(evm_address);
    }
    assert is_warm = 0;
    return ();
}

func test__is_account_warm__warms_up_account{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    let state = State.init();
    let evm_address = 'alive';
    with state {
        let is_warm = State.is_account_warm(evm_address);
    }
    assert is_warm = 0;

    with state {
        let is_warm = State.is_account_warm(evm_address);
    }

    assert is_warm = 1;
    return ();
}

func test__cache_precompiles{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> model.State* {
    alloc_locals;
    let state = State.init();
    with state {
        State.cache_precompiles();
    }

    return state;
}

func test__cache_access_list{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    access_list_cost: felt, state: model.State*
) {
    alloc_locals;
    local access_list_len: felt;
    let (access_list) = alloc();
    %{
        ids.access_list_len = len(program_input["access_list"])
        segments.write_arg(ids.access_list, program_input["access_list"])
    %}
    let state = State.init();
    with state {
        let access_list_cost = State.cache_access_list(access_list_len, access_list);
    }

    return (access_list_cost, state);
}

func test__is_storage_warm__should_return_true_when_already_read{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    let state = State.init();
    tempvar key = new Uint256(1, 2);
    tempvar address = 'evm_address';
    with state {
        let account = State.get_account('evm_address');
        let (account, value) = Account.read_storage(account, key);
        State.update_account(account);

        // When
        let result = State.is_storage_warm(address, key);
    }

    // Then
    assert result = 1;
    return ();
}

func test__is_storage_warm__should_return_true_when_already_written{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    let state = State.init();
    tempvar key = new Uint256(1, 2);
    tempvar address = 'evm_address';
    tempvar value = new Uint256(2, 3);
    with state {
        let account = State.get_account('evm_address');
        let account = Account.write_storage(account, key, value);
        State.update_account(account);

        // When
        let result = State.is_storage_warm(address, key);
    }

    // Then
    assert result = 1;
    return ();
}

func test__is_storage_warm__should_return_false_when_not_accessed{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    let state = State.init();
    tempvar address = 'evm_address';
    tempvar key = new Uint256(1, 2);

    // When
    with state {
        let result = State.is_storage_warm(address, key);
    }
    // Then
    assert result = 0;
    return ();
}
