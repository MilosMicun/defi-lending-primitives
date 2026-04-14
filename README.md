# Milos Mirkovic

Solidity / Smart Contract Engineer ⚙️  
Protocol Engineering: DeFi Systems, Risk, and On-Chain Interaction

---

> ⚠️ This is a protocol engineering repository — not a tutorial.  
> Focus: building and understanding the core systems behind DeFi lending, including risk, pricing, and on-chain interaction.

---

## Background

Most DeFi developers learn trade finance from whitepapers.

I ran it.

8 years operating a business that dealt with invoicing, receivables, buyer credit risk, and factoring — before writing a single line of Solidity.

This repository is the technical foundation for what comes next: a production RWA invoice financing protocol built by someone who understands the financial reality behind the contracts.

---

## Positioning

This repository reflects a specific focus:

- designing protocol primitives  
- understanding financial risk at system level  
- building on-chain interaction tooling  

Not just writing contracts — but understanding how protocols behave in production.

---

## What This Repo Is

**defi-lending-primitives** is a protocol engineering project focused on breaking down DeFi lending into fundamental components.

This is not a full protocol.

It is a structured implementation of the systems that make lending protocols work:

- pricing (AMM, oracles)  
- risk (liquidations, oracle failure)  
- incentives (interest rates, staking)  
- on-chain interaction (reads, writes, events)  

Each component is implemented, tested, and analyzed in isolation.

---

## System Overview

The project is organized into three layers:

### 1. Solidity Primitives (`src/`)

Core protocol components:

- oracle systems (Chainlink + custom RWA oracle)  
- AMM (price formation)  
- staking rewards (index-based accounting)  
- lending pool (collateral, borrow, liquidation)  
- interest rate model (utilization-based pricing)  

---

### 2. Protocol Reasoning (`docs/`)

Each system is explained through:

- invariants  
- failure modes  
- financial meaning of state transitions  

---

### 3. On-Chain Interaction Layer (`script/`) 🔥

JavaScript tooling for real protocol interaction:

- reading chain state (balances, blocks, protocol data)  
- multicall aggregation  
- sending transactions  
- transaction lifecycle tracking  
- receipt parsing  
- event decoding  
- historical log queries  
- live event listeners  

This reflects how backend systems interact with protocols in production.

---

## System Flow

```
User deposits collateral
↓
Collateral value (via oracle)
↓
Borrow capacity calculated
↓
User borrows asset
↓
Health factor monitored

If price drops ↓

Health factor < 1
↓
Liquidation triggered
↓
Collateral sold with bonus
↓
Protocol remains solvent
```

---

## Core Concepts Implemented

### Oracle Safety
- stale data protection  
- deviation guards  
- validated price storage  
- failure-aware consumption  

### Custom Oracle (RWA)
- submit → dispute → finalize state machine  
- time-bound dispute window  
- role-based system  

### AMM & TWAP
- constant product invariant (x * y = k)  
- price impact and slippage  
- TWAP as manipulation resistance  

### Staking Rewards
- rewardPerToken model  
- cumulative index accounting  
- fair time-based distribution  

### Lending Model
- collateral vs debt accounting  
- borrow limits  
- solvency constraints  

### Liquidations
- health factor  
- liquidation threshold & bonus  
- bad debt prevention  

### Interest Rate Model
- utilization-based pricing  
- two-slope (kink) model  
- liquidity control mechanism  

### Aave v3 Mapping
- Pool / aToken / debt token architecture  
- full lifecycle: deposit → borrow → repay → liquidate  

---

## On-Chain Interaction

### Backend Flow

```
read state (multicall)
→ send transaction
→ wait for confirmation
→ parse receipt
→ decode events
→ monitor via listeners
```

---

## Example: Event Decoding

```js
const receipt = await tx.wait();

for (const log of receipt.logs) {
  try {
    const parsed = iface.parseLog(log);

    if (parsed.name === "Transfer") {
      console.log({
        from: parsed.args.from,
        to: parsed.args.to,
        value: parsed.args.value.toString()
      });
    }

  } catch (e) {
    // ignore non-matching logs
  }
}
```

---

## Failure Scenario: Oracle Mispricing → Insolvency

A lending protocol can be fully correct at the code level and still fail due to incorrect pricing.

```
Collateral real value: $100
Oracle reports: $150 (stale or manipulated)

User borrows against inflated value:
→ borrows $120

Market corrects price to $100:
→ position becomes undercollateralized

If liquidation is delayed or insufficient:
→ protocol absorbs bad debt
→ system becomes insolvent
```

Key insight:

- protocols depend on external truth  
- incorrect pricing breaks all internal guarantees  
- oracle safety is not a feature — it is a system dependency  
- liquidation is only effective if pricing is correct  

---

## Project Structure

```
src/
  ├── oracle/
  ├── amm/
  ├── staking/
  └── lending/

test/
  ├── oracle/
  ├── amm/
  ├── staking/
  └── lending/

docs/
  ├── liquidation-mechanics.md
  ├── interest-rate-models.md
  ├── oracle-risk-in-lending-protocols.md
  ├── tx-lifecycle-and-receipt-analysis.md
  └── aave-v3-architecture-mapping.md

script/
  ├── contractStateReader.js
  ├── writeAndDecode.js
  ├── analyzeBorrowReceipt.js
  ├── readTransferEvents.js
  ├── listenTransferEvents.js
  └── mint.js
```

---

## What This Demonstrates

- Ability to design DeFi protocol primitives  
- Understanding of financial risk in smart contracts  
- Strong grasp of oracle failure modes  
- Experience with transaction lifecycle and event systems  
- Ability to read and interact with live blockchain state  
- Mapping production protocols (Aave v3) into implementable models  

---

## Tech Stack

- Solidity (0.8.x)  
- Foundry  
- Ethers.js v6  
- Node.js  

---

## How to Run

```bash
forge build
forge test
```

Run scripts:

```bash
node script/contractStateReader.js
node script/writeAndDecode.js
```

---

## What Comes Next

This repository is the foundation.

The production work lives in two separate repositories:

- **defi-lending-protocol** — full lending protocol: collateral vault, borrow engine, liquidation, interest accrual, invariant tests  
- **rwa-invoice-financing** — RWA invoice financing protocol: invoice NFT registry, senior/junior tranches, custom oracle adapter, settlement logic, self-audit  

Both built from the primitives developed here.