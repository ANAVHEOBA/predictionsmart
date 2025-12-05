/// Trading Types - Structs, constants, getters, setters, constructors
///
/// This module defines all data structures for the order book trading system.
module predictionsmart::trading_types {
    use sui::table::{Self, Table};

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    // --- Order Side ---
    const SIDE_BUY: u8 = 0;
    const SIDE_SELL: u8 = 1;

    // --- Outcome ---
    const OUTCOME_YES: u8 = 0;
    const OUTCOME_NO: u8 = 1;

    // --- Order Status ---
    const STATUS_OPEN: u8 = 0;
    const STATUS_FILLED: u8 = 1;
    const STATUS_CANCELLED: u8 = 2;
    const STATUS_PARTIAL: u8 = 3;

    // --- Price Limits ---
    const MIN_PRICE: u64 = 1;        // 0.01% minimum
    const MAX_PRICE: u64 = 9999;     // 99.99% maximum
    const PRICE_PRECISION: u64 = 10000; // 100% = 10000 basis points

    // --- Order Limits ---
    const MIN_ORDER_AMOUNT: u64 = 10_000_000; // 0.01 SUI minimum order

    // --- AMM Constants ---
    const MIN_LIQUIDITY: u64 = 1_000_000_000; // 1 SUI minimum liquidity
    const AMM_FEE_BPS: u64 = 30; // 0.3% swap fee

    // ═══════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Order - A limit order to buy or sell outcome tokens
    public struct Order has key, store {
        id: UID,
        /// Unique order ID within the order book
        order_id: u64,
        /// Market this order is for
        market_id: u64,
        /// Address that placed the order
        maker: address,
        /// Buy or Sell
        side: u8,
        /// YES or NO token
        outcome: u8,
        /// Price in basis points (0-10000)
        price: u64,
        /// Total amount of tokens
        amount: u64,
        /// Amount already filled
        filled: u64,
        /// Order status
        status: u8,
        /// Timestamp when order was created
        created_at: u64,
    }

    /// OrderBook - Stores all orders for a market
    public struct OrderBook has key, store {
        id: UID,
        /// Market this order book is for
        market_id: u64,
        /// All orders indexed by order_id
        orders: Table<u64, Order>,
        /// Next order ID to assign
        next_order_id: u64,
        /// Count of open orders
        open_order_count: u64,
        /// Total volume traded
        total_volume: u64,
        /// Total number of trades
        trade_count: u64,
    }

    /// LiquidityPool - AMM pool for a market
    /// Uses x*y=k constant product formula
    public struct LiquidityPool has key, store {
        id: UID,
        /// Market this pool is for
        market_id: u64,
        /// Reserve of YES tokens
        yes_reserve: u64,
        /// Reserve of NO tokens
        no_reserve: u64,
        /// Total LP tokens issued
        total_lp_tokens: u64,
        /// Total fees collected (in basis points equivalent)
        total_fees_collected: u64,
        /// Whether the pool is active
        is_active: bool,
    }

    /// LPToken - Liquidity provider token
    public struct LPToken has key, store {
        id: UID,
        /// Market this LP token is for
        market_id: u64,
        /// Amount of LP tokens
        amount: u64,
        /// Provider address
        provider: address,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANT GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    // --- Side ---
    public fun side_buy(): u8 { SIDE_BUY }
    public fun side_sell(): u8 { SIDE_SELL }

    // --- Outcome ---
    public fun outcome_yes(): u8 { OUTCOME_YES }
    public fun outcome_no(): u8 { OUTCOME_NO }

    // --- Status ---
    public fun status_open(): u8 { STATUS_OPEN }
    public fun status_filled(): u8 { STATUS_FILLED }
    public fun status_cancelled(): u8 { STATUS_CANCELLED }
    public fun status_partial(): u8 { STATUS_PARTIAL }

    // --- Limits ---
    public fun min_price(): u64 { MIN_PRICE }
    public fun max_price(): u64 { MAX_PRICE }
    public fun price_precision(): u64 { PRICE_PRECISION }
    public fun min_order_amount(): u64 { MIN_ORDER_AMOUNT }

    // --- AMM ---
    public fun min_liquidity(): u64 { MIN_LIQUIDITY }
    public fun amm_fee_bps(): u64 { AMM_FEE_BPS }

    // ═══════════════════════════════════════════════════════════════════════════
    // ORDER GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    public fun order_id(o: &Order): u64 { o.order_id }
    public fun order_market_id(o: &Order): u64 { o.market_id }
    public fun order_maker(o: &Order): address { o.maker }
    public fun order_side(o: &Order): u8 { o.side }
    public fun order_outcome(o: &Order): u8 { o.outcome }
    public fun order_price(o: &Order): u64 { o.price }
    public fun order_amount(o: &Order): u64 { o.amount }
    public fun order_filled(o: &Order): u64 { o.filled }
    public fun order_status(o: &Order): u8 { o.status }
    public fun order_created_at(o: &Order): u64 { o.created_at }

    // --- Computed Getters ---
    public fun order_remaining(o: &Order): u64 { o.amount - o.filled }
    public fun order_is_open(o: &Order): bool { o.status == STATUS_OPEN || o.status == STATUS_PARTIAL }
    public fun order_is_buy(o: &Order): bool { o.side == SIDE_BUY }
    public fun order_is_sell(o: &Order): bool { o.side == SIDE_SELL }
    public fun order_is_yes(o: &Order): bool { o.outcome == OUTCOME_YES }
    public fun order_is_no(o: &Order): bool { o.outcome == OUTCOME_NO }

    // ═══════════════════════════════════════════════════════════════════════════
    // ORDER BOOK GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    public fun book_market_id(b: &OrderBook): u64 { b.market_id }
    public fun book_next_order_id(b: &OrderBook): u64 { b.next_order_id }
    public fun book_open_order_count(b: &OrderBook): u64 { b.open_order_count }
    public fun book_total_volume(b: &OrderBook): u64 { b.total_volume }
    public fun book_trade_count(b: &OrderBook): u64 { b.trade_count }

    /// Check if order exists
    public fun book_has_order(b: &OrderBook, order_id: u64): bool {
        table::contains(&b.orders, order_id)
    }

    /// Get order reference
    public fun book_get_order(b: &OrderBook, order_id: u64): &Order {
        table::borrow(&b.orders, order_id)
    }

    /// Get mutable order reference (package only)
    public(package) fun book_get_order_mut(b: &mut OrderBook, order_id: u64): &mut Order {
        table::borrow_mut(&mut b.orders, order_id)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // LIQUIDITY POOL GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    public fun pool_market_id(p: &LiquidityPool): u64 { p.market_id }
    public fun pool_yes_reserve(p: &LiquidityPool): u64 { p.yes_reserve }
    public fun pool_no_reserve(p: &LiquidityPool): u64 { p.no_reserve }
    public fun pool_total_lp_tokens(p: &LiquidityPool): u64 { p.total_lp_tokens }
    public fun pool_total_fees(p: &LiquidityPool): u64 { p.total_fees_collected }
    public fun pool_is_active(p: &LiquidityPool): bool { p.is_active }

    /// Get implied YES price from pool reserves (in basis points)
    /// Price = no_reserve / (yes_reserve + no_reserve) * 10000
    public fun pool_yes_price(p: &LiquidityPool): u64 {
        if (p.yes_reserve == 0 || p.no_reserve == 0) {
            return 5000 // 50% if no liquidity
        };
        (p.no_reserve * PRICE_PRECISION) / (p.yes_reserve + p.no_reserve)
    }

    /// Get implied NO price from pool reserves (in basis points)
    public fun pool_no_price(p: &LiquidityPool): u64 {
        PRICE_PRECISION - pool_yes_price(p)
    }

    /// Get the constant product k = x * y
    public fun pool_k(p: &LiquidityPool): u128 {
        (p.yes_reserve as u128) * (p.no_reserve as u128)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // LP TOKEN GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    public fun lp_token_market_id(t: &LPToken): u64 { t.market_id }
    public fun lp_token_amount(t: &LPToken): u64 { t.amount }
    public fun lp_token_provider(t: &LPToken): address { t.provider }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTORS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a new Order
    public(package) fun new_order(
        order_id: u64,
        market_id: u64,
        maker: address,
        side: u8,
        outcome: u8,
        price: u64,
        amount: u64,
        created_at: u64,
        ctx: &mut TxContext,
    ): Order {
        Order {
            id: object::new(ctx),
            order_id,
            market_id,
            maker,
            side,
            outcome,
            price,
            amount,
            filled: 0,
            status: STATUS_OPEN,
            created_at,
        }
    }

    /// Create a new OrderBook for a market
    public(package) fun new_order_book(
        market_id: u64,
        ctx: &mut TxContext,
    ): OrderBook {
        OrderBook {
            id: object::new(ctx),
            market_id,
            orders: table::new(ctx),
            next_order_id: 0,
            open_order_count: 0,
            total_volume: 0,
            trade_count: 0,
        }
    }

    /// Create a new LiquidityPool for a market
    public(package) fun new_liquidity_pool(
        market_id: u64,
        ctx: &mut TxContext,
    ): LiquidityPool {
        LiquidityPool {
            id: object::new(ctx),
            market_id,
            yes_reserve: 0,
            no_reserve: 0,
            total_lp_tokens: 0,
            total_fees_collected: 0,
            is_active: true,
        }
    }

    /// Create a new LP token
    public(package) fun new_lp_token(
        market_id: u64,
        amount: u64,
        provider: address,
        ctx: &mut TxContext,
    ): LPToken {
        LPToken {
            id: object::new(ctx),
            market_id,
            amount,
            provider,
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ORDER SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Add to filled amount
    public(package) fun add_filled(o: &mut Order, amount: u64) {
        o.filled = o.filled + amount;
        if (o.filled >= o.amount) {
            o.status = STATUS_FILLED;
        } else if (o.filled > 0) {
            o.status = STATUS_PARTIAL;
        };
    }

    /// Set order status to cancelled
    public(package) fun set_cancelled(o: &mut Order) {
        o.status = STATUS_CANCELLED;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ORDER BOOK SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Add order to book and return assigned order_id
    public(package) fun add_order(b: &mut OrderBook, order: Order): u64 {
        let order_id = order.order_id;
        table::add(&mut b.orders, order_id, order);
        b.next_order_id = b.next_order_id + 1;
        b.open_order_count = b.open_order_count + 1;
        order_id
    }

    /// Get next order ID
    public(package) fun get_next_order_id(b: &OrderBook): u64 {
        b.next_order_id
    }

    /// Decrease open order count
    public(package) fun decrease_open_count(b: &mut OrderBook) {
        b.open_order_count = b.open_order_count - 1;
    }

    /// Add to total volume
    public(package) fun add_volume(b: &mut OrderBook, amount: u64) {
        b.total_volume = b.total_volume + amount;
    }

    /// Increment trade count
    public(package) fun increment_trade_count(b: &mut OrderBook) {
        b.trade_count = b.trade_count + 1;
    }

    /// Remove order from book (returns the order)
    public(package) fun remove_order(b: &mut OrderBook, order_id: u64): Order {
        table::remove(&mut b.orders, order_id)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // LIQUIDITY POOL SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Add liquidity to pool
    public(package) fun add_liquidity(
        p: &mut LiquidityPool,
        yes_amount: u64,
        no_amount: u64,
        lp_tokens: u64,
    ) {
        p.yes_reserve = p.yes_reserve + yes_amount;
        p.no_reserve = p.no_reserve + no_amount;
        p.total_lp_tokens = p.total_lp_tokens + lp_tokens;
    }

    /// Remove liquidity from pool
    public(package) fun remove_liquidity(
        p: &mut LiquidityPool,
        yes_amount: u64,
        no_amount: u64,
        lp_tokens: u64,
    ) {
        p.yes_reserve = p.yes_reserve - yes_amount;
        p.no_reserve = p.no_reserve - no_amount;
        p.total_lp_tokens = p.total_lp_tokens - lp_tokens;
    }

    /// Update reserves after swap (generic)
    public(package) fun update_reserves(
        p: &mut LiquidityPool,
        new_yes_reserve: u64,
        new_no_reserve: u64,
    ) {
        p.yes_reserve = new_yes_reserve;
        p.no_reserve = new_no_reserve;
    }

    /// Add fees to pool
    public(package) fun add_fees(p: &mut LiquidityPool, fee_amount: u64) {
        p.total_fees_collected = p.total_fees_collected + fee_amount;
    }

    /// Deactivate pool (e.g., when market closes)
    public(package) fun deactivate_pool(p: &mut LiquidityPool) {
        p.is_active = false;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // LP TOKEN SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Add to LP token amount
    public(package) fun add_lp_amount(t: &mut LPToken, amount: u64) {
        t.amount = t.amount + amount;
    }

    /// Subtract from LP token amount
    public(package) fun sub_lp_amount(t: &mut LPToken, amount: u64) {
        t.amount = t.amount - amount;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TRANSFER FUNCTIONS (must be in defining module)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Share order book globally
    #[allow(lint(share_owned, custom_state_change))]
    public(package) fun share_order_book(book: OrderBook) {
        transfer::share_object(book);
    }

    /// Share liquidity pool globally
    #[allow(lint(share_owned, custom_state_change))]
    public(package) fun share_liquidity_pool(pool: LiquidityPool) {
        transfer::share_object(pool);
    }

    /// Transfer LP token to address
    #[allow(lint(custom_state_change))]
    public(package) fun transfer_lp_token(token: LPToken, recipient: address) {
        transfer::transfer(token, recipient);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DESTROY FUNCTIONS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Destroy an order (when cancelled or filled)
    public(package) fun destroy_order(order: Order) {
        let Order {
            id,
            order_id: _,
            market_id: _,
            maker: _,
            side: _,
            outcome: _,
            price: _,
            amount: _,
            filled: _,
            status: _,
            created_at: _,
        } = order;
        object::delete(id);
    }

    /// Destroy LP token
    public(package) fun destroy_lp_token(token: LPToken) {
        let LPToken {
            id,
            market_id: _,
            amount: _,
            provider: _,
        } = token;
        object::delete(id);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test_only]
    public fun destroy_order_for_testing(order: Order) {
        destroy_order(order);
    }

    #[test_only]
    public fun destroy_order_book_for_testing(book: OrderBook) {
        let OrderBook {
            id,
            market_id: _,
            mut orders,
            next_order_id: _,
            open_order_count: _,
            total_volume: _,
            trade_count: _,
        } = book;
        // Remove and destroy all orders in the table
        let mut i = 0u64;
        while (i < 1000) { // Max orders to clean up
            if (table::contains(&orders, i)) {
                let order = table::remove(&mut orders, i);
                destroy_order(order);
            };
            i = i + 1;
        };
        table::destroy_empty(orders);
        object::delete(id);
    }

    #[test_only]
    public fun destroy_liquidity_pool_for_testing(pool: LiquidityPool) {
        let LiquidityPool {
            id,
            market_id: _,
            yes_reserve: _,
            no_reserve: _,
            total_lp_tokens: _,
            total_fees_collected: _,
            is_active: _,
        } = pool;
        object::delete(id);
    }

    #[test_only]
    public fun destroy_lp_token_for_testing(token: LPToken) {
        destroy_lp_token(token);
    }

    #[test_only]
    public fun new_lp_token_for_testing(
        market_id: u64,
        amount: u64,
        provider: address,
        ctx: &mut TxContext,
    ): LPToken {
        new_lp_token(market_id, amount, provider, ctx)
    }
}
