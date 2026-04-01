# DeFi Lending Primitives

This repository explores core building blocks behind DeFi lending protocols:

- oracle design  
- price formation  
- and reward distribution mechanics  

The goal is not just implementation, but understanding **how trust, pricing, and incentives are engineered at protocol level**.

---

## Architecture Overview

This repository is structured around independent protocol modules:

- Oracle Systems → bringing external data on-chain safely  
- AMM Mechanics → understanding how price emerges from liquidity  
- Reward Systems → distributing value over time  

Each module is designed to reflect **real production patterns used in DeFi protocols**.

---

## Modules

---

### Oracle Systems

#### Chainlink Integration

- `ChainlinkPriceFeedReader`
- `OracleGuard`
- `OracleConsumer`

Implements a layered oracle architecture:

1. Read external data  
2. Validate safety conditions  
3. Store trusted values  
4. Expose safe price to protocol  

---

#### Problem

External data is:

- unreliable  
- delayed  
- manipulable  

Blindly trusting oracle feeds introduces systemic risk.

---

#### Solution

Instead of using oracle data directly:

- validate once  
- store accepted value  
- reuse trusted state  

---

#### Implementation

- `updatePrice()` → validates and stores price  
- `getPrice()` → returns last accepted value  

---

#### Safety Mechanisms

- staleness check  
- deviation threshold  
- invalid round detection  
- no state update on failure  

---

#### Key Insight


External data is untrusted.

Protocols must validate → store → reuse.


---

### Custom Oracle (RWA)

- `InvoiceOracle`

Designed for illiquid real-world assets:

- invoices  
- receivables  
- private debt  

These assets:

- do not have market prices  
- cannot rely on price feeds  

---

#### Approach

Instead of fetching price:

- submit value  
- allow dispute  
- finalize if uncontested  

---

#### State Machine


NO STATE
↓
SUBMITTED
↓
├── FINALIZED
└── DISPUTED → CANCELLED


---

#### Properties

- no overwrite of active submissions  
- mutually exclusive terminal states  
- strict dispute window  
- full cleanup after resolution  

---

#### Roles

- submitter → proposes value  
- challenger → disputes value  
- owner → manages permissions  

---

#### Key Insight


Oracle ≠ data feed

Oracle = state machine + incentives + time


---

### AMM & Price Formation

- `SimpleAMM`

Implements constant product invariant:


x * y = k


---

#### Core Mechanics

- price = reserve ratio  
- trades move price along curve  
- liquidity defines price  
- no external reference required  

---

#### Slippage

- small trades → minimal impact  
- large trades → worse execution price  

---

#### Price Impact


bigger trade → bigger deviation from spot


---

#### TWAP (Time-Weighted Average Price)

Instead of trusting spot price:

- accumulate `price * time`  
- compute average  


TWAP = (cumulativeEnd - cumulativeStart) / timeElapsed


---

#### Key Insight


AMM price is not truth.

It is a function of liquidity and can be manipulated.


---

### Staking & Reward Distribution

- `StakingRewards`

Implements time-based reward distribution using **cumulative index accounting** (Synthetix model).

---

## Problem

Tracking rewards per user directly leads to:

- complex state updates  
- unfair distribution  
- high gas costs  

Users:

- enter at different times  
- leave at different times  
- change balances dynamically  

---

## Solution

Use a **global cumulative index**:


rewardPerToken


Instead of tracking rewards per user continuously.

---

## Core Model

### Global Accounting


rewardPerToken = cumulative reward per token


---

### User Accounting


earned(user) =
stored rewards

balance * (currentIndex - userCheckpoint)

---

### Interpretation

- system tracks total reward globally  
- users track only their checkpoint  
- rewards are derived, not stored continuously  

---

## Key Variables

- `rewardRate` → tokens per second  
- `rewardPerToken` → global index  
- `userRewardPerTokenPaid` → checkpoint  
- `rewards[user]` → stored reward  

---

## Accounting Engine

### `_updateReward(account)`

Core function responsible for:

1. Updating global state  
2. Updating user state (if needed)  

---

### Behavior

- always updates global index  
- updates user only if `account != address(0)`  

---

## Critical Properties

- no historical rewards for new users  
- rewards proportional to stake  
- checkpoint before balance changes  
- reward accumulation is linear in time  
- safe when `totalSupply == 0`  

---

## Fairness Guarantees

### New User

- starts from current index  
- receives no past rewards  

---

### Existing User

- accumulates reward continuously  
- unaffected by new entrants  

---

### Withdraw

- rewards are checkpointed before balance change  
- no loss of earned rewards  

---

### Claim

- rewards transferred  
- internal state reset  
- no double claiming  

---

## Example (Intuition)

### Scenario

- Alice stakes first  
- time passes  
- Bob joins later  

---

### Result

- Alice earns full early rewards  
- later rewards are shared proportionally  

---

### Key Mechanism


rewardPerToken grows globally
users only track delta since their checkpoint


---

## Key Insight


Rewards are not tracked per user.

They are tracked globally and distributed via an index.


---

## Key Concepts

- Oracle safety layers  
- Time-based state machines  
- Liquidity-driven pricing  
- Slippage and manipulation cost  
- TWAP vs spot  
- Global vs local accounting  
- Checkpoint-based reward systems  

---

## Design Principles

- separate read vs write logic  
- minimize trust in external data  
- encode invariants in state  
- prefer deterministic accounting  
- avoid implicit assumptions  

---

## Summary

This repository demonstrates how DeFi protocols handle:

### 1. External Truth
Validate and safely integrate off-chain data.

### 2. Missing Data
Design systems when price feeds do not exist.

### 3. Market Dynamics
Understand how price emerges and can be manipulated.

### 4. Incentives
Distribute value fairly over time.

---

## Final Insight

DeFi protocols are not just smart contracts.

They are:

- state machines  
- accounting systems  
- adversarial environments  

Correctness emerges from:


math + state + time