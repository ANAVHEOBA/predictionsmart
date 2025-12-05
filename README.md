# PredictionSmart

Sui Move smart contracts for decentralized prediction markets.

---

## Overview

PredictionSmart is a prediction market protocol built on Sui. Users can create markets, trade outcome tokens, and earn rewards for accurate predictions.

```
┌─────────────────────────────────────────────────────────────┐
│  "Will BTC reach $100k by end of 2025?"                     │
│                                                             │
│              67%                                            │
│            chance                                           │
│                                                             │
│      [Yes $0.67]          [No $0.33]                        │
│                                                             │
│  $2.4m Vol.  |  Dec 31, 2025                                │
└─────────────────────────────────────────────────────────────┘
```

---

## Modules

| Module | Description | Features | Tests |
|--------|-------------|----------|-------|
| [Market](sources/market/README.md) | Binary prediction markets | 6 | 18 |
| [Token](sources/token/README.md) | Outcome tokens (YES/NO) | 8 | 25 |
| [Trading](sources/trading/README.md) | Order book + AMM | 10 | 18 |
| [Wallet](sources/wallet/README.md) | Proxy wallets, gasless tx | 7 | 51 |

**Total: 112 tests (all passing)**

---

## How It Works

### 1. Create Market

Anyone can create a binary prediction market with a question and end date.

```
User pays creation fee → Market created → Trading opens
```

### 2. Mint Tokens

Users deposit SUI to mint outcome tokens.

```
1 SUI → 1 YES token + 1 NO token
```

### 3. Trade

Buy/sell tokens via order book or AMM.

```
YES at $0.67 = 67% implied probability
NO at $0.33 = 33% implied probability
```

### 4. Resolution

When market ends, outcome is determined.

```
YES wins → YES tokens worth $1, NO tokens worth $0
NO wins  → NO tokens worth $1, YES tokens worth $0
```

### 5. Redeem

Winners redeem tokens for payout.

```
1 winning token → 1 SUI
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Entry Points                           │
│  market_entries | token_entries | trading_entries | wallet  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Business Logic                           │
│  market_operations | token_operations | trading_operations  │
│                    wallet_operations                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Types & Events                            │
│  market_types | token_types | trading_types | wallet_types  │
│  market_events | token_events | trading_events | wallet_ev  │
└─────────────────────────────────────────────────────────────┘
```

Each module follows:
- `types.move` - Data structures, constants, getters, setters
- `operations.move` - Business logic
- `entries.move` - Entry functions
- `events.move` - Event definitions

---

## Features Summary

### Market Module
- Create binary markets (Yes/No)
- Automatic trading end
- Creator/Admin resolution
- Void markets with refunds

### Token Module
- Mint token sets (SUI → YES + NO)
- Merge token sets (YES + NO → SUI)
- Redeem winning tokens
- Refund voided markets

### Trading Module
- Limit order book
- AMM liquidity pools
- Order matching
- Swap YES ↔ NO

### Wallet Module
- Proxy wallets per user
- Gasless transactions (relayer-paid)
- Operator approvals with limits
- Batch transactions
- Ed25519/Secp256k1 signatures

---

## Quick Start

### Build

```bash
sui move build
```

### Test

```bash
sui move test
```

### Deploy

```bash
sui client publish --gas-budget 100000000
```

---

## Project Structure

```
predictionsmart/
├── Move.toml              # Package manifest
├── README.md              # This file
├── sources/
│   ├── market/            # Market module
│   │   ├── types.move
│   │   ├── events.move
│   │   ├── operations.move
│   │   ├── entries.move
│   │   └── README.md
│   ├── token/             # Token module
│   │   ├── types.move
│   │   ├── events.move
│   │   ├── operations.move
│   │   ├── entries.move
│   │   └── README.md
│   ├── trading/           # Trading module
│   │   ├── types.move
│   │   ├── events.move
│   │   ├── operations.move
│   │   ├── entries.move
│   │   └── README.md
│   └── wallet/            # Wallet module
│       ├── types.move
│       ├── events.move
│       ├── operations.move
│       ├── entries.move
│       └── README.md
└── tests/
    ├── market_tests.move
    ├── token_tests.move
    ├── trading_tests.move
    └── wallet_tests.move
```

---

## Not Yet Implemented

| Module | Description |
|--------|-------------|
| Oracle Adapter | UMA/Pyth integration for automated resolution |
| Fee Module | Dynamic fees, tiers, revenue sharing |
| Multi-Collateral | USDC and stablecoin support |
| Neg-Risk | Multi-outcome markets (>2 outcomes) |
| Off-chain Matching | Hybrid order book |

See [modules.md](modules.md) for details.

---

## License

MIT
