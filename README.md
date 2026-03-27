# DeFi Lending Primitives

This module implements safe oracle consumption for DeFi lending protocols.

## Components

- ChainlinkPriceFeedReader  
  Reads oracle data and performs basic validation.

- OracleGuard  
  Validates price safety (staleness, deviation).

- OracleConsumer  
  Demonstrates safe usage of oracle data in a protocol context.

## Key Concepts

- Price normalization (1e18)
- Staleness protection
- Oracle safety layer design

---

## Day 68 — Oracle Consumer Refactor

Refactored oracle consumption into a stateful model:

- `updatePrice()` — validates and accepts new oracle price
- `getPrice()` — returns last accepted price

### Improvements

- Separated write (oracle update) from read (price usage)
- Introduced `lastAcceptedPrice` as a stable price reference
- Prevented invalid updates from affecting protocol state
- Enforces invariant: failed updates must not modify previously accepted price

### Test Coverage

Added full test coverage for:

- stale price
- deviation limits (upward, downward, boundary)
- negative price
- incomplete oracle round
- uninitialized state

### Design Insight

Instead of trusting oracle data on every read, the protocol now:

- validates external data once
- stores a safe version in state
- uses only previously accepted values

This pattern protects the protocol from faulty or manipulated oracle updates.