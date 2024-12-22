# Kakarot's EVM - Internal Design

The EVM is a stack-based computer responsible for the execution of EVM bytecode.
It has two context-bound data structures: the stack and the memory. The stack is
a 256bit-words based data structure used to store and retrieve intermediate
values during the execution of opcodes. The memory is a byte-addressable data
structure organized into 32-byte words used volatile space to store data
during execution. Both the stack and the memory are initialized empty at the
start of a call context, and destroyed when a call context ends.

The initial design of Kakarot's EVM had a single struct to model the execution
context, which contained the stack, the memory, and the execution state. Each
local execution context optionally contained parent and child execution
contexts, which were used to model the execution of sub-calls. However, this
design was not possible to implement in Cairo, as Cairo does not support the use
of `Nullable` types containing dictionaries. Since the `ExecutionContext` struct
contains such `Nullable` types, we had to change the design of the EVM to use a
machine with a single stack and memory, which are our dict-based data
structures.

## The Kakarot Machine design

To overcome the problem stated above, we have come up with the following design:

- There is only one instance of the Memory and the Stack, which is shared
  between the different execution contexts.
- Each execution context has its own identifier `id`, which uniquely identifies
  it.
- Each execution context has a `parent_ctx` field, which value is either a
  pointer to its parent execution context or `null`.
- Each execution context has a `return_data` field, whose value is either
  nothing or the return data from the child context. This is meant to enable
  opcodes `RETURNDATASIZE` and `RETURNDATACOPY`. These two opcodes are the only
  ones enabling a current context to access its child context's return data.
- The execution context tree is a directed acyclic graph, where each execution
  context has at most one parent.
- A specific execution context is accessible by traversing the execution context
  tree, starting from the root execution context, and following the execution
  context tree until the desired execution context is reached. The machine also
  stores a pointer to the current execution context.
- The execution context tree is initialized with a single root execution
  context, which has no parent and no child. It has an `id` field equal to 0.

The following diagram describes the model of the Kakarot machine.

```mermaid
classDiagram
    class Machine{
        current_ctx: Box~ExecutionContext~,
        ctx_count: usize,
        stack: Stack,
        memory: Memory,
        state: State,
    }

    class Memory{
        active_segment: usize,
        items: Felt252Dict~u128~,
        bytes_len: Felt252Dict~usize~,
    }

    class Stack{
        +active_segment: usize,
        +items: Felt252Dict~Nullable~u256~~,
        +len: Felt252Dict~usize~
    }

    class ExecutionContext{
      ctx_type: ExecutionContextType,
      address: Address,
      program_counter: u32,
      status: Status,
      call_ctx: Box~CallContext~,
      return_data: Span~u8~,
      parent_ctx: Nullable~ExecutionContext~,
      gas_used: u128,
    }

    class ExecutionContextType {
      <<enumeration>>
      Root: IsCreate,
      Call: usize,
      Create: usize
    }

    class CallContext{
        caller: EthAddress,
        value: u256,
        bytecode: Span~u8~,
        calldata: Span~u8~,
        gas_price: u128,
        gas_limit: u128,
        read_only: bool,
        ret_offset: usize,
        ret_size: usize,
    }

    class State{
      accounts: StateChangeLog~Account~,
      accounts_storage: StateChangeLog~EthAddress_u256_u256~,
      events: SimpleLog~Event~,
      transfers: SimpleLog~Transfer~,
    }

    class StateChangeLog~T~ {
      contextual_changes: Felt252Dict~Nullable~T~~,
      contextual_keyset: Array~felt252~,
      transactional_changes: Felt252Dict~Nullable~T~~,
      transactional_keyset: Array~felt252~
    }

    class SimpleLog~T~ {
      contextual_logs: Array~T~,
      transactional_logs: Array~T~,
    }

    class Status{
    <<enumeration>>
      Active,
      Stopped,
      Reverted
    }


    Machine *-- Memory
    Machine *-- Stack
    Machine *-- ExecutionContext
    Machine *-- State
    ExecutionContext *-- ExecutionContext
    ExecutionContext *-- ExecutionContextType
    ExecutionContext *-- CallContext
    ExecutionContext *-- Status
    State *-- StateChangeLog
    State *-- SimpleLog
```

<span class="caption">Kakarot internal architecture model</span>

### The Stack

Instead of having one Stack per execution context, we have a single Stack shared
between all execution contexts. Because our Stack is a dict-based data
structure, we can actually simulate multiple stacks by using different keys for
each execution context. The `active_segment` field of the Stack is used to keep
track of the current active execution context. The `len` field is a dictionary
field is a dictionary mapping execution context identifiers to the length of
their corresponding stacks. The `items` field is a dictionary mapping indexes to
values.

The EVM imposes a limit of a maximum of 1024 items on the stack. At any given
time, the stack relative to an execution context contains at most 1024 items.
This means that if we consider items to be stored at sequential indexes, the
stack relative to an execution context is a contiguous segment of the global
stack of maximum size `1024`. When pushing an item to the stack, we will compute
an index which corresponds to the index in the dict the item will be stored at.
The internal index is computed as follows:

$$index = len(Stack_i) + i \cdot 1024$$

where $i$ is the id of the active execution context.

If we want to push an item to the stack of the root context, the internal index
will be $index = len(Stack_0) + 0 \cdot 1024 = len(Stack_0)$.

The process is analogous for popping an item from the stack.

### The Memory

The Memory is modeled in a similar way to the Stack. The difference is that the
memory doesn't have a limit on the number of items it can store. Instead, the
cost of expanding the size of the memory grows quadratically relative to its
size. Given that an Ethereum block has a gas limit, we can assume that the
maximum size of the memory is bounded by the gas limit of a block, which is 30M
gas.

The expansion cost of the memory is defined as follows in the Ethereum Yellow
Paper:

$$C_{mem}(a) \equiv G_{memory} · a + [\frac{a^2}{512}]$$

where $G_{memory} = 3$ and $a$ is the number of 32-byte words allocated.

Following this formula, the gas costs required to have a memory containing
125000 words is above the 30M gas limit. We will use this heuristic to bound the
maximum size of the memory to the closest power of two to 125000: $2^17$.
Therefore, we will bound the maximum size of the memory to 131072 256-bits
words.

The internal index at which an item will be inserted in the memory, given a
specific offset, is computed as:

$$index = offset + i \cdot 131072$$

where $i$ is the id of the active execution context.

If we want to store an item at offset 10 of the memory relative to the execution
context of id 1, the internal index will be
$index = 10 + 1 \cdot 131072 = 131082$.

## Execution flow

The following diagram describe the flow of the execution context when executing
the `run` function given an instance of the `Machine` struct instantiated with
the bytecode to execute and the appropriate execution context.

The run function is responsible for executing EVM bytecode. The flow of
execution involves decoding and executing the current opcode, handling the
execution, and continue executing the next opcode if the execution of the
previous one succeeded. If the execution of an opcode fails, the execution
context reverts, the changes made in this context are dropped, and the state of
the blockchain is not updated.

```mermaid
flowchart TD
AA["START"] --> A
A["run()"] --> B[Decode and Execute Opcode]
B --> |pc+=1| C{Result OK?}
C -->|Yes| D{Execution stopped?}
D -->|No| A
D -->|Yes| F{Reverted?}
C -->|No| RA
F --> |No| FA
F -->|Yes| RA[Discard account updates]

subgraph Discard context changes
RA --> RB["Discard storage updates"]
RB --> RC["Discard event log"]
RC --> RD["Discard transfers log"]
end

RD --> FA[finalize context]
```

<span class="caption">Execution flow of EVM bytecode</span>

## Conclusion

With its shared stack and memory accessed via calculated internal indexes
relative to the current execution context, this EVM design remains compatible
with the original EVM design, easily refactorable if we implement all
interactions with the machine through type methods, and compatible with Cairo's
limitations.
