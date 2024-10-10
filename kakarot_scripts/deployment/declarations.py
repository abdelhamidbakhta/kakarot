from kakarot_scripts.constants import DECLARED_CONTRACTS
from kakarot_scripts.utils.starknet import declare, dump_declarations


async def declare_contracts():
    class_hash = {contract: await declare(contract) for contract in DECLARED_CONTRACTS}
    dump_declarations(class_hash)
    return class_hash
