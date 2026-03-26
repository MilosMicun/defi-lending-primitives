# DeFi Lending Primitives

Phase 5 — Oracle Safety

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