from contextlib import contextmanager
from unittest import IsolatedAsyncioTestCase
from asyncio import run
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo

from cairo_coverage import cairo_coverage


class TestBasic(IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        async def _setUpClass(cls) -> None:
            cls.starknet = await Starknet.empty()
            cls.starknet.state.state.update_block_info(
                BlockInfo.create_for_testing(block_number=1, block_timestamp=1)
            )
            cls.unit_test = await cls.starknet.deploy(
                source="./tests/cairo_files/test_execution_context.cairo",
                cairo_path=["src"],
                disable_hint_validation=True,
            )

        run(_setUpClass(cls))

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

    async def test_everything(self):
        await self.unit_test.test__init__should_return_an_empty_execution_context().call()
        #UPDATE PROGRAM COUNTER
        await self.unit_test.test__update_program_counter__should_set_pc_to_given_value().call()
        with self.raisesStarknetError("Kakarot: new pc target out of range"):
            await self.unit_test.test__update_program_counter__should_fail__when_given_value_not_in_code_range().call()
        with self.raisesStarknetError("Kakarot: JUMPed to pc offset is not JUMPDEST"):
            await self.unit_test.test__update_program_counter__should_fail__when_given_destination_that_is_not_JUMPDEST().call()
        #READ CALLDATA    
        await self.unit_test.test__read_calldata__should_return_parameter_from_calldata().call()
        with self.raisesStarknetError("Kakarot: calldataload offset out of range"):
            await self.unit_test.test__read_calldata__should_fail__when_given_offset_out_of_range().call()
        with self.raisesStarknetError("Kakarot: calldataload offset does not point to start of a calldata parameter"):
            await self.unit_test.test__read_calldata__should_fail__when_providing_invalid_parameter_offset().call()
        with self.raisesStarknetError("Kakarot: calldataload offset does not point to start of a calldata parameter"):
            await self.unit_test.test__read_calldata__should_fail__when_providing_invalid_selector_offset().call()
