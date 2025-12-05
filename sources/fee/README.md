# Fee Module

Dynamic fee system with tiers, sharing, and protocol fees.

---

## Overview

The Fee Module centralizes all fee logic into a configurable, transparent system. It supports dynamic fee tiers based on volume, creator revenue sharing, referral rewards, and protocol fee collection.

```
┌─────────────────────────────────────────────────────────────────┐
│                        FEE DISTRIBUTION                         │
│                                                                 │
│  Trade/Redemption Amount: 100 SUI                               │
│  Fee Rate: 1% (100 BPS)                                         │
│  Total Fee: 1 SUI                                               │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Protocol   │  │   Creator    │  │   Referrer   │          │
│  │     50%      │  │     40%      │  │     10%      │          │
│  │   0.5 SUI    │  │   0.4 SUI    │  │   0.1 SUI    │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Current State (Before Module)

| Fee Type | Rate | Destination | Configurable |
|----------|------|-------------|--------------|
| Market Creation | 1 SUI flat | Treasury | Yes (admin) |
| Token Redemption | 0-10% per market | Treasury | Yes (per market) |
| AMM Swap | 0.3% fixed | Pool (LP reward) | No |
| Order Book | None | - | - |

---

## Fee Types

| Type | Description | When Applied |
|------|-------------|--------------|
| Protocol Fee | Platform revenue | All trades |
| Creator Fee | Market creator revenue | Trades on their market |
| Referral Fee | Referrer reward | Trades from referred users |
| Maker Rebate | Rebate for limit orders | Filled limit orders |
| LP Fee | Liquidity provider reward | AMM swaps |

---

## Data Model

### FeeRegistry

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `id` | UID | Unique object ID | - |
| `admin` | address | Registry admin | 0xAD... |
| `protocol_treasury` | address | Protocol fee recipient | 0xTR... |
| `base_fee_bps` | u16 | Default trading fee | 100 (1%) |
| `protocol_share_bps` | u16 | Protocol's share of fees | 5000 (50%) |
| `creator_share_bps` | u16 | Creator's share of fees | 4000 (40%) |
| `referral_share_bps` | u16 | Referrer's share of fees | 1000 (10%) |
| `maker_rebate_bps` | u16 | Rebate for makers | 10 (0.1%) |
| `tiers` | vector<FeeTier> | Volume-based fee tiers | [...] |
| `total_fees_collected` | u64 | Lifetime fees collected | 1000 SUI |
| `paused` | bool | Fee collection paused | false |

### FeeTier

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `name` | String | Tier name | "Gold" |
| `min_volume` | u64 | Minimum 30-day volume | 10000 SUI |
| `fee_bps` | u16 | Fee rate for tier | 80 (0.8%) |
| `maker_rebate_bps` | u16 | Maker rebate for tier | 15 (0.15%) |

### UserFeeStats

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `id` | UID | Unique object ID | - |
| `user` | address | User address | 0x123... |
| `volume_30d` | u64 | 30-day trading volume | 5000 SUI |
| `volume_lifetime` | u64 | Lifetime trading volume | 50000 SUI |
| `fees_paid` | u64 | Total fees paid | 500 SUI |
| `rebates_earned` | u64 | Total rebates earned | 50 SUI |
| `referral_earnings` | u64 | Earnings from referrals | 100 SUI |
| `current_tier` | u8 | Current fee tier index | 1 |
| `last_updated` | u64 | Last volume update | timestamp |

### CreatorFeeConfig

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `creator` | address | Market creator | 0x456... |
| `custom_fee_bps` | Option<u16> | Custom fee (if set) | Some(150) |
| `earnings` | u64 | Unclaimed earnings | 100 SUI |
| `total_earned` | u64 | Lifetime earnings | 1000 SUI |

### ReferralConfig

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `id` | UID | Unique object ID | - |
| `referrer` | address | Referrer address | 0x789... |
| `referral_code` | String | Unique referral code | "ABC123" |
| `referred_users` | vector<address> | Users who used code | [...] |
| `earnings` | u64 | Unclaimed earnings | 50 SUI |
| `total_earned` | u64 | Lifetime earnings | 500 SUI |
| `is_active` | bool | Code still valid | true |

---

## Features

### Feature 1: Fee Registry Management

**Who:** Admin

**Purpose:** Configure global fee parameters.

**Functions:**
- `initialize_fee_registry` - Create fee registry
- `set_base_fee` - Update default trading fee
- `set_protocol_share` - Update protocol's share
- `set_creator_share` - Update creator's share
- `set_referral_share` - Update referral share
- `set_maker_rebate` - Update maker rebate
- `set_protocol_treasury` - Update treasury address
- `pause_fees` / `unpause_fees` - Emergency controls

**Validation:**
- Only admin can modify
- Shares must sum to <= 10000 BPS
- Base fee <= MAX_FEE_BPS (1000 = 10%)

**Output:**
- FeeRegistry object (shared)
- FeeRegistryUpdated event

---

### Feature 2: Fee Tiers

**Who:** Admin

**Purpose:** Create volume-based fee discounts.

**Functions:**
- `add_fee_tier` - Add new tier
- `update_fee_tier` - Modify existing tier
- `remove_fee_tier` - Remove tier

**Default Tiers:**

| Tier | Name | Min Volume (30d) | Fee | Maker Rebate |
|------|------|------------------|-----|--------------|
| 0 | Bronze | 0 SUI | 1.0% | 0.05% |
| 1 | Silver | 1,000 SUI | 0.8% | 0.10% |
| 2 | Gold | 10,000 SUI | 0.6% | 0.15% |
| 3 | Platinum | 100,000 SUI | 0.4% | 0.20% |
| 4 | Diamond | 1,000,000 SUI | 0.2% | 0.25% |

**Validation:**
- Tiers must be in ascending volume order
- Fee rates must decrease with higher tiers
- Maker rebate must increase with higher tiers

**Output:**
- FeeTierAdded/Updated/Removed events

---

### Feature 3: Calculate & Collect Fees

**Who:** Internal (called by trading/token modules)

**Purpose:** Calculate fees for trades and distribute to recipients.

**Functions:**
- `calculate_fee` - Calculate fee amount for a trade
- `collect_and_distribute` - Collect fee and split among recipients
- `calculate_maker_rebate` - Calculate rebate for limit order makers

**Inputs:**
- Trade amount
- Market reference (for creator)
- User address (for tier lookup)
- Referrer address (optional)
- Is maker order (for rebate)

**Process:**
1. Look up user's fee tier
2. Calculate total fee based on tier rate
3. If maker order, apply rebate
4. Split remaining fee:
   - Protocol share → Treasury
   - Creator share → Creator earnings
   - Referral share → Referrer earnings (if applicable)
5. Update user volume stats
6. Emit events

**Output:**
- FeeCollected event
- Updated balances

---

### Feature 4: User Fee Stats

**Who:** Anyone (for their own stats)

**Purpose:** Track user trading volume and tier status.

**Functions:**
- `create_user_stats` - Initialize stats for user
- `get_user_tier` - Get current fee tier
- `get_user_stats` - View volume/fees/rebates
- `update_volume` - Internal: add to user's volume

**Volume Decay:**
- 30-day rolling window
- Volume decays over time
- Tier calculated at trade time

**Output:**
- UserFeeStats object (user-owned)
- TierChanged event (when tier changes)

---

### Feature 5: Creator Fee Management

**Who:** Market creators

**Purpose:** Configure and claim creator fee earnings.

**Functions:**
- `set_custom_creator_fee` - Override fee for own markets (within limits)
- `claim_creator_earnings` - Withdraw accumulated fees
- `get_creator_stats` - View earnings and pending

**Validation:**
- Custom fee cannot exceed max_fee_bps
- Only creator can modify their config
- Cannot lower fee below minimum

**Output:**
- CreatorFeeSet event
- CreatorEarningsClaimed event

---

### Feature 6: Referral System

**Who:** Anyone

**Purpose:** Earn rewards by referring traders.

**Functions:**
- `create_referral_code` - Generate unique referral code
- `use_referral_code` - Link user to referrer
- `claim_referral_earnings` - Withdraw referral rewards
- `deactivate_referral_code` - Disable code
- `get_referral_stats` - View referrals and earnings

**Rules:**
- One referral code per address
- Users can only be referred once
- Referral link is permanent
- Self-referral not allowed

**Output:**
- ReferralCodeCreated event
- UserReferred event
- ReferralEarningsClaimed event

---

### Feature 7: Fee Exemptions

**Who:** Admin

**Purpose:** Exempt certain addresses from fees.

**Functions:**
- `add_fee_exemption` - Exempt address from fees
- `remove_fee_exemption` - Remove exemption
- `is_exempt` - Check if address is exempt

**Use Cases:**
- Protocol-owned addresses
- Liquidity mining contracts
- Strategic partners
- Market makers

**Output:**
- FeeExemptionAdded/Removed events

---

## Fee Calculation Example

```
Trade: Swap 1000 SUI worth of YES tokens
User: Silver tier (0.8% fee)
Market Creator: Alice
Referrer: Bob

Base Fee: 1000 × 0.008 = 8 SUI

Distribution (assuming 50/40/10 split):
├── Protocol:  8 × 0.50 = 4.0 SUI → Treasury
├── Creator:   8 × 0.40 = 3.2 SUI → Alice's earnings
└── Referrer:  8 × 0.10 = 0.8 SUI → Bob's earnings

If Maker Order (limit order filled):
├── Maker Rebate: 1000 × 0.001 = 1 SUI back to user
└── Net Fee: 8 - 1 = 7 SUI collected
```

---

## Events

| Event | When | Data |
|-------|------|------|
| FeeRegistryInitialized | Registry created | admin, base_fee, shares |
| FeeConfigUpdated | Config changed | field, old_value, new_value |
| FeeTierAdded | New tier added | tier_index, name, min_volume, fee_bps |
| FeeTierUpdated | Tier modified | tier_index, old_fee, new_fee |
| FeeCollected | Fee collected | market_id, user, amount, breakdown |
| MakerRebatePaid | Rebate given | user, amount |
| TierChanged | User tier changed | user, old_tier, new_tier |
| CreatorEarningsClaimed | Creator withdrew | creator, amount |
| ReferralCodeCreated | Code generated | referrer, code |
| UserReferred | User linked | user, referrer, code |
| ReferralEarningsClaimed | Referrer withdrew | referrer, amount |
| FeeExemptionAdded | Address exempted | address, reason |

---

## Access Control

| Action | Anyone | User | Creator | Admin |
|--------|--------|------|---------|-------|
| View fee rates | ✅ | ✅ | ✅ | ✅ |
| View own stats | - | ✅ | ✅ | ✅ |
| Create referral code | - | ✅ | ✅ | ✅ |
| Claim own earnings | - | ✅ | ✅ | ✅ |
| Set custom creator fee | - | - | ✅ | ✅ |
| Modify fee tiers | - | - | - | ✅ |
| Add exemptions | - | - | - | ✅ |
| Update registry | - | - | - | ✅ |

---

## Integration Points

The Fee Module integrates with:

1. **Trading Module** - Called on every swap/trade
2. **Token Module** - Called on redemptions
3. **Market Module** - Creator fee configuration
4. **Wallet Module** - Referral linking

```move
// In trading/operations.move (swap function)
let (net_amount, fee_breakdown) = fee_operations::collect_and_distribute(
    fee_registry,
    market,
    trader,
    trade_amount,
    referrer,
    is_maker,
    ctx,
);

// In token/operations.move (redeem function)
let (payout, fee_breakdown) = fee_operations::collect_and_distribute(
    fee_registry,
    market,
    redeemer,
    redemption_amount,
    option::none(), // no referrer for redemptions
    false, // not a maker order
    ctx,
);
```

---

## File Structure

```
sources/fee/
├── types.move       # Structs + getters + setters + constructors
├── events.move      # Event structs + emit functions
├── operations.move  # Business logic (Features 1-7)
├── entries.move     # Public entry functions
└── README.md        # This file
```

---

## Constants

```move
// Fee Limits
const MAX_FEE_BPS: u16 = 1000;           // 10% max fee
const MIN_FEE_BPS: u16 = 0;              // 0% min fee
const MAX_MAKER_REBATE_BPS: u16 = 50;    // 0.5% max rebate

// Default Shares (must sum to 10000)
const DEFAULT_PROTOCOL_SHARE: u16 = 5000;   // 50%
const DEFAULT_CREATOR_SHARE: u16 = 4000;    // 40%
const DEFAULT_REFERRAL_SHARE: u16 = 1000;   // 10%

// Default Rates
const DEFAULT_BASE_FEE_BPS: u16 = 100;      // 1%
const DEFAULT_MAKER_REBATE_BPS: u16 = 5;    // 0.05%

// Volume Window
const VOLUME_WINDOW_MS: u64 = 2_592_000_000; // 30 days in ms

// Referral
const MAX_REFERRAL_CODE_LENGTH: u64 = 20;
const MIN_REFERRAL_CODE_LENGTH: u64 = 4;
```

---

## Error Codes

```move
E_NOT_ADMIN: u64 = 1
E_INVALID_FEE: u64 = 2
E_INVALID_SHARE: u64 = 3
E_SHARES_EXCEED_100: u64 = 4
E_TIER_EXISTS: u64 = 5
E_TIER_NOT_FOUND: u64 = 6
E_INVALID_TIER_ORDER: u64 = 7
E_NOT_CREATOR: u64 = 8
E_INSUFFICIENT_EARNINGS: u64 = 9
E_REFERRAL_CODE_EXISTS: u64 = 10
E_REFERRAL_CODE_NOT_FOUND: u64 = 11
E_ALREADY_REFERRED: u64 = 12
E_SELF_REFERRAL: u64 = 13
E_CODE_TOO_SHORT: u64 = 14
E_CODE_TOO_LONG: u64 = 15
E_FEES_PAUSED: u64 = 16
E_USER_EXEMPT: u64 = 17
```
