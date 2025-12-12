# Trading Module Integration

## Overview

The Trading module provides two trading mechanisms:
1. **Order Book** - Limit orders matched peer-to-peer
2. **AMM (Liquidity Pool)** - Instant swaps with automated pricing

## Trading Mechanisms

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         TRADING OPTIONS                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ORDER BOOK (Limit Orders)                                              │
│  ┌─────────────┐         ┌─────────────┐                               │
│  │ Buy Orders  │ <─────> │ Sell Orders │   Best price matching         │
│  │ 0.45, 0.44  │         │ 0.55, 0.56  │   Maker/taker fees            │
│  └─────────────┘         └─────────────┘                               │
│                                                                         │
│  AMM LIQUIDITY POOL (Instant Swaps)                                     │
│  ┌─────────────────────────────────────┐                               │
│  │     YES Tokens  <──>  NO Tokens     │   Constant product formula    │
│  │        1000     :     1000          │   x * y = k                   │
│  └─────────────────────────────────────┘   Price = y / x              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Object Types

### OrderBook

```typescript
interface OrderBook {
  id: string;
  market_id: string;
  buy_orders: Order[]; // Sorted by price (highest first)
  sell_orders: Order[]; // Sorted by price (lowest first)
  order_count: number;
  total_volume: number;
}
```

### Order

```typescript
interface Order {
  id: string;
  maker: string;
  side: number; // 0=BUY, 1=SELL
  token_type: number; // 0=YES, 1=NO
  price: number; // Price in basis points (0-10000)
  amount: number; // Token amount
  filled: number; // Amount already filled
  created_at: number;
  status: number; // 0=OPEN, 1=FILLED, 2=CANCELLED
}
```

### LiquidityPool

```typescript
interface LiquidityPool {
  id: string;
  market_id: string;
  yes_reserve: number;
  no_reserve: number;
  k_last: number; // Constant product
  lp_supply: number;
  fee_bps: number; // Fee in basis points
}
```

### LPToken

```typescript
interface LPToken {
  id: string;
  pool_id: string;
  balance: number;
}
```

## Price Representation

Prices are in **basis points (0-10000)** representing probability:

```typescript
// Price conversion helpers
const bpsToPercent = (bps: number) => bps / 100; // 5000 -> 50%
const percentToBps = (pct: number) => pct * 100; // 50 -> 5000
const bpsToDecimal = (bps: number) => bps / 10000; // 5000 -> 0.50

// Examples:
// Price 5000 = 50% probability = $0.50 per token
// Price 7500 = 75% probability = $0.75 per token
// Price 2500 = 25% probability = $0.25 per token
```

## Order Book Functions

### 1. Initialize Order Book

```typescript
const PACKAGE_ID = "0x9d006bf5d2141570cf19e4cee42ed9638db7aff56cb30ad1a4b1aa212caf9adb";

async function initializeOrderBook(marketId: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::trading_entries::initialize_order_book`,
    arguments: [tx.object(marketId)],
  });

  return tx;
}
```

### 2. Place Buy Order

Buy YES or NO tokens at a specific price.

```typescript
async function placeBuyOrder(
  marketId: string,
  orderBookId: string,
  tokenType: "YES" | "NO",
  price: number, // In basis points (0-10000)
  amount: number, // SUI amount to spend
) {
  const tx = new Transaction();

  const [paymentCoin] = tx.splitCoins(tx.gas, [amount]);

  tx.moveCall({
    target: `${PACKAGE_ID}::trading_entries::place_buy_order`,
    arguments: [
      tx.object(marketId),
      tx.object(orderBookId),
      tx.pure.u8(tokenType === "YES" ? 0 : 1),
      tx.pure.u64(price),
      paymentCoin,
      tx.object("0x6"), // Clock
    ],
  });

  return tx;
}

// Example: Buy YES tokens at 60% ($0.60)
const tx = await placeBuyOrder(
  "0x...", // market ID
  "0x...", // order book ID
  "YES",
  6000, // 60% in basis points
  1_000_000_000 // 1 SUI
);
```

### 3. Place Sell Order

Sell YES or NO tokens at a specific price.

```typescript
async function placeSellOrder(
  marketId: string,
  orderBookId: string,
  tokenId: string, // YesToken or NoToken ID
  tokenType: "YES" | "NO",
  price: number, // In basis points
  amount: number // Token amount to sell
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::trading_entries::place_sell_order`,
    arguments: [
      tx.object(marketId),
      tx.object(orderBookId),
      tx.object(tokenId),
      tx.pure.u8(tokenType === "YES" ? 0 : 1),
      tx.pure.u64(price),
      tx.pure.u64(amount),
      tx.object("0x6"),
    ],
  });

  return tx;
}
```

### 4. Cancel Order

```typescript
async function cancelOrder(orderBookId: string, orderId: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::trading_entries::cancel_order`,
    arguments: [tx.object(orderBookId), tx.pure.string(orderId)],
  });

  return tx;
}
```

### 5. Match Orders

Match buy and sell orders (can be called by anyone).

```typescript
async function matchOrders(
  orderBookId: string,
  buyOrderId: string,
  sellOrderId: string
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::trading_entries::match_orders`,
    arguments: [
      tx.object(orderBookId),
      tx.pure.string(buyOrderId),
      tx.pure.string(sellOrderId),
      tx.object("0x6"),
    ],
  });

  return tx;
}
```

## AMM Liquidity Pool Functions

### 1. Create Liquidity Pool

```typescript
async function createLiquidityPool(
  marketId: string,
  yesTokenId: string,
  noTokenId: string,
  yesAmount: number,
  noAmount: number
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::trading_entries::create_liquidity_pool`,
    arguments: [
      tx.object(marketId),
      tx.object(yesTokenId),
      tx.object(noTokenId),
      tx.pure.u64(yesAmount),
      tx.pure.u64(noAmount),
    ],
  });

  return tx;
}
```

### 2. Add Liquidity

```typescript
async function addLiquidity(
  poolId: string,
  yesTokenId: string,
  noTokenId: string,
  yesAmount: number,
  noAmount: number
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::trading_entries::add_liquidity`,
    arguments: [
      tx.object(poolId),
      tx.object(yesTokenId),
      tx.object(noTokenId),
      tx.pure.u64(yesAmount),
      tx.pure.u64(noAmount),
    ],
  });

  return tx;
}
```

### 3. Remove Liquidity

```typescript
async function removeLiquidity(poolId: string, lpTokenId: string, amount: number) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::trading_entries::remove_liquidity`,
    arguments: [tx.object(poolId), tx.object(lpTokenId), tx.pure.u64(amount)],
  });

  return tx;
}
```

### 4. Swap YES for NO

```typescript
async function swapYesForNo(
  poolId: string,
  yesTokenId: string,
  amountIn: number,
  minAmountOut: number // Slippage protection
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::trading_entries::swap_yes_for_no`,
    arguments: [
      tx.object(poolId),
      tx.object(yesTokenId),
      tx.pure.u64(amountIn),
      tx.pure.u64(minAmountOut),
    ],
  });

  return tx;
}
```

### 5. Swap NO for YES

```typescript
async function swapNoForYes(
  poolId: string,
  noTokenId: string,
  amountIn: number,
  minAmountOut: number
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::trading_entries::swap_no_for_yes`,
    arguments: [
      tx.object(poolId),
      tx.object(noTokenId),
      tx.pure.u64(amountIn),
      tx.pure.u64(minAmountOut),
    ],
  });

  return tx;
}
```

## Query Functions

### Get Order Book

```typescript
async function getOrderBook(orderBookId: string) {
  const orderBook = await client.getObject({
    id: orderBookId,
    options: { showContent: true },
  });

  const fields = orderBook.data?.content?.fields as any;

  return {
    id: orderBookId,
    marketId: fields.market_id,
    buyOrders: fields.buy_orders || [],
    sellOrders: fields.sell_orders || [],
    orderCount: Number(fields.order_count),
    totalVolume: Number(fields.total_volume),
  };
}
```

### Get Best Bid/Ask

```typescript
async function getBestPrices(orderBookId: string) {
  const book = await getOrderBook(orderBookId);

  const bestBid = book.buyOrders.length > 0 ? book.buyOrders[0].price : null;
  const bestAsk = book.sellOrders.length > 0 ? book.sellOrders[0].price : null;
  const spread = bestBid && bestAsk ? bestAsk - bestBid : null;

  return { bestBid, bestAsk, spread };
}
```

### Get Pool Price

```typescript
async function getPoolPrice(poolId: string) {
  const pool = await client.getObject({
    id: poolId,
    options: { showContent: true },
  });

  const fields = pool.data?.content?.fields as any;
  const yesReserve = Number(fields.yes_reserve);
  const noReserve = Number(fields.no_reserve);

  // Price of YES = NO reserve / (YES reserve + NO reserve)
  const yesPrice = noReserve / (yesReserve + noReserve);
  const noPrice = yesReserve / (yesReserve + noReserve);

  return {
    yesPriceBps: Math.round(yesPrice * 10000),
    noPriceBps: Math.round(noPrice * 10000),
    yesReserve,
    noReserve,
  };
}
```

### Calculate Swap Output

```typescript
function calculateSwapOutput(
  amountIn: number,
  reserveIn: number,
  reserveOut: number,
  feeBps: number = 30 // 0.3% default fee
): number {
  const amountInWithFee = amountIn * (10000 - feeBps);
  const numerator = amountInWithFee * reserveOut;
  const denominator = reserveIn * 10000 + amountInWithFee;
  return Math.floor(numerator / denominator);
}

// Example: How many NO tokens for 100 YES?
const noOut = calculateSwapOutput(
  100_000_000_000, // 100 YES tokens
  1000_000_000_000, // YES reserve
  1000_000_000_000, // NO reserve
  30 // 0.3% fee
);
```

### Get User Orders

```typescript
async function getUserOrders(address: string, orderBookId: string) {
  const book = await getOrderBook(orderBookId);

  const userBuyOrders = book.buyOrders.filter((o: any) => o.maker === address);
  const userSellOrders = book.sellOrders.filter((o: any) => o.maker === address);

  return { buyOrders: userBuyOrders, sellOrders: userSellOrders };
}
```

## Events

```typescript
// Order placed
async function onOrderPlaced(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::trading_events::OrderPlaced`,
    },
    onMessage: callback,
  });
}

// Order matched/filled
async function onOrderFilled(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::trading_events::OrderFilled`,
    },
    onMessage: callback,
  });
}

// Swap executed
async function onSwapExecuted(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::trading_events::SwapExecuted`,
    },
    onMessage: callback,
  });
}

// Liquidity added/removed
async function onLiquidityChanged(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::trading_events::LiquidityAdded`,
    },
    onMessage: callback,
  });
}
```

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 1 | `E_INVALID_PRICE` | Price must be 1-9999 bps |
| 2 | `E_INSUFFICIENT_AMOUNT` | Amount too small |
| 3 | `E_ORDER_NOT_FOUND` | Order doesn't exist |
| 4 | `E_NOT_ORDER_MAKER` | Only maker can cancel |
| 5 | `E_PRICE_MISMATCH` | Buy/sell prices don't cross |
| 6 | `E_MARKET_NOT_OPEN` | Trading not allowed |
| 7 | `E_INSUFFICIENT_LIQUIDITY` | Pool doesn't have enough |
| 8 | `E_SLIPPAGE_EXCEEDED` | Output less than minimum |
| 9 | `E_ZERO_LIQUIDITY` | Can't create empty pool |

## Complete Example: Trading Service

```typescript
import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";

const PACKAGE_ID = "0x9d006bf5d2141570cf19e4cee42ed9638db7aff56cb30ad1a4b1aa212caf9adb";

class TradingService {
  constructor(
    private client: SuiClient,
    private signAndExecute: (tx: Transaction) => Promise<any>
  ) {}

  // Get market trading info
  async getTradingInfo(marketId: string, orderBookId: string, poolId?: string) {
    const book = await this.getOrderBook(orderBookId);
    const pool = poolId ? await this.getPoolInfo(poolId) : null;

    return {
      orderBook: book,
      pool,
      bestBid: book.buyOrders[0]?.price ?? null,
      bestAsk: book.sellOrders[0]?.price ?? null,
      poolYesPrice: pool?.yesPriceBps ?? null,
    };
  }

  async getOrderBook(orderBookId: string) {
    const ob = await this.client.getObject({
      id: orderBookId,
      options: { showContent: true },
    });
    return ob.data?.content?.fields;
  }

  async getPoolInfo(poolId: string) {
    const pool = await this.client.getObject({
      id: poolId,
      options: { showContent: true },
    });
    const fields = pool.data?.content?.fields as any;
    const yesReserve = Number(fields.yes_reserve);
    const noReserve = Number(fields.no_reserve);

    return {
      yesReserve,
      noReserve,
      yesPriceBps: Math.round((noReserve / (yesReserve + noReserve)) * 10000),
      noPriceBps: Math.round((yesReserve / (yesReserve + noReserve)) * 10000),
      lpSupply: Number(fields.lp_supply),
    };
  }

  // Place limit buy order
  async placeBuyOrder(
    marketId: string,
    orderBookId: string,
    tokenType: "YES" | "NO",
    priceBps: number,
    suiAmount: number
  ) {
    const tx = new Transaction();
    const [paymentCoin] = tx.splitCoins(tx.gas, [suiAmount]);

    tx.moveCall({
      target: `${PACKAGE_ID}::trading_entries::place_buy_order`,
      arguments: [
        tx.object(marketId),
        tx.object(orderBookId),
        tx.pure.u8(tokenType === "YES" ? 0 : 1),
        tx.pure.u64(priceBps),
        paymentCoin,
        tx.object("0x6"),
      ],
    });

    return await this.signAndExecute(tx);
  }

  // Instant swap via AMM
  async swapYesForNo(
    poolId: string,
    yesTokenId: string,
    amountIn: number,
    slippageBps: number = 100 // 1% default slippage
  ) {
    // Calculate expected output
    const pool = await this.getPoolInfo(poolId);
    const expectedOut = this.calculateSwapOutput(
      amountIn,
      pool.yesReserve,
      pool.noReserve
    );
    const minOut = Math.floor((expectedOut * (10000 - slippageBps)) / 10000);

    const tx = new Transaction();

    tx.moveCall({
      target: `${PACKAGE_ID}::trading_entries::swap_yes_for_no`,
      arguments: [
        tx.object(poolId),
        tx.object(yesTokenId),
        tx.pure.u64(amountIn),
        tx.pure.u64(minOut),
      ],
    });

    return await this.signAndExecute(tx);
  }

  calculateSwapOutput(
    amountIn: number,
    reserveIn: number,
    reserveOut: number,
    feeBps: number = 30
  ): number {
    const amountInWithFee = amountIn * (10000 - feeBps);
    const numerator = amountInWithFee * reserveOut;
    const denominator = reserveIn * 10000 + amountInWithFee;
    return Math.floor(numerator / denominator);
  }
}
```

## UI Components

### Order Book Display

```tsx
function OrderBookDisplay({ orderBookId }: { orderBookId: string }) {
  const { data: book } = useQuery({
    queryKey: ["orderBook", orderBookId],
    queryFn: () => tradingService.getOrderBook(orderBookId),
    refetchInterval: 5000,
  });

  if (!book) return <div>Loading...</div>;

  return (
    <div className="order-book">
      <div className="sells">
        <h4>Asks (Sell Orders)</h4>
        {book.sellOrders.slice(0, 10).reverse().map((order: any) => (
          <div key={order.id} className="order sell">
            <span>{(order.price / 100).toFixed(2)}%</span>
            <span>{formatTokens(order.amount - order.filled)}</span>
          </div>
        ))}
      </div>

      <div className="spread">
        Spread: {book.sellOrders[0] && book.buyOrders[0]
          ? ((book.sellOrders[0].price - book.buyOrders[0].price) / 100).toFixed(2)
          : "-"}%
      </div>

      <div className="buys">
        <h4>Bids (Buy Orders)</h4>
        {book.buyOrders.slice(0, 10).map((order: any) => (
          <div key={order.id} className="order buy">
            <span>{(order.price / 100).toFixed(2)}%</span>
            <span>{formatTokens(order.amount - order.filled)}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
```

### Price Chart

```tsx
function PriceDisplay({ poolId }: { poolId: string }) {
  const { data: pool } = useQuery({
    queryKey: ["pool", poolId],
    queryFn: () => tradingService.getPoolInfo(poolId),
    refetchInterval: 10000,
  });

  if (!pool) return null;

  return (
    <div className="price-display">
      <div className="yes-price">
        <span>YES</span>
        <span className="price">{(pool.yesPriceBps / 100).toFixed(1)}%</span>
        <span className="dollar">${(pool.yesPriceBps / 10000).toFixed(2)}</span>
      </div>
      <div className="no-price">
        <span>NO</span>
        <span className="price">{(pool.noPriceBps / 100).toFixed(1)}%</span>
        <span className="dollar">${(pool.noPriceBps / 10000).toFixed(2)}</span>
      </div>
    </div>
  );
}
```
