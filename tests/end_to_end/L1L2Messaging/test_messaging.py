import asyncio

import pytest

from kakarot_scripts.utils.l1 import (
    dump_l1_addresses,
    get_l1_addresses,
    get_l1_contract,
    l1_contract_exists,
)
from kakarot_scripts.utils.starknet import get_deployments


@pytest.fixture(scope="session")
async def sn_messaging_local(deploy_l1_contract, owner):
    # If the contract is already deployed on the l1, we can get the address from the deployments file
    # Otherwise, we deploy it
    l1_addresses = get_l1_addresses()
    if l1_addresses.get("StarknetMessagingLocal"):
        address = l1_addresses["StarknetMessagingLocal"]["address"]
        if l1_contract_exists(address):
            return get_l1_contract("starknet", "StarknetMessagingLocal", address)

    contract = await deploy_l1_contract(
        "starknet",
        "StarknetMessagingLocal",
    )
    l1_addresses.update({"StarknetMessagingLocal": {"address": contract.address}})
    dump_l1_addresses(l1_addresses)
    return contract


@pytest.fixture(scope="session")
async def message_sender_l2(deploy_contract, owner):
    message_sender = await deploy_contract(
        "L1L2Messaging",
        "MessageAppL2",
        caller_eoa=owner.starknet_contract,
    )
    return message_sender


@pytest.fixture(scope="session")
async def message_consumer_test(deploy_l1_contract, sn_messaging_local):
    kakarot_address = get_deployments()["kakarot"]["address"]
    return await deploy_l1_contract(
        "L1L2Messaging",
        "MessageAppL1",
        sn_messaging_local.address,
        kakarot_address,
    )


async def wait_for_message(sn_messaging_local):
    event_filter = sn_messaging_local.events.MessageHashesAddedFromL2.create_filter(
        fromBlock="latest"
    )
    while True:
        messages = event_filter.get_new_entries()
        if messages:
            return messages
        await asyncio.sleep(3)


async def test_should_send_message_to_l1(
    sn_messaging_local, message_consumer_test, message_sender_l2
):
    await message_sender_l2.sendMessageToL1(message_consumer_test.address, 42)
    await wait_for_message(sn_messaging_local)
    await message_consumer_test.consumeMessage([42])
