# Oracle Risk in Lending Protocols

## Why Oracle Design Is Critical

In a lending protocol, the oracle is not just a market data source.

It is the pricing input used by the solvency engine.

Oracle prices directly affect:

- collateral valuation
- borrow capacity
- health factor
- liquidation eligibility

If the protocol uses incorrect prices, every downstream decision becomes unsafe, even if the core pool logic is implemented correctly.

A correct pool with a bad oracle is still a broken protocol.

---

## The Core Risk

Lending systems rely on the assumption that collateral and debt can be converted into a shared unit of account.

In simplified form:

- collateral value = collateral amount × collateral price
- debt value = debt amount × debt price

These values are then used to determine:

- maximum borrow amount
- liquidation thresholds
- solvency status

Because of this, oracle failure is not a UI issue or a reporting issue.

It is a balance-sheet failure.

---

## Main Oracle Risk Categories

### 1. Stale Data

If the oracle returns an outdated price, the protocol may continue to treat unhealthy positions as safe.

This is dangerous during fast market moves.

If collateral falls sharply but the price feed still reports the older value, users may borrow against collateral that no longer supports the debt.

#### Risk

- delayed liquidations
- undercollateralized debt
- bad debt accumulation

#### Defenses

- heartbeat / max delay checks
- updatedAt validation
- reject stale price usage
- pause risk-increasing actions when data is stale

---

### 2. Spot Price Manipulation

Raw AMM spot prices can be moved within a single block if liquidity is shallow enough.

If a lending protocol uses manipulated spot prices as the collateral reference, an attacker may temporarily inflate collateral value, borrow too much, and leave the protocol with bad debt after the price returns to normal.

#### Risk

- inflated collateral valuation
- over-borrowing
- oracle-driven insolvency

#### Defenses

- do not use raw spot price for borrow-critical decisions
- prefer TWAP or robust external oracle sources
- compare multiple sources when possible
- use deviation checks

---

### 3. Bad Collateral Valuation

A price can be fresh and still be unsafe.

This happens when the oracle source does not reflect realizable liquidation value.

Examples:

- thinly traded assets
- incorrect market pair
- wrong decimal normalization
- stale NAV-based assets
- illiquid RWA collateral

#### Risk

- incorrect LTV assumptions
- liquidations that cannot fully cover debt
- hidden insolvency

#### Defenses

- conservative collateral factors
- asset-specific risk parameters
- borrow and supply caps
- governance review before listing
- liquidity-aware collateral policy

---

### 4. Oracle Lag vs Market Reality

Unlike stale data, where the oracle stops updating, lag occurs when the oracle is updating correctly but market volatility exceeds its update frequency.

Even if a price feed is functioning, it may update too slowly relative to market volatility.

In that case, liquidations are triggered too late.

The system can become undercollateralized before liquidators are able to act.

#### Risk

- liquidation backlog
- underwater positions
- protocol bad debt

#### Defenses

- lower LTV for volatile assets
- strong liquidation incentives
- caps and isolation modes
- careful asset listing standards

---

## Oracle Risk for RWAs (Off-Chain Assets)

Oracle risk for real-world assets (RWAs) is fundamentally different from crypto price feed risk.

In crypto markets, the main risk is price manipulation of an existing market price.

In RWAs, the main risk is latency between off-chain reality and on-chain state.

An invoice does not gradually change price like a token.

It becomes impaired when an off-chain event occurs:

- the debtor defaults
- the payment is delayed
- the legal status changes

The key problem is that this information is not instantly reflected on-chain.

There is an unavoidable delay between:

- real-world state change
- oracle submission
- dispute window
- finalization

During this delay, the protocol may operate on outdated assumptions.

### Risk

- collateral appears valid while it is already impaired off-chain
- borrowing continues against assets that should no longer be accepted
- liquidations may happen too late to fully recover value

### Key Difference vs Crypto Oracles

- crypto oracle risk → incorrect price of a liquid asset
- RWA oracle risk → delayed awareness of a discrete state change

### Defenses

- conservative LTV and liquidation thresholds
- delayed borrowing power for newly submitted collateral
- dispute windows before finalization
- role-based submission with accountability
- periodic re-validation of asset state
- caps on total exposure per asset type

### Protocol Insight

In RWAs, oracle design is not just about price accuracy.

It is about correctly modeling time, state transitions, and information delay between off-chain events and on-chain enforcement.

---

## TWAP vs Spot

### Spot Price

Spot price reflects the current reserve state of a pool at a single moment.

#### Advantage

- very fresh

#### Weakness

- highly manipulable in short time windows

Spot price is often unsuitable as the sole oracle input for lending decisions.

---

### TWAP

TWAP smooths price over time.

#### Advantage

- improves resistance to short-lived manipulation
- makes single-block attacks more expensive

#### Weakness

- slower to reflect sudden market changes

TWAP is not perfect.

It trades some freshness for greater manipulation resistance.

---

## Core Oracle Design Principles

### 1. Treat price as a risky input

Oracle values should never be assumed safe by default.

---

### 2. Enforce staleness checks

If the protocol cannot verify freshness, it should not continue using the price as if it were valid.

---

### 3. Block risk-increasing actions first

When oracle quality is uncertain, borrowing and risky withdrawals should be restricted before repayments or other risk-reducing actions.

---

### 4. Use conservative parameters for risky collateral

Not all assets deserve the same LTV, threshold, or caps.

---

### 5. Match oracle design to asset type

Liquid on-chain assets, thinly traded tokens, and RWAs require different valuation models.

---

### 6. Prefer sanity checks and source comparison

Deviation checks and secondary references help detect anomalous prices.

---

### 7. Remember that oracle risk is broader than smart contract risk

Oracle failure can come from technical issues, liquidity conditions, operational failure, or governance mistakes.

---

## Protocol Engineering Takeaway

Lending protocols do not only depend on code correctness.

They depend on value correctness.

The pool can be mathematically correct and still fail economically if the oracle provides stale, manipulable, or unrealistic prices.

That is why oracle design is one of the most critical parts of lending protocol architecture.