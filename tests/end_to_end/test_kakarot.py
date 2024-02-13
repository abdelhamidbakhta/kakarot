import logging
import random

import pytest
import pytest_asyncio
from starknet_py.contract import Contract
from starknet_py.net.full_node_client import FullNodeClient

from tests.end_to_end.bytecodes import test_cases
from tests.utils.constants import PRE_FUND_AMOUNT
from tests.utils.helpers import (
    extract_memory_from_execute,
    generate_random_evm_address,
    hex_string_to_bytes_array,
)
from tests.utils.reporting import traceit

params_execute = [pytest.param(case.pop("params"), **case) for case in test_cases]


logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


@pytest.fixture(scope="session")
def evm(get_contract):
    """
    Return a cached EVM contract.
    """

    return get_contract("EVM")


@pytest.fixture(scope="session")
async def other():
    """
    Just another Starknet contract.
    """
    from scripts.utils.starknet import deploy_starknet_account, get_starknet_account

    account_info = await deploy_starknet_account()
    return await get_starknet_account(account_info["address"])


@pytest.fixture(scope="session")
async def class_hashes():
    """
    All declared class hashes.
    """
    from scripts.utils.starknet import get_declarations

    return get_declarations()


@pytest_asyncio.fixture(scope="session")
async def origin(evm: Contract, addresses):
    """
    Deploys the origin's Starknet contract to the correct address and funds it.
    """
    from scripts.utils.starknet import fund_address

    evm_address = int(addresses[0].address, 16)
    sn_address = (
        await evm.functions["compute_starknet_address"].call(evm_address)
    ).contract_address
    await fund_address(sn_address, 10)
    return evm_address


@pytest.mark.asyncio
class TestKakarot:
    class TestEVM:
        @pytest.mark.parametrize(
            "params",
            params_execute,
        )
        async def test_execute(
            self,
            starknet: FullNodeClient,
            eth: Contract,
            wait_for_transaction,
            params: dict,
            request,
            evm: Contract,
            addresses,
            max_fee,
            origin,
        ):
            with traceit.context(request.node.callspec.id):
                result = await evm.functions["evm_call"].call(
                    origin=origin,
                    value=int(params["value"]),
                    bytecode=hex_string_to_bytes_array(params["code"]),
                    calldata=hex_string_to_bytes_array(params["calldata"]),
                    access_list=[],
                )

            assert result.success == params["success"]
            assert result.stack_values[: result.stack_size] == (
                [
                    int(x)
                    for x in params["stack"]
                    .format(
                        account_address=int(addresses[0].address, 16),
                        timestamp=result.block_timestamp,
                        block_number=result.block_number,
                    )
                    .split(",")
                ]
                if params["stack"]
                else []
            )
            assert bytes(extract_memory_from_execute(result)).hex() == params["memory"]
            assert bytes(result.return_data).hex() == params["return_data"]

            events = params.get("events")
            if events:
                # Events only show up in a transaction, thus we run the same call, but in a tx
                tx = await evm.functions["evm_execute"].invoke(
                    origin=origin,
                    value=int(params["value"]),
                    bytecode=hex_string_to_bytes_array(params["code"]),
                    calldata=hex_string_to_bytes_array(params["calldata"]),
                    max_fee=max_fee,
                    access_list=[],
                )
                status = await wait_for_transaction(tx.hash)
                assert status == "✅"
                receipt = await starknet.get_transaction_receipt(tx.hash)
                assert [
                    [
                        # we remove the key that is used to convey the emitting kakarot evm contract
                        event.keys[1:],
                        event.data,
                    ]
                    for event in receipt.events
                    if event.from_address != eth.address
                ] == events

    class TestComputeStarknetAddress:
        async def test_should_return_same_as_deployed_address(
            self, compute_starknet_address, addresses
        ):
            eoa = addresses[0]
            starknet_address = await compute_starknet_address(eoa.address)
            assert eoa.starknet_contract.address == starknet_address

    class TestDeployExternallyOwnedAccount:
        async def test_should_deploy_starknet_contract_at_corresponding_address(
            self,
            fund_starknet_address,
            deploy_externally_owned_account,
            compute_starknet_address,
            get_contract,
        ):
            evm_address = generate_random_evm_address()
            starknet_address = await compute_starknet_address(evm_address)
            await fund_starknet_address(starknet_address, PRE_FUND_AMOUNT / 1e18)

            await deploy_externally_owned_account(evm_address)
            eoa = get_contract("externally_owned_account", address=starknet_address)
            actual_evm_address = (
                await eoa.functions["get_evm_address"].call()
            ).evm_address
            assert actual_evm_address == int(evm_address, 16)

    class TestEthCallNativeCoinTransfer:
        async def test_eth_call_should_succeed(
            self,
            fund_starknet_address,
            deploy_externally_owned_account,
            is_account_deployed,
            compute_starknet_address,
            wait_for_transaction,
            kakarot,
        ):
            seed = random.randint(0, 0x5EED)
            evm_address = generate_random_evm_address(seed=seed)
            while await is_account_deployed(evm_address):
                seed += 1
                evm_address = generate_random_evm_address(seed=seed)

            starknet_address = await compute_starknet_address(evm_address)
            amount = PRE_FUND_AMOUNT / 1e16
            await fund_starknet_address(starknet_address, amount)
            tx = await deploy_externally_owned_account(evm_address)
            status = await wait_for_transaction(tx.hash)
            assert status == "✅"

            result = await kakarot.functions["eth_call"].call(
                origin=int(evm_address, 16),
                to={
                    "is_some": 1,
                    "value": int(generate_random_evm_address(seed=3), 16),
                },
                gas_limit=1_000_000_000,
                gas_price=1_000,
                value=1_000,
                data=bytes(),
                access_list=[],
            )

            logger.info(f"result: {result}")
            assert result.success == 1
            assert result.return_data == []
            assert result.gas_used == 21_000

    class TestUpgrade:

        async def test_should_raise_when_caller_is_not_owner(
            self, starknet, kakarot, invoke, other, class_hashes
        ):
            prev_class_hash = await starknet.get_class_hash_at(kakarot.address)
            await invoke("kakarot", "upgrade", class_hashes["EVM"], account=other)
            new_class_hash = await starknet.get_class_hash_at(kakarot.address)
            assert prev_class_hash == new_class_hash

        async def test_should_raise_when_class_hash_is_not_declared(
            self, starknet, kakarot, invoke
        ):
            prev_class_hash = await starknet.get_class_hash_at(kakarot.address)
            await invoke("kakarot", "upgrade", 0xDEAD)
            new_class_hash = await starknet.get_class_hash_at(kakarot.address)
            assert prev_class_hash == new_class_hash

        async def test_should_upgrade_class_hash(
            self, starknet, kakarot, invoke, class_hashes
        ):
            prev_class_hash = await starknet.get_class_hash_at(kakarot.address)
            await invoke("kakarot", "upgrade", class_hashes["replace_class"])
            new_class_hash = await starknet.get_class_hash_at(kakarot.address)
            assert prev_class_hash != new_class_hash
            assert new_class_hash == class_hashes["replace_class"]
            await invoke("kakarot", "upgrade", prev_class_hash)
