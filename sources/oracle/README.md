# Oracle Module

External oracle integration for automated market resolution.

---

## Overview

The Oracle module enables trustless, decentralized market resolution using external data sources. Instead of relying on a single creator or admin to resolve markets, oracles provide verifiable outcomes from real-world data.

```
┌─────────────────────────────────────────────────────────────┐
│  Market: "Will BTC reach $100k by Dec 31, 2025?"            │
│                                                             │
│  Resolution Source: pyth:BTC/USD                            │
│  Resolution Type: Oracle                                    │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Request   │───►│   Propose   │───►│  Finalize   │     │
│  │  Resolution │    │   Outcome   │    │   Market    │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│                           │                                 │
│                      [Dispute?]                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Oracle Types

| Type | Description | Use Case |
|------|-------------|----------|
| Optimistic | Propose + dispute window | General questions, events |
| Price Feed | Direct price lookup | "BTC > $100k", price targets |
| API/Custom | Off-chain data verification | Sports, elections, custom |

---

## Data Model

### OracleRegistry

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `id` | UID | Unique object ID | - |
| `admin` | address | Registry admin | 0xAD... |
| `providers` | Table<String, OracleProvider> | Registered oracles | "pyth" → Provider |
| `default_bond` | u64 | Default bond amount | 1_000_000_000 (1 SUI) |
| `default_dispute_window` | u64 | Default dispute period (ms) | 7_200_000 (2 hours) |
| `total_requests` | u64 | Total resolution requests | 156 |

### OracleProvider

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `name` | String | Provider identifier | "pyth" |
| `provider_type` | u8 | Type of oracle | 0=Optimistic, 1=PriceFeed |
| `is_active` | bool | Can accept requests | true |
| `config` | vector<u8> | Provider-specific config | encoded data |
| `total_resolutions` | u64 | Successful resolutions | 89 |

### ResolutionRequest

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `id` | UID | Unique object ID | - |
| `request_id` | u64 | Sequential request number | 1, 2, 3... |
| `market_id` | u64 | Target market | 42 |
| `oracle_source` | String | Oracle identifier | "pyth:BTC/USD" |
| `requester` | address | Who requested | 0x123... |
| `bond_amount` | u64 | Requester's bond | 1_000_000_000 |
| `request_time` | u64 | When requested | 1701388800000 |
| `status` | u8 | Request status | 0=Pending, 1=Proposed, 2=Disputed, 3=Finalized |
| `proposed_outcome` | u8 | Proposed result | 0=Yes, 1=No |
| `proposer` | address | Who proposed | 0x456... |
| `proposer_bond` | u64 | Proposer's stake | 1_000_000_000 |
| `proposal_time` | u64 | When proposed | 1701392400000 |
| `dispute_deadline` | u64 | End of dispute window | 1701399600000 |
| `disputer` | address | Who disputed (if any) | 0x789... |
| `disputer_bond` | u64 | Disputer's stake | 1_000_000_000 |
| `final_outcome` | u8 | Verified outcome | 0=Yes, 1=No, 255=Unset |
| `resolved_time` | u64 | When finalized | 1701399600000 |

### PriceRequest (for Price Feed oracles)

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `id` | UID | Unique object ID | - |
| `market_id` | u64 | Target market | 42 |
| `price_feed_id` | String | Oracle feed ID | "pyth:BTC/USD" |
| `threshold` | u64 | Price threshold | 100_000_00000000 ($100k) |
| `comparison` | u8 | Comparison type | 0=Greater, 1=Less, 2=Equal |
| `timestamp` | u64 | When to check price | 1735689600000 |

---

## Features

### Feature 1: Oracle Registry

**Who:** Admin

**Purpose:** Manage supported oracle providers.

**Functions:**
- `initialize_registry` - Create the oracle registry
- `register_provider` - Add new oracle provider
- `update_provider` - Modify provider config
- `deactivate_provider` - Disable a provider
- `set_default_bond` - Update default bond amount
- `set_default_dispute_window` - Update dispute period

**Validation:**
- Only admin can modify registry
- Provider name must be unique
- Bond amount > 0

**Output:**
- OracleRegistry object (shared)
- ProviderRegistered event

---

### Feature 2: Request Resolution

**Who:** Anyone (for oracle-type markets)

**Purpose:** Initiate oracle resolution for a market.

**Inputs:**
- Market reference
- Bond payment (SUI)

**Validation:**
- Market resolution_type = ORACLE
- Market trading has ended
- Market not already resolved
- Resolution time has passed
- Bond >= minimum required
- No pending request for this market

**Output:**
- ResolutionRequest object created
- Bond locked in request
- ResolutionRequested event

---

### Feature 3: Propose Outcome

**Who:** Anyone

**Purpose:** Propose the market outcome, starting dispute window.

**Inputs:**
- Resolution request reference
- Proposed outcome (YES/NO)
- Proposer bond (SUI)

**Validation:**
- Request status = Pending
- Proposed outcome valid (0 or 1)
- Proposer bond >= minimum required
- Proposer != requester (optional)

**Output:**
- Request status → Proposed
- Dispute window starts
- Proposer bond locked
- OutcomeProposed event

---

### Feature 4: Dispute Outcome

**Who:** Anyone (except proposer)

**Purpose:** Challenge a proposed outcome during dispute window.

**Inputs:**
- Resolution request reference
- Disputer bond (SUI)

**Validation:**
- Request status = Proposed
- Within dispute window
- Disputer != proposer
- Disputer bond >= proposer bond

**Output:**
- Request status → Disputed
- Disputer bond locked
- OutcomeDisputed event
- Triggers escalation (admin/DAO resolution)

---

### Feature 5: Finalize Resolution

**Who:** Anyone (after dispute window) or Admin (after dispute)

**Purpose:** Complete resolution and update market.

**Inputs:**
- Resolution request reference
- Market reference
- Final outcome (only if disputed, resolved by admin)

**Validation:**
- If not disputed: dispute window passed
- If disputed: admin provides final outcome
- Market matches request

**Process:**
1. Determine final outcome
2. Call market resolution
3. Distribute bonds:
   - No dispute: return all bonds
   - Dispute + proposer correct: proposer gets disputer bond
   - Dispute + proposer wrong: disputer gets proposer bond
4. Update request status → Finalized

**Output:**
- Market resolved
- Bonds distributed
- ResolutionFinalized event

---

### Feature 6: Price Feed Resolution

**Who:** Anyone

**Purpose:** Resolve price-based markets using oracle price feeds.

**Inputs:**
- Market reference
- Price feed data (from Pyth/Switchboard)
- Price feed proof/signature

**Validation:**
- Market resolution_source matches price feed
- Price timestamp >= market resolution_time
- Price data signature valid
- Market trading ended

**Process:**
1. Verify price feed authenticity
2. Compare price to threshold
3. Determine outcome (YES if condition met, NO otherwise)
4. Resolve market directly (no dispute period)

**Output:**
- Market resolved
- PriceFeedResolution event

---

### Feature 7: Emergency Override

**Who:** Admin only

**Purpose:** Handle stuck or failed oracle requests.

**Inputs:**
- Resolution request reference (or market reference)
- Override outcome
- Reason string

**Validation:**
- Admin capability required
- Request/market in valid state for override
- Sufficient time passed (e.g., 24h after dispute)

**Process:**
1. Set final outcome
2. Resolve market
3. Return bonds to original depositors (no penalty)
4. Log override reason

**Output:**
- Market resolved
- EmergencyOverride event

---

## Status Flow

```
                         ┌───────────────┐
       request() ───────►│    PENDING    │
                         └───────┬───────┘
                                 │
                           propose()
                                 │
                                 ▼
                         ┌───────────────┐
                         │   PROPOSED    │◄─── dispute window starts
                         └───────┬───────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
              dispute()    window passes   emergency()
                    │            │            │
                    ▼            │            │
            ┌───────────────┐    │            │
            │   DISPUTED    │    │            │
            └───────┬───────┘    │            │
                    │            │            │
              admin resolves     │            │
                    │            │            │
                    ▼            ▼            ▼
                         ┌───────────────┐
                         │   FINALIZED   │───► Market Resolved
                         └───────────────┘
```

---

## Events

| Event | When | Data |
|-------|------|------|
| ProviderRegistered | Oracle provider added | name, provider_type, config |
| ProviderUpdated | Provider config changed | name, old_config, new_config |
| ResolutionRequested | Resolution initiated | request_id, market_id, requester, bond |
| OutcomeProposed | Outcome proposed | request_id, proposer, outcome, dispute_deadline |
| OutcomeDisputed | Proposal challenged | request_id, disputer, bond |
| ResolutionFinalized | Market resolved via oracle | request_id, market_id, outcome, resolver |
| PriceFeedResolution | Price-based resolution | market_id, price_feed, price, outcome |
| EmergencyOverride | Admin override used | request_id, market_id, outcome, reason |
| BondDistributed | Bonds returned/awarded | request_id, recipient, amount, reason |

---

## Access Control

| Action | Anyone | Requester | Proposer | Admin |
|--------|--------|-----------|----------|-------|
| Register provider | - | - | - | ✅ |
| Request resolution | ✅ | - | - | ✅ |
| Propose outcome | ✅ | ✅ | - | ✅ |
| Dispute outcome | ✅ | ✅ | - | ✅ |
| Finalize (no dispute) | ✅ | ✅ | ✅ | ✅ |
| Finalize (disputed) | - | - | - | ✅ |
| Emergency override | - | - | - | ✅ |

---

## Bond Economics

```
Scenario 1: No Dispute
┌─────────────────────────────────────────────┐
│ Requester posts 1 SUI                       │
│ Proposer posts 1 SUI                        │
│ No dispute during window                    │
│ → Requester gets 1 SUI back                 │
│ → Proposer gets 1 SUI back                  │
└─────────────────────────────────────────────┘

Scenario 2: Dispute - Proposer Correct
┌─────────────────────────────────────────────┐
│ Proposer posts 1 SUI (outcome: YES)         │
│ Disputer posts 1 SUI (claims: NO)           │
│ Admin verifies: YES is correct              │
│ → Proposer gets 2 SUI (own + disputer's)    │
│ → Disputer gets 0 SUI (lost bond)           │
└─────────────────────────────────────────────┘

Scenario 3: Dispute - Disputer Correct
┌─────────────────────────────────────────────┐
│ Proposer posts 1 SUI (outcome: YES)         │
│ Disputer posts 1 SUI (claims: NO)           │
│ Admin verifies: NO is correct               │
│ → Disputer gets 2 SUI (own + proposer's)    │
│ → Proposer gets 0 SUI (lost bond)           │
└─────────────────────────────────────────────┘

Scenario 4: Emergency Override
┌─────────────────────────────────────────────┐
│ Oracle stuck/failed                         │
│ Admin uses emergency override               │
│ → All bonds returned to original depositors │
│ → No penalty (not anyone's fault)           │
└─────────────────────────────────────────────┘
```

---

## File Structure

```
sources/oracle/
├── types.move       # Structs + getters + setters + constructors
├── events.move      # Event structs + emit functions
├── operations.move  # Business logic
├── entries.move     # Public entry functions
└── README.md        # This file
```

---

## Constants

```move
// Request Status
STATUS_PENDING: u8 = 0
STATUS_PROPOSED: u8 = 1
STATUS_DISPUTED: u8 = 2
STATUS_FINALIZED: u8 = 3
STATUS_CANCELLED: u8 = 4

// Oracle Provider Types
PROVIDER_OPTIMISTIC: u8 = 0
PROVIDER_PRICE_FEED: u8 = 1
PROVIDER_API: u8 = 2

// Price Comparison
COMPARE_GREATER: u8 = 0
COMPARE_LESS: u8 = 1
COMPARE_EQUAL: u8 = 2
COMPARE_GREATER_OR_EQUAL: u8 = 3
COMPARE_LESS_OR_EQUAL: u8 = 4

// Defaults
DEFAULT_BOND: u64 = 1_000_000_000         // 1 SUI
DEFAULT_DISPUTE_WINDOW: u64 = 7_200_000   // 2 hours
MIN_BOND: u64 = 100_000_000               // 0.1 SUI
MAX_DISPUTE_WINDOW: u64 = 86_400_000      // 24 hours
```

---

## Error Codes

```move
E_NOT_ADMIN: u64 = 1
E_PROVIDER_EXISTS: u64 = 2
E_PROVIDER_NOT_FOUND: u64 = 3
E_PROVIDER_INACTIVE: u64 = 4
E_INVALID_MARKET: u64 = 5
E_MARKET_NOT_ORACLE_TYPE: u64 = 6
E_MARKET_ALREADY_RESOLVED: u64 = 7
E_TRADING_NOT_ENDED: u64 = 8
E_TOO_EARLY: u64 = 9
E_INSUFFICIENT_BOND: u64 = 10
E_REQUEST_EXISTS: u64 = 11
E_REQUEST_NOT_FOUND: u64 = 12
E_INVALID_STATUS: u64 = 13
E_INVALID_OUTCOME: u64 = 14
E_DISPUTE_WINDOW_PASSED: u64 = 15
E_DISPUTE_WINDOW_ACTIVE: u64 = 16
E_SELF_DISPUTE: u64 = 17
E_NOT_DISPUTED: u64 = 18
E_INVALID_PRICE_FEED: u64 = 19
E_PRICE_TOO_OLD: u64 = 20
E_INVALID_SIGNATURE: u64 = 21
```

---

## Integration with Market Module

The Oracle module calls into the Market module to finalize resolution:

```move
// In oracle/operations.move
public fun finalize_resolution(
    request: &mut ResolutionRequest,
    market: &mut Market,
    clock: &Clock,
    ctx: &TxContext,
) {
    // ... validation ...

    // Call market module to resolve
    market_operations::resolve_by_oracle(
        market,
        request.final_outcome,
        clock,
        ctx,
    );

    // ... distribute bonds ...
}
```

Requires adding to Market module:
```move
// In market/operations.move
public(package) fun resolve_by_oracle(
    market: &mut Market,
    winning_outcome: u8,
    clock: &Clock,
    _ctx: &TxContext,
) {
    assert!(
        market_types::resolution_type(market) == market_types::resolution_oracle(),
        E_NOT_AUTHORIZED
    );

    resolve_internal(market, winning_outcome, @oracle_module, clock);
}
```
