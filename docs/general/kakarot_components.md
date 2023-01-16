# Kakarot Components and Deployment

The entire Kakarot protocol is composed of 4 different contracts:

- Kakarot (Core)
- Contract Accounts
- Account Registry
- Blockhash Registry

## Kakarot

The main Kakarot contract is located at: `./src/kakarot/kakarot.cairo`.

This is the core contract which is capable of parsing and executing ethereum bytecode.

Its functionality is accessed via two functions:

- `deploy(bytecode_len: felt, bytecode: felt*)`: Deploys a new contract (a *Contract Account*) that is initialized using the bytecode that is accompanied with the method call as a parameter.

- `execute_at_address(address: felt, value: felt, gas_limit: felt, calldata_len: felt, calldata: felt*)`: Executes the code held by a previously deployed *Account Contract*.

## Contract Accounts

A *Contract Account* is a StarkNet contract. However, it also acts as an Ethereum style contract account within the Kakarot EVM.
In isolation it is not more than a StarkNet contract that stores some bytecode as well as some key-value pairs which were assigned to it on creation.
It is only addressable via its StarkNet address and not an EVM address (which it is associated with inside the Kakarot EVM).

## Account Registry

The account registry contract maps StarkNet addresses of deployed *Contract Accounts* to their EVM addresses (which are their identifiers within the Kakarot EVM).

The mapping is created on deployment of the *Contract Account* by the core Kakarot contract (after its EVM address is computed).

When the Kakarot core contract needs to execute a *Contract Accounts* bytecode or needs to write/read its storage it will use the account registry contract to convert its EVM address to the StarkNet address. Using the StarkNet address it is now capable of addressing the *Contract Accounts* methods.

## Blockhash Registry

The EVM computes a hash from the contents of each created block (the so called *blockhash*).

As Kakarot core is not aware of which transactions are within one block, it cannot compute the hash itself.
However, Kakarot needs to be able to access the blockhash for a given block number in order to be EVM compatible. 

The blockhash registry enables this by holding a `block_number -> block_hash` mapping that admins can write to and Kakarot core can read from.

## Deploying Kakarot

With the above information in mind the Kakarot EVM can be deployed and configured on StarkNet with the following steps:

1. Declare the *Contract Account*.

This generates a class hash which will be used by the core Kakarot contract to deploy *Contract Accounts*.

2. Deploy Kakarot (core), with the following constructor arguments:
- StarkNet address of the owner/admin account that controls the Kakarot core contract.
- Address of the ETH token contract (Which is also used as ether within the Kakarot EVM)
- *Contract Account* class hash.

3. Deploy Account Registry

4. Deploy Blockhash Registry

5. Store the addresses of the account and blockhash registry contracts in Kakarot core using `set_account_registry` and `set_blockhash_registry` respectively. This is required for Kakarot to access the functionality of the registries.
