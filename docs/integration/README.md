# PredictionSmart Frontend Integration Guide

## Deployed Contract (Testnet)

```typescript
const CONFIG = {
  PACKAGE_ID: "0x9d006bf5d2141570cf19e4cee42ed9638db7aff56cb30ad1a4b1aa212caf9adb",
  MARKET_REGISTRY: "0xdb9b4975c219f9bfe8755031d467a274c94eacb317f7dbb144c5285a023fdc10",
  ADMIN_CAP: "0xf729d4b7c157cfa3e1cda4098caf2a57fe7e60ffff8be62e46bda906ec4ff462",
  UPGRADE_CAP: "0xc11f4572360048eb24ef64967b4a1f0c419ec7318aa849e448252d33fc54291d",
  NETWORK: "testnet",
};
```

## Quick Start

### 1. Install Dependencies

```bash
npm install @mysten/sui @mysten/dapp-kit @tanstack/react-query
```

### 2. Setup Sui Client

```typescript
import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";

const client = new SuiClient({ url: getFullnodeUrl("testnet") });
```

### 3. Connect Wallet (React)

```typescript
import { ConnectButton, useCurrentAccount, useSignAndExecuteTransaction } from "@mysten/dapp-kit";

function App() {
  const account = useCurrentAccount();
  const { mutate: signAndExecute } = useSignAndExecuteTransaction();

  return (
    <div>
      <ConnectButton />
      {account && <p>Connected: {account.address}</p>}
    </div>
  );
}
```

## Module Overview

| Module | Purpose | Doc Link |
|--------|---------|----------|
| **Market** | Create/manage prediction markets | [market.md](./market.md) |
| **Token** | Mint/redeem YES/NO tokens | [token.md](./token.md) |
| **Trading** | Order book + AMM trading | [trading.md](./trading.md) |
| **Oracle** | Market resolution | [oracle.md](./oracle.md) |
| **Wallet** | Smart contract wallets | [wallet.md](./wallet.md) |
| **Fee** | Fee calculation & distribution | [fee.md](./fee.md) |

## User Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           USER JOURNEY                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. DISCOVER MARKETS                                                        │
│     └─> Query MarketRegistry for active markets                             │
│                                                                             │
│  2. PARTICIPATE IN MARKET                                                   │
│     ├─> Option A: Mint tokens (deposit SUI → get YES + NO tokens)          │
│     └─> Option B: Buy tokens from order book or AMM                        │
│                                                                             │
│  3. TRADE POSITIONS                                                         │
│     ├─> Place limit orders on order book                                   │
│     ├─> Swap via AMM liquidity pool                                        │
│     └─> Provide liquidity to earn fees                                     │
│                                                                             │
│  4. MARKET RESOLUTION                                                       │
│     ├─> Wait for market end time                                           │
│     ├─> Oracle resolves outcome (YES/NO/VOID)                              │
│     └─> Claim winnings or refund                                           │
│                                                                             │
│  5. REDEEM WINNINGS                                                         │
│     ├─> Winning tokens → Redeem for SUI                                    │
│     └─> Voided market → Merge tokens back for full refund                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Common Transaction Patterns

### Pattern 1: Simple Transaction

```typescript
import { Transaction } from "@mysten/sui/transactions";

async function createMarket() {
  const tx = new Transaction();

  // Split coin for creation fee
  const [feeCoin] = tx.splitCoins(tx.gas, [100_000_000]); // 0.1 SUI

  tx.moveCall({
    target: `${PACKAGE_ID}::market_entries::create_market`,
    arguments: [
      tx.object(MARKET_REGISTRY),
      tx.pure.string("Will BTC reach $100k by Dec 2025?"),
      tx.pure.string("Bitcoin price prediction"),
      tx.pure.u8(1), // ORACLE resolution type
      tx.pure.u64(Date.now() + 86400000 * 30), // 30 days from now
      feeCoin,
      tx.object("0x6"), // Clock
    ],
  });

  const result = await signAndExecute({ transaction: tx });
  return result;
}
```

### Pattern 2: Transaction with Object Creation

```typescript
async function mintTokens(marketId: string, vaultId: string, amount: number) {
  const tx = new Transaction();

  const [depositCoin] = tx.splitCoins(tx.gas, [amount]);

  tx.moveCall({
    target: `${PACKAGE_ID}::token_entries::mint_tokens`,
    arguments: [
      tx.object(marketId),
      tx.object(vaultId),
      depositCoin,
      tx.object("0x6"), // Clock
    ],
  });

  return await signAndExecute({ transaction: tx });
}
```

### Pattern 3: Query Objects

```typescript
async function getMarketDetails(marketId: string) {
  const market = await client.getObject({
    id: marketId,
    options: {
      showContent: true,
      showType: true,
    },
  });

  return market.data?.content?.fields;
}

async function getUserTokens(address: string) {
  const tokens = await client.getOwnedObjects({
    owner: address,
    filter: {
      StructType: `${PACKAGE_ID}::token_types::YesToken`,
    },
    options: { showContent: true },
  });

  return tokens.data;
}
```

### Pattern 4: Subscribe to Events

```typescript
async function subscribeToMarketEvents() {
  const unsubscribe = await client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::market_events::MarketCreated`,
    },
    onMessage: (event) => {
      console.log("New market created:", event);
    },
  });

  return unsubscribe;
}
```

## Object Types Reference

### Shared Objects (Global State)
```typescript
// These are shared - reference by ID
const SHARED_OBJECTS = {
  MarketRegistry: "0xdb9b4975c219f9bfe8755031d467a274c94eacb317f7dbb144c5285a023fdc10",
  Clock: "0x6", // Sui system clock
};
```

### Owned Objects (Per User)
```typescript
// Query user's owned objects
interface UserObjects {
  YesToken: `${PACKAGE_ID}::token_types::YesToken`;
  NoToken: `${PACKAGE_ID}::token_types::NoToken`;
  LPToken: `${PACKAGE_ID}::trading_types::LPToken`;
  SmartWallet: `${PACKAGE_ID}::wallet_types::SmartWallet`;
}
```

### Created on Demand
```typescript
// These are created per market
interface MarketObjects {
  Market: `${PACKAGE_ID}::market_types::Market`;
  TokenVault: `${PACKAGE_ID}::token_types::TokenVault`;
  OrderBook: `${PACKAGE_ID}::trading_types::OrderBook`;
  LiquidityPool: `${PACKAGE_ID}::trading_types::LiquidityPool`;
}
```

## Error Handling

```typescript
async function safeExecute(tx: Transaction) {
  try {
    const result = await signAndExecute({ transaction: tx });

    if (result.effects?.status?.status === "failure") {
      const error = result.effects.status.error;
      throw new Error(`Transaction failed: ${error}`);
    }

    return result;
  } catch (error) {
    // Parse Move abort codes
    if (error.message.includes("MoveAbort")) {
      const code = extractAbortCode(error.message);
      throw new Error(getErrorMessage(code));
    }
    throw error;
  }
}

const ERROR_CODES = {
  // Market errors
  1: "Market not found",
  2: "Market not open",
  3: "Market already resolved",
  // Token errors
  101: "Insufficient balance",
  102: "Invalid token type",
  // Trading errors
  201: "Invalid price",
  202: "Insufficient liquidity",
  // ... etc
};
```

## Next Steps

1. **[Market Integration](./market.md)** - Creating and managing markets
2. **[Token Integration](./token.md)** - Minting and redeeming tokens
3. **[Trading Integration](./trading.md)** - Order book and AMM
4. **[Oracle Integration](./oracle.md)** - Market resolution
5. **[Wallet Integration](./wallet.md)** - Smart wallets
6. **[Fee Integration](./fee.md)** - Fee system

## Useful Links

- **Sui TypeScript SDK**: https://sdk.mystenlabs.com/typescript
- **dApp Kit**: https://sdk.mystenlabs.com/dapp-kit
- **Testnet Explorer**: https://suiscan.xyz/testnet
- **Testnet Faucet**: https://faucet.sui.io/
