# Chain State and Event Reading

## Overview

Understanding a DeFi protocol requires more than reading contract code.

A protocol exists as:
- on-chain state (balances, storage)
- execution context (blocks)
- state transitions (events)

This document focuses on reading blockchain data with protocol context, not as raw values.

---

## Problem

Reading raw blockchain data without context leads to incorrect conclusions.

Examples:
- A token balance does not explain how it changed
- A pool balance does not represent total protocol deposits
- A single snapshot hides system dynamics

Protocol engineers need to understand both:
- current state
- recent changes

---

## Approach

Used a Foundry script on a mainnet fork to:

- read latest block context:
  - block number
  - timestamp
  - gas limit
  - base fee
- read ETH and ERC20 balances
- interpret values in protocol context using Aave V3 Pool

Additionally:
- inspected recent protocol activity via event logs
- filtered Aave Supply events using event signature hash

---

## Key Concepts

### 1. Block = Execution Context

Block data defines:
- when execution happens
- under what conditions (gas, base fee)

This is critical for understanding timing and cost of actions.

---

### 2. Balance = Snapshot of State

Reading balances shows:
- current capital distribution

But does NOT show:
- how the state was reached
- recent activity

Example:

USDC.balanceOf(pool)


This returns:
- current underlying liquidity at the Pool address

Not:
- total deposits
- total protocol accounting

---

### 3. Event = State Transition

Events represent actual changes in the system.

Example:
- Supply → capital enters protocol
- Borrow → capital leaves pool
- Repay → debt is reduced

Each event answers:
- what happened
- who triggered it
- how much value moved

---

### 4. topic0 = Event Identity

Each event is identified by:


keccak256("EventName(type1,type2,...)")


This hash (topic0) allows filtering logs for a specific event type.

Example:

Supply(address,address,address,uint256,uint16)


→ used to identify Aave supply events in logs

---

## Observations from Aave V3

Using a mainnet fork, I queried the Aave V3 Pool contract directly.

Observed values:

- Block number: 24842120  
- Timestamp: 1775737259  
- ETH balance (Pool): 0  
- USDC balance (raw): 15896459  
- USDC balance (6 decimals): ~15.896459 USDC  

### Interpretation

- The Pool contract does not hold native ETH for execution  
- The USDC balance is relatively small compared to total protocol activity  
- This indicates that most capital is not sitting idle in the Pool  

Key insight:

> Pool balance ≠ total deposits  
> It represents only the currently available underlying liquidity

### Deeper implication

If:
- Pool USDC balance is low  
- but protocol activity is high  

Then:
- a large portion of supplied capital is already borrowed  
- utilization is likely elevated  
- available liquidity is constrained  

This demonstrates why balance alone is insufficient for understanding protocol state.

---

## State vs Flow

| Concept  | Meaning |
|--------|--------|
| Block   | When execution happens |
| Balance | Where capital is |
| Event   | How capital moves |

This leads to:

- Balance = snapshot  
- Event = flow  

Both are required to understand protocol behavior.

---

## Limitations

- Event inspection was performed via CLI (cast logs)
- No automated indexing or continuous event tracking
- No aggregation of protocol metrics (e.g. utilization, borrow rates)

---

## Conclusion

Reading blockchain data without context is misleading.

To understand a protocol, you must combine:

- block data (context)
- balances (state)
- events (transitions)

This enables observing not only what the system is,  
but how it evolves over time.