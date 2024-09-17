import pytest
import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy as deploy_kakarot
from kakarot_scripts.utils.starknet import deploy as deploy_starknet
from kakarot_scripts.utils.starknet import get_contract as get_contract_starknet
from kakarot_scripts.utils.starknet import invoke
from tests.utils.errors import cairo_error


@pytest_asyncio.fixture()
async def starknet_token(owner):
    address = (
        await deploy_starknet(
            "StarknetToken", int(1e18), owner.starknet_contract.address
        )
    )["address"]
    return get_contract_starknet("StarknetToken", address=address)


@pytest_asyncio.fixture()
async def dual_vm_token(kakarot, starknet_token, owner):
    dual_vm_token = await deploy_kakarot(
        "CairoPrecompiles",
        "DualVmToken",
        kakarot.address,
        starknet_token.address,
        caller_eoa=owner.starknet_contract,
    )

    await invoke(
        "kakarot",
        "set_authorized_cairo_precompile_caller",
        int(dual_vm_token.address, 16),
        True,
    )
    return dual_vm_token


@pytest.mark.asyncio(scope="module")
@pytest.mark.CairoPrecompiles
class TestDualVmToken:
    class TestMetadata:
        async def test_should_return_name(self, starknet_token, dual_vm_token):
            (name_starknet,) = await starknet_token.functions["name"].call()
            name_evm = await dual_vm_token.name()
            assert name_starknet == name_evm

        async def test_should_return_symbol(self, starknet_token, dual_vm_token):
            (symbol_starknet,) = await starknet_token.functions["symbol"].call()
            symbol_evm = await dual_vm_token.symbol()
            assert symbol_starknet == symbol_evm

        async def test_should_return_decimals(self, starknet_token, dual_vm_token):
            (decimals_starknet,) = await starknet_token.functions["decimals"].call()
            decimals_evm = await dual_vm_token.decimals()
            assert decimals_starknet == decimals_evm

    class TestAccounting:

        async def test_should_return_total_supply(self, starknet_token, dual_vm_token):
            (total_supply_starknet,) = await starknet_token.functions[
                "total_supply"
            ].call()
            total_supply_evm = await dual_vm_token.totalSupply()
            assert total_supply_starknet == total_supply_evm

        async def test_should_return_balance_of(
            self, starknet_token, dual_vm_token, owner
        ):
            (balance_owner_starknet,) = await starknet_token.functions[
                "balance_of"
            ].call(owner.starknet_contract.address)
            balance_owner_evm = await dual_vm_token.balanceOf(owner.address)
            assert balance_owner_starknet == balance_owner_evm

    class TestActions:
        async def test_should_transfer(
            self, starknet_token, dual_vm_token, owner, other
        ):
            amount = 1
            balance_owner_before = await dual_vm_token.balanceOf(owner.address)
            balance_other_before = await dual_vm_token.balanceOf(other.address)
            receipt = (await dual_vm_token.transfer(other.address, amount))["receipt"]
            events = dual_vm_token.events.parse_events(receipt)
            assert events["Transfer"] == [
                {
                    "from": str(owner.address),
                    "to": str(other.address),
                    "amount": amount,
                }
            ]
            balance_owner_after = await dual_vm_token.balanceOf(owner.address)
            balance_other_after = await dual_vm_token.balanceOf(other.address)

            assert balance_owner_before - amount == balance_owner_after
            assert balance_other_before + amount == balance_other_after

        async def test_should_approve(
            self, starknet_token, dual_vm_token, owner, other
        ):
            amount = 1
            allowance_before = await dual_vm_token.allowance(
                owner.address, other.address
            )
            receipt = (await dual_vm_token.approve(other.address, amount))["receipt"]
            events = dual_vm_token.events.parse_events(receipt)
            assert events["Approval"] == [
                {
                    "owner": str(owner.address),
                    "spender": str(other.address),
                    "amount": amount,
                }
            ]
            allowance_after = await dual_vm_token.allowance(
                owner.address, other.address
            )
            assert allowance_after == allowance_before + amount

        async def test_should_transfer_from(
            self, starknet_token, dual_vm_token, owner, other
        ):
            amount = 1
            balance_owner_before = await dual_vm_token.balanceOf(owner.address)
            balance_other_before = await dual_vm_token.balanceOf(other.address)
            await dual_vm_token.approve(other.address, amount)
            receipt = (
                await dual_vm_token.transferFrom(
                    owner.address,
                    other.address,
                    amount,
                    caller_eoa=other.starknet_contract,
                )
            )["receipt"]
            events = dual_vm_token.events.parse_events(receipt)
            assert events["Transfer"] == [
                {
                    "from": str(owner.address),
                    "to": str(other.address),
                    "amount": amount,
                }
            ]
            balance_owner_after = await dual_vm_token.balanceOf(owner.address)
            balance_other_after = await dual_vm_token.balanceOf(other.address)

            assert balance_owner_before - amount == balance_owner_after
            assert balance_other_before + amount == balance_other_after

        async def test_should_revert_tx_cairo_precompiles(
            self, starknet_token, dual_vm_token, owner, other
        ):
            with cairo_error(
                "EVM tx reverted, reverting SN tx because of previous calls to cairo precompiles"
            ):
                await dual_vm_token.transfer(
                    other.address, 1, gas_limit=45_000
                )  # fails with out of gas

    class TestIntegrationUniswap:
        async def test_should_add_liquidity_and_swap(
            starknet_token, dual_vm_token, token_a, router, owner, other
        ):
            amount_a_desired = 1000 * await token_a.decimals()
            amount_dual_vm_token_desired = 500 * await dual_vm_token.decimals()

            await token_a.mint(owner.address, amount_a_desired)
            await token_a.approve(
                router.address, amount_a_desired * 2, caller_eoa=owner.starknet_contract
            )
            await dual_vm_token.approve(
                router.address,
                amount_dual_vm_token_desired * 2,
                caller_eoa=owner.starknet_contract,
            )

            deadline = 99999999999
            to_address = owner.address
            success = (
                await router.addLiquidity(
                    token_a.address,
                    dual_vm_token.address,
                    amount_a_desired,
                    amount_dual_vm_token_desired,
                    0,
                    0,
                    to_address,
                    deadline,
                    caller_eoa=owner.starknet_contract,
                )
            )["success"]

            assert success == 1

            amount_dual_vm_token_desired = 5 * await dual_vm_token.decimals()

            balance_other_before = await dual_vm_token.balanceOf(other.address)
            amount_in_max = 2**128
            success = (
                await router.swapTokensForExactTokens(
                    amount_dual_vm_token_desired,
                    amount_in_max,
                    [token_a.address, dual_vm_token.address],
                    other.address,
                    deadline,
                    caller_eoa=owner.starknet_contract,
                )
            )["success"]
            assert success == 1

            balance_other_after = await dual_vm_token.balanceOf(other.address)
            assert (
                balance_other_before + amount_dual_vm_token_desired
                == balance_other_after
            )
