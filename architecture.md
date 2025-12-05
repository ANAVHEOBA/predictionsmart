# PredictionSmart - Sui Prediction Market Architecture

## Overview

This document outlines the architecture for building a decentralized prediction market on Sui blockchain, inspired by Polymarket's proven design patterns but adapted for Sui's object-centric model and Move programming language.

---

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [System Architecture](#system-architecture)
3. [Smart Contract Design](#smart-contract-design)
4. [Token Mechanics](#token-mechanics)
5. [Order Book System](#order-book-system)
6. [Oracle Integration](#oracle-integration)
7. [Market Lifecycle](#market-lifecycle)
8. [Key Differences from Polymarket](#key-differences-from-polymarket)

---

## Core Concepts

### What is a Prediction Market?

A prediction market allows users to trade on the outcome of future events. Users buy shares representing outcomes (YES/NO), and the market price reflects the collective probability assessment.

**Key Principles:**
- Each winning share redeems for $1 (or 1 USDC equivalent)
- Losing shares become worthless
- Market prices represent implied probabilities (e.g., $0.60 = 60% probability)

### Polymarket's Proven Model

Polymarket uses:
- **Gnosis Conditional Token Framework (CTF)**: ERC-1155 tokens representing outcome shares
- **Hybrid-Decentralized CLOB**: Off-chain order matching, on-chain settlement
- **UMA Optimistic Oracle**: Decentralized outcome resolution with dispute mechanism

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend (Web/Mobile)                     │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Off-Chain Components                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Order Book     │  │  Matching       │  │  API Gateway    │  │
│  │  (CLOB)         │  │  Engine         │  │                 │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Sui Blockchain (On-Chain)                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Market         │  │  Outcome        │  │  Settlement     │  │
│  │  Registry       │  │  Tokens         │  │  Module         │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Collateral     │  │  Oracle         │  │  Admin          │  │
│  │  Vault          │  │  Adapter        │  │  Controls       │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    External Services                             │
│  ┌─────────────────┐  ┌─────────────────┐                       │
│  │  Pyth Oracle    │  │  Switchboard    │                       │
│  │  (Price Feeds)  │  │  (Custom Data)  │                       │
│  └─────────────────┘  └─────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Smart Contract Design

### Monolithic Architecture Pattern

We use a **single-package monolithic architecture** - all modules in one deployable package. This is the standard pattern for Sui DeFi protocols like DeepBook and Cetus.

**Why Monolithic for Prediction Markets:**
- Atomic transactions across all modules (critical for trading)
- Simpler deployment and upgrades
- Shared types without cross-package dependencies
- Easier testing and auditing

---

### Project Structure (Industry Standard)

```
predictionsmart/
│
├── Move.toml                    # Package manifest & dependencies
├── Move.lock                    # Dependency lock (auto-generated)
│
├── sources/                     # All Move source code
│   │
│   ├── predictionsmart.move     # Main entry point & package init
│   │
│   ├── # ─────────── CORE MODULES ───────────
│   ├── market.move              # Market creation, state, lifecycle
│   ├── outcome_token.move       # Conditional tokens (YES/NO shares)
│   ├── vault.move               # Collateral custody & accounting
│   │
│   ├── # ─────────── TRADING MODULES ───────────
│   ├── orderbook.move           # On-chain order book (optional)
│   ├── exchange.move            # Trade execution & settlement
│   ├── matching.move            # Order matching logic
│   │
│   ├── # ─────────── ORACLE MODULES ───────────
│   ├── oracle.move              # Oracle interface & resolution
│   ├── pyth_adapter.move        # Pyth price feed integration
│   ├── resolution.move          # Optimistic resolution logic
│   │
│   ├── # ─────────── ACCESS CONTROL ───────────
│   ├── admin.move               # Admin capabilities & controls
│   ├── operator.move            # Operator permissions (for CLOB)
│   │
│   ├── # ─────────── UTILITIES ───────────
│   ├── events.move              # All event definitions
│   ├── errors.move              # Error codes & constants
│   └── math.move                # Math utilities (fixed-point, etc.)
│
├── tests/                       # Unit & integration tests
│   ├── market_tests.move
│   ├── token_tests.move
│   ├── trading_tests.move
│   ├── oracle_tests.move
│   └── integration_tests.move
│
├── scripts/                     # Deployment & admin scripts
│   ├── deploy.sh
│   ├── upgrade.sh
│   └── seed_markets.sh
│
├── docs/                        # Documentation
│   └── api.md
│
└── architecture.md              # This file
```

---

### Module Dependency Graph

```
                    ┌─────────────────┐
                    │ predictionsmart │  (entry point)
                    │    .move        │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
   ┌──────────┐       ┌──────────┐       ┌──────────┐
   │  admin   │       │  market  │       │ operator │
   └────┬─────┘       └────┬─────┘       └────┬─────┘
        │                  │                  │
        │     ┌────────────┼────────────┐     │
        │     │            │            │     │
        ▼     ▼            ▼            ▼     ▼
   ┌──────────────┐  ┌──────────┐  ┌──────────────┐
   │outcome_token │  │  vault   │  │   exchange   │
   └──────────────┘  └──────────┘  └──────┬───────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    │                     │                     │
                    ▼                     ▼                     ▼
              ┌──────────┐         ┌──────────┐         ┌──────────┐
              │ orderbook│         │ matching │         │  oracle  │
              └──────────┘         └──────────┘         └────┬─────┘
                                                             │
                                          ┌──────────────────┼──────────────────┐
                                          │                  │                  │
                                          ▼                  ▼                  ▼
                                   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
                                   │pyth_adapter │   │ resolution  │   │   events    │
                                   └─────────────┘   └─────────────┘   └─────────────┘

                    ┌─────────────────────────────────────────────────┐
                    │              SHARED UTILITIES                    │
                    │     errors.move  │  math.move  │  events.move   │
                    └─────────────────────────────────────────────────┘
```

---

### Move.toml Configuration

```toml
[package]
name = "predictionsmart"
edition = "2024.beta"
license = "MIT"
authors = ["Your Name <your@email.com>"]
published-at = "0x0"  # Updated after deployment

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/testnet" }

# Pyth Oracle (for price-based markets)
Pyth = { git = "https://github.com/pyth-network/pyth-crosschain.git", subdir = "target_chains/sui/contracts", rev = "sui-contract-v1.0.0" }

# Optional: Switchboard for custom feeds
# Switchboard = { git = "https://github.com/switchboard-xyz/sui-sdk.git", rev = "main" }

[addresses]
predictionsmart = "0x0"  # Placeholder, assigned on publish
sui = "0x2"
pyth = "0x0"  # Set to Pyth package address on target network

[dev-dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/testnet" }

[dev-addresses]
predictionsmart = "0x0"
```

---

### Module Responsibilities

| Module | Responsibility | Key Types |
|--------|----------------|-----------|
| `predictionsmart` | Package init, shared object creation | `Registry` |
| `market` | Market CRUD, lifecycle states | `Market`, `MarketConfig` |
| `outcome_token` | Token minting, burning, transfers | `OutcomeToken` |
| `vault` | Collateral deposits, withdrawals | `Vault`, `Balance` |
| `exchange` | Trade execution, settlement | `Trade`, `Order` |
| `orderbook` | On-chain limit order book | `OrderBook`, `Level` |
| `matching` | Price-time priority matching | - |
| `oracle` | Resolution interface | `OracleCap`, `Resolution` |
| `pyth_adapter` | Pyth price feed integration | `PriceConfig` |
| `resolution` | Optimistic oracle logic | `Proposal`, `Dispute` |
| `admin` | Admin capabilities | `AdminCap`, `GlobalConfig` |
| `operator` | CLOB operator permissions | `OperatorCap` |
| `events` | Event definitions | All `*Event` types |
| `errors` | Error codes | Constants |
| `math` | Fixed-point math, calculations | - |

---

### Shared Objects vs Owned Objects

```
SHARED OBJECTS (global state, consensus required):
┌─────────────────────────────────────────────────────────┐
│ Registry        - Global market registry                │
│ Vault<T>        - Collateral pool per asset type        │
│ OrderBook       - Order book per market (if on-chain)   │
│ GlobalConfig    - Platform configuration                │
└─────────────────────────────────────────────────────────┘

OWNED OBJECTS (user-owned, no consensus):
┌─────────────────────────────────────────────────────────┐
│ OutcomeToken    - User's YES/NO shares                  │
│ AdminCap        - Admin capability (single owner)       │
│ OperatorCap     - Operator capability                   │
│ OracleCap       - Oracle resolver capability            │
└─────────────────────────────────────────────────────────┘

IMMUTABLE OBJECTS:
┌─────────────────────────────────────────────────────────┐
│ Market          - Market definition (after creation)    │
│ MarketConfig    - Resolution rules, fees                │
└─────────────────────────────────────────────────────────┘
```

### 1. Market Module (`market.move`)

Handles market creation and state management.

```move
module predictionsmart::market {
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;

    /// Represents a prediction market
    struct Market has key, store {
        id: UID,
        question: vector<u8>,           // Market question (IPFS hash or direct)
        description: vector<u8>,        // Additional details
        outcome_count: u8,              // Always 2 for binary markets
        resolution_time: u64,           // When market can be resolved
        status: u8,                     // 0=Open, 1=Paused, 2=Resolved
        winning_outcome: Option<u8>,    // Set after resolution
        total_collateral: u64,          // Total USDC locked
        created_at: u64,
        oracle_source: address,         // Oracle that will resolve this market
    }

    /// Market status constants
    const MARKET_OPEN: u8 = 0;
    const MARKET_PAUSED: u8 = 1;
    const MARKET_RESOLVED: u8 = 2;

    /// Create a new binary prediction market
    public fun create_market(
        question: vector<u8>,
        description: vector<u8>,
        resolution_time: u64,
        oracle_source: address,
        ctx: &mut TxContext
    ): Market;

    /// Resolve market with winning outcome
    public fun resolve_market(
        market: &mut Market,
        winning_outcome: u8,
        oracle_cap: &OracleCap
    );
}
```

### 2. Outcome Token Module (`outcome_token.move`)

Implements conditional tokens as Sui objects.

```move
module predictionsmart::outcome_token {
    use sui::object::{Self, UID};
    use sui::balance::Balance;
    use sui::coin::Coin;

    /// Represents shares in a specific outcome
    struct OutcomeToken<phantom COLLATERAL> has key, store {
        id: UID,
        market_id: ID,          // Reference to parent market
        outcome: u8,            // 0 = NO, 1 = YES
        amount: u64,            // Number of shares
    }

    /// Split collateral into outcome tokens
    /// 1 USDC -> 1 YES token + 1 NO token
    public fun split<COLLATERAL>(
        market: &Market,
        collateral: Coin<COLLATERAL>,
        ctx: &mut TxContext
    ): (OutcomeToken<COLLATERAL>, OutcomeToken<COLLATERAL>);

    /// Merge outcome tokens back into collateral
    /// 1 YES token + 1 NO token -> 1 USDC
    public fun merge<COLLATERAL>(
        market: &Market,
        yes_token: OutcomeToken<COLLATERAL>,
        no_token: OutcomeToken<COLLATERAL>,
        ctx: &mut TxContext
    ): Coin<COLLATERAL>;

    /// Redeem winning tokens after resolution
    /// 1 winning token -> 1 USDC
    public fun redeem<COLLATERAL>(
        market: &Market,
        token: OutcomeToken<COLLATERAL>,
        ctx: &mut TxContext
    ): Coin<COLLATERAL>;
}
```

### 3. Vault Module (`vault.move`)

Manages collateral deposits and withdrawals.

```move
module predictionsmart::vault {
    use sui::object::{Self, UID};
    use sui::balance::Balance;
    use sui::coin::Coin;

    /// Global vault holding all collateral
    struct Vault<phantom COLLATERAL> has key {
        id: UID,
        balance: Balance<COLLATERAL>,
        total_locked: u64,
    }

    /// Deposit collateral for minting outcome tokens
    public fun deposit<COLLATERAL>(
        vault: &mut Vault<COLLATERAL>,
        coin: Coin<COLLATERAL>,
    ): u64;

    /// Withdraw collateral (for redemption/merge)
    public fun withdraw<COLLATERAL>(
        vault: &mut Vault<COLLATERAL>,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<COLLATERAL>;
}
```

### 4. Exchange Module (`exchange.move`)

Handles atomic swaps and order execution.

```move
module predictionsmart::exchange {
    use sui::object::{Self, UID};

    /// Signed order structure (EIP-712 equivalent for Sui)
    struct Order has store, drop {
        maker: address,
        market_id: ID,
        outcome: u8,              // Which outcome to buy/sell
        side: u8,                 // 0 = BUY, 1 = SELL
        price: u64,               // Price in basis points (0-10000)
        amount: u64,              // Number of shares
        expiration: u64,          // Order expiry timestamp
        nonce: u64,               // For replay protection
        signature: vector<u8>,    // Maker's signature
    }

    /// Execute a matched trade between maker and taker
    public fun execute_trade<COLLATERAL>(
        market: &Market,
        vault: &mut Vault<COLLATERAL>,
        maker_order: Order,
        taker_order: Order,
        ctx: &mut TxContext
    );

    /// Fill order against existing liquidity (operator-submitted)
    public fun fill_order<COLLATERAL>(
        market: &Market,
        vault: &mut Vault<COLLATERAL>,
        orders: vector<Order>,
        operator_cap: &OperatorCap,
        ctx: &mut TxContext
    );
}
```

### 5. Oracle Adapter Module (`oracle_adapter.move`)

Integrates with external oracles for market resolution.

```move
module predictionsmart::oracle_adapter {
    use sui::object::{Self, UID};

    /// Oracle capability for resolution
    struct OracleCap has key, store {
        id: UID,
        authorized_resolver: address,
    }

    /// Proposal for market resolution (optimistic oracle pattern)
    struct ResolutionProposal has key, store {
        id: UID,
        market_id: ID,
        proposed_outcome: u8,
        proposer: address,
        bond_amount: u64,
        proposal_time: u64,
        challenge_period_end: u64,
        disputed: bool,
    }

    /// Propose a resolution (requires bond)
    public fun propose_resolution<COLLATERAL>(
        market: &Market,
        outcome: u8,
        bond: Coin<COLLATERAL>,
        ctx: &mut TxContext
    ): ResolutionProposal;

    /// Dispute a proposal (within challenge period)
    public fun dispute_resolution<COLLATERAL>(
        proposal: &mut ResolutionProposal,
        bond: Coin<COLLATERAL>,
        ctx: &mut TxContext
    );

    /// Finalize resolution after challenge period
    public fun finalize_resolution(
        market: &mut Market,
        proposal: ResolutionProposal,
        ctx: &mut TxContext
    );

    /// Integration with Pyth for price-based markets
    public fun resolve_with_pyth(
        market: &mut Market,
        pyth_price_info: &PriceInfoObject,
        oracle_cap: &OracleCap,
    );
}
```

---

## Token Mechanics

### Splitting and Merging

The core mechanism that enables prediction markets:

```
SPLITTING:
┌─────────┐        ┌─────────┐
│ 1 USDC  │  ───►  │ 1 YES   │
└─────────┘        └─────────┘
                   ┌─────────┐
                   │ 1 NO    │
                   └─────────┘

MERGING:
┌─────────┐
│ 1 YES   │        ┌─────────┐
└─────────┘  ───►  │ 1 USDC  │
┌─────────┐        └─────────┘
│ 1 NO    │
└─────────┘

REDEMPTION (after resolution, if YES wins):
┌─────────┐        ┌─────────┐
│ 1 YES   │  ───►  │ 1 USDC  │
└─────────┘        └─────────┘

┌─────────┐        ┌─────────┐
│ 1 NO    │  ───►  │ 0 USDC  │
└─────────┘        └─────────┘
```

### Price Discovery

- **YES price + NO price = $1.00** (always, due to arbitrage)
- If YES trades at $0.65, NO implicitly trades at $0.35
- This creates a "mirrored" order book

---

## Order Book System

### Hybrid-Decentralized Model

Following Polymarket's approach:

1. **Off-Chain Order Book**
   - Orders stored and matched off-chain for speed
   - Users sign orders with their Sui wallet
   - Operator matches orders based on price-time priority

2. **On-Chain Settlement**
   - Matched orders submitted to blockchain
   - Smart contract verifies signatures and executes atomically
   - Non-custodial: funds never leave user control until trade executes

### Order Flow

```
1. User creates order → Signs with wallet
2. Order sent to operator → Stored in order book
3. Matching engine finds counterparty
4. Operator submits matched orders to Sui
5. Exchange contract:
   - Verifies both signatures
   - Checks balances/allowances
   - Executes atomic swap
   - Emits trade event
```

### Order Types

| Type | Description |
|------|-------------|
| GTC (Good Till Canceled) | Remains until filled or canceled |
| FOK (Fill or Kill) | Must fill entirely or not at all |
| IOC (Immediate or Cancel) | Fill what's possible, cancel rest |

---

## Oracle Integration

### The Challenge: Long-Tail Data

Unlike price feeds (BTC/USD), prediction markets need answers to questions like:
- "Will Chelsea win the match?"
- "Will Trump sign the deal?"
- "Will it rain in NYC on Dec 25?"

**No oracle provides this data on-chain.** This is why Polymarket uses human reporters with economic incentives.

### Our Approach: Tiered Resolution System

We use different resolution methods based on market type and stage of platform growth:

```
┌─────────────────────────────────────────────────────────────────┐
│                    RESOLUTION TIERS                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  TIER 1: Price-Based Markets (Automated)                        │
│  ├── Pyth Oracle (FREE on-chain)                                │
│  ├── "Will BTC > $100k?" → Auto-resolve from price feed         │
│  └── No human intervention needed                               │
│                                                                  │
│  TIER 2: Admin Resolution (MVP Phase)                           │
│  ├── Platform admin resolves markets                            │
│  ├── Simple, fast, no infrastructure cost                       │
│  └── Users trust platform initially                             │
│                                                                  │
│  TIER 3: Optimistic Resolution (Growth Phase)                   │
│  ├── Anyone can propose outcome + stake bond                    │
│  ├── Challenge period for disputes                              │
│  └── Disputed → Admin/DAO decides                               │
│                                                                  │
│  TIER 4: Decentralized Voting (Scale Phase)                     │
│  ├── Token holders vote on disputed outcomes                    │
│  ├── Quadratic voting to prevent whale attacks                  │
│  └── Full decentralization                                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

### Tier 1: Pyth Price Feeds (FREE)

For markets based on asset prices. **No API key required for on-chain usage.**

**Supported market types:**
- Crypto prices: "Will BTC be above $100k on Dec 31?"
- Stock prices: "Will AAPL close above $200?"
- Forex: "Will EUR/USD be above 1.10?"

```move
/// Resolve market using Pyth price feed
public fun resolve_with_pyth(
    market: &mut Market,
    pyth_state: &PythState,
    price_info: &PriceInfoObject,
    target_price: u64,
    comparison: u8,  // 0 = above, 1 = below, 2 = equal
) {
    // Verify resolution time has passed
    assert!(clock::timestamp_ms() >= market.resolution_time, E_TOO_EARLY);

    // Get price from Pyth (free on-chain)
    let price = pyth::get_price(pyth_state, price_info);

    // Determine outcome based on comparison
    let outcome = match (comparison) {
        0 => if (price.price >= target_price) { 1 } else { 0 },  // above
        1 => if (price.price <= target_price) { 1 } else { 0 },  // below
        2 => if (price.price == target_price) { 1 } else { 0 },  // equal
    };

    resolve_market_internal(market, outcome);
}
```

---

### Tier 2: Admin Resolution (MVP - Start Here)

For all other markets in the early stage. Simple and effective.

**How it works:**
1. Admin creates market with question + resolution criteria
2. Event happens in real world
3. Admin checks outcome against resolution criteria
4. Admin calls `resolve_market()` with winning outcome
5. Users redeem winning tokens

```move
/// Admin-only market resolution
struct AdminCap has key, store {
    id: UID,
}

public fun admin_resolve(
    market: &mut Market,
    outcome: u8,
    _admin_cap: &AdminCap,  // Proves caller is admin
    ctx: &mut TxContext
) {
    assert!(market.status == MARKET_OPEN, E_MARKET_NOT_OPEN);
    assert!(clock::timestamp_ms() >= market.resolution_time, E_TOO_EARLY);
    assert!(outcome < market.outcome_count, E_INVALID_OUTCOME);

    market.status = MARKET_RESOLVED;
    market.winning_outcome = option::some(outcome);

    emit(MarketResolved {
        market_id: object::id(market),
        outcome,
        resolver: tx_context::sender(ctx),
        timestamp: clock::timestamp_ms(),
    });
}
```

**Why this is fine for MVP:**
- Polymarket also has admin emergency controls
- Users accept some trust in early-stage platforms
- Build reputation before decentralizing
- Focus on UX and market mechanics first

---

### Tier 3: Optimistic Resolution (Growth Phase)

When you have users and want more decentralization.

**Flow:**
```
1. Event happens (Chelsea wins)
           │
           ▼
2. Reporter proposes "YES" + stakes 100 SUI bond
           │
           ▼
3. Challenge period starts (2-6 hours)
           │
     ┌─────┴─────┐
     │           │
     ▼           ▼
4a. No dispute   4b. Someone disputes + stakes 100 SUI
     │                    │
     ▼                    ▼
5a. Auto-finalize   5b. Escalate to Admin/DAO
     │                    │
     ▼                    ▼
6a. Reporter gets    6b. Winner gets both bonds
    bond back + reward    Loser loses bond
```

```move
/// Resolution proposal with bond
struct ResolutionProposal has key, store {
    id: UID,
    market_id: ID,
    proposed_outcome: u8,
    proposer: address,
    bond: Balance<SUI>,
    proposal_time: u64,
    challenge_end: u64,
    status: u8,  // 0=pending, 1=disputed, 2=finalized
}

/// Minimum bond scales with market size
const MIN_BOND_BPS: u64 = 100;  // 1% of market collateral, min 10 SUI

public fun propose_resolution(
    market: &Market,
    outcome: u8,
    bond: Coin<SUI>,
    clock: &Clock,
    ctx: &mut TxContext
): ResolutionProposal {
    let min_bond = max(
        (market.total_collateral * MIN_BOND_BPS) / 10000,
        10_000_000_000  // 10 SUI minimum
    );
    assert!(coin::value(&bond) >= min_bond, E_INSUFFICIENT_BOND);

    ResolutionProposal {
        id: object::new(ctx),
        market_id: object::id(market),
        proposed_outcome: outcome,
        proposer: tx_context::sender(ctx),
        bond: coin::into_balance(bond),
        proposal_time: clock::timestamp_ms(clock),
        challenge_end: clock::timestamp_ms(clock) + CHALLENGE_PERIOD,
        status: PROPOSAL_PENDING,
    }
}

public fun dispute_resolution(
    proposal: &mut ResolutionProposal,
    bond: Coin<SUI>,
    ctx: &mut TxContext
) {
    assert!(proposal.status == PROPOSAL_PENDING, E_NOT_DISPUTABLE);
    assert!(clock::timestamp_ms() < proposal.challenge_end, E_CHALLENGE_ENDED);
    assert!(coin::value(&bond) >= balance::value(&proposal.bond), E_INSUFFICIENT_BOND);

    proposal.status = PROPOSAL_DISPUTED;
    // Store disputer bond, escalate to admin/DAO
}

public fun finalize_resolution(
    market: &mut Market,
    proposal: ResolutionProposal,
    clock: &Clock,
    ctx: &mut TxContext
): Coin<SUI> {
    assert!(proposal.status == PROPOSAL_PENDING, E_DISPUTED);
    assert!(clock::timestamp_ms() >= proposal.challenge_end, E_CHALLENGE_ACTIVE);

    // Resolve market
    market.status = MARKET_RESOLVED;
    market.winning_outcome = option::some(proposal.proposed_outcome);

    // Return bond + reward to proposer
    let ResolutionProposal { id, bond, .. } = proposal;
    object::delete(id);
    coin::from_balance(bond, ctx)
}
```

**Economic Security:**
- Bond scales with market size (1% of total collateral, min 10 SUI)
- $7M market → $70k bond (not $750 like Polymarket's vulnerability)
- Disputers must match bond
- Wrong proposer/disputer loses bond to winner

---

### Tier 4: Decentralized Voting (Future)

For fully trustless operation. Implement when you have a governance token.

**Features:**
- Platform token holders vote on disputed outcomes
- Quadratic voting: 1 vote = 1 token, 4 votes = 16 tokens
- Time-locked tokens (must hold 30+ days to vote)
- Rewards for correct voters, slashing for incorrect

---

### Market Type → Resolution Method Matrix

| Market Type | Examples | Resolution Method |
|-------------|----------|-------------------|
| **Crypto Price** | BTC > $100k, ETH > $5k | Pyth (automated) |
| **Stock Price** | AAPL > $200, TSLA > $300 | Pyth (automated) |
| **Sports** | Chelsea wins, Lakers win | Optimistic → Admin |
| **Politics** | Election results, legislation | Optimistic → Admin |
| **Weather** | Rain in NYC, temperature | Admin (no oracle) |
| **Custom Events** | Product launches, earnings | Optimistic → Admin |

---

### Why Not Just Use UMA?

UMA is EVM-only (Ethereum/Polygon). We're on Sui.

**Our advantages over UMA's model:**
1. **Scaled bonds** - Bond proportional to market size prevents cheap attacks
2. **Simpler dispute** - Admin resolution for disputes (for now) vs complex DVM
3. **Faster** - 2-hour challenge vs potential 48-72 hour UMA disputes
4. **Sui-native** - No bridging, no EVM dependency

---

## Market Lifecycle

```
┌──────────────────────────────────────────────────────────────────┐
│                        MARKET LIFECYCLE                           │
└──────────────────────────────────────────────────────────────────┘

    ┌─────────┐      ┌─────────┐      ┌─────────┐      ┌─────────┐
    │ CREATE  │ ───► │  OPEN   │ ───► │ RESOLVE │ ───► │ SETTLED │
    └─────────┘      └─────────┘      └─────────┘      └─────────┘
         │                │                │                │
         ▼                ▼                ▼                ▼
    - Set question   - Trading      - Oracle        - Winners
    - Set deadline     active         reports         redeem
    - Initialize     - Split/merge   - Challenge    - Losing
      collateral       allowed        period         tokens
    - Set oracle     - Order book   - Finalize       worthless
                       active
```

### State Transitions

| From | To | Trigger |
|------|----|---------|
| - | Created | Admin creates market |
| Created | Open | After initialization |
| Open | Paused | Admin pause (emergency) |
| Paused | Open | Admin unpause |
| Open | Resolving | Resolution time reached |
| Resolving | Resolved | Oracle finalizes outcome |
| Resolved | Settled | All redemptions processed |

---

## Key Differences from Polymarket

| Aspect | Polymarket (Polygon/EVM) | PredictionSmart (Sui) |
|--------|--------------------------|----------------------|
| **Token Standard** | ERC-1155 (CTF) | Sui Objects (native) |
| **Collateral** | USDC (ERC-20) | USDC on Sui |
| **Gas Model** | User pays gas | Sponsor transactions possible |
| **Object Model** | Account-based | Object-centric |
| **Parallelism** | Sequential | Parallel execution |
| **Oracle** | UMA Optimistic Oracle | Pyth/Switchboard + Custom |
| **Signatures** | EIP-712 | Sui native signatures |

### Sui-Specific Advantages

1. **Object-Centric Model**: Outcome tokens are first-class objects, enabling direct transfers without approval patterns
2. **Parallel Execution**: Multiple trades can execute simultaneously
3. **Sponsored Transactions**: Platform can pay gas for better UX
4. **Native Move Safety**: Type-safe, resource-oriented programming prevents common exploits

---

## Security Considerations

### Smart Contract Security

1. **Reentrancy**: Move's ownership model prevents reentrancy by default
2. **Integer Overflow**: Move has built-in overflow checks
3. **Access Control**: Capability-based permissions
4. **Oracle Manipulation**: Use time-weighted prices, multiple sources

### Economic Security

1. **Bond Requirements**: Proposers stake collateral for resolutions
2. **Challenge Period**: Time for disputes before finalization
3. **Liquidity Guards**: Minimum liquidity requirements
4. **Rate Limiting**: Prevent flash loan attacks

---

## Implementation Phases

### Phase 1: Core Infrastructure
- [ ] Market creation and management
- [ ] Outcome token minting (split/merge)
- [ ] Basic collateral vault
- [ ] Manual resolution (admin-only)

### Phase 2: Trading
- [ ] On-chain order execution
- [ ] Signature verification
- [ ] Operator integration
- [ ] Fee collection

### Phase 3: Oracle Integration
- [ ] Optimistic oracle pattern
- [ ] Pyth price feed integration
- [ ] Dispute resolution mechanism

### Phase 4: Advanced Features
- [ ] Multi-outcome markets
- [ ] Liquidity incentives
- [ ] Governance
- [ ] Cross-chain support

---

## References

- [Polymarket Documentation](https://docs.polymarket.com/)
- [Polymarket CTF Exchange (GitHub)](https://github.com/Polymarket/ctf-exchange)
- [Gnosis Conditional Token Framework](https://docs.gnosis.io/conditionaltokens/)
- [UMA Optimistic Oracle](https://docs.uma.xyz/)
- [Pyth Network on Sui](https://docs.pyth.network/price-feeds/use-real-time-data/sui)
- [Sui Move Documentation](https://docs.sui.io/concepts/sui-move-concepts)
- [How Polymarket Works](https://rocknblock.io/blog/how-polymarket-works-the-tech-behind-prediction-markets)
- [Polymarket Architecture Analysis](https://research.auditless.com/p/al-71-how-polymarkets-architecture)
