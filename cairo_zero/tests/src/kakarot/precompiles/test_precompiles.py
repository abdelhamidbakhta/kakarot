import pytest
from starkware.starknet.public.abi import get_selector_from_name

from tests.utils.constants import (
    CAIRO_PRECOMPILE_GAS,
    ETHEREUM_PRECOMPILES,
    KAKAROT_PRECOMPILES,
    ROLLUP_PRECOMPILES,
)
from tests.utils.syscall_handler import SyscallHandler

AUTHORIZED_CALLER_ADDRESS = 0xA7071ED
UNAUTHORIZED_CALLER_ADDRESS = 0xC0C0C0
CALLER_ADDRESS = 0x123ABC432


class TestPrecompiles:
    class TestRun:

        class TestEthereumPrecompiles:
            @pytest.mark.parametrize(
                "address, error_message",
                [
                    (0x0, "Kakarot: UnknownPrecompile 0"),
                    (0x5, "Kakarot: NotImplementedPrecompile 5"),
                    (0x8, "Kakarot: NotImplementedPrecompile 8"),
                    (0x0A, "Kakarot: NotImplementedPrecompile 10"),
                ],
            )
            def test__precompiles_run_should_fail(
                self, cairo_run, address, error_message
            ):
                return_data, reverted, _ = cairo_run(
                    "test__precompiles_run",
                    address=address,
                    input=[],
                    message_address=address,
                )
                assert bytes(return_data).decode() == error_message
                assert reverted

        class TestRollupPrecompiles:
            # input data from <https://github.com/ulerdogan/go-ethereum/blob/75062a6998e4e3fbb4cdb623b8b02e79e7b8f965/core/vm/contracts_test.go#L401-L410>
            @pytest.mark.parametrize(
                "address, input_data, expected_return_data",
                [
                    (
                        0x100,
                        bytes.fromhex(
                            "4cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4da73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d604aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff37618b065f9832de4ca6ca971a7a1adc826d0f7c00181a5fb2ddf79ae00b4e10e"
                        ),
                        [0] * 31 + [1],
                    ),
                    (
                        0x100,
                        bytes.fromhex(
                            "5cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4da73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d604aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff37618b065f9832de4ca6ca971a7a1adc826d0f7c00181a5fb2ddf79ae00b4e10e"
                        ),
                        [],
                    ),
                ],
            )
            def test__p256_verify_precompile(
                self, cairo_run, address, input_data, expected_return_data
            ):
                return_data, reverted, gas_used = cairo_run(
                    "test__precompiles_run",
                    address=address,
                    input=input_data,
                    message_address=address,
                )
                assert not reverted
                assert return_data == expected_return_data
                assert gas_used == 3450

        class TestKakarotPrecompiles:
            @SyscallHandler.patch(
                "Kakarot_authorized_cairo_precompiles_callers",
                AUTHORIZED_CALLER_ADDRESS,
                1,
            )
            @SyscallHandler.patch("deploy", lambda *_: [0])
            @SyscallHandler.patch("Kakarot_evm_to_starknet_address", CALLER_ADDRESS, 0)
            @SyscallHandler.patch("ICairo.inc", lambda *_: [])
            def test_should_deploy_account_when_sender_starknet_address_zero(
                self,
                cairo_run,
            ):
                """
                Tests the behavior when the `msg.sender` in the contract that calls the precompile resolves
                to a zero starknet address (meaning - it's not deployed yet).
                """
                return_data, reverted, gas_used = cairo_run(
                    "test__precompiles_run",
                    address=0x75001,
                    input=bytes.fromhex(
                        f"{0xc0de:064x}"
                        + f"{get_selector_from_name('inc'):064x}"
                        + f"{0x60:064x}"  # data_offset
                        + f"{0x00:064x}"  # data_len
                    ),
                    caller_address=AUTHORIZED_CALLER_ADDRESS,
                    message_address=0x75001,
                )
                assert not bool(reverted)
                assert bytes(return_data) == b""
                assert gas_used == CAIRO_PRECOMPILE_GAS

                assert SyscallHandler.mock_deploy.call_count == 1

            @SyscallHandler.patch(
                "Kakarot_authorized_cairo_precompiles_callers",
                AUTHORIZED_CALLER_ADDRESS,
                1,
            )
            @SyscallHandler.patch(
                "Kakarot_evm_to_starknet_address", CALLER_ADDRESS, 0x1234
            )
            @SyscallHandler.patch("deploy", lambda *_: [0])
            @pytest.mark.parametrize(
                "address, caller_address, input_data, expected_return_data, expected_reverted",
                [
                    (
                        0x75001,
                        AUTHORIZED_CALLER_ADDRESS,
                        bytes.fromhex("0abcdef0"),
                        b"Kakarot: OutOfBoundsRead",
                        True,
                    ),  # invalid input
                    (
                        0x75001,
                        AUTHORIZED_CALLER_ADDRESS,
                        bytes.fromhex(
                            f"{0xc0de:064x}"
                            + f"{get_selector_from_name('inc'):064x}"
                            + f"{0x60:064x}"  # data_offset
                            + f"{0x00:064x}"  # data_len
                        ),
                        b"",
                        False,
                    ),  # call_contract
                    (
                        0x75001,
                        AUTHORIZED_CALLER_ADDRESS,
                        bytes.fromhex(
                            f"{0xc0de:064x}"
                            + f"{get_selector_from_name('get'):064x}"
                            + f"{0x60:064x}"  # data_offset
                            + f"{0x01:064x}"  # data_len
                            + f"{0x01:064x}"  # data
                        ),
                        bytes.fromhex(f"{0x01:064x}"),
                        False,
                    ),  # call_contract with return data
                    (
                        0x75001,
                        UNAUTHORIZED_CALLER_ADDRESS,
                        bytes.fromhex("0abcdef0"),
                        b"Kakarot: unauthorizedPrecompile",
                        True,
                    ),  # invalid caller
                ],
                ids=[
                    "invalid_input",
                    "call_contract",
                    "call_contract_w_returndata",
                    "invalid_caller",
                ],
            )
            def test__cairo_precompiles(
                self,
                cairo_run,
                address,
                caller_address,
                input_data,
                expected_return_data,
                expected_reverted,
            ):
                # The expected returndata is a list of 32-byte words where each word is a felt returned by the precompile.
                cairo_return_data = [
                    int.from_bytes(expected_return_data[i : i + 32], "big")
                    for i in range(0, len(expected_return_data), 32)
                ]
                with SyscallHandler.patch(
                    "ICairo.inc",
                    lambda *_: [],
                ), SyscallHandler.patch(
                    "ICairo.get",
                    lambda *_: cairo_return_data,
                ):
                    return_data, reverted, gas_used = cairo_run(
                        "test__precompiles_run",
                        address=address,
                        input=input_data,
                        caller_address=caller_address,
                        message_address=address,
                    )
                assert bool(reverted) == expected_reverted
                assert bytes(return_data) == expected_return_data
                assert gas_used == (
                    CAIRO_PRECOMPILE_GAS
                    if caller_address == AUTHORIZED_CALLER_ADDRESS
                    else 0
                )
                return

    class TestIsPrecompile:
        @pytest.mark.parametrize("address", range(0, ETHEREUM_PRECOMPILES[-1] + 2))
        def test__is_precompile_ethereum_precompiles(self, cairo_run, address):
            result = cairo_run("test__is_precompile", address=address)
            assert result == (address in ETHEREUM_PRECOMPILES)

        @pytest.mark.parametrize(
            "address",
            range(ROLLUP_PRECOMPILES[0], ROLLUP_PRECOMPILES[-1] + 2),
        )
        def test__is_precompile_rollup_precompiles(self, cairo_run, address):
            result = cairo_run("test__is_precompile", address=address)
            assert result == (address in ROLLUP_PRECOMPILES)

        @pytest.mark.parametrize(
            "address",
            [
                KAKAROT_PRECOMPILES[0] - 1,
                *KAKAROT_PRECOMPILES,
                KAKAROT_PRECOMPILES[-1] + 1,
            ],
        )
        def test__is_precompile_kakarot_precompiles(self, cairo_run, address):
            result = cairo_run("test__is_precompile", address=address)
            assert result == (address in KAKAROT_PRECOMPILES)
