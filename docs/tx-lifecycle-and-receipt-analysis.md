# Transaction Lifecycle & Receipt Analysis

## 1. Transaction Lifecycle

A transaction in Ethereum is not just "success" or "fail".

It goes through three distinct stages:

- Intent → what we send (to, data, value)
- Execution → EVM runs the transaction
- Receipt → the result of execution

The receipt is the first reliable signal of what actually happened.

---

## 2. Receipt Structure

A transaction receipt contains:

- status → 1 (success) or 0 (revert)
- blockNumber → where execution happened
- gasUsed → execution cost
- logs → emitted events

The receipt does not store state changes directly.

Instead, it stores logs that describe what happened.

---

## 3. Logs and Events

Each log contains:

- address → contract that emitted the event
- topics → indexed parameters (including event signature)
- data → non-indexed parameters

Events are decoded using ABI.

Example:

Borrow(
  reserve,
  user,
  onBehalfOf,
  amount,
  interestRateMode,
  borrowRate,
  referralCode
)

Logs are not the source of truth.

State is.

But logs are the signal that allows us to understand execution.

---

## 4. Borrow Event Analysis (Aave v3)

From a single transaction receipt we can extract:

- asset borrowed (reserve)
- user address
- borrow amount
- interest rate mode
- borrow rate
- referral code

Example:

- Asset: USDT
- Amount: 12,000
- Rate mode: variable

Borrow rate is reported in ray format, where 1e27 = 100%.

Example:
33236824142730526465265708 / 1e27 ≈ 0.033236824142730526  
≈ 3.32% APR

This represents a real protocol state transition.

---

## 5. Failed Transactions & Revert Inspection

If receipt.status === 0:

- transaction started execution
- reverted at some point
- all state changes are discarded
- gas is still consumed

To understand why it failed:

- replay the transaction using `provider.call`
- execute it at the original block (blockTag)

This allows extracting revert reason.

Important:

Replaying on the latest block can produce incorrect results.

---

## 6. Key Insights

- Transaction ≠ Receipt
- Receipt ≠ State
- Logs ≠ Source of truth
- Logs = Execution signal
- Revert reason requires replay
- Block context matters for correctness

---

## 7. Engineering Insight

Receipt parsing is naturally handled in the off-chain layer (ethers / JS).

Solidity is better suited for:

- execution
- state reading
- invariant enforcement

Understanding where each tool fits is critical for protocol engineering.