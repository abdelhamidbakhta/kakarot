from asyncio import run
from contextlib import contextmanager
from dataclasses import dataclass
from typing import List, Tuple
from unittest import IsolatedAsyncioTestCase

from cairo_coverage import cairo_coverage
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException


@dataclass
class Uint256:
    """Uint256 dataclass to ease the asserting process"""

    __slots__ = ("low", "high")
    low: int  # 2**128 low bits
    high: int  # 2**128 high bits

    def __eq__(self, __o: object) -> bool:
        """__eq__ method allows to do a == b (a and b being Uints256)"""
        return self.low == __o.low and self.high == __o.high

    def __str__(self):
        return str(self.low + self.high * 2**128)


def hex_string_to_int_array(text):
    return [int(text[i : i + 2], 16) for i in range(0, len(text), 2)]


def get_case(case: str) -> Tuple[List[int], List[int]]:
    from json import load

    with open(case, "r") as f:
        test_case_data = load(f)
    return (
        hex_string_to_int_array(test_case_data["code"]),
        hex_string_to_int_array(test_case_data["calldata"]),
    )


class TestBasic(IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        async def _setUpClass(cls) -> None:
            cls.starknet = await Starknet.empty()
            cls.starknet.state.state.update_block_info(
                BlockInfo.create_for_testing(block_number=1, block_timestamp=1)
            )
            await cls.coverageSetupClass(cls)

        run(_setUpClass(cls))

    async def coverageSetupClass(cls):
        cls.eth = await cls.starknet.deploy(
            source="./tests/utils/ERC20.cairo",
            constructor_calldata=[2] * 6,
        )
        cls.zk_evm = await cls.starknet.deploy(
            source="./src/kakarot/kakarot.cairo",
            cairo_path=["src"],
            disable_hint_validation=True,
            constructor_calldata=[1, cls.eth.contract_address],
        )
        cls.registry = await cls.starknet.deploy(
            source="./src/kakarot/accounts/registry/account_registry.cairo",
            cairo_path=["src"],
            disable_hint_validation=True,
            constructor_calldata=[cls.zk_evm.contract_address],
        )
        await cls.zk_evm.set_account_registry(
            registry_address_=cls.registry.contract_address
        ).execute(caller_address=1)

    @classmethod
    def tearDownClass(cls):
        cairo_coverage.report_runs(excluded_file={"site-packages"})

    @contextmanager
    def raisesStarknetError(self, error_message):
        with self.assertRaises(StarkException) as error_msg:
            yield error_msg
        self.assertTrue(
            f"Error message: {error_message}" in str(error_msg.exception.message)
        )

    async def assert_compare(self, case: str, expected: Uint256):
        code, calldata = get_case(case=f"./tests/cases/003{case}.json")

        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, expected)
        self.assertListEqual(res.result.memory, [])

    async def test_arithmetic_operation(self):
        code, calldata = get_case(case="./tests/cases/001.json")

        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(16, 0))
        self.assertListEqual(res.result.memory, [])

    async def test_comparison_operations(self):
        # lt
        await self.assert_compare("_lt", Uint256(0, 0))
        # gt
        await self.assert_compare("_gt", Uint256(1, 0))
        # slt
        await self.assert_compare("_slt", Uint256(1, 0))
        # sgt
        await self.assert_compare("_sgt", Uint256(0, 0))
        # eq
        await self.assert_compare("_eq", Uint256(0, 0))
        # iszero
        await self.assert_compare("_iszero", Uint256(1, 0))

    async def test_bitwise_operations(self):

        ##############
        # SHIFT LEFT #
        ##############
        await self.assert_compare("/shl/1", Uint256(1, 0))
        await self.assert_compare("/shl/2", Uint256(2, 0))
        await self.assert_compare(
            "/shl/3", Uint256(0, 0x80000000000000000000000000000000)
        )
        await self.assert_compare("/shl/4", Uint256(0, 0))
        await self.assert_compare("/shl/5", Uint256(0, 0))
        await self.assert_compare(
            "/shl/6",
            Uint256(
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            ),
        )
        await self.assert_compare(
            "/shl/7",
            Uint256(
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE,
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            ),
        )
        await self.assert_compare(
            "/shl/8", Uint256(0, 0x80000000000000000000000000000000)
        )
        await self.assert_compare("/shl/9", Uint256(0, 0))
        await self.assert_compare("/shl/10", Uint256(0, 0))
        await self.assert_compare(
            "/shl/11",
            Uint256(
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE,
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            ),
        )

        ###############
        # SHIFT RIGHT #
        ###############

        await self.assert_compare("/shr/1", Uint256(1, 0))
        await self.assert_compare("/shr/2", Uint256(0, 0))
        await self.assert_compare(
            "/shr/3", Uint256(0, 0x40000000000000000000000000000000)
        )
        await self.assert_compare("/shr/4", Uint256(1, 0))
        await self.assert_compare("/shr/5", Uint256(0, 0))
        await self.assert_compare("/shr/6", Uint256(0, 0))
        await self.assert_compare(
            "/shr/7",
            Uint256(
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            ),
        )
        await self.assert_compare(
            "/shr/8",
            Uint256(
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            ),
        )
        await self.assert_compare("/shr/9", Uint256(1, 0))
        await self.assert_compare("/shr/10", Uint256(0, 0))
        await self.assert_compare("/shr/11", Uint256(0, 0))

        ##########################
        # SHIFT ARITHMETIC RIGHT #
        ##########################
        # https://eips.ethereum.org/EIPS/eip-145

        await self.assert_compare("/sar/1", Uint256(1, 0))
        await self.assert_compare("/sar/2", Uint256(0, 0))
        await self.assert_compare(
            "/sar/3", Uint256(0, 0xC0000000000000000000000000000000)
        )
        await self.assert_compare(
            "/sar/4",
            Uint256(
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            ),
        )
        await self.assert_compare(
            "/sar/5",
            Uint256(
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            ),
        )
        await self.assert_compare(
            "/sar/6",
            Uint256(
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            ),
        )
        await self.assert_compare(
            "/sar/7",
            Uint256(
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            ),
        )
        await self.assert_compare(
            "/sar/8",
            Uint256(
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            ),
        )
        await self.assert_compare(
            "/sar/9",
            Uint256(
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            ),
        )
        await self.assert_compare(
            "/sar/10",
            Uint256(
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            ),
        )
        await self.assert_compare("/sar/11", Uint256(0x0, 0x0))
        await self.assert_compare("/sar/12", Uint256(0x1, 0x0))
        await self.assert_compare("/sar/13", Uint256(0x7F, 0x0))
        await self.assert_compare("/sar/14", Uint256(0x1, 0x0))
        await self.assert_compare("/sar/15", Uint256(0x0, 0x0))
        await self.assert_compare("/sar/16", Uint256(0x0, 0x0))

        ###############
        #     NOT     #
        ###############
        await self.assert_compare(
            "_not",
            Uint256(
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            ),
        )

    async def test_duplication_operations(self):
        code, calldata = get_case(case="./tests/cases/002.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(3, 0))
        self.assertListEqual(res.result.memory, [])

    async def test_memory_operation(self):
        code, calldata = get_case(case="./tests/cases/memory/001.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(0, 0))
        self.assertListEqual(res.result.memory, [*[0] * 31, 10])

        # 0 offset stores 0x0a then 36 offset stores 0xfa
        code, calldata = get_case(case="./tests/cases/memory/002.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(0, 0))
        self.assertListEqual(
            res.result.memory,
            [
                *[0] * 31,  # leading 0s
                10,
                *[0] * 35,  # 36 offset + 31 leading 0s = 32 + 35
                250,
            ],
        )
        # Testing when initial offset if higher than 32 bytes (0x40 for the test)
        code, calldata = get_case(case="./tests/cases/memory/009.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(0, 0))
        self.assertListEqual(
            res.result.memory,
            [
                *[0] * 95,
                17,
            ],  # leading 0s
        )
        # Checking when data is saved on already saved memory location
        code, calldata = get_case(case="./tests/cases/memory/010.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(0, 0))
        self.assertListEqual(
            res.result.memory,
            [
                *[0] * 95,
                34,
            ],  # 0x40 offset
        )
        # Checking when data is saved on already saved memory location
        code, calldata = get_case(case="./tests/cases/memory/010.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(0, 0))
        self.assertListEqual(
            res.result.memory,
            [
                *[0] * 95,
                34,
            ],  # 0x40 offset
        )

        # Checking saving memory with 30 bytes or more
        code, calldata = get_case(case="./tests/cases/memory/011.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(0, 0))
        self.assertListEqual(
            res.result.memory,
            [
                *[0] * 2,  # offset 0x00 for 30 Bytes data
                *[17] * 30,
            ],
        )

        # Checking when data is saved on already saved memory location
        code, calldata = get_case(case="./tests/cases/memory/012.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(0, 0))
        self.assertListEqual(
            res.result.memory,
            [*[0] * 84, 17, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255],
        )

        # PC
        code, calldata = get_case(case="./tests/cases/memory/003.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(3, 0))
        self.assertListEqual(res.result.memory, [])

        # MEMORY SIZE
        code, calldata = get_case(case="./tests/cases/memory/004.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(0, 0))
        self.assertListEqual(res.result.memory, [])

        # MLOAD
        code, calldata = get_case(case="./tests/cases/memory/005.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(10, 0))
        self.assertListEqual(res.result.memory, [*[0] * 31, 10])

        # JUMPDEST
        code, calldata = get_case(case="./tests/cases/memory/006.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )

        self.assertEqual(res.result.top_stack, Uint256(8, 0))
        self.assertListEqual(res.result.memory, [])

        # JUMP
        code, calldata = get_case(case="./tests/cases/memory/007.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )

        self.assertEqual(res.result.top_stack, Uint256(11, 0))
        self.assertListEqual(res.result.memory, [])

        # JUMPI
        code, calldata = get_case(case="./tests/cases/memory/008.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )

        self.assertEqual(res.result.top_stack, Uint256(20, 0))
        self.assertListEqual(res.result.memory, [])

        # MSTORE8
        code, calldata = get_case(case="./tests/cases/025.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(caller_address=1)
        self.assertEqual(res.result.top_stack, Uint256(0, 0))
        self.assertEqual(res.result.top_memory, Uint256(255, 0))

    async def test_exchange_operations(self):
        code, calldata = get_case(case="./tests/cases/005.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(4, 0))
        self.assertListEqual(res.result.memory, [])

    async def test_environmental_information(self):
        # CODESIZE
        code, calldata = get_case(case="./tests/cases/006.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(7, 0))
        self.assertListEqual(res.result.memory, [])

        # CALLER
        code, calldata = get_case(case="./tests/cases/012.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(1, 0))
        self.assertListEqual(res.result.memory, [])

        code, calldata = get_case(case="./tests/cases/017.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(0, 0))
        self.assertListEqual(res.result.memory, [])

        # CALLDATASIZE
        code, calldata = get_case(case="./tests/cases/024.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(0, 0))
        self.assertListEqual(res.result.memory, [])

        # BALANCE
        code, calldata = get_case(case="./tests/cases/balance.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(0, 0))
        self.assertListEqual(res.result.memory, [])

    async def test_system_operations(self):
        code, calldata = get_case(case="./tests/cases/009.json")
        with self.raisesStarknetError("Kakarot: 0xFE: Invalid Opcode"):
            await self.zk_evm.execute(code=code, calldata=calldata).execute(
                caller_address=1
            )

    async def test_block_information(self):
        # chain id
        code, calldata = get_case(case="./tests/cases/007.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(1263227476, 0))
        self.assertListEqual(res.result.memory, [])

        # coinbase
        code, calldata = get_case(case="./tests/cases/008.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        # 0x388ca486b82e20cc81965d056b4cdcaacdffe0cf08e20ed8ba10ea97a487004
        # default config sequencer address
        self.assertEqual(
            res.result.top_stack,
            Uint256(
                229790250231684299717252079072141930500,
                4697939144556246738688061959621103050,
            ),
        )
        self.assertListEqual(res.result.memory, [])

        # block_number
        code, calldata = get_case(case="./tests/cases/010.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(1, 0))
        self.assertListEqual(res.result.memory, [])

        # block_timestamp
        code, calldata = get_case(case="./tests/cases/011.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(1, 0))
        self.assertListEqual(res.result.memory, [])

        # gas limit
        code, calldata = get_case(case="./tests/cases/015.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(0, 0))
        self.assertListEqual(res.result.memory, [])

        # difficulty
        code, calldata = get_case(case="./tests/cases/021.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(0, 0))
        self.assertListEqual(res.result.memory, [])

        # basefee
        code, calldata = get_case(case="./tests/cases/023.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(0, 0))
        self.assertListEqual(res.result.memory, [])

    async def test_sha3(self):
        code, calldata = get_case(case="./tests/cases/013/sha3.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )
        # keccak(0000000000000000000000000000000000000000000000000000000000000100)
        # <=>
        #  0x45e010b9ae401e2eb71529478da8bd513a9bdc2d095a111e324f5b95c09ed87b
        self.assertEqual(
            res.result.top_stack,
            Uint256(
                77904495466872384669646666695347984507,
                92880145435162625678889344074777148753,
            ),
        )
        self.assertListEqual(res.result.memory, [*[0] * 30, 1, 0])

        code, calldata = get_case(case="./tests/cases/013/sha3prime.json")
        res = await self.zk_evm.execute(code=code, calldata=calldata).execute(
            caller_address=1
        )

        # keccak(10)
        # <=>
        #  0x967f2a2c7f3d22f9278175c1e6aa39cf9171db91dceacd5ee0f37c2e507b5abe
        self.assertListEqual(res.result.memory, [*[0] * 31, 16])
        self.assertEqual(
            res.result.top_stack,
            Uint256(
                193329242337984562015045870912253156030,
                200044476455392313921036785920804272591,
            ),
        )
