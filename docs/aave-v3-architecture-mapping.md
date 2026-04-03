# Aave v3 Architecture Mapping

## Overview

This document maps a minimal lending pool model to the Aave v3 architecture.

In the minimal model, user state lives directly inside `Pool.sol` through internal mappings:
- collateral balance
- debt balance

In Aave v3, positions are represented through protocol-controlled tokens:
- `aToken` for the collateral side
- `VariableDebtToken` for the debt side

The goal of this document is to show how the same lending operations are modeled differently in:
- a simple mapping-based system
- a production DeFi protocol architecture

Final mental model:
position = (aToken balance, VariableDebtToken balance)

---

## My Model vs Aave Model

### My Model (Mapping-Based)

In the minimal implementation, all user state is stored directly inside the `Pool` contract:

- `collateralBalanceOf[user]`
- `debtBalanceOf[user]`

The `Pool` is responsible for:
- holding user funds
- updating balances
- enforcing risk constraints (LTV, health factor)
- executing all state transitions

This creates a tightly coupled system where:
- execution logic and storage live in the same contract
- user positions are tied directly to addresses through mappings

---

### Aave Model (Token-Based)

In Aave v3, user positions are not stored as mappings inside the `Pool`.

Instead, they are represented through tokens:

- `aToken` → represents supplied collateral
- `VariableDebtToken` → represents borrowed debt

This creates a different architecture:

- `Pool` acts as an orchestrator (validation + coordination)
- `aToken` handles collateral accounting
- `VariableDebtToken` handles debt accounting

---

### Key Difference

Minimal model:
- state = mappings inside one contract

Aave model:
- state = token balances across multiple contracts

This allows Aave to:
- decouple execution from accounting
- make positions composable across the DeFi ecosystem
- scale across multiple assets and reserves

---

## Flow Mapping

### Deposit

Minimal model:
- user transfers collateral to the Pool
- Pool updates:
  - `collateralBalanceOf[user] += amount`

Aave:
- user supplies underlying asset via Pool
- Pool validates the action
- `aToken` is minted to the user

Key idea:
- mapping update → replaced by aToken mint

---

### Borrow

Minimal model:
- Pool checks borrow limit
- `debtBalanceOf[user] += amount`
- Pool transfers asset to user

Aave:
- Pool validates borrow (collateral, oracle, risk parameters)
- underlying asset is transferred to the user
- `VariableDebtToken` is minted to represent the debt

Key idea:
- mapping debt increase → replaced by debt token mint

---

### Repay

Minimal model:
- user transfers asset to Pool
- Pool reduces:
  - `debtBalanceOf[user] -= amount`

Aave:
- user transfers underlying asset to the protocol
- `VariableDebtToken` is burned

Key idea:
- mapping decrease → replaced by debt token burn

---

### Withdraw

Minimal model:
- Pool checks health factor
- Pool reduces:
  - `collateralBalanceOf[user] -= amount`
- underlying asset is transferred to user

Aave:
- Pool validates health factor after withdrawal
- `aToken` is burned
- underlying asset is transferred to the user

Key idea:
- mapping decrease → replaced by aToken burn

---

## Core Components

### Pool

`Pool` is the main execution layer of the protocol.

It does not represent the full user position by itself. Its role is to:
- receive user actions
- validate protocol rules
- coordinate state transitions across the system

`Pool` is the orchestrator, not the accounting container.

---

### AToken

`AToken` represents the supplied side of the position.

When a user deposits collateral:
- `aToken` is minted to the user's wallet

When a user withdraws:
- `aToken` is burned

This means:
- collateral is tokenized
- ownership is determined by token balance, not internal mappings
- the position lives in the user's wallet as a standard ERC20

---

### VariableDebtToken

`VariableDebtToken` represents the borrowed side of the position.

When a user borrows:
- debt tokens are minted to the borrower

When a user repays:
- debt tokens are burned

This means:
- debt is tokenized and tracked per address
- debt is not just a number in `Pool`, but a separate accounting layer

**VariableDebtToken is intentionally non-transferable.**

Unlike `aToken`, debt cannot be sent to another address. This is a deliberate protocol design decision, not a limitation.

If debt were transferable, a borrower could move their liability to any address — including one with no collateral. The protocol would lose the ability to enforce health factor checks and liquidate the correct position. Solvency depends on the debt staying attached to the address that owns the collateral.

---

## Why Aave Uses This Design

Aave separates `Pool`, `aToken`, and `VariableDebtToken` because a production lending protocol requires modular and scalable architecture.

### 1. Separation of Concerns

Minimal model:
- one contract handles everything

Aave:
- `Pool` → execution and validation
- `aToken` → collateral accounting
- `VariableDebtToken` → debt accounting

This makes the system modular and easier to extend without changing core logic.

---

### 2. Tokenized Positions

Minimal model:
- positions stored as mappings, invisible outside the contract

Aave:
- positions represented as tokens, readable by any external system

This provides a standard, interoperable way to represent user state.

---

### 3. Composability

Mapping-based state is locked inside a single contract. Nothing outside can read or use it without custom integration.

Token-based state behaves as a first-class asset. For example: a user who deposits USDC into Aave receives `aUSDC` in their wallet. That `aUSDC` can be deposited into a Curve or Convex strategy to earn additional yield — while the underlying USDC continues earning Aave supply interest. This is not possible with `collateralBalanceOf[alice] = 1000` stored in a private mapping.

---

### 4. Clear Asset/Liability Model

Aave models positions explicitly:

- assets → `aToken`
- liabilities → `VariableDebtToken`

This mirrors how real financial systems separate assets from liabilities on a balance sheet, and scales better than a single-contract mapping model.

---

## Key Takeaways

The minimal Pool model demonstrates core lending mechanics correctly.

Aave v3 implements the same ideas with a modular, token-based architecture.

The key shift is:

- minimal model → state stored in Pool mappings
- Aave → state represented through protocol-controlled tokens

The architectural consequence: in Aave, your position is portable. In a mapping-based system, your position is a number inside someone else's contract.