// SPDX-License-Identifier: MIT

from kakarot.gas import Gas

// @title Constants file.
// @notice This file contains global constants.
namespace Constants {
    // STACK
    const STACK_MAX_DEPTH = 1024;

    // TRANSACTION
    // Used in tests only
    const TRANSACTION_GAS_LIMIT = 1000000;

    // PROXY
    const INITIALIZE_SELECTOR = 0x79dc0da7c54b95f10aa182ad0a46400db63156920adb65eca2654c0945a463;
    const CONTRACT_ADDRESS_PREFIX = 'STARKNET_CONTRACT_ADDRESS';
    // EOA_V0.0.1 => [69, 79, 65, 95, 86, 48, 46, 48, 46, 49] => 0x454f415f56302e302e31 => pedersen hashed
    const EOA_VERSION = 0x6f5f51231e876bd085664a890c148a20ea806c5211a8ffd1a61747cf71c71d9;
    // CA_V0.0.1 => [67, 65, 95, 86, 48, 46, 48, 46, 49] => 0x43415f56302e302e31 => pedersen hashed
    const CA_VERSION = 0x7be1c12f918a11456a63db29ebfd5e477c967ae994e1bf751a7d04fa8429095;
    // ACCOUNTS
    const BYTES_PER_FELT = 16;
    const MAX_NONCE = 2 ** 64 - 1;
    const MAX_CODE_SIZE = 0x6000;
}

// See model.Opcode:
// number
// gas. Some opcodes have a zero fixed gas cost, only depending on dynamic gas cost. (e.g. warm/cold costs).
// stack_input
// stack_size_min
// stack_size_diff
opcodes_label:
// STOP
dw 0x00;
dw 0;
dw 0;
dw 0;
dw 0;
// ADD
dw 0x01;
dw Gas.VERY_LOW;
dw 2;
dw 2;
dw -1;
// MUL
dw 0x02;
dw Gas.LOW;
dw 2;
dw 2;
dw -1;
// SUB
dw 0x03;
dw Gas.VERY_LOW;
dw 2;
dw 2;
dw -1;
// DIV
dw 0x04;
dw Gas.LOW;
dw 2;
dw 2;
dw -1;
// SDIV
dw 0x05;
dw Gas.LOW;
dw 2;
dw 2;
dw -1;
// MOD
dw 0x06;
dw Gas.LOW;
dw 2;
dw 2;
dw -1;
// SMOD
dw 0x07;
dw Gas.LOW;
dw 2;
dw 2;
dw -1;
// ADDMOD
dw 0x08;
dw Gas.MID;
dw 3;
dw 3;
dw -1;
// MULMOD
dw 0x09;
dw Gas.MID;
dw 3;
dw 3;
dw -1;
// EXP
dw 0x0a;
dw Gas.EXPONENTIATION;
dw 2;
dw 2;
dw -1;
// SIGNEXTEND
dw 0x0b;
dw Gas.LOW;
dw 2;
dw 2;
dw -1;
// INVALID
dw 0x0c;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x0d;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x0e;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x0f;
dw 0;
dw 0;
dw 0;
dw 0;
// LT
dw 0x10;
dw Gas.VERY_LOW;
dw 2;
dw 2;
dw -1;
// GT
dw 0x11;
dw Gas.VERY_LOW;
dw 2;
dw 2;
dw -1;
// SLT
dw 0x12;
dw Gas.VERY_LOW;
dw 2;
dw 2;
dw -1;
// SGT
dw 0x13;
dw Gas.VERY_LOW;
dw 2;
dw 2;
dw -1;
// EQ
dw 0x14;
dw Gas.VERY_LOW;
dw 2;
dw 2;
dw -1;
// ISZERO
dw 0x15;
dw Gas.VERY_LOW;
dw 1;
dw 1;
dw 0;
// AND
dw 0x16;
dw Gas.VERY_LOW;
dw 2;
dw 2;
dw -1;
// OR
dw 0x17;
dw Gas.VERY_LOW;
dw 2;
dw 2;
dw -1;
// XOR
dw 0x18;
dw Gas.VERY_LOW;
dw 2;
dw 2;
dw -1;
// NOT
dw 0x19;
dw Gas.VERY_LOW;
dw 1;
dw 1;
dw -1;
// BYTE
dw 0x1a;
dw Gas.VERY_LOW;
dw 2;
dw 2;
dw -1;
// SHL
dw 0x1b;
dw Gas.VERY_LOW;
dw 2;
dw 2;
dw -1;
// SHR
dw 0x1c;
dw Gas.VERY_LOW;
dw 2;
dw 2;
dw -1;
// SAR
dw 0x1d;
dw Gas.VERY_LOW;
dw 2;
dw 2;
dw -1;
// INVALID
dw 0x1e;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x1f;
dw 0;
dw 0;
dw 0;
dw 0;
// SHA3
dw 0x20;
dw Gas.KECCAK256;
dw 2;
dw 2;
dw -1;
// INVALID
dw 0x21;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x22;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x23;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x24;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x25;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x26;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x27;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x28;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x29;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x2a;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x2b;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x2c;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x2d;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x2e;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x2f;
dw 0;
dw 0;
dw 0;
dw 0;
// ADDRESS
dw 0x30;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// BALANCE
dw 0x31;
dw 0;
dw 1;
dw 1;
dw 0;
// ORIGIN
dw 0x32;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// CALLER
dw 0x33;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// CALLVALUE
dw 0x34;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// CALLDATALOAD
dw 0x35;
dw Gas.VERY_LOW;
dw 1;
dw 1;
dw 0;
// CALLDATASIZE
dw 0x36;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// CALLDATACOPY
dw 0x37;
dw Gas.VERY_LOW;
dw 3;
dw 3;
dw 0;
// CODESIZE
dw 0x38;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// CODECOPY
dw 0x39;
dw Gas.VERY_LOW;
dw 3;
dw 3;
dw 0;
// GASPRICE
dw 0x3a;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// EXTCODESIZE
dw 0x3b;
dw 0;
dw 1;
dw 1;
dw 0;
// EXTCODECOPY
dw 0x3c;
dw 0;
dw 4;
dw 4;
dw 0;
// RETURNDATASIZE
dw 0x3d;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// RETURNDATACOPY
dw 0x3e;
dw Gas.VERY_LOW;
dw 3;
dw 3;
dw 0;
// EXTCODEHASH
dw 0x3f;
dw 0;
dw 1;
dw 1;
dw 0;
// BLOCKHASH
dw 0x40;
dw Gas.BLOCK_HASH;
dw 1;
dw 1;
dw 0;
// COINBASE
dw 0x41;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// TIMESTAMP
dw 0x42;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// NUMBER
dw 0x43;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// PREVRANDAO
dw 0x44;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// GASLIMIT
dw 0x45;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// CHAINID
dw 0x46;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// SELFBALANCE
dw 0x47;
dw Gas.FAST_STEP;
dw 0;
dw 0;
dw 1;
// BASEFEE
dw 0x48;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// INVALID
dw 0x49;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x4a;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x4b;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x4c;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x4d;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x4e;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0x4f;
dw 0;
dw 0;
dw 0;
dw 0;
// POP
dw 0x50;
dw Gas.BASE;
dw 1;
dw 1;
dw -1;
// MLOAD
dw 0x51;
dw Gas.VERY_LOW;
dw 1;
dw 1;
dw 0;
// MSTORE
dw 0x52;
dw Gas.VERY_LOW;
dw 2;
dw 2;
dw -2;
// MSTORE8
dw 0x53;
dw Gas.VERY_LOW;
dw 2;
dw 2;
dw -2;
// SLOAD
dw 0x54;
dw 0;  // gas cost is dynamic
dw 1;
dw 1;
dw 0;
// SSTORE
dw 0x55;
dw 0;
dw 2;
dw 2;
dw -2;
// JUMP
dw 0x56;
dw Gas.MID;
dw 1;
dw 1;
dw -1;
// JUMPI
dw 0x57;
dw Gas.HIGH;
dw 2;
dw 2;
dw -2;
// PC
dw 0x58;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// MSIZE
dw 0x59;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// GAS
dw 0x5a;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// JUMPDEST
dw 0x5b;
dw Gas.JUMPDEST;
dw 0;
dw 0;
dw 0;
// TLOAD
dw 0x5c;
dw 0;  // gas cost is dynamic
dw 1;
dw 1;
dw 0;
// TSTORE
dw 0x5d;
dw 0;  // gas cost is dynamic
dw 2;
dw 2;
dw -2;
// MCOPY
dw 0x5e;
dw Gas.VERY_LOW;  // + Dynamic gas
dw 3;
dw 3;
dw -3;
// PUSH0
dw 0x5f;
dw Gas.BASE;
dw 0;
dw 0;
dw 1;
// PUSH1
dw 0x60;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH2
dw 0x61;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH3
dw 0x62;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH4
dw 0x63;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH5
dw 0x64;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH6
dw 0x65;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH7
dw 0x66;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH8
dw 0x67;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH9
dw 0x68;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH10
dw 0x69;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH11
dw 0x6a;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH12
dw 0x6b;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH13
dw 0x6c;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH14
dw 0x6d;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH15
dw 0x6e;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH16
dw 0x6f;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH17
dw 0x70;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH18
dw 0x71;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH19
dw 0x72;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH20
dw 0x73;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH21
dw 0x74;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH22
dw 0x75;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH23
dw 0x76;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH24
dw 0x77;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH25
dw 0x78;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH26
dw 0x79;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH27
dw 0x7a;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH28
dw 0x7b;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH29
dw 0x7c;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH30
dw 0x7d;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH31
dw 0x7e;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// PUSH32
dw 0x7f;
dw Gas.VERY_LOW;
dw 0;
dw 0;
dw 1;
// DUP1
dw 0x80;
dw Gas.VERY_LOW;
dw 0;
dw 1;
dw 1;
// DUP2
dw 0x81;
dw Gas.VERY_LOW;
dw 0;
dw 2;
dw 1;
// DUP3
dw 0x82;
dw Gas.VERY_LOW;
dw 0;
dw 3;
dw 1;
// DUP4
dw 0x83;
dw Gas.VERY_LOW;
dw 0;
dw 4;
dw 1;
// DUP5
dw 0x84;
dw Gas.VERY_LOW;
dw 0;
dw 5;
dw 1;
// DUP6
dw 0x85;
dw Gas.VERY_LOW;
dw 0;
dw 6;
dw 1;
// DUP7
dw 0x86;
dw Gas.VERY_LOW;
dw 0;
dw 7;
dw 1;
// DUP8
dw 0x87;
dw Gas.VERY_LOW;
dw 0;
dw 8;
dw 1;
// DUP9
dw 0x88;
dw Gas.VERY_LOW;
dw 0;
dw 9;
dw 1;
// DUP10
dw 0x89;
dw Gas.VERY_LOW;
dw 0;
dw 10;
dw 1;
// DUP11
dw 0x8a;
dw Gas.VERY_LOW;
dw 0;
dw 11;
dw 1;
// DUP12
dw 0x8b;
dw Gas.VERY_LOW;
dw 0;
dw 12;
dw 1;
// DUP13
dw 0x8c;
dw Gas.VERY_LOW;
dw 0;
dw 13;
dw 1;
// DUP14
dw 0x8d;
dw Gas.VERY_LOW;
dw 0;
dw 14;
dw 1;
// DUP15
dw 0x8e;
dw Gas.VERY_LOW;
dw 0;
dw 15;
dw 1;
// DUP16
dw 0x8f;
dw Gas.VERY_LOW;
dw 0;
dw 16;
dw 1;
// SWAP1
dw 0x90;
dw Gas.VERY_LOW;
dw 0;
dw 2;
dw 0;
// SWAP2
dw 0x91;
dw Gas.VERY_LOW;
dw 0;
dw 3;
dw 0;
// SWAP3
dw 0x92;
dw Gas.VERY_LOW;
dw 0;
dw 4;
dw 0;
// SWAP4
dw 0x93;
dw Gas.VERY_LOW;
dw 0;
dw 5;
dw 0;
// SWAP5
dw 0x94;
dw Gas.VERY_LOW;
dw 0;
dw 6;
dw 0;
// SWAP6
dw 0x95;
dw Gas.VERY_LOW;
dw 0;
dw 7;
dw 0;
// SWAP7
dw 0x96;
dw Gas.VERY_LOW;
dw 0;
dw 8;
dw 0;
// SWAP8
dw 0x97;
dw Gas.VERY_LOW;
dw 0;
dw 9;
dw 0;
// SWAP9
dw 0x98;
dw Gas.VERY_LOW;
dw 0;
dw 10;
dw 0;
// SWAP10
dw 0x99;
dw Gas.VERY_LOW;
dw 0;
dw 11;
dw 0;
// SWAP11
dw 0x9a;
dw Gas.VERY_LOW;
dw 0;
dw 12;
dw 0;
// SWAP12
dw 0x9b;
dw Gas.VERY_LOW;
dw 0;
dw 13;
dw 0;
// SWAP13
dw 0x9c;
dw Gas.VERY_LOW;
dw 0;
dw 14;
dw 0;
// SWAP14
dw 0x9d;
dw Gas.VERY_LOW;
dw 0;
dw 15;
dw 0;
// SWAP15
dw 0x9e;
dw Gas.VERY_LOW;
dw 0;
dw 16;
dw 0;
// SWAP16
dw 0x9f;
dw Gas.VERY_LOW;
dw 0;
dw 17;
dw 0;
// LOG0
dw 0xa0;
dw Gas.LOG;
dw 2;
dw 2;
dw -2;
// LOG1
dw 0xa1;
dw Gas.LOG;
dw 3;
dw 3;
dw -3;
// LOG2
dw 0xa2;
dw Gas.LOG;
dw 4;
dw 4;
dw -4;
// LOG3
dw 0xa3;
dw Gas.LOG;
dw 5;
dw 5;
dw -5;
// LOG4
dw 0xa4;
dw Gas.LOG;
dw 6;
dw 6;
dw -6;
// INVALID
dw 0xa5;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xa6;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xa7;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xa8;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xa9;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xaa;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xab;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xac;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xad;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xae;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xaf;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xb0;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xb1;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xb2;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xb3;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xb4;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xb5;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xb6;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xb7;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xb8;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xb9;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xba;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xbb;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xbc;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xbd;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xbe;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xbf;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xc0;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xc1;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xc2;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xc3;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xc4;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xc5;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xc6;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xc7;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xc8;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xc9;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xca;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xcb;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xcc;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xcd;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xce;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xcf;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xd0;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xd1;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xd2;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xd3;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xd4;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xd5;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xd6;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xd7;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xd8;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xd9;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xda;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xdb;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xdc;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xdd;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xde;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xdf;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xe0;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xe1;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xe2;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xe3;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xe4;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xe5;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xe6;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xe7;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xe8;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xe9;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xea;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xeb;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xec;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xed;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xee;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xef;
dw 0;
dw 0;
dw 0;
dw 0;
// CREATE
dw 0xf0;
dw Gas.CREATE;
dw 3;
dw 3;
dw -2;
// CALL
dw 0xf1;
dw 0;
dw 7;
dw 7;
dw -6;
// CALLCODE
dw 0xf2;
dw 0;
dw 7;
dw 7;
dw -6;
// RETURN
dw 0xf3;
dw Gas.ZERO;
dw 2;
dw 2;
dw -2;
// DELEGATECALL
dw 0xf4;
dw 0;
dw 6;
dw 6;
dw -5;
// CREATE2
dw 0xf5;
dw Gas.CREATE;
dw 4;
dw 4;
dw -3;
// INVALID
dw 0xf6;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xf7;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xf8;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xf9;
dw 0;
dw 0;
dw 0;
dw 0;
// STATICCALL
dw 0xfa;
dw 0;
dw 6;
dw 6;
dw -5;
// INVALID
dw 0xfb;
dw 0;
dw 0;
dw 0;
dw 0;
// INVALID
dw 0xfc;
dw 0;
dw 0;
dw 0;
dw 0;
// REVERT
dw 0xfd;
dw 0;
dw 2;
dw 2;
dw -2;
// INVALID
dw 0xfe;
dw 0;
dw 0;
dw 0;
dw 0;
// SELFDESTRUCT
dw 0xff;
dw Gas.SELF_DESTRUCT;
dw 1;
dw 1;
dw -1;
