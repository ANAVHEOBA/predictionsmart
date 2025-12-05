# Market Module - Binary Markets

Focus: **Binary Markets (Yes/No)** - the simplest and most common market type.

---

## What is a Binary Market?

A prediction with exactly **two outcomes**: Yes or No.

```
┌─────────────────────────────────────────────────────────┐
│  "Will China invade Taiwan in 2025?"                    │
│                                                         │
│              1%                                         │
│            chance                                       │
│                                                         │
│      [Yes]              [No]                            │
│                                                         │
│  $9m Vol.  |  monthly                                   │
└─────────────────────────────────────────────────────────┘
```

---

## Data Model

### Market Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `id` | UID | Unique object ID | - |
| `market_id` | u64 | Sequential market number | 1, 2, 3... |
| `question` | String | The prediction question | "Will China invade Taiwan in 2025?" |
| `description` | String | Detailed rules/criteria | "Resolves YES if..." |
| `image_url` | String | Market card image | "https://..." |
| `category` | String | Primary category | "Geopolitics" |
| `tags` | vector<String> | Searchable tags | ["China", "Taiwan", "War"] |
| `outcome_yes_label` | String | YES outcome label | "Yes" |
| `outcome_no_label` | String | NO outcome label | "No" |
| `created_at` | u64 | Creation timestamp (ms) | 1701388800000 |
| `end_time` | u64 | Trading end timestamp | 1735689600000 |
| `resolution_time` | u64 | When can be resolved | 1735689600000 |
| `timeframe` | String | Display label | "monthly", "annual" |
| `resolution_type` | u8 | How it resolves | 0=Creator, 1=Admin, 2=Oracle |
| `resolution_source` | String | Oracle ID or source | "pyth:BTC/USD" |
| `total_volume` | u64 | Total traded volume | 9000000000000 |
| `total_collateral` | u64 | Total locked collateral | 500000000000 |
| `fee_bps` | u16 | Trading fee (basis points) | 100 (= 1%) |
| `status` | u8 | Market status | 0=Open, 1=Ended, 2=Resolved, 3=Voided |
| `winning_outcome` | u8 | Result after resolution | 0=Yes, 1=No, 2=Void |
| `creator` | address | Who created the market | 0x123... |

---

## Features

### Feature 1: Create Binary Market

**Who:** Anyone (pays creation fee)

**Inputs:**
- Question text
- Description/rules
- Image URL
- Category
- Tags
- Yes/No labels (default: "Yes"/"No")
- End time (when trading stops)
- Resolution time
- Timeframe label
- Resolution type
- Fee percentage

**Validation:**
- Question: 10-500 characters
- End time: > now + 1 hour
- Resolution time: >= end time
- Fee: <= 10%
- Creation fee paid

**Output:**
- New Market object (shared)
- MarketCreated event

---

### Feature 2: Get Market Info

**Who:** Anyone

**Reads:**
- All market fields
- Computed: is_open, is_resolved, can_trade, can_redeem

---

### Feature 3: End Trading

**Who:** Anyone (triggers automatically when time passes)

**Conditions:**
- Current time >= end_time
- Status = Open

**Output:**
- Status changes to TradingEnded
- TradingEnded event

---

### Feature 4: Resolve Market

**Who:** Creator (if creator-resolved) OR Admin OR Oracle

**Inputs:**
- Winning outcome (0=Yes, 1=No)

**Conditions:**
- Current time >= resolution_time
- Status = TradingEnded
- Caller is authorized

**Output:**
- winning_outcome set
- Status changes to Resolved
- MarketResolved event

---

### Feature 5: Void Market

**Who:** Creator (if still open) OR Admin (anytime)

**Inputs:**
- Reason string

**Output:**
- Status changes to Voided
- winning_outcome = Void
- MarketVoided event
- All users can refund (handled by token module)

---

### Feature 6: Update Volume/Collateral

**Who:** Internal (called by trading/token modules)

**Updates:**
- total_volume (on trades)
- total_collateral (on mint/redeem)

---

## Status Flow

```
                    ┌─────────┐
      create() ───► │  OPEN   │ ◄─── trading active
                    └────┬────┘
                         │
            time >= end_time OR admin
                         │
                         ▼
                    ┌─────────────┐
                    │TRADING_ENDED│ ◄─── no more trades
                    └──────┬──────┘
                           │
              time >= resolution_time
                           │
              ┌────────────┴────────────┐
              │                         │
              ▼                         ▼
        ┌──────────┐              ┌──────────┐
        │ RESOLVED │              │  VOIDED  │
        └──────────┘              └──────────┘
         winners get $1           everyone refunds
```

---

## Events

| Event | When | Data |
|-------|------|------|
| MarketCreated | Market created | market_id, question, creator, end_time, ... |
| TradingEnded | Trading stops | market_id, total_volume, total_collateral |
| MarketResolved | Outcome set | market_id, winning_outcome, resolver |
| MarketVoided | Market cancelled | market_id, reason, voided_by |

---

## Access Control

| Action | Creator | Admin | Anyone |
|--------|---------|-------|--------|
| Create market | - | - | ✅ (pays fee) |
| View market | ✅ | ✅ | ✅ |
| End trading | ✅ | ✅ | ✅ (if time passed) |
| Resolve (creator type) | ✅ | ✅ | ❌ |
| Resolve (admin type) | ❌ | ✅ | ❌ |
| Void (if open) | ✅ | ✅ | ❌ |
| Void (after trading) | ❌ | ✅ | ❌ |

---

## File Structure

```
sources/market/
├── types.move       # Structs + getters + setters + constructors
├── events.move      # Event structs + emit functions
├── operations.move  # Business logic
├── entries.move     # Public entry functions
└── README.md        # This file
```

---

## Constants

```move
// Status
STATUS_OPEN: u8 = 0
STATUS_TRADING_ENDED: u8 = 1
STATUS_RESOLVED: u8 = 2
STATUS_VOIDED: u8 = 3

// Outcome
OUTCOME_YES: u8 = 0
OUTCOME_NO: u8 = 1
OUTCOME_VOID: u8 = 2
OUTCOME_UNSET: u8 = 255

// Resolution Type
RESOLUTION_CREATOR: u8 = 0
RESOLUTION_ADMIN: u8 = 1
RESOLUTION_ORACLE: u8 = 2

// Limits
MIN_QUESTION_LENGTH: u64 = 10
MAX_QUESTION_LENGTH: u64 = 500
MAX_FEE_BPS: u16 = 1000  // 10%
MIN_DURATION_MS: u64 = 3600000  // 1 hour
DEFAULT_CREATION_FEE: u64 = 1_000_000_000  // 1 SUI
```

---

## Error Codes

```move
E_PLATFORM_PAUSED: u64 = 1
E_INSUFFICIENT_FEE: u64 = 2
E_QUESTION_TOO_SHORT: u64 = 3
E_QUESTION_TOO_LONG: u64 = 4
E_INVALID_END_TIME: u64 = 5
E_INVALID_RESOLUTION_TIME: u64 = 6
E_INVALID_FEE: u64 = 7
E_INVALID_RESOLUTION_TYPE: u64 = 8
E_NOT_CREATOR: u64 = 9
E_NOT_AUTHORIZED: u64 = 10
E_MARKET_NOT_OPEN: u64 = 11
E_TRADING_NOT_ENDED: u64 = 12
E_ALREADY_RESOLVED: u64 = 13
E_INVALID_OUTCOME: u64 = 14
E_TOO_EARLY: u64 = 15
```
