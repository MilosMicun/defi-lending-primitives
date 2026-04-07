# DeFi Lending Primitives

A collection of core building blocks behind DeFi lending protocols.

Focus:
- oracle design  
- price formation  
- lending mechanics  
- reward distribution  

The goal is not just implementation, but understanding **how trust, pricing, and incentives are engineered at protocol level**.

---

## Architecture Overview

This repository is structured as independent protocol modules.

Each module reflects a real production pattern used in DeFi:

- **Oracle Systems** → bringing external data on-chain safely  
- **AMM Mechanics** → understanding how price emerges from liquidity  
- **Reward Systems** → distributing value over time  
- **Lending Primitives** → collateral, debt, liquidation, and pricing  

Each module includes:

- Solidity implementation  
- focused documentation  
- tests covering edge cases and invariants  

---

## Modules

---

### Oracle Systems

#### Components

- [`ChainlinkPriceFeedReader`](src/oracle/ChainlinkPriceFeedReader.sol)  
- [`OracleGuard`](src/oracle/OracleGuard.sol)  
- [`OracleConsumer`](src/oracle/OracleConsumer.sol)  

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

- staleness checks  
- deviation limits  
- incomplete round validation  
- no state update on failure  

---

#### Key Insight

External data is untrusted.

Protocols must validate → store → reuse.

---

### Custom Oracle (RWA)

#### Component

- [`InvoiceOracle`](src/oracle/custom/InvoiceOracle.sol)

---

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

#### Component

- [`SimpleAMM`](src/amm/SimpleAMM.sol)

---

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

#### Component

- [`StakingRewards`](src/staking/StakingRewards.sol)

---

Implements time-based reward distribution using **cumulative index accounting** (Synthetix model).

---

#### Problem

Tracking rewards per user directly leads to:

- complex state updates  
- unfair distribution  
- high gas costs  

---

#### Solution

Use a global cumulative index:


rewardPerToken


---

#### Core Model


earned(user) =
stored rewards +
balance * (currentIndex - userCheckpoint)


---

#### Key Properties

- no historical rewards for new users  
- rewards proportional to stake  
- checkpoint before balance changes  
- safe when `totalSupply == 0`  

---

#### Key Insight

Rewards are not tracked per user.

They are tracked globally and distributed via an index.

---

### Lending Primitives

Core components of a lending protocol:

- collateral management  
- borrowing constraints  
- liquidation logic  
- dynamic pricing of capital  

---

#### Components

- [`Pool.sol`](src/lending/Pool.sol)  
- [`InterestRateModel.sol`](src/lending/InterestRateModel.sol)  

---

#### Liquidation Mechanics

- [`docs/liquidation-mechanics.md`](docs/liquidation-mechanics.md)

Defines how unhealthy positions are closed to maintain solvency.

Key concepts:

- health factor  
- liquidation threshold  
- liquidation bonus  
- bad debt prevention  

---

#### Interest Rate Model

- [`docs/interest-rate-models.md`](docs/interest-rate-models.md)

Implements utilization-based pricing of capital using a two-slope (kink) model.


U = borrows / (cash + borrows)

borrowAPR = f(U)


Before kink → gradual increase  
After kink → aggressive increase  

---

#### System Behavior


utilization ↑
→ borrow APR ↑
→ borrow ↓ + repay ↑ + supply ↑
→ utilization ↓


---

#### Key Insight

Interest rate is not yield.

It is a control mechanism that stabilizes liquidity through user behavior.

---

## Key Concepts

- Oracle safety layers  
- Time-based state machines  
- Liquidity-driven pricing  
- Slippage and manipulation cost  
- TWAP vs spot  
- Global vs local accounting  
- Checkpoint-based reward systems  
- Utilization-driven interest rates  

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

### External Truth  
Safely integrating off-chain data.

### Missing Data  
Designing systems without reliable price feeds.

### Market Dynamics  
Understanding how price emerges and can be manipulated.

### Incentives  
Distributing value over time.

### Liquidity  
Pricing capital dynamically to maintain system balance.

---

## Final Insight

DeFi protocols are not just smart contracts.

They are:

- state machines  
- accounting systems  
- adversarial environments  

Correctness emerges from:


math + state + time