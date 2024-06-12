import pytest


@pytest.fixture(scope="session")
def deploy_l1_contract():
    """
    Fixture to deploy and attach a modified web3.contract instance to a contract on L1.
    """

    from kakarot_scripts.utils.l1 import deploy_on_l1

    async def _factory(contract_app, contract_name, *args, **kwargs):
        """
        Create a web3.contract based on the basename of the target solidity file.
        """
        return await deploy_on_l1(contract_app, contract_name, *args, **kwargs)

    return _factory
