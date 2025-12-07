# Market Module Integration

## Overview

The Market module handles creating, managing, and resolving prediction markets.

## Object Types

### Market

```typescript
interface Market {
  id: string;
  question: string;
  description: string;
  creator: string;
  resolution_type: number; // 0=ADMIN, 1=ORACLE, 2=CREATOR
  status: number; // 0=OPEN, 1=TRADING_ENDED, 2=RESOLVED, 3=VOIDED
  outcome: number | null; // 0=YES, 1=NO, null=unresolved
  end_time: number; // Unix timestamp (ms)
  resolution_time: number | null;
  total_volume: number;
  created_at: number;
}
```

### MarketRegistry

```typescript
interface MarketRegistry {
  id: string;
  admin: string;
  markets: string[]; // Market IDs
  market_count: number;
  creation_fee: number;
  is_paused: boolean;
}
```

## Entry Functions

### 1. Create Market

Creates a new prediction market.

```typescript
import { Transaction } from "@mysten/sui/transactions";

const PACKAGE_ID = "0x19469d6070113bd28ae67c52bd788ed8b6822eedbc8926aef4881a32bb11a685";
const MARKET_REGISTRY = "0x26ccdbdc1b9d2f71a5155e11953a495128f30c3acbf0108d1d4f17701c829d7f";

async function createMarket(
  question: string,
  description: string,
  resolutionType: number, // 0=ADMIN, 1=ORACLE, 2=CREATOR
  endTime: number, // Unix timestamp in milliseconds
  creationFee: number // in MIST (1 SUI = 1_000_000_000 MIST)
) {
  const tx = new Transaction();

  // Split fee from gas
  const [feeCoin] = tx.splitCoins(tx.gas, [creationFee]);

  tx.moveCall({
    target: `${PACKAGE_ID}::market_entries::create_market`,
    arguments: [
      tx.object(MARKET_REGISTRY),
      tx.pure.string(question),
      tx.pure.string(description),
      tx.pure.u8(resolutionType),
      tx.pure.u64(endTime),
      feeCoin,
      tx.object("0x6"), // Clock
    ],
  });

  return tx;
}

// Usage
const tx = await createMarket(
  "Will Bitcoin reach $100,000 by December 31, 2025?",
  "Market resolves YES if BTC/USD price exceeds $100,000 on any major exchange.",
  1, // ORACLE resolution
  new Date("2025-12-31").getTime(),
  100_000_000 // 0.1 SUI fee
);
```

### 2. End Trading

Manually end trading (creator or admin only, after end time).

```typescript
async function endTrading(marketId: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::market_entries::end_trading`,
    arguments: [
      tx.object(MARKET_REGISTRY),
      tx.object(marketId),
      tx.object("0x6"), // Clock
    ],
  });

  return tx;
}
```

### 3. Resolve Market (Admin)

Admin resolves market with outcome.

```typescript
async function resolveByAdmin(
  adminCapId: string,
  marketId: string,
  outcome: number // 0=YES, 1=NO
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::market_entries::resolve_by_admin`,
    arguments: [
      tx.object(MARKET_REGISTRY),
      tx.object(adminCapId),
      tx.object(marketId),
      tx.pure.u8(outcome),
      tx.object("0x6"), // Clock
    ],
  });

  return tx;
}
```

### 4. Resolve Market (Creator)

Creator resolves their own market.

```typescript
async function resolveByCreator(marketId: string, outcome: number) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::market_entries::resolve_by_creator`,
    arguments: [
      tx.object(MARKET_REGISTRY),
      tx.object(marketId),
      tx.pure.u8(outcome),
      tx.object("0x6"), // Clock
    ],
  });

  return tx;
}
```

### 5. Void Market

Cancel market and enable refunds.

```typescript
// Void by admin
async function voidByAdmin(adminCapId: string, marketId: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::market_entries::void_by_admin`,
    arguments: [
      tx.object(MARKET_REGISTRY),
      tx.object(adminCapId),
      tx.object(marketId),
      tx.object("0x6"), // Clock
    ],
  });

  return tx;
}

// Void by creator (only after trading ended)
async function voidByCreator(marketId: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::market_entries::void_by_creator`,
    arguments: [
      tx.object(MARKET_REGISTRY),
      tx.object(marketId),
      tx.object("0x6"), // Clock
    ],
  });

  return tx;
}
```

## Query Functions

### Get Market Details

```typescript
import { SuiClient } from "@mysten/sui/client";

const client = new SuiClient({ url: "https://fullnode.testnet.sui.io:443" });

async function getMarket(marketId: string): Promise<Market> {
  const response = await client.getObject({
    id: marketId,
    options: { showContent: true },
  });

  const fields = response.data?.content?.fields as any;

  return {
    id: marketId,
    question: fields.question,
    description: fields.description,
    creator: fields.creator,
    resolution_type: fields.resolution_type,
    status: fields.status,
    outcome: fields.outcome?.fields?.value ?? null,
    end_time: Number(fields.end_time),
    resolution_time: fields.resolution_time ? Number(fields.resolution_time) : null,
    total_volume: Number(fields.total_volume),
    created_at: Number(fields.created_at),
  };
}
```

### Get All Markets

```typescript
async function getAllMarkets(): Promise<string[]> {
  const registry = await client.getObject({
    id: MARKET_REGISTRY,
    options: { showContent: true },
  });

  const fields = registry.data?.content?.fields as any;
  return fields.markets; // Array of market IDs
}

async function getMarketsWithDetails(): Promise<Market[]> {
  const marketIds = await getAllMarkets();

  const markets = await client.multiGetObjects({
    ids: marketIds,
    options: { showContent: true },
  });

  return markets.map((m, i) => {
    const fields = m.data?.content?.fields as any;
    return {
      id: marketIds[i],
      question: fields.question,
      description: fields.description,
      creator: fields.creator,
      resolution_type: fields.resolution_type,
      status: fields.status,
      outcome: fields.outcome?.fields?.value ?? null,
      end_time: Number(fields.end_time),
      resolution_time: fields.resolution_time ? Number(fields.resolution_time) : null,
      total_volume: Number(fields.total_volume),
      created_at: Number(fields.created_at),
    };
  });
}
```

### Filter Markets

```typescript
// Get open markets
async function getOpenMarkets(): Promise<Market[]> {
  const markets = await getMarketsWithDetails();
  return markets.filter((m) => m.status === 0); // OPEN
}

// Get markets by creator
async function getMarketsByCreator(creator: string): Promise<Market[]> {
  const markets = await getMarketsWithDetails();
  return markets.filter((m) => m.creator === creator);
}

// Get resolved markets
async function getResolvedMarkets(): Promise<Market[]> {
  const markets = await getMarketsWithDetails();
  return markets.filter((m) => m.status === 2); // RESOLVED
}
```

## Events

### Subscribe to Market Events

```typescript
// New market created
async function onMarketCreated(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::market_events::MarketCreated`,
    },
    onMessage: callback,
  });
}

// Market resolved
async function onMarketResolved(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::market_events::MarketResolved`,
    },
    onMessage: callback,
  });
}

// Market voided
async function onMarketVoided(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::market_events::MarketVoided`,
    },
    onMessage: callback,
  });
}
```

### Query Historical Events

```typescript
async function getMarketHistory(marketId: string) {
  const events = await client.queryEvents({
    query: {
      MoveEventModule: {
        package: PACKAGE_ID,
        module: "market_events",
      },
    },
    limit: 100,
  });

  return events.data.filter((e) => {
    const parsed = e.parsedJson as any;
    return parsed.market_id === marketId;
  });
}
```

## Constants

```typescript
// Resolution Types
const RESOLUTION_TYPE = {
  ADMIN: 0,
  ORACLE: 1,
  CREATOR: 2,
};

// Market Status
const MARKET_STATUS = {
  OPEN: 0,
  TRADING_ENDED: 1,
  RESOLVED: 2,
  VOIDED: 3,
};

// Outcomes
const OUTCOME = {
  YES: 0,
  NO: 1,
};
```

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 1 | `E_NOT_ADMIN` | Caller is not admin |
| 2 | `E_NOT_CREATOR` | Caller is not market creator |
| 3 | `E_MARKET_NOT_FOUND` | Market doesn't exist |
| 4 | `E_MARKET_NOT_OPEN` | Market is not open for trading |
| 5 | `E_MARKET_ALREADY_RESOLVED` | Market already has outcome |
| 6 | `E_TRADING_NOT_ENDED` | Trading period hasn't ended |
| 7 | `E_INVALID_OUTCOME` | Outcome must be 0 (YES) or 1 (NO) |
| 8 | `E_END_TIME_TOO_SOON` | End time must be in the future |
| 9 | `E_QUESTION_TOO_SHORT` | Question must be at least 10 chars |
| 10 | `E_INSUFFICIENT_FEE` | Creation fee not met |
| 11 | `E_REGISTRY_PAUSED` | Registry is paused |

## Complete Example: Market Lifecycle

```typescript
import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";

const PACKAGE_ID = "0x19469d6070113bd28ae67c52bd788ed8b6822eedbc8926aef4881a32bb11a685";
const MARKET_REGISTRY = "0x26ccdbdc1b9d2f71a5155e11953a495128f30c3acbf0108d1d4f17701c829d7f";

class MarketService {
  constructor(
    private client: SuiClient,
    private signAndExecute: (tx: Transaction) => Promise<any>
  ) {}

  // Create a new market
  async createMarket(
    question: string,
    description: string,
    resolutionType: number,
    endTime: Date,
    feeAmount: number = 100_000_000
  ) {
    const tx = new Transaction();
    const [feeCoin] = tx.splitCoins(tx.gas, [feeAmount]);

    tx.moveCall({
      target: `${PACKAGE_ID}::market_entries::create_market`,
      arguments: [
        tx.object(MARKET_REGISTRY),
        tx.pure.string(question),
        tx.pure.string(description),
        tx.pure.u8(resolutionType),
        tx.pure.u64(endTime.getTime()),
        feeCoin,
        tx.object("0x6"),
      ],
    });

    const result = await this.signAndExecute(tx);

    // Extract created market ID from events
    const marketCreatedEvent = result.events?.find(
      (e: any) => e.type.includes("MarketCreated")
    );

    return {
      txDigest: result.digest,
      marketId: marketCreatedEvent?.parsedJson?.market_id,
    };
  }

  // Get market info
  async getMarket(marketId: string) {
    const response = await this.client.getObject({
      id: marketId,
      options: { showContent: true },
    });

    return response.data?.content?.fields;
  }

  // Get all active markets
  async getActiveMarkets() {
    const registry = await this.client.getObject({
      id: MARKET_REGISTRY,
      options: { showContent: true },
    });

    const fields = registry.data?.content?.fields as any;
    const marketIds = fields.markets || [];

    if (marketIds.length === 0) return [];

    const markets = await this.client.multiGetObjects({
      ids: marketIds,
      options: { showContent: true },
    });

    return markets
      .map((m, i) => ({
        id: marketIds[i],
        ...m.data?.content?.fields,
      }))
      .filter((m: any) => m.status === 0); // Only OPEN markets
  }

  // Resolve market (creator)
  async resolveAsCreator(marketId: string, outcome: "YES" | "NO") {
    const tx = new Transaction();

    tx.moveCall({
      target: `${PACKAGE_ID}::market_entries::resolve_by_creator`,
      arguments: [
        tx.object(MARKET_REGISTRY),
        tx.object(marketId),
        tx.pure.u8(outcome === "YES" ? 0 : 1),
        tx.object("0x6"),
      ],
    });

    return await this.signAndExecute(tx);
  }
}

// Usage with React dApp Kit
import { useSignAndExecuteTransaction, useSuiClient } from "@mysten/dapp-kit";

function useMarketService() {
  const client = useSuiClient();
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();

  return new MarketService(client, async (tx) => {
    return await signAndExecute({ transaction: tx });
  });
}
```
