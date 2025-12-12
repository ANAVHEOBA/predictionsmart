# PredictionSmart Integration Flow

## Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         PREDICTIONSMART INTEGRATION FLOW                        │
└─────────────────────────────────────────────────────────────────────────────────┘

                                    ┌──────────────┐
                                    │   1. SETUP   │
                                    └──────┬───────┘
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    ▼                      ▼                      ▼
            ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
            │ Connect      │      │ Initialize   │      │ Setup        │
            │ Wallet       │      │ Sui Client   │      │ Fee Registry │
            │ (dApp Kit)   │      │              │      │ (Admin only) │
            └──────────────┘      └──────────────┘      └──────────────┘


                                    ┌──────────────┐
                                    │  2. MARKETS  │
                                    └──────┬───────┘
                                           │
            ┌──────────────────────────────┼──────────────────────────────┐
            ▼                              ▼                              ▼
    ┌──────────────┐              ┌──────────────┐              ┌──────────────┐
    │ Browse       │              │ Create       │              │ Get Market   │
    │ Markets      │              │ Market       │              │ Details      │
    │ (Query)      │              │ (Creator)    │              │ (Query)      │
    └──────────────┘              └──────┬───────┘              └──────────────┘
                                         │
                                         ▼
                                  ┌──────────────┐
                                  │ Initialize   │
                                  │ Token Vault  │
                                  │ + Order Book │
                                  └──────────────┘


                                    ┌──────────────┐
                                    │ 3. TRADING   │
                                    └──────┬───────┘
                                           │
        ┌──────────────────────────────────┼──────────────────────────────────┐
        ▼                                  ▼                                  ▼
┌──────────────┐                  ┌──────────────┐                  ┌──────────────┐
│ MINT TOKENS  │                  │ ORDER BOOK   │                  │ AMM POOL     │
│              │                  │              │                  │              │
│ Deposit SUI  │                  │ Place Buy    │                  │ Swap YES↔NO  │
│     ↓        │                  │ Place Sell   │                  │ Add Liq.     │
│ Get YES + NO │                  │ Cancel Order │                  │ Remove Liq.  │
└──────────────┘                  └──────────────┘                  └──────────────┘


                                    ┌──────────────┐
                                    │ 4. RESOLUTION│
                                    └──────┬───────┘
                                           │
        ┌──────────────────────────────────┼──────────────────────────────────┐
        ▼                                  ▼                                  ▼
┌──────────────┐                  ┌──────────────┐                  ┌──────────────┐
│ ADMIN/       │                  │ OPTIMISTIC   │                  │ PRICE FEED   │
│ CREATOR      │                  │ ORACLE       │                  │ (Pyth/SB)    │
│              │                  │              │                  │              │
│ Direct       │                  │ 1. Request   │                  │ Auto-resolve │
│ Resolution   │                  │ 2. Propose   │                  │ via price    │
│              │                  │ 3. Dispute?  │                  │ comparison   │
│              │                  │ 4. Finalize  │                  │              │
└──────────────┘                  └──────────────┘                  └──────────────┘


                                    ┌──────────────┐
                                    │  5. REDEEM   │
                                    └──────┬───────┘
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    ▼                      ▼                      ▼
            ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
            │ Redeem       │      │ Merge        │      │ Redeem       │
            │ Winning      │      │ YES + NO     │      │ Voided       │
            │ Tokens       │      │ (anytime)    │      │ (refund)     │
            │              │      │              │      │              │
            │ YES/NO → SUI │      │ → Get SUI    │      │ → Full SUI   │
            └──────────────┘      └──────────────┘      └──────────────┘
```

## Step-by-Step Integration Guide

### Step 1: Initial Setup

```typescript
// 1a. Install dependencies
// npm install @mysten/sui @mysten/dapp-kit @tanstack/react-query

// 1b. Initialize client
import { SuiClient } from "@mysten/sui/client";

const client = new SuiClient({ url: "https://fullnode.testnet.sui.io:443" });

const CONFIG = {
  PACKAGE_ID: "0x9d006bf5d2141570cf19e4cee42ed9638db7aff56cb30ad1a4b1aa212caf9adb",
  MARKET_REGISTRY: "0xdb9b4975c219f9bfe8755031d467a274c94eacb317f7dbb144c5285a023fdc10",
};

// 1c. Connect wallet (React)
import { ConnectButton } from "@mysten/dapp-kit";
// <ConnectButton />
```

### Step 2: Browse & Create Markets

```typescript
// 2a. Get all markets
const registry = await client.getObject({
  id: CONFIG.MARKET_REGISTRY,
  options: { showContent: true },
});
const marketIds = registry.data?.content?.fields?.markets || [];

// 2b. Create a market
const tx = new Transaction();
const [feeCoin] = tx.splitCoins(tx.gas, [100_000_000]); // 0.1 SUI fee

tx.moveCall({
  target: `${CONFIG.PACKAGE_ID}::market_entries::create_market`,
  arguments: [
    tx.object(CONFIG.MARKET_REGISTRY),
    tx.pure.string("Will BTC reach $100k by Dec 2025?"),
    tx.pure.string("Resolves YES if BTC > $100,000"),
    tx.pure.u8(1), // ORACLE resolution
    tx.pure.u64(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
    feeCoin,
    tx.object("0x6"), // Clock
  ],
});
```

### Step 3: Trade Tokens

```typescript
// 3a. MINT: Deposit SUI → Get YES + NO tokens
const tx = new Transaction();
const [deposit] = tx.splitCoins(tx.gas, [1_000_000_000]); // 1 SUI

tx.moveCall({
  target: `${CONFIG.PACKAGE_ID}::token_entries::mint_tokens`,
  arguments: [
    tx.object(MARKET_ID),
    tx.object(VAULT_ID),
    deposit,
    tx.object("0x6"),
  ],
});
// Result: User gets 1 YES token + 1 NO token

// 3b. ORDER BOOK: Place limit order
const tx = new Transaction();
const [payment] = tx.splitCoins(tx.gas, [500_000_000]); // 0.5 SUI

tx.moveCall({
  target: `${CONFIG.PACKAGE_ID}::trading_entries::place_buy_order`,
  arguments: [
    tx.object(MARKET_ID),
    tx.object(ORDER_BOOK_ID),
    tx.pure.u8(0), // YES token
    tx.pure.u64(6000), // 60% price
    payment,
    tx.object("0x6"),
  ],
});

// 3c. AMM: Instant swap
tx.moveCall({
  target: `${CONFIG.PACKAGE_ID}::trading_entries::swap_yes_for_no`,
  arguments: [
    tx.object(POOL_ID),
    tx.object(YES_TOKEN_ID),
    tx.pure.u64(100_000_000), // Amount in
    tx.pure.u64(90_000_000), // Min out (slippage)
  ],
});
```

### Step 4: Market Resolution

```typescript
// 4a. OPTIMISTIC: Request → Propose → Wait → Finalize
// Anyone requests
tx.moveCall({
  target: `${CONFIG.PACKAGE_ID}::oracle_entries::request_resolution`,
  arguments: [
    tx.object(ORACLE_REGISTRY),
    tx.object(MARKET_ID),
    bondCoin,
    tx.object("0x6"),
  ],
});

// Proposer proposes outcome
tx.moveCall({
  target: `${CONFIG.PACKAGE_ID}::oracle_entries::propose_outcome`,
  arguments: [
    tx.object(ORACLE_REGISTRY),
    tx.object(REQUEST_ID),
    tx.pure.u8(0), // 0 = YES
    bondCoin,
    tx.object("0x6"),
  ],
});

// After dispute window (anyone can finalize)
tx.moveCall({
  target: `${CONFIG.PACKAGE_ID}::oracle_entries::finalize_undisputed`,
  arguments: [
    tx.object(ORACLE_REGISTRY),
    tx.object(REQUEST_ID),
    tx.object(MARKET_ID),
    tx.object("0x6"),
  ],
});

// 4b. ADMIN: Direct resolution
tx.moveCall({
  target: `${CONFIG.PACKAGE_ID}::market_entries::resolve_by_admin`,
  arguments: [
    tx.object(MARKET_REGISTRY),
    tx.object(ADMIN_CAP),
    tx.object(MARKET_ID),
    tx.pure.u8(0), // YES
    tx.object("0x6"),
  ],
});
```

### Step 5: Redeem Winnings

```typescript
// 5a. Redeem winning tokens (if YES won, redeem YES tokens)
tx.moveCall({
  target: `${CONFIG.PACKAGE_ID}::token_entries::redeem_yes_tokens`,
  arguments: [
    tx.object(MARKET_ID),
    tx.object(VAULT_ID),
    tx.object(YES_TOKEN_ID),
  ],
});
// Result: YES tokens → SUI

// 5b. Merge tokens (anytime - exit position)
tx.moveCall({
  target: `${CONFIG.PACKAGE_ID}::token_entries::merge_token_set`,
  arguments: [
    tx.object(MARKET_ID),
    tx.object(VAULT_ID),
    tx.object(YES_TOKEN_ID),
    tx.object(NO_TOKEN_ID),
    tx.pure.u64(amount),
  ],
});
// Result: 1 YES + 1 NO → 1 SUI
```

## User Journey Summary

| Stage | User Action | Contract Call |
|-------|-------------|---------------|
| **Discovery** | Browse markets | Query `MarketRegistry` |
| **Entry** | Buy position | `mint_tokens` or `place_buy_order` |
| **Trading** | Adjust position | `swap_*`, `place_*_order` |
| **Resolution** | Wait/Participate | `propose_outcome`, `finalize_*` |
| **Exit** | Claim winnings | `redeem_*_tokens` |

## Frontend Pages Needed

| Page | Purpose | Key Functions |
|------|---------|---------------|
| **Home/Markets** | List all markets, filters | Query `MarketRegistry` |
| **Market Detail** | Chart, order book, trade UI | `mint_tokens`, `place_*_order`, `swap_*` |
| **Portfolio** | User's positions across markets | Query user's tokens |
| **Create Market** | Form to create new market | `create_market` |
| **Resolution** | View/participate in oracle | `propose_outcome`, `dispute_outcome` |
| **Profile** | Fee tier, referrals, wallet | Query `UserFeeStats` |

## Event Subscriptions

Subscribe to real-time updates:

```typescript
// Market events
client.subscribeEvent({
  filter: { MoveEventType: `${PACKAGE_ID}::market_events::MarketCreated` },
  onMessage: (event) => console.log("New market:", event),
});

// Trading events
client.subscribeEvent({
  filter: { MoveEventType: `${PACKAGE_ID}::trading_events::OrderFilled` },
  onMessage: (event) => console.log("Order filled:", event),
});

// Token events
client.subscribeEvent({
  filter: { MoveEventType: `${PACKAGE_ID}::token_events::TokensMinted` },
  onMessage: (event) => console.log("Tokens minted:", event),
});
```

## Error Handling

```typescript
try {
  const result = await signAndExecute({ transaction: tx });

  if (result.effects?.status?.status === "failure") {
    const error = result.effects.status.error;
    // Parse Move abort code
    console.error("Transaction failed:", error);
  }
} catch (error) {
  console.error("Error:", error.message);
}
```

## Constants Reference

```typescript
// Resolution Types
const RESOLUTION_TYPE = { ADMIN: 0, ORACLE: 1 };

// Market Status
const MARKET_STATUS = { OPEN: 0, TRADING_ENDED: 1, RESOLVED: 2, VOIDED: 3 };

// Outcomes
const OUTCOME = { YES: 0, NO: 1 };

// Order Side
const ORDER_SIDE = { BUY: 0, SELL: 1 };

// Token Type
const TOKEN_TYPE = { YES: 0, NO: 1 };

// Approval Scope
const APPROVAL_SCOPE = { ALL: 0, TRADE: 1, WITHDRAW: 2, DEPOSIT: 3 };

// Price Comparison
const COMPARISON = { GREATER: 0, LESS: 1, EQUAL: 2, GTE: 3, LTE: 4 };
```

## Deployed Contract Reference

```typescript
// Testnet Deployment
const CONFIG = {
  PACKAGE_ID: "0x9d006bf5d2141570cf19e4cee42ed9638db7aff56cb30ad1a4b1aa212caf9adb",
  MARKET_REGISTRY: "0xdb9b4975c219f9bfe8755031d467a274c94eacb317f7dbb144c5285a023fdc10",
  ADMIN_CAP: "0xf729d4b7c157cfa3e1cda4098caf2a57fe7e60ffff8be62e46bda906ec4ff462",
  UPGRADE_CAP: "0xc11f4572360048eb24ef64967b4a1f0c419ec7318aa849e448252d33fc54291d",
  NETWORK: "testnet",
  RPC_URL: "https://fullnode.testnet.sui.io:443",
};
```

## Related Documentation

- [README.md](./README.md) - Overview and setup
- [market.md](./market.md) - Market module details
- [token.md](./token.md) - Token module details
- [trading.md](./trading.md) - Trading module details
- [oracle.md](./oracle.md) - Oracle module details
- [wallet.md](./wallet.md) - Wallet module details
- [fee.md](./fee.md) - Fee module details
