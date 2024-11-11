import pytest
import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy, get_eoa
from kakarot_scripts.utils.starknet import get_contract, invoke, wait_for_transaction
from tests.utils.errors import cairo_error


@pytest_asyncio.fixture(scope="module")
async def cairo_counter(max_fee, deployer):
    cairo_counter = get_contract("Counter", provider=deployer)

    yield cairo_counter

    tx = await cairo_counter.functions["set_counter"].invoke_v1(0, max_fee=max_fee)
    await wait_for_transaction(tx.hash)


@pytest_asyncio.fixture(scope="module")
async def cairo_counter_caller(owner, cairo_counter):
    caller_contract = await deploy(
        "CairoPrecompiles",
        "WhitelistedCallCairoPrecompileTest",
        cairo_counter.address,
        caller_eoa=owner.starknet_contract,
    )

    await invoke(
        "kakarot",
        "set_authorized_cairo_precompile_caller",
        int(caller_contract.address, 16),
        True,
    )
    return caller_contract


@pytest_asyncio.fixture(scope="module")
async def sub_context_precompile(owner, cairo_counter_caller):
    sub_context_precompile = await deploy(
        "CairoPrecompiles",
        "SubContextPrecompile",
        cairo_counter_caller.address,
        caller_eoa=owner.starknet_contract,
    )
    return sub_context_precompile


@pytest.mark.asyncio(scope="module")
@pytest.mark.CairoPrecompiles
class TestCairoPrecompiles:
    class TestCounterPrecompiles:
        async def test_should_get_cairo_counter(
            self, cairo_counter, cairo_counter_caller
        ):
            await invoke("Counter", "inc")
            cairo_count = (await cairo_counter.functions["get"].call()).count
            evm_count = await cairo_counter_caller.getCairoCounter()
            assert evm_count == cairo_count == 1

        async def test_should_increase_cairo_counter(
            self, cairo_counter, cairo_counter_caller
        ):
            prev_count = (await cairo_counter.functions["get"].call()).count
            await cairo_counter_caller.incrementCairoCounter()
            new_count = (await cairo_counter.functions["get"].call()).count
            assert new_count == prev_count + 1

        @pytest.mark.parametrize("count", [0, 1, 2**128 - 1, 2**128, 2**256 - 1])
        async def test_should_set_cairo_counter(
            self, cairo_counter, cairo_counter_caller, count
        ):
            await cairo_counter_caller.setCairoCounter(count)
            new_count = (await cairo_counter.functions["get"].call()).count

            assert new_count == count

        async def test_should_fail_precompile_caller_not_whitelisted(
            self, cairo_counter
        ):
            cairo_counter_caller = await deploy(
                "CairoPrecompiles",
                "WhitelistedCallCairoPrecompileTest",
                cairo_counter.address,
            )
            with cairo_error(
                "EVM tx reverted, reverting SN tx because of previous calls to cairo precompiles"
            ):
                await cairo_counter_caller.incrementCairoCounter()

        async def test_last_caller_address_should_be_eoa(self, cairo_counter_caller):
            eoa = await get_eoa()
            await cairo_counter_caller.delegateCallIncrementCairoCounter(caller_eoa=eoa)
            last_caller_address = await cairo_counter_caller.getLastCaller()
            assert last_caller_address == eoa.address

        async def test_should_fail_when_precompiles_called_and_low_level_call_fails(
            self, sub_context_precompile
        ):
            with cairo_error(
                "EVM tx reverted, reverting SN tx because of previous calls to cairo precompiles"
            ):
                await sub_context_precompile.exploitLowLevelCall()

        async def test_should_fail_when_precompiles_called_and_child_context_fails(
            self, sub_context_precompile
        ):
            with cairo_error(
                "EVM tx reverted, reverting SN tx because of previous calls to cairo precompiles"
            ):
                await sub_context_precompile.exploitChildContext()
