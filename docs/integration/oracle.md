# Oracle Module Integration

## Overview

The Oracle module handles market resolution through multiple mechanisms:
1. **Optimistic Oracle** - Anyone proposes, disputed if wrong
2. **Price Feeds** - Pyth/Switchboard for crypto prices
3. **Admin Override** - Emergency resolution

## Resolution Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     ORACLE RESOLUTION FLOW                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  OPTIMISTIC ORACLE (Sports, Elections, Custom Events)                   │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ 1. Market ends                                                    │  │
│  │ 2. Anyone requests resolution + posts bond                        │  │
│  │ 3. Proposer submits outcome (YES/NO) + bond                       │  │
│  │ 4. Dispute window (24-48 hours)                                   │  │
│  │    - If no dispute → Outcome accepted, proposer gets bond back    │  │
│  │    - If disputed → Admin decides, loser loses bond                │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  PRICE FEED ORACLE (Crypto prices)                                      │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ 1. Market ends (e.g., "BTC > $100k by Dec 31")                    │  │
│  │ 2. Anyone calls resolution with Pyth/Switchboard price feed       │  │
│  │ 3. Contract compares price vs threshold                           │  │
│  │ 4. Instant resolution based on on-chain price data                │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ADMIN/CREATOR RESOLUTION                                               │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ - Admin can resolve any ADMIN-type market                         │  │
│  │ - Creator can resolve their CREATOR-type market                   │  │
│  │ - Emergency override for stuck markets                            │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Object Types

### OracleRegistry

```typescript
interface OracleRegistry {
  id: string;
  admin: string;
  providers: Map<string, OracleProvider>;
  default_bond: number;
  default_dispute_window: number; // In milliseconds
  total_resolutions: number;
}
```

### ResolutionRequest

```typescript
interface ResolutionRequest {
  id: string;
  market_id: string;
  requester: string;
  bond_amount: number;
  proposed_outcome: number | null; // 0=YES, 1=NO
  proposer: string | null;
  proposer_bond: number;
  disputed: boolean;
  disputer: string | null;
  dispute_bond: number;
  dispute_deadline: number; // Timestamp
  status: number; // 0=PENDING, 1=PROPOSED, 2=DISPUTED, 3=FINALIZED
  created_at: number;
}
```

## Optimistic Oracle Functions

### 1. Initialize Oracle Registry (Admin)

```typescript
const PACKAGE_ID = "0x9d006bf5d2141570cf19e4cee42ed9638db7aff56cb30ad1a4b1aa212caf9adb";

async function initializeOracleRegistry() {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::oracle_entries::initialize_registry`,
    arguments: [],
  });

  return tx;
}
```

### 2. Request Resolution

Anyone can request resolution for an ended market.

```typescript
async function requestResolution(
  oracleRegistryId: string,
  marketId: string,
  bondAmount: number // Minimum bond required
) {
  const tx = new Transaction();

  const [bondCoin] = tx.splitCoins(tx.gas, [bondAmount]);

  tx.moveCall({
    target: `${PACKAGE_ID}::oracle_entries::request_resolution`,
    arguments: [
      tx.object(oracleRegistryId),
      tx.object(marketId),
      bondCoin,
      tx.object("0x6"), // Clock
    ],
  });

  return tx;
}
```

### 3. Propose Outcome

Propose YES or NO outcome with bond.

```typescript
async function proposeOutcome(
  oracleRegistryId: string,
  requestId: string,
  outcome: "YES" | "NO",
  bondAmount: number
) {
  const tx = new Transaction();

  const [bondCoin] = tx.splitCoins(tx.gas, [bondAmount]);

  tx.moveCall({
    target: `${PACKAGE_ID}::oracle_entries::propose_outcome`,
    arguments: [
      tx.object(oracleRegistryId),
      tx.object(requestId),
      tx.pure.u8(outcome === "YES" ? 0 : 1),
      bondCoin,
      tx.object("0x6"),
    ],
  });

  return tx;
}
```

### 4. Dispute Outcome

Challenge a proposed outcome.

```typescript
async function disputeOutcome(
  oracleRegistryId: string,
  requestId: string,
  bondAmount: number
) {
  const tx = new Transaction();

  const [bondCoin] = tx.splitCoins(tx.gas, [bondAmount]);

  tx.moveCall({
    target: `${PACKAGE_ID}::oracle_entries::dispute_outcome`,
    arguments: [
      tx.object(oracleRegistryId),
      tx.object(requestId),
      bondCoin,
      tx.object("0x6"),
    ],
  });

  return tx;
}
```

### 5. Finalize Undisputed

Anyone can finalize after dispute window passes.

```typescript
async function finalizeUndisputed(
  oracleRegistryId: string,
  requestId: string,
  marketId: string
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::oracle_entries::finalize_undisputed`,
    arguments: [
      tx.object(oracleRegistryId),
      tx.object(requestId),
      tx.object(marketId),
      tx.object("0x6"),
    ],
  });

  return tx;
}
```

### 6. Finalize Disputed (Admin Only)

Admin resolves disputed outcome.

```typescript
async function finalizeDisputed(
  oracleRegistryId: string,
  requestId: string,
  marketId: string,
  adminCapId: string,
  finalOutcome: "YES" | "NO"
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::oracle_entries::finalize_disputed`,
    arguments: [
      tx.object(oracleRegistryId),
      tx.object(requestId),
      tx.object(marketId),
      tx.object(adminCapId),
      tx.pure.u8(finalOutcome === "YES" ? 0 : 1),
      tx.object("0x6"),
    ],
  });

  return tx;
}
```

## Price Feed Functions

### Using Pyth Oracle

```typescript
// Pyth testnet price feeds
const PYTH_PRICE_FEEDS = {
  BTC_USD: "0xf9c0172ba10dfa4d19088d94f5bf61d3b54d5bd7483a322a982e1373ee8ea31b",
  ETH_USD: "0xca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6",
  SUI_USD: "0x50c67b3fd225db8912a424dd4baed60ffdde625ed2feaaf283724f9608fea266",
  SOL_USD: "0xfe650f0367d4a7ef9815a593ea15d36593f0643aaaf0149bb04be67ab851decd",
};

// Pyth state on testnet
const PYTH_STATE = "0xd3e79c2c083b934e78b3bd58a490ec6b092561954da6e7322e1e2b3c8abfddc0";

async function resolveWithPyth(
  oracleRegistryId: string,
  marketId: string,
  adminCapId: string,
  priceInfoObjectId: string, // Pyth PriceInfoObject
  threshold: number, // Price threshold (8 decimals)
  comparison: number // 0=GREATER, 1=LESS, 2=EQUAL, 3=GTE, 4=LTE
) {
  const tx = new Transaction();

  // First, update the Pyth price (requires calling Pyth)
  // Then resolve using the price

  tx.moveCall({
    target: `${PACKAGE_ID}::oracle_entries::resolve_by_price_feed`,
    arguments: [
      tx.object(oracleRegistryId),
      tx.object(marketId),
      tx.object(adminCapId),
      tx.pure.u64(getCurrentPriceFromPyth()), // Get from Pyth
      tx.pure.u64(threshold),
      tx.pure.u8(comparison),
      tx.object("0x6"),
    ],
  });

  return tx;
}
```

### Using Switchboard Oracle

```typescript
// Switchboard testnet
const SWITCHBOARD_STATE = "0x578b91ec9dcc505439b2f0ec761c23ad2c533a1c23b0467f6c4ae3d9686709f6";

async function resolveWithSwitchboard(
  oracleRegistryId: string,
  marketId: string,
  adminCapId: string,
  aggregatorId: string, // Switchboard Aggregator
  threshold: number,
  comparison: number
) {
  const tx = new Transaction();

  // Read price from Switchboard aggregator and resolve
  tx.moveCall({
    target: `${PACKAGE_ID}::oracle_entries::resolve_by_price_feed`,
    arguments: [
      tx.object(oracleRegistryId),
      tx.object(marketId),
      tx.object(adminCapId),
      tx.pure.u64(getCurrentPriceFromSwitchboard()), // Get from Switchboard
      tx.pure.u64(threshold),
      tx.pure.u8(comparison),
      tx.object("0x6"),
    ],
  });

  return tx;
}
```

### Comparison Types

```typescript
const COMPARISON = {
  GREATER: 0, // price > threshold
  LESS: 1, // price < threshold
  EQUAL: 2, // price == threshold
  GREATER_OR_EQUAL: 3, // price >= threshold
  LESS_OR_EQUAL: 4, // price <= threshold
};

// Example: "BTC > $100,000"
// threshold = 100000_00000000 (100k with 8 decimals)
// comparison = COMPARISON.GREATER
```

## Emergency Functions

### Emergency Override

```typescript
async function emergencyOverride(
  oracleRegistryId: string,
  requestId: string,
  marketId: string,
  adminCapId: string,
  outcome: "YES" | "NO",
  reason: string
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::oracle_entries::emergency_override`,
    arguments: [
      tx.object(oracleRegistryId),
      tx.object(requestId),
      tx.object(marketId),
      tx.object(adminCapId),
      tx.pure.u8(outcome === "YES" ? 0 : 1),
      tx.pure.vector("u8", new TextEncoder().encode(reason)),
      tx.object("0x6"),
    ],
  });

  return tx;
}
```

### Emergency Void

```typescript
async function emergencyVoid(
  oracleRegistryId: string,
  requestId: string,
  marketId: string,
  adminCapId: string,
  reason: string
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::oracle_entries::emergency_void`,
    arguments: [
      tx.object(oracleRegistryId),
      tx.object(requestId),
      tx.object(marketId),
      tx.object(adminCapId),
      tx.pure.vector("u8", new TextEncoder().encode(reason)),
      tx.object("0x6"),
    ],
  });

  return tx;
}
```

## Query Functions

### Get Resolution Request

```typescript
async function getResolutionRequest(requestId: string) {
  const request = await client.getObject({
    id: requestId,
    options: { showContent: true },
  });

  const fields = request.data?.content?.fields as any;

  return {
    id: requestId,
    marketId: fields.market_id,
    requester: fields.requester,
    bondAmount: Number(fields.bond_amount),
    proposedOutcome: fields.proposed_outcome?.fields?.value ?? null,
    proposer: fields.proposer,
    disputed: fields.disputed,
    disputer: fields.disputer,
    disputeDeadline: Number(fields.dispute_deadline),
    status: fields.status,
  };
}
```

### Get Pending Resolutions

```typescript
async function getPendingResolutions() {
  // Query ResolutionRequested events
  const events = await client.queryEvents({
    query: {
      MoveEventType: `${PACKAGE_ID}::oracle_events::ResolutionRequested`,
    },
    limit: 100,
  });

  const requestIds = events.data.map((e) => (e.parsedJson as any).request_id);

  const requests = await client.multiGetObjects({
    ids: requestIds,
    options: { showContent: true },
  });

  return requests
    .filter((r) => {
      const fields = r.data?.content?.fields as any;
      return fields.status < 3; // Not finalized
    })
    .map((r) => ({
      id: r.data?.objectId,
      ...r.data?.content?.fields,
    }));
}
```

### Check Dispute Window

```typescript
async function canFinalize(requestId: string): Promise<boolean> {
  const request = await getResolutionRequest(requestId);

  if (request.status !== 1) return false; // Must be PROPOSED
  if (request.disputed) return false; // Can't auto-finalize if disputed

  const now = Date.now();
  return now > request.disputeDeadline;
}

async function getTimeRemaining(requestId: string): Promise<number> {
  const request = await getResolutionRequest(requestId);
  const now = Date.now();
  return Math.max(0, request.disputeDeadline - now);
}
```

## Events

```typescript
// Resolution requested
async function onResolutionRequested(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::oracle_events::ResolutionRequested`,
    },
    onMessage: callback,
  });
}

// Outcome proposed
async function onOutcomeProposed(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::oracle_events::OutcomeProposed`,
    },
    onMessage: callback,
  });
}

// Outcome disputed
async function onOutcomeDisputed(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::oracle_events::OutcomeDisputed`,
    },
    onMessage: callback,
  });
}

// Resolution finalized
async function onResolutionFinalized(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::oracle_events::ResolutionFinalized`,
    },
    onMessage: callback,
  });
}
```

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 1 | `E_NOT_ADMIN` | Caller is not oracle admin |
| 2 | `E_MARKET_NOT_ENDED` | Market trading hasn't ended |
| 3 | `E_INSUFFICIENT_BOND` | Bond amount too low |
| 4 | `E_ALREADY_PROPOSED` | Outcome already proposed |
| 5 | `E_NOT_PROPOSED` | No outcome proposed yet |
| 6 | `E_ALREADY_DISPUTED` | Already disputed |
| 7 | `E_DISPUTE_WINDOW_PASSED` | Can't dispute after window |
| 8 | `E_DISPUTE_WINDOW_ACTIVE` | Can't finalize during window |
| 9 | `E_INVALID_OUTCOME` | Outcome must be 0 or 1 |
| 10 | `E_NOT_ORACLE_MARKET` | Market doesn't use oracle resolution |

## Complete Example: Oracle Service

```typescript
import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";

const PACKAGE_ID = "0x9d006bf5d2141570cf19e4cee42ed9638db7aff56cb30ad1a4b1aa212caf9adb";

class OracleService {
  constructor(
    private client: SuiClient,
    private signAndExecute: (tx: Transaction) => Promise<any>,
    private oracleRegistryId: string
  ) {}

  // Request resolution for a market
  async requestResolution(marketId: string, bondAmount: number = 100_000_000) {
    const tx = new Transaction();
    const [bondCoin] = tx.splitCoins(tx.gas, [bondAmount]);

    tx.moveCall({
      target: `${PACKAGE_ID}::oracle_entries::request_resolution`,
      arguments: [
        tx.object(this.oracleRegistryId),
        tx.object(marketId),
        bondCoin,
        tx.object("0x6"),
      ],
    });

    return await this.signAndExecute(tx);
  }

  // Propose outcome
  async proposeOutcome(
    requestId: string,
    outcome: "YES" | "NO",
    bondAmount: number = 100_000_000
  ) {
    const tx = new Transaction();
    const [bondCoin] = tx.splitCoins(tx.gas, [bondAmount]);

    tx.moveCall({
      target: `${PACKAGE_ID}::oracle_entries::propose_outcome`,
      arguments: [
        tx.object(this.oracleRegistryId),
        tx.object(requestId),
        tx.pure.u8(outcome === "YES" ? 0 : 1),
        bondCoin,
        tx.object("0x6"),
      ],
    });

    return await this.signAndExecute(tx);
  }

  // Dispute proposed outcome
  async dispute(requestId: string, bondAmount: number = 200_000_000) {
    const tx = new Transaction();
    const [bondCoin] = tx.splitCoins(tx.gas, [bondAmount]);

    tx.moveCall({
      target: `${PACKAGE_ID}::oracle_entries::dispute_outcome`,
      arguments: [
        tx.object(this.oracleRegistryId),
        tx.object(requestId),
        bondCoin,
        tx.object("0x6"),
      ],
    });

    return await this.signAndExecute(tx);
  }

  // Finalize (anyone can call after dispute window)
  async finalizeUndisputed(requestId: string, marketId: string) {
    const tx = new Transaction();

    tx.moveCall({
      target: `${PACKAGE_ID}::oracle_entries::finalize_undisputed`,
      arguments: [
        tx.object(this.oracleRegistryId),
        tx.object(requestId),
        tx.object(marketId),
        tx.object("0x6"),
      ],
    });

    return await this.signAndExecute(tx);
  }

  // Get request status
  async getRequestStatus(requestId: string) {
    const request = await this.client.getObject({
      id: requestId,
      options: { showContent: true },
    });

    const fields = request.data?.content?.fields as any;
    const now = Date.now();
    const deadline = Number(fields.dispute_deadline);

    return {
      status: this.getStatusLabel(fields.status),
      proposedOutcome:
        fields.proposed_outcome?.fields?.value === 0
          ? "YES"
          : fields.proposed_outcome?.fields?.value === 1
          ? "NO"
          : null,
      disputed: fields.disputed,
      timeRemaining: Math.max(0, deadline - now),
      canFinalize: fields.status === 1 && !fields.disputed && now > deadline,
      canDispute: fields.status === 1 && !fields.disputed && now <= deadline,
    };
  }

  private getStatusLabel(status: number): string {
    switch (status) {
      case 0:
        return "PENDING";
      case 1:
        return "PROPOSED";
      case 2:
        return "DISPUTED";
      case 3:
        return "FINALIZED";
      default:
        return "UNKNOWN";
    }
  }
}
```

## UI Component: Resolution Panel

```tsx
function ResolutionPanel({ marketId, requestId }: Props) {
  const { data: status } = useQuery({
    queryKey: ["resolution", requestId],
    queryFn: () => oracleService.getRequestStatus(requestId),
    refetchInterval: 10000,
  });

  if (!status) return <div>Loading...</div>;

  return (
    <div className="resolution-panel">
      <h3>Market Resolution</h3>

      <div className="status">
        Status: <span className={status.status.toLowerCase()}>{status.status}</span>
      </div>

      {status.proposedOutcome && (
        <div className="proposed">
          Proposed Outcome: <strong>{status.proposedOutcome}</strong>
        </div>
      )}

      {status.timeRemaining > 0 && (
        <div className="countdown">
          Dispute window: {formatTime(status.timeRemaining)} remaining
        </div>
      )}

      {status.canDispute && (
        <button onClick={() => handleDispute()}>
          Dispute (Propose different outcome)
        </button>
      )}

      {status.canFinalize && (
        <button onClick={() => handleFinalize()}>Finalize Resolution</button>
      )}

      {status.disputed && (
        <div className="disputed-notice">
          This outcome is disputed. Awaiting admin resolution.
        </div>
      )}
    </div>
  );
}
```
