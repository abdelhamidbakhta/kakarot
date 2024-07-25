import json
import logging
import os
from enum import Enum, IntEnum
from math import ceil, log
from pathlib import Path

import requests
from dotenv import load_dotenv
from eth_keys import keys
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.models.chains import StarknetChainId
from web3 import Web3

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
load_dotenv()

# Hardcode block gas limit to 7M
BLOCK_GAS_LIMIT = 7_000_000
DEFAULT_GAS_PRICE = int(1e9)
BEACON_ROOT_ADDRESS = "0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02"


class NetworkType(Enum):
    PROD = "prod"
    DEV = "dev"
    STAGING = "staging"


NETWORKS = {
    "mainnet": {
        "name": "mainnet",
        "explorer_url": "https://starkscan.co",
        "rpc_url": f"https://starknet-mainnet.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "l1_rpc_url": f"https://mainnet.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "type": NetworkType.PROD,
        "chain_id": StarknetChainId.MAINNET,
    },
    "sepolia": {
        "name": "starknet-sepolia",
        "explorer_url": "https://sepolia.starkscan.co/",
        "rpc_url": "https://starknet-sepolia.public.blastapi.io/rpc/v0_6",
        "l1_rpc_url": f"https://sepolia.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "type": NetworkType.PROD,
        "chain_id": StarknetChainId.SEPOLIA,
        "check_interval": 5,
        "max_wait": 30,
    },
    "starknet-devnet": {
        "name": "starknet-devnet",
        "explorer_url": "",
        "rpc_url": "http://127.0.0.1:5050/rpc",
        "l1_rpc_url": "http://127.0.0.1:8545",
        "type": NetworkType.DEV,
        "check_interval": 0.01,
        "max_wait": 3,
    },
    "katana": {
        "name": "katana",
        "explorer_url": "",
        "rpc_url": os.getenv("KATANA_RPC_URL", "http://127.0.0.1:5050"),
        "l1_rpc_url": "http://127.0.0.1:8545",
        "type": NetworkType.DEV,
        "check_interval": 0.01,
        "max_wait": 3,
    },
    "madara": {
        "name": "madara",
        "explorer_url": "",
        "rpc_url": os.getenv("MADARA_RPC_URL", "http://127.0.0.1:9944"),
        "l1_rpc_url": "http://127.0.0.1:8545",
        "type": NetworkType.DEV,
        "check_interval": 6,
        "max_wait": 30,
    },
    "sharingan": {
        "name": "sharingan",
        "explorer_url": "",
        "rpc_url": os.getenv("SHARINGAN_RPC_URL"),
        "l1_rpc_url": "http://127.0.0.1:8545",
        "type": NetworkType.PROD,
        "check_interval": 6,
        "max_wait": 30,
    },
    "kakarot-sepolia": {
        "name": "kakarot-sepolia",
        "explorer_url": "",
        "rpc_url": os.getenv("KAKAROT_SEPOLIA_RPC_URL"),
        "l1_rpc_url": f"https://sepolia.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "type": NetworkType.PROD,
        "check_interval": 6,
        "max_wait": 360,
    },
    "kakarot-staging": {
        "name": "kakarot-staging",
        "explorer_url": "",
        "rpc_url": os.getenv("KAKAROT_STAGING_RPC_URL"),
        "l1_rpc_url": f"https://sepolia.infura.io/v3/{os.getenv('INFURA_KEY')}",
        "type": NetworkType.STAGING,
        "check_interval": 1,
        "max_wait": 30,
    },
}

if os.getenv("STARKNET_NETWORK") is not None:
    if NETWORKS.get(os.environ["STARKNET_NETWORK"]) is not None:
        NETWORK = NETWORKS[os.environ["STARKNET_NETWORK"]]
    else:
        raise ValueError(
            f"STARKNET_NETWORK {os.environ['STARKNET_NETWORK']} given in env variable unknown"
        )
elif os.getenv("RPC_URL") is not None:
    NETWORK = {
        "name": os.getenv("RPC_NAME", "custom-rpc"),
        "rpc_url": os.getenv("RPC_URL"),
        "explorer_url": "",
        "type": NetworkType.PROD,
        "check_interval": float(os.getenv("CHECK_INTERVAL", 0.1)),
        "max_wait": float(os.getenv("MAX_WAIT", 30)),
    }
else:
    NETWORK = NETWORKS["katana"]

prefix = NETWORK["name"].upper().replace("-", "_")
NETWORK["account_address"] = os.environ.get(f"{prefix}_ACCOUNT_ADDRESS")
if NETWORK["account_address"] is None:
    logger.warning(
        f"⚠️  {prefix}_ACCOUNT_ADDRESS not set, defaulting to ACCOUNT_ADDRESS"
    )
    NETWORK["account_address"] = os.getenv("ACCOUNT_ADDRESS")
NETWORK["private_key"] = os.environ.get(f"{prefix}_PRIVATE_KEY")
if NETWORK["private_key"] is None:
    logger.warning(f"⚠️  {prefix}_PRIVATE_KEY not set, defaulting to PRIVATE_KEY")
    NETWORK["private_key"] = os.getenv("PRIVATE_KEY")

RPC_CLIENT = FullNodeClient(node_url=NETWORK["rpc_url"])
L1_RPC_PROVIDER = Web3(Web3.HTTPProvider(NETWORK["l1_rpc_url"]))
WEB3 = Web3()

try:
    response = requests.post(
        RPC_CLIENT.url,
        json={
            "jsonrpc": "2.0",
            "method": "starknet_chainId",
            "params": [],
            "id": 0,
        },
    )
    payload = json.loads(response.text)
    starknet_chain_id = int(payload["result"], 16)

    if WEB3.is_connected():
        chain_id = WEB3.eth.chain_id
    else:
        chain_id = starknet_chain_id
except (
    requests.exceptions.ConnectionError,
    requests.exceptions.MissingSchema,
    requests.exceptions.InvalidSchema,
) as e:
    logger.info(
        f"⚠️  Could not get chain Id from {NETWORK['rpc_url']}: {e}, defaulting to KKRT"
    )
    chain_id = int.from_bytes(b"KKRT", "big")
    starknet_chain_id = int.from_bytes(b"KKRT", "big")


class ChainId(IntEnum):
    chain_id = chain_id
    starknet_chain_id = starknet_chain_id


NETWORK["chain_id"] = ChainId.chain_id

ETH_TOKEN_ADDRESS = 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7
COINBASE = int(
    os.getenv("KAKAROT_COINBASE_RECIPIENT")
    or "0x20eB005C0b9c906691F885eca5895338E15c36De",
    16,
)
SOURCE_DIR = Path("src")
SOURCE_DIR_FIXTURES = Path("tests/fixtures")
CONTRACTS = {p.stem: p for p in list(SOURCE_DIR.glob("**/*.cairo"))}
CONTRACTS_FIXTURES = {p.stem: p for p in list(SOURCE_DIR_FIXTURES.glob("**/*.cairo"))}

BUILD_DIR = Path("build")
BUILD_DIR_FIXTURES = BUILD_DIR / "fixtures"
BUILD_DIR.mkdir(exist_ok=True, parents=True)
BUILD_DIR_FIXTURES.mkdir(exist_ok=True, parents=True)
BUILD_DIR_SSJ = BUILD_DIR / "ssj"

DATA_DIR = Path("kakarot_scripts") / "data"


class ArtifactType(Enum):
    cairo0 = 0
    cairo1 = 1


DEPLOYMENTS_DIR = Path("deployments") / NETWORK["name"]
DEPLOYMENTS_DIR.mkdir(exist_ok=True, parents=True)

COMPILED_CONTRACTS = [
    {"contract_name": "kakarot", "is_account_contract": False},
    {"contract_name": "account_contract", "is_account_contract": True},
    {"contract_name": "uninitialized_account_fixture", "is_account_contract": False},
    {"contract_name": "uninitialized_account", "is_account_contract": False},
    {"contract_name": "EVM", "is_account_contract": False},
    {"contract_name": "OpenzeppelinAccount", "is_account_contract": True},
    {"contract_name": "ERC20", "is_account_contract": False},
    {"contract_name": "replace_class", "is_account_contract": False},
    {"contract_name": "Counter", "is_account_contract": False},
]
DECLARED_CONTRACTS = [
    {"contract_name": "kakarot", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "account_contract", "cairo_version": ArtifactType.cairo0},
    {
        "contract_name": "uninitialized_account_fixture",
        "cairo_version": ArtifactType.cairo0,
    },
    {"contract_name": "uninitialized_account", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "EVM", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "OpenzeppelinAccount", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "Cairo1Helpers", "cairo_version": ArtifactType.cairo1},
    {"contract_name": "Cairo1HelpersFixture", "cairo_version": ArtifactType.cairo1},
    {"contract_name": "replace_class", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "Counter", "cairo_version": ArtifactType.cairo0},
    {"contract_name": "MockPragmaOracle", "cairo_version": ArtifactType.cairo1},
    {"contract_name": "StarknetToken", "cairo_version": ArtifactType.cairo1},
    {"contract_name": "ERC20", "cairo_version": ArtifactType.cairo0},
]

# PRE-EIP155 TX
MULTICALL3_DEPLOYER = "0x05f32b3cc3888453ff71b01135b34ff8e41263f2"
MULTICALL3_SIGNED_TX = bytes.fromhex(
    json.loads((DATA_DIR / "signed_txs.json").read_text())["multicall3"]
)
ARACHNID_PROXY_DEPLOYER = "0x3fab184622dc19b6109349b94811493bf2a45362"
ARACHNID_PROXY_SIGNED_TX = bytes.fromhex(
    json.loads((DATA_DIR / "signed_txs.json").read_text())["arachnid"]
)
CREATEX_DEPLOYER = "0xeD456e05CaAb11d66C4c797dD6c1D6f9A7F352b5"
CREATEX_SIGNED_TX = bytes.fromhex(
    json.loads((DATA_DIR / "signed_txs.json").read_text())["createx"]
)

EVM_PRIVATE_KEY = os.getenv("EVM_PRIVATE_KEY")
EVM_ADDRESS = (
    EVM_PRIVATE_KEY
    and keys.PrivateKey(
        bytes.fromhex(EVM_PRIVATE_KEY[2:])
    ).public_key.to_checksum_address()
)

if NETWORK.get("chain_id"):
    logger.info(
        f"ℹ️  Connected to CHAIN_ID {NETWORK['chain_id'].value.to_bytes(ceil(log(NETWORK['chain_id'].value, 256)), 'big')}"
    )
