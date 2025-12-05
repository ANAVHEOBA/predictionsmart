# Token Module

Handles outcome tokens (YES/NO) for binary prediction markets.

---

## Features

### Feature 1: Token Vault
- Create a vault for each market to hold collateral (SUI)
- Track total collateral locked per market
- Secure storage with market-linked access control

### Feature 2: Mint Token Sets
- User deposits SUI collateral
- Receives equal amounts of YES and NO tokens (1 SUI = 1 YES + 1 NO)
- Collateral goes into market vault
- Updates market collateral tracking
- Emits mint event

### Feature 3: Merge Token Sets
- User returns equal amounts of YES and NO tokens
- Tokens are burned
- Collateral returned to user (minus optional fee)
- Updates market collateral tracking
- Emits merge event

### Feature 4: Redeem Winning Tokens
- Only after market is resolved
- User submits winning outcome tokens
- Tokens are burned
- Receives proportional collateral payout
- Handles fee deduction to treasury
- Emits redemption event

### Feature 5: Redeem Voided Market
- Only after market is voided
- User can redeem both YES and NO tokens
- Returns original collateral value
- No winner/loser - everyone gets refunded
- Emits void redemption event

### Feature 6: Token Balance Queries
- Get user's YES token balance for a market
- Get user's NO token balance for a market
- Get total supply of YES tokens
- Get total supply of NO tokens
- Get vault collateral amount

---

## Token Economics

```
Minting:
  1 SUI → 1 YES + 1 NO

Merging:
  1 YES + 1 NO → 1 SUI (minus fee)

Resolution (YES wins):
  1 YES → 1 SUI (minus fee)
  1 NO  → 0 SUI

Resolution (NO wins):
  1 YES → 0 SUI
  1 NO  → 1 SUI (minus fee)

Voided:
  1 YES → 0.5 SUI (proportional refund)
  1 NO  → 0.5 SUI (proportional refund)
  OR
  1 YES + 1 NO → 1 SUI (full refund)
```

---

## Data Structures

### TokenVault
- Market ID reference
- SUI balance (collateral)
- YES token total supply
- NO token total supply

### YesToken
- Market ID
- Amount

### NoToken
- Market ID
- Amount

---

## Events

- `TokensMinted` - collateral deposited, tokens created
- `TokensMerged` - tokens burned, collateral returned
- `TokensRedeemed` - winning tokens cashed out
- `VoidRedemption` - voided market refund

---

## Access Control

| Action | Who Can Call |
|--------|--------------|
| Mint tokens | Anyone (with SUI) |
| Merge tokens | Token holder |
| Redeem winning | Token holder (after resolution) |
| Redeem voided | Token holder (after void) |

---

## Dependencies

- `market_types` - Market struct, status checks
- `market_operations` - Collateral tracking updates
