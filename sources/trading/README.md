# Trading Module

Handles trading of outcome tokens (YES/NO) between users.

---

## Trading Approaches

### Option A: Simple P2P Trading
Direct peer-to-peer token swaps without intermediary.

**Pros:** Simple, no liquidity needed, no impermanent loss
**Cons:** Requires finding counterparty, no price discovery

### Option B: AMM (Automated Market Maker)
Constant product formula (x * y = k) like Uniswap.

**Pros:** Always liquid, automatic price discovery
**Cons:** Impermanent loss, requires initial liquidity

### Option C: Order Book
Traditional limit orders with price-time priority.

**Pros:** Best prices, professional trading
**Cons:** Complex, often needs off-chain matching

### Option D: Hybrid (Polymarket-style)
Off-chain order book, on-chain settlement.

**Pros:** Fast matching, low gas, on-chain security
**Cons:** Centralized matching, complex architecture

---

## Features

### Feature 1: Limit Orders
- Place buy order for YES/NO tokens at specific price
- Place sell order for YES/NO tokens at specific price
- Price in basis points (0-10000 = 0%-100% probability)
- Orders stored on-chain with maker address
- Cancel unfilled orders

### Feature 2: Order Matching
- Match buy and sell orders at compatible prices
- Price-time priority (best price first, then oldest)
- Partial fills supported
- Atomic execution (all or nothing per match)

### Feature 3: Market Orders
- Buy/sell at best available price
- Immediate execution against existing orders
- Slippage protection (max price for buys, min for sells)

### Feature 4: AMM Liquidity Pool (Optional)
- Add liquidity (deposit YES + NO tokens)
- Remove liquidity (withdraw proportionally)
- Swap through pool when no matching orders
- LP tokens to track liquidity provider shares
- Fee sharing for LPs

### Feature 5: Trade Settlement
- Transfer tokens between parties
- Update order book state
- Emit trade events
- Handle partial fills

### Feature 6: Order Book Queries
- Get best bid/ask prices
- Get order book depth
- Get user's open orders
- Get recent trades

---

## Data Structures

### Order
- Order ID
- Market ID
- Maker address
- Side (Buy/Sell)
- Outcome (YES/NO)
- Price (in basis points, 0-10000)
- Amount (token quantity)
- Filled amount
- Status (Open/Filled/Cancelled)
- Created timestamp

### OrderBook
- Market ID
- Yes buy orders (sorted by price desc)
- Yes sell orders (sorted by price asc)
- No buy orders (sorted by price desc)
- No sell orders (sorted by price asc)
- Order count

### LiquidityPool (if AMM)
- Market ID
- YES token reserve
- NO token reserve
- LP token total supply
- Fee rate

### Trade
- Trade ID
- Market ID
- Maker order ID
- Taker address
- Outcome (YES/NO)
- Price
- Amount
- Timestamp

---

## Price Mechanics

```
Price Range: 0 to 10000 basis points (0% to 100%)

Example:
- YES price = 6500 (65% probability)
- NO price = 3500 (35% probability)
- YES + NO prices should sum to ~10000 (100%)

Buying YES at 6500:
- Pay 0.65 SUI per YES token
- If YES wins: receive 1 SUI (profit: 0.35 SUI)
- If NO wins: receive 0 SUI (loss: 0.65 SUI)

Selling YES at 6500:
- Receive 0.65 SUI per YES token
- Give up potential 1 SUI payout if YES wins
```

---

## Order Matching Logic

```
Buy Order: "I want to buy YES at 6500 or lower"
Sell Order: "I want to sell YES at 6500 or higher"

Matching:
1. Find sell orders with price <= buy price
2. Sort by price (lowest first), then time (oldest first)
3. Execute trades until buy order filled or no more matches
4. Remaining amount stays as open order

Example:
- Buy 100 YES @ 6500
- Sell orders: 50 YES @ 6400, 30 YES @ 6500, 50 YES @ 6600
- Matches: 50 @ 6400, 30 @ 6500 (80 filled)
- Remaining: 20 YES @ 6500 becomes open buy order
```

---

## Events

- `OrderPlaced` - new order created
- `OrderCancelled` - order cancelled by maker
- `OrderFilled` - order completely filled
- `Trade` - trade executed between parties
- `LiquidityAdded` - LP added liquidity
- `LiquidityRemoved` - LP removed liquidity

---

## Access Control

| Action | Who Can Call |
|--------|--------------|
| Place order | Anyone (with tokens/SUI) |
| Cancel order | Order maker only |
| Match orders | Anyone (keeper/bot) |
| Add liquidity | Anyone |
| Remove liquidity | LP token holder |

---

## Dependencies

- `market_types` - Market struct, status checks
- `token_types` - YesToken, NoToken structs
- `token_operations` - Token transfers

---

## Implementation Priority

1. **Phase 1: Basic Orders**
   - Place limit orders
   - Cancel orders
   - Simple matching

2. **Phase 2: Advanced Trading**
   - Market orders
   - Partial fills
   - Order book queries

3. **Phase 3: AMM (Optional)**
   - Liquidity pools
   - Automated pricing
   - LP rewards
