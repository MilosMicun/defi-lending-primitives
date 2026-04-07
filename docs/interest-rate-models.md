# Interest Rate Models — Utilization & Kink Design

## Overview

In a lending protocol, interest is not just yield.

It is the **price of liquidity over time**.

The interest rate model determines how this price changes based on how much of the pool is currently being used.

Its role is not cosmetic — it is a **core control mechanism** that keeps the system balanced.

---

## Mental Model

A lending market has two sides:

- suppliers provide capital
- borrowers consume liquidity

The protocol does not manually balance the system.

Instead, it adjusts **price**, and users react.

The core loop is:
utilization ↑
→ borrow APR ↑
→ borrow ↓ + repay ↑ + supply ↑
→ utilization ↓

This is a **self-regulating system**.

---

## Utilization

Utilization measures how much of the available capital is currently borrowed.
U = borrows / (cash + borrows)

Where:

- `cash` = available liquidity
- `borrows` = outstanding debt

Interpretation:

- low U → excess liquidity
- high U → scarce liquidity
- very high U → system under stress

---

## Borrow Rate as a Function of Utilization

The protocol defines:
borrowAPR = f(U)

The rate must:

- be low when liquidity is abundant
- increase as liquidity becomes scarce
- become very high when the pool is near exhaustion

A constant rate would fail to adapt to market conditions.

---

## Kink Model (Two-Slope Design)

Instead of a single linear function, the model uses a **piecewise curve** with a kink.

### Visual intuition
APR
│                                         ╱
│                                       ╱
│                                     ╱  ← slope2 (steep)
│                                   ╱
│                                 ╱
│                 ╱──────────────╱  ← kink point
│               ╱  ← slope1 (gentle)
│             ╱
│           ╱
│─────────╱
0%       kink (e.g. 80%)              100%   U

- before kink → gentle slope (normal zone)
- after kink → steep slope (stress zone)

---

## Parameters

- `baseRate` — minimum rate at U = 0
- `slope1` — rate increase per unit of utilization before kink
- `slope2` — rate increase per unit of utilization after kink
- `kink` — utilization threshold separating the two zones

---

## Before Kink (Normal Zone)
r(U) = baseRate + (U * slope1) / kink

- gradual increase
- encourages borrowing
- reflects healthy liquidity conditions

---

## After Kink (Stress Zone)
r(U) = baseRate + slope1 + ((U - kink) * slope2) / (1 - kink)

- aggressive increase
- discourages further borrowing
- incentivizes repayment and new deposits

---

## Key Property

The function is **continuous at the kink**:
r(kink) = baseRate + slope1

There is no jump in value — only a change in slope.

---

## Supply Rate

Suppliers do not receive the full borrow rate.
supplyAPR = borrowAPR * U * (1 - reserveFactor)

Reasons:

1. Only utilized capital generates yield
2. The protocol keeps a portion as reserves

---

## Flow of Value
Borrowers pay interest
↓
Borrow APR
↓
× utilization
↓
Active yield
↓
Split:
→ Suppliers (yield)
→ Protocol (reserves)

---

## Reserve Factor

The reserve factor represents the protocol's share of interest.

It is used for:

- absorbing bad debt
- improving system resilience
- maintaining long-term stability

Constraint:
reserveFactor < 100%

If it were 100%, suppliers would earn nothing.

---

## System Behavior

The model creates economic incentives instead of hard rules.

### When utilization is low

- borrow APR is low
- borrowing is attractive
- utilization increases

### When utilization is high

- borrow APR rises sharply
- borrowing becomes expensive
- repayment increases
- suppliers are attracted by higher yield

---

## Dynamic Equilibrium

The system does not stay fixed.

It oscillates around the kink:
U < kink → cheap borrowing → U increases
U > kink → expensive borrowing → U decreases

The kink acts as a **magnet point**.

---

## Edge Cases

### U = 0

- no active borrowing
- borrow APR = baseRate
- supply APR = 0

### U = kink

- transition point
- still uses slope1
- ensures continuity

### U → 100%

- liquidity is nearly exhausted
- borrow APR approaches maximum
- strong pressure to restore liquidity

---

## Design Insight

The interest rate model does not enforce safety directly.

It **shapes user behavior** so that unsafe states are less likely to occur.

---

## Relation to Liquidations

- liquidations → enforce solvency
- interest rates → manage liquidity conditions

Together, they form the core risk framework of a lending protocol.

---

## Key Takeaway

Interest rates in DeFi are not a feature.

They are a **deterministic control system** that:

- prices liquidity
- influences user decisions
- stabilizes the market

→ See implementation: [`src/lending/InterestRateModel.sol`](../src/lending/InterestRateModel.sol)