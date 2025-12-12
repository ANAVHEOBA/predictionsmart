# Fee Module Integration

## Overview

The Fee module handles:
- Dynamic fee calculation based on user tiers
- Revenue sharing (protocol, creator, referrer)
- Referral system
- Fee exemptions

## Fee Structure

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         FEE DISTRIBUTION                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Trading Fee (e.g., 50 bps = 0.5%)                                      │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                                                                  │   │
│  │  Protocol Share (50%)  ─────────────> Treasury                  │   │
│  │  Creator Share (40%)   ─────────────> Market Creator            │   │
│  │  Referrer Share (10%)  ─────────────> User's Referrer           │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  User Tiers (Fee Discounts)                                             │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Bronze    │ 0 volume      │ 50 bps (0.50%)                     │   │
│  │  Silver    │ $10k volume   │ 40 bps (0.40%)  - 20% discount     │   │
│  │  Gold      │ $100k volume  │ 30 bps (0.30%)  - 40% discount     │   │
│  │  Platinum  │ $500k volume  │ 20 bps (0.20%)  - 60% discount     │   │
│  │  Diamond   │ $1M volume    │ 10 bps (0.10%)  - 80% discount     │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Object Types

### FeeRegistry

```typescript
interface FeeRegistry {
  id: string;
  admin: string;
  treasury: string;
  base_fee_bps: number; // Base fee in basis points
  protocol_share_bps: number; // Protocol's share (out of 10000)
  creator_share_bps: number; // Creator's share
  referrer_share_bps: number; // Referrer's share
  tiers: FeeTier[];
  total_fees_collected: number;
  is_paused: boolean;
}
```

### FeeTier

```typescript
interface FeeTier {
  name: string; // "Bronze", "Silver", etc.
  min_volume: number; // Minimum volume to qualify
  fee_bps: number; // Fee rate for this tier
  maker_rebate_bps: number; // Rebate for makers
}
```

### UserFeeStats

```typescript
interface UserFeeStats {
  id: string;
  user: string;
  total_volume: number;
  total_fees_paid: number;
  current_tier: string;
  referrer: string | null;
  referral_code: string | null;
  total_referral_earnings: number;
}
```

### ReferralCode

```typescript
interface ReferralCode {
  code: string;
  owner: string;
  uses: number;
  total_earnings: number;
  is_active: boolean;
}
```

## Entry Functions

### 1. Initialize Fee Registry (Admin)

```typescript
const PACKAGE_ID = "0x9d006bf5d2141570cf19e4cee42ed9638db7aff56cb30ad1a4b1aa212caf9adb";

async function initializeFeeRegistry(treasuryAddress: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::fee_entries::initialize_registry`,
    arguments: [tx.pure.address(treasuryAddress)],
  });

  return tx;
}
```

### 2. Create Referral Code

```typescript
async function createReferralCode(feeRegistryId: string, code: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::fee_entries::create_referral_code`,
    arguments: [tx.object(feeRegistryId), tx.pure.string(code)],
  });

  return tx;
}
```

### 3. Use Referral Code

```typescript
async function useReferralCode(feeRegistryId: string, code: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::fee_entries::use_referral_code`,
    arguments: [tx.object(feeRegistryId), tx.pure.string(code)],
  });

  return tx;
}
```

### 4. Calculate Fee

Read-only function to calculate fee for a trade.

```typescript
async function calculateFee(
  feeRegistryId: string,
  userAddress: string,
  tradeAmount: number
): Promise<{ fee: number; breakdown: FeeBreakdown }> {
  // Query user's tier
  const userStats = await getUserFeeStats(userAddress);
  const registry = await getFeeRegistry(feeRegistryId);

  // Find applicable tier
  const tier = findTierForVolume(registry.tiers, userStats?.total_volume || 0);

  // Calculate fee
  const feeBps = tier.fee_bps;
  const feeAmount = Math.floor((tradeAmount * feeBps) / 10000);

  // Calculate distribution
  const protocolAmount = Math.floor(
    (feeAmount * registry.protocol_share_bps) / 10000
  );
  const creatorAmount = Math.floor(
    (feeAmount * registry.creator_share_bps) / 10000
  );
  const referrerAmount = userStats?.referrer
    ? Math.floor((feeAmount * registry.referrer_share_bps) / 10000)
    : 0;

  return {
    fee: feeAmount,
    breakdown: {
      total: feeAmount,
      protocol: protocolAmount,
      creator: creatorAmount,
      referrer: referrerAmount,
      tierName: tier.name,
      feeBps: feeBps,
    },
  };
}

function findTierForVolume(tiers: FeeTier[], volume: number): FeeTier {
  // Tiers sorted by min_volume descending
  const sortedTiers = [...tiers].sort((a, b) => b.min_volume - a.min_volume);
  return sortedTiers.find((t) => volume >= t.min_volume) || tiers[0];
}
```

### 5. Admin: Set Base Fee

```typescript
async function setBaseFee(
  feeRegistryId: string,
  adminCapId: string,
  newFeeBps: number
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::fee_entries::set_base_fee`,
    arguments: [
      tx.object(feeRegistryId),
      tx.object(adminCapId),
      tx.pure.u64(newFeeBps),
    ],
  });

  return tx;
}
```

### 6. Admin: Set Revenue Shares

```typescript
async function setShares(
  feeRegistryId: string,
  adminCapId: string,
  protocolShareBps: number,
  creatorShareBps: number,
  referrerShareBps: number
) {
  const tx = new Transaction();

  // Shares must sum to 10000 (100%)
  if (protocolShareBps + creatorShareBps + referrerShareBps !== 10000) {
    throw new Error("Shares must sum to 100%");
  }

  tx.moveCall({
    target: `${PACKAGE_ID}::fee_entries::set_shares`,
    arguments: [
      tx.object(feeRegistryId),
      tx.object(adminCapId),
      tx.pure.u64(protocolShareBps),
      tx.pure.u64(creatorShareBps),
      tx.pure.u64(referrerShareBps),
    ],
  });

  return tx;
}
```

### 7. Admin: Add Fee Tier

```typescript
async function addFeeTier(
  feeRegistryId: string,
  adminCapId: string,
  name: string,
  minVolume: number,
  feeBps: number,
  makerRebateBps: number
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::fee_entries::add_fee_tier`,
    arguments: [
      tx.object(feeRegistryId),
      tx.object(adminCapId),
      tx.pure.string(name),
      tx.pure.u64(minVolume),
      tx.pure.u64(feeBps),
      tx.pure.u64(makerRebateBps),
    ],
  });

  return tx;
}
```

### 8. Admin: Update Fee Tier

```typescript
async function updateFeeTier(
  feeRegistryId: string,
  adminCapId: string,
  tierName: string,
  newMinVolume: number,
  newFeeBps: number,
  newMakerRebateBps: number
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::fee_entries::update_fee_tier`,
    arguments: [
      tx.object(feeRegistryId),
      tx.object(adminCapId),
      tx.pure.string(tierName),
      tx.pure.u64(newMinVolume),
      tx.pure.u64(newFeeBps),
      tx.pure.u64(newMakerRebateBps),
    ],
  });

  return tx;
}
```

### 9. Admin: Add Fee Exemption

```typescript
async function addFeeExemption(
  feeRegistryId: string,
  adminCapId: string,
  userAddress: string
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::fee_entries::add_fee_exemption`,
    arguments: [
      tx.object(feeRegistryId),
      tx.object(adminCapId),
      tx.pure.address(userAddress),
    ],
  });

  return tx;
}
```

### 10. Creator: Set Custom Fee

Market creators can set custom fees for their markets.

```typescript
async function setCreatorFee(
  feeRegistryId: string,
  marketId: string,
  customFeeBps: number
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::fee_entries::set_creator_fee`,
    arguments: [
      tx.object(feeRegistryId),
      tx.object(marketId),
      tx.pure.u64(customFeeBps),
    ],
  });

  return tx;
}
```

## Query Functions

### Get Fee Registry

```typescript
async function getFeeRegistry(registryId: string) {
  const registry = await client.getObject({
    id: registryId,
    options: { showContent: true },
  });

  const fields = registry.data?.content?.fields as any;

  return {
    id: registryId,
    admin: fields.admin,
    treasury: fields.treasury,
    baseFeeBps: Number(fields.base_fee_bps),
    protocolShareBps: Number(fields.protocol_share_bps),
    creatorShareBps: Number(fields.creator_share_bps),
    referrerShareBps: Number(fields.referrer_share_bps),
    tiers: fields.tiers || [],
    totalFeesCollected: Number(fields.total_fees_collected),
    isPaused: fields.is_paused,
  };
}
```

### Get User Fee Stats

```typescript
async function getUserFeeStats(userAddress: string) {
  // Query UserFeeStats objects owned by user
  const stats = await client.getOwnedObjects({
    owner: userAddress,
    filter: {
      StructType: `${PACKAGE_ID}::fee_types::UserFeeStats`,
    },
    options: { showContent: true },
  });

  if (stats.data.length === 0) return null;

  const fields = stats.data[0].data?.content?.fields as any;

  return {
    id: stats.data[0].data?.objectId,
    user: fields.user,
    totalVolume: Number(fields.total_volume),
    totalFeesPaid: Number(fields.total_fees_paid),
    currentTier: fields.current_tier,
    referrer: fields.referrer,
    referralCode: fields.referral_code,
    totalReferralEarnings: Number(fields.total_referral_earnings),
  };
}
```

### Get User's Tier

```typescript
async function getUserTier(
  registryId: string,
  userAddress: string
): Promise<FeeTier> {
  const [registry, userStats] = await Promise.all([
    getFeeRegistry(registryId),
    getUserFeeStats(userAddress),
  ]);

  const volume = userStats?.totalVolume || 0;
  return findTierForVolume(registry.tiers, volume);
}
```

### Get Referral Code Info

```typescript
async function getReferralCodeInfo(registryId: string, code: string) {
  // Query ReferralCode dynamic field or events
  const events = await client.queryEvents({
    query: {
      MoveEventType: `${PACKAGE_ID}::fee_events::ReferralCodeCreated`,
    },
    limit: 1000,
  });

  const codeEvent = events.data.find(
    (e) => (e.parsedJson as any).code === code
  );

  if (!codeEvent) return null;

  return {
    code: code,
    owner: (codeEvent.parsedJson as any).owner,
    // Additional stats would need separate query
  };
}
```

### Calculate Trade Fee Preview

```typescript
interface FeePreview {
  tradeAmount: number;
  feeAmount: number;
  feePercentage: string;
  tierName: string;
  breakdown: {
    protocol: number;
    creator: number;
    referrer: number;
  };
  afterFee: number;
}

async function previewTradeFee(
  registryId: string,
  userAddress: string,
  tradeAmount: number
): Promise<FeePreview> {
  const [registry, userStats] = await Promise.all([
    getFeeRegistry(registryId),
    getUserFeeStats(userAddress),
  ]);

  const tier = findTierForVolume(registry.tiers, userStats?.totalVolume || 0);
  const feeAmount = Math.floor((tradeAmount * tier.fee_bps) / 10000);

  const protocolFee = Math.floor(
    (feeAmount * registry.protocolShareBps) / 10000
  );
  const creatorFee = Math.floor((feeAmount * registry.creatorShareBps) / 10000);
  const referrerFee = userStats?.referrer
    ? Math.floor((feeAmount * registry.referrerShareBps) / 10000)
    : 0;

  return {
    tradeAmount,
    feeAmount,
    feePercentage: `${(tier.fee_bps / 100).toFixed(2)}%`,
    tierName: tier.name,
    breakdown: {
      protocol: protocolFee,
      creator: creatorFee,
      referrer: referrerFee,
    },
    afterFee: tradeAmount - feeAmount,
  };
}
```

## Events

```typescript
// Fee collected
async function onFeeCollected(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::fee_events::FeeCollected`,
    },
    onMessage: callback,
  });
}

// Tier changed
async function onTierChanged(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::fee_events::TierChanged`,
    },
    onMessage: callback,
  });
}

// Referral used
async function onReferralUsed(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::fee_events::ReferralUsed`,
    },
    onMessage: callback,
  });
}
```

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 1 | `E_NOT_ADMIN` | Caller is not fee admin |
| 2 | `E_INVALID_FEE` | Fee too high (>10%) |
| 3 | `E_INVALID_SHARE` | Shares don't sum to 100% |
| 4 | `E_CODE_EXISTS` | Referral code already exists |
| 5 | `E_CODE_TOO_SHORT` | Referral code too short |
| 6 | `E_SELF_REFERRAL` | Can't refer yourself |
| 7 | `E_ALREADY_REFERRED` | User already has referrer |
| 8 | `E_CODE_NOT_FOUND` | Referral code doesn't exist |
| 9 | `E_TIER_NOT_FOUND` | Fee tier doesn't exist |
| 10 | `E_PAUSED` | Fee system is paused |

## Complete Example: Fee Service

```typescript
import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";

const PACKAGE_ID = "0x9d006bf5d2141570cf19e4cee42ed9638db7aff56cb30ad1a4b1aa212caf9adb";

class FeeService {
  constructor(
    private client: SuiClient,
    private signAndExecute: (tx: Transaction) => Promise<any>,
    private feeRegistryId: string
  ) {}

  // Get fee info for display
  async getFeeInfo(userAddress: string) {
    const [registry, userStats] = await Promise.all([
      this.getFeeRegistry(),
      this.getUserStats(userAddress),
    ]);

    const currentVolume = userStats?.totalVolume || 0;
    const currentTier = this.findTier(registry.tiers, currentVolume);
    const nextTier = this.findNextTier(registry.tiers, currentVolume);

    return {
      currentTier: currentTier.name,
      currentFeeBps: currentTier.fee_bps,
      currentFeePercent: `${(currentTier.fee_bps / 100).toFixed(2)}%`,
      totalVolume: currentVolume,
      totalVolumeFormatted: this.formatVolume(currentVolume),
      nextTier: nextTier?.name || null,
      volumeToNextTier: nextTier
        ? nextTier.min_volume - currentVolume
        : null,
      hasReferrer: !!userStats?.referrer,
      referralCode: userStats?.referralCode,
      referralEarnings: userStats?.totalReferralEarnings || 0,
    };
  }

  // Create referral code
  async createReferralCode(code: string) {
    const tx = new Transaction();

    tx.moveCall({
      target: `${PACKAGE_ID}::fee_entries::create_referral_code`,
      arguments: [tx.object(this.feeRegistryId), tx.pure.string(code)],
    });

    return await this.signAndExecute(tx);
  }

  // Apply referral code
  async applyReferralCode(code: string) {
    const tx = new Transaction();

    tx.moveCall({
      target: `${PACKAGE_ID}::fee_entries::use_referral_code`,
      arguments: [tx.object(this.feeRegistryId), tx.pure.string(code)],
    });

    return await this.signAndExecute(tx);
  }

  // Preview fee for trade
  async previewFee(userAddress: string, tradeAmount: number) {
    const registry = await this.getFeeRegistry();
    const userStats = await this.getUserStats(userAddress);

    const tier = this.findTier(registry.tiers, userStats?.totalVolume || 0);
    const feeAmount = Math.floor((tradeAmount * tier.fee_bps) / 10000);

    return {
      tradeAmount: tradeAmount / 1_000_000_000, // Convert to SUI
      feeAmount: feeAmount / 1_000_000_000,
      feePercent: `${(tier.fee_bps / 100).toFixed(2)}%`,
      youReceive: (tradeAmount - feeAmount) / 1_000_000_000,
      tier: tier.name,
    };
  }

  private async getFeeRegistry() {
    const registry = await this.client.getObject({
      id: this.feeRegistryId,
      options: { showContent: true },
    });
    return registry.data?.content?.fields as any;
  }

  private async getUserStats(address: string) {
    const stats = await this.client.getOwnedObjects({
      owner: address,
      filter: {
        StructType: `${PACKAGE_ID}::fee_types::UserFeeStats`,
      },
      options: { showContent: true },
    });

    if (stats.data.length === 0) return null;
    return stats.data[0].data?.content?.fields as any;
  }

  private findTier(tiers: any[], volume: number) {
    const sorted = [...tiers].sort(
      (a, b) => Number(b.min_volume) - Number(a.min_volume)
    );
    return (
      sorted.find((t) => volume >= Number(t.min_volume)) || tiers[0]
    );
  }

  private findNextTier(tiers: any[], volume: number) {
    const sorted = [...tiers].sort(
      (a, b) => Number(a.min_volume) - Number(b.min_volume)
    );
    return sorted.find((t) => Number(t.min_volume) > volume);
  }

  private formatVolume(volume: number): string {
    const sui = volume / 1_000_000_000;
    if (sui >= 1_000_000) return `${(sui / 1_000_000).toFixed(1)}M`;
    if (sui >= 1_000) return `${(sui / 1_000).toFixed(1)}K`;
    return sui.toFixed(2);
  }
}
```

## UI Components

### Fee Tier Display

```tsx
function FeeTierProgress({ userAddress }: { userAddress: string }) {
  const { data: feeInfo } = useQuery({
    queryKey: ["feeInfo", userAddress],
    queryFn: () => feeService.getFeeInfo(userAddress),
  });

  if (!feeInfo) return null;

  const progress = feeInfo.nextTier
    ? (feeInfo.totalVolume /
        (feeInfo.totalVolume + feeInfo.volumeToNextTier!)) *
      100
    : 100;

  return (
    <div className="fee-tier">
      <div className="current-tier">
        <span className="tier-badge">{feeInfo.currentTier}</span>
        <span className="fee-rate">{feeInfo.currentFeePercent} fee</span>
      </div>

      {feeInfo.nextTier && (
        <div className="progress-to-next">
          <div className="progress-bar">
            <div className="progress" style={{ width: `${progress}%` }} />
          </div>
          <p>
            Trade {feeService.formatVolume(feeInfo.volumeToNextTier!)} more to
            reach <strong>{feeInfo.nextTier}</strong>
          </p>
        </div>
      )}

      <div className="volume">
        Total Volume: {feeInfo.totalVolumeFormatted} SUI
      </div>
    </div>
  );
}
```

### Referral Code Section

```tsx
function ReferralSection({ userAddress }: { userAddress: string }) {
  const [code, setCode] = useState("");
  const { data: feeInfo, refetch } = useQuery({
    queryKey: ["feeInfo", userAddress],
    queryFn: () => feeService.getFeeInfo(userAddress),
  });

  const createCode = useMutation({
    mutationFn: (code: string) => feeService.createReferralCode(code),
    onSuccess: () => refetch(),
  });

  const applyCode = useMutation({
    mutationFn: (code: string) => feeService.applyReferralCode(code),
    onSuccess: () => refetch(),
  });

  return (
    <div className="referral-section">
      <h3>Referral Program</h3>

      {feeInfo?.referralCode ? (
        <div className="my-code">
          <p>Your referral code:</p>
          <code>{feeInfo.referralCode}</code>
          <button onClick={() => copyToClipboard(feeInfo.referralCode)}>
            Copy
          </button>
          <p>Earnings: {(feeInfo.referralEarnings / 1e9).toFixed(4)} SUI</p>
        </div>
      ) : (
        <div className="create-code">
          <input
            value={code}
            onChange={(e) => setCode(e.target.value)}
            placeholder="Enter code (min 4 chars)"
          />
          <button
            onClick={() => createCode.mutate(code)}
            disabled={code.length < 4}
          >
            Create Code
          </button>
        </div>
      )}

      {!feeInfo?.hasReferrer && (
        <div className="apply-code">
          <h4>Have a referral code?</h4>
          <input
            value={code}
            onChange={(e) => setCode(e.target.value)}
            placeholder="Enter referral code"
          />
          <button onClick={() => applyCode.mutate(code)}>Apply</button>
        </div>
      )}
    </div>
  );
}
```
