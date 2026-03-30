# DeFi Lending Primitives

This module explores oracle design patterns for DeFi lending protocols.

From external price feeds to custom validation systems for illiquid assets.

---

## Components

### ChainlinkPriceFeedReader  
Reads oracle data and performs basic validation.

### OracleGuard  
Validates price safety (staleness, deviation).

### OracleConsumer  
Demonstrates safe usage of oracle data in a protocol context.

### InvoiceOracle  
Custom oracle for illiquid real-world assets using dispute-based validation.

---

## Key Concepts

- Price normalization (1e18)
- Staleness protection
- Oracle safety layers
- Dispute-based validation
- Time-dependent state machines

---

## Day 68 — Oracle Consumer Refactor

Refactored oracle consumption into a stateful model.

### Approach

Instead of trusting oracle data on every read, the protocol:

- validates external data once  
- stores a safe version in state  
- uses only previously accepted values  

### Implementation

- `updatePrice()` — validates and accepts new oracle price  
- `getPrice()` — returns last accepted price  

### Improvements

- Separated write (oracle update) from read (price usage)  
- Introduced `lastAcceptedPrice` as a stable reference  
- Prevented invalid updates from affecting protocol state  
- Enforced invariant: failed updates must not modify accepted price  

### Test Coverage

- stale price  
- deviation limits (upward, downward, boundary)  
- negative price  
- incomplete oracle round  
- uninitialized state  

### Insight

External data is untrusted.

Protocols should **validate once, store, and reuse safe values**.

---

## Day 69 — Custom Oracle Design (RWA)

Designed a custom oracle for illiquid real-world assets where no price feed exists.

### Problem

Traditional oracle systems assume:

- continuous market pricing  
- external data availability  

RWA assets (invoices, receivables, private debt) do not satisfy these assumptions.

### Approach

Instead of price feeds:

- submit value  
- allow dispute  
- finalize if uncontested  

This shifts oracle design from data ingestion to **state validation**.

---

### Architecture

`InvoiceOracle` implements a dispute-based validation model:

- `submit()` — authorized submitter proposes value  
- `dispute()` — challenger can contest within dispute window  
- `finalize()` — value becomes final if not disputed  
- `cancelDisputedSubmission()` — disputed submissions are removed  

Each `invoiceId` represents an independent state machine.

---

### State Machine


NO STATE
↓
SUBMITTED (active)
↓
├──→ FINALIZED
└──→ DISPUTED → CANCELLED


---

### Properties

- mutually exclusive terminal states  
- no overwrite of active submissions  
- no finalize after dispute  
- strict dispute window enforcement  
- full state cleanup after terminal transitions  

---

### Access Control

- `submitter` — proposes values  
- `challenger` — disputes values  
- `owner` — manages roles and resolves disputes  

Enforces separation of responsibilities in adversarial environments.

---

### Test Coverage

22 tests covering:

- full state machine transitions  
- role-based access control  
- invalid input and invalid state transitions  
- dispute window boundary conditions  
- event emission verification  
- storage cleanup correctness  
- isolation across multiple `invoiceId` values  

---

### Insight

Not all oracles are data feeds.

For illiquid assets, oracle design becomes:

→ value assertion  
→ challenge mechanism  
→ time-based resolution  

Security emerges from **roles, time, and state transitions**, not external data sources.

---

## Summary

This module demonstrates two oracle paradigms:

- Day 68 → **validate external data before using it**
- Day 69 → **design a system when external data does not exist**

Together, they show that oracle design is not just integration — it is protocol engineering.