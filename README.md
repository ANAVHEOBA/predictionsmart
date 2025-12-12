# PredictionSmart

Decentralized prediction market protocol built on **Sui Move**.

---

## Deployed on Sui Testnet

```
Package ID:      0x9d006bf5d2141570cf19e4cee42ed9638db7aff56cb30ad1a4b1aa212caf9adb
MarketRegistry:  0xdb9b4975c219f9bfe8755031d467a274c94eacb317f7dbb144c5285a023fdc10
Network:         Sui Testnet
```

**Explorer:** [View on SuiScan](https://suiscan.xyz/testnet/object/0x9d006bf5d2141570cf19e4cee42ed9638db7aff56cb30ad1a4b1aa212caf9adb)

---

## Overview

PredictionSmart enables users to create prediction markets, trade outcome tokens, and earn rewards for accurate predictions. Similar to Polymarket, but built natively on Sui.

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
| [Trading](sources/trading/README.md) | Order book + AMM | 10 | 28 |
| [Wallet](sources/wallet/README.md) | Smart wallets, gasless tx | 7 | 51 |
| [Oracle](sources/oracle/README.md) | Market resolution, price feeds | 8 | 21 |
| [Fee](sources/fee/README.md) | Dynamic fees, referrals | 7 | 29 |

**Total: 172 tests (all passing)**

---

## Sui Integration

Built natively on Sui using Mysten Labs frameworks:

| Integration | Usage |
|-------------|-------|
| **Sui Move** | All smart contracts |
| **Sui Objects** | Markets, Tokens, Vaults as first-class objects |
| **Shared Objects** | MarketRegistry for global state |
| **sui::coin** | Native SUI payments |
| **sui::clock** | On-chain timestamps |
| **sui::event** | Event emission for indexing |
| **Pyth Network** | Price feed oracle (testnet) |
| **Switchboard** | Price feed oracle (testnet) |

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

When market ends, outcome is determined via:
- **Admin resolution** - Platform admin decides
- **Creator resolution** - Market creator decides
- **Oracle resolution** - Optimistic oracle with disputes
- **Price feed** - Automatic via Pyth/Switchboard

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
┌─────────────────────────────────────────────────────────────────────────────┐
│                              ENTRY POINTS                                    │
│  market_entries | token_entries | trading_entries | wallet_entries          │
│  oracle_entries | fee_entries                                                │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            BUSINESS LOGIC                                    │
│  market_operations | token_operations | trading_operations                   │
│  wallet_operations | oracle_operations | fee_operations                      │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TYPES & EVENTS                                     │
│  market_types/events | token_types/events | trading_types/events            │
│  wallet_types/events | oracle_types/events | fee_types/events               │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          ORACLE ADAPTERS                                     │
│                    pyth_adapter | switchboard_adapter                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

Each module follows a 4-file pattern:
- `types.move` - Data structures, constants, getters, setters
- `events.move` - Event definitions
- `operations.move` - Business logic (internal)
- `entries.move` - Entry functions (public)

---

## Features

### Market Module
- Create binary markets (Yes/No)
- Configurable resolution types (Admin/Creator/Oracle)
- Automatic trading end on expiry
- Void markets with full refunds
- Pause/unpause functionality

### Token Module
- Mint token sets (SUI → YES + NO)
- Merge token sets (YES + NO → SUI)
- Redeem winning tokens
- Split/merge individual tokens
- Refund voided markets

### Trading Module
- Limit order book
- AMM liquidity pools (constant product)
- Order matching engine
- Swap YES ↔ NO
- Liquidity provider rewards

### Wallet Module
- Smart contract wallets
- Operator approvals with spending limits
- Session keys with expiration
- Batch transactions
- Gasless transaction support

### Oracle Module
- Optimistic oracle (propose → dispute → finalize)
- Pyth price feed integration
- Switchboard price feed integration
- Configurable dispute windows
- Bond-based security

### Fee Module
- Dynamic fee tiers (Bronze → Diamond)
- Volume-based discounts
- Revenue sharing (protocol/creator/referrer)
- Referral code system
- Fee exemptions

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
sui client publish --gas-budget 800000000
```

---

## Frontend Integration

See [docs/integration/](docs/integration/) for comprehensive frontend integration guides:

- [README.md](docs/integration/README.md) - Setup and overview
- [FLOW.md](docs/integration/FLOW.md) - Integration flow diagram
- [market.md](docs/integration/market.md) - Market module
- [token.md](docs/integration/token.md) - Token module
- [trading.md](docs/integration/trading.md) - Trading module
- [oracle.md](docs/integration/oracle.md) - Oracle module
- [wallet.md](docs/integration/wallet.md) - Wallet module
- [fee.md](docs/integration/fee.md) - Fee module

### Quick Example

```typescript
import { SuiClient } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";

const client = new SuiClient({ url: "https://fullnode.testnet.sui.io:443" });

const PACKAGE_ID = "0x9d006bf5d2141570cf19e4cee42ed9638db7aff56cb30ad1a4b1aa212caf9adb";
const MARKET_REGISTRY = "0xdb9b4975c219f9bfe8755031d467a274c94eacb317f7dbb144c5285a023fdc10";

// Create a market
const tx = new Transaction();
const [feeCoin] = tx.splitCoins(tx.gas, [100_000_000]);

tx.moveCall({
  target: `${PACKAGE_ID}::market_entries::create_market`,
  arguments: [
    tx.object(MARKET_REGISTRY),
    tx.pure.string("Will BTC reach $100k by Dec 2025?"),
    tx.pure.string("Resolves YES if BTC > $100,000"),
    tx.pure.u8(1), // ORACLE resolution
    tx.pure.u64(Date.now() + 30 * 24 * 60 * 60 * 1000),
    feeCoin,
    tx.object("0x6"),
  ],
});
```

---

## Project Structure

```
predictionsmart/
├── Move.toml                 # Package manifest
├── README.md                 # This file
├── sources/
│   ├── market/               # Market module
│   │   ├── types.move
│   │   ├── events.move
│   │   ├── operations.move
│   │   ├── entries.move
│   │   └── README.md
│   ├── token/                # Token module
│   │   ├── types.move
│   │   ├── events.move
│   │   ├── operations.move
│   │   ├── entries.move
│   │   └── README.md
│   ├── trading/              # Trading module
│   │   ├── types.move
│   │   ├── events.move
│   │   ├── operations.move
│   │   ├── entries.move
│   │   └── README.md
│   ├── wallet/               # Wallet module
│   │   ├── types.move
│   │   ├── events.move
│   │   ├── operations.move
│   │   ├── entries.move
│   │   └── README.md
│   ├── oracle/               # Oracle module
│   │   ├── types.move
│   │   ├── events.move
│   │   ├── operations.move
│   │   ├── entries.move
│   │   ├── pyth_adapter.move
│   │   ├── switchboard_adapter.move
│   │   └── README.md
│   └── fee/                  # Fee module
│       ├── types.move
│       ├── events.move
│       ├── operations.move
│       ├── entries.move
│       └── README.md
├── tests/
│   ├── market_tests.move
│   ├── token_tests.move
│   ├── trading_tests.move
│   ├── wallet_tests.move
│   ├── oracle_tests.move
│   └── fee_tests.move
└── docs/
    └── integration/          # Frontend integration docs
        ├── README.md
        ├── FLOW.md
        ├── market.md
        ├── token.md
        ├── trading.md
        ├── oracle.md
        ├── wallet.md
        └── fee.md
```

---

## Future Improvements

| Feature | Description |
|---------|-------------|
| Multi-Collateral | USDC and stablecoin support |
| Multi-Outcome | Markets with >2 outcomes |
| Off-chain Matching | Hybrid order book for gas efficiency |
| Governance | DAO for protocol parameters |

---

## License

MIT




 | Name      | Vibe                                      |
  |-----------|-------------------------------------------|
  | Oraclr    | Clean, modern, hints at oracle/prediction |
  | Foresui   | Foresight + Sui mashup                    |
  | Prophex   | Prophet + exchange                        |
  | Veredic   | From "verdict" - markets decide truth     |
  | Augur Sui | Classic prediction market name            |
  | Presage   | Means "omen/prediction" - elegant         |
  | Suicasts  | Sui + forecasts                           |
  | Divina    | Divine/divination - knowing the future    |
