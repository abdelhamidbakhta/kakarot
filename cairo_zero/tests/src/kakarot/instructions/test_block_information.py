from unittest.mock import patch

import pytest

from kakarot_scripts.constants import COINBASE
from tests.utils.constants import (
    BLOCK_GAS_LIMIT,
    CHAIN_ID,
    MIN_BASE_FEE_PER_BLOB_GAS,
    Opcodes,
)
from tests.utils.syscall_handler import SyscallHandler


class TestBlockInformation:
    @pytest.mark.parametrize(
        "opcode,expected_result",
        [
            (Opcodes.COINBASE, COINBASE),
            (Opcodes.TIMESTAMP, 0x1234),
            (Opcodes.NUMBER, SyscallHandler.block_number),
            (Opcodes.PREVRANDAO, 0),
            (Opcodes.GASLIMIT, BLOCK_GAS_LIMIT),
            (Opcodes.CHAINID, CHAIN_ID),
            (Opcodes.BASEFEE, 0),
            (Opcodes.BLOBHASH, 0),
            (Opcodes.BLOBBASEFEE, MIN_BASE_FEE_PER_BLOB_GAS),
        ],
    )
    @SyscallHandler.patch("Kakarot_coinbase", COINBASE)
    @SyscallHandler.patch("Kakarot_block_gas_limit", BLOCK_GAS_LIMIT)
    @SyscallHandler.patch("Kakarot_chain_id", CHAIN_ID)
    @patch.object(SyscallHandler, "block_timestamp", 0x1234)
    def test__exec_block_information(self, cairo_run, opcode, expected_result):
        output = cairo_run("test__exec_block_information", opcode=opcode)
        assert output == hex(expected_result)
