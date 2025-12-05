/// Trading Operations - Core business logic
///
/// This module contains all the business logic for trading:
/// - Creating order books
/// - Placing limit orders
/// - Cancelling orders
/// - Matching orders
/// - Market orders
module predictionsmart::trading_operations {
    use sui::clock::Clock;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    use predictionsmart::market_types::{Self, Market};
    use predictionsmart::token_types::{Self, YesToken, NoToken};
    use predictionsmart::trading_types::{Self, OrderBook, LiquidityPool, LPToken};
    use predictionsmart::trading_events;

    // ═══════════════════════════════════════════════════════════════════════════
    // ERROR CODES
    // ═══════════════════════════════════════════════════════════════════════════

    const E_MARKET_NOT_OPEN: u64 = 200;
    const E_INVALID_PRICE: u64 = 201;
    const E_AMOUNT_TOO_SMALL: u64 = 202;
    const E_MARKET_ID_MISMATCH: u64 = 203;
    const E_NOT_ORDER_MAKER: u64 = 204;
    const E_ORDER_NOT_OPEN: u64 = 205;
    const E_INVALID_SIDE: u64 = 206;
    const E_INVALID_OUTCOME: u64 = 207;
    const E_NO_MATCHING_ORDERS: u64 = 210;
    const E_ORDER_NOT_FOUND: u64 = 212;
    const E_POOL_NOT_ACTIVE: u64 = 213;
    const E_INSUFFICIENT_LIQUIDITY: u64 = 214;
    const E_INVALID_LP_TOKEN: u64 = 215;
    const E_SLIPPAGE_EXCEEDED: u64 = 216;
    const E_ZERO_AMOUNT: u64 = 217;

    // ═══════════════════════════════════════════════════════════════════════════
    // ORDER BOOK CREATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a new order book for a market
    public fun create_order_book(
        market_id: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): OrderBook {
        let book = trading_types::new_order_book(market_id, ctx);

        trading_events::emit_order_book_created(
            market_id,
            clock.timestamp_ms(),
        );

        book
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: LIMIT ORDERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Place a buy order for YES tokens using SUI
    /// Returns the order_id
    public fun place_buy_yes_order(
        market: &Market,
        book: &mut OrderBook,
        payment: Coin<SUI>,
        price: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u64, Coin<SUI>) {
        // Validate market
        assert!(market_types::is_open(market), E_MARKET_NOT_OPEN);
        let market_id = market_types::market_id(market);
        assert!(trading_types::book_market_id(book) == market_id, E_MARKET_ID_MISMATCH);

        // Validate price
        assert!(price >= trading_types::min_price(), E_INVALID_PRICE);
        assert!(price <= trading_types::max_price(), E_INVALID_PRICE);

        // Calculate amount of tokens based on price and payment
        // price is in basis points (e.g., 6500 = 65%)
        // If price is 6500, then 0.65 SUI buys 1 token
        // amount = payment * 10000 / price
        let payment_value = coin::value(&payment);
        let amount = (payment_value * trading_types::price_precision()) / price;

        assert!(amount >= trading_types::min_order_amount(), E_AMOUNT_TOO_SMALL);

        // Create order
        let order_id = trading_types::get_next_order_id(book);
        let order = trading_types::new_order(
            order_id,
            market_id,
            ctx.sender(),
            trading_types::side_buy(),
            trading_types::outcome_yes(),
            price,
            amount,
            clock.timestamp_ms(),
            ctx,
        );

        // Add to order book
        trading_types::add_order(book, order);

        // Emit event
        trading_events::emit_order_placed(
            order_id,
            market_id,
            ctx.sender(),
            trading_types::side_buy(),
            trading_types::outcome_yes(),
            price,
            amount,
            clock.timestamp_ms(),
        );

        (order_id, payment)
    }

    /// Place a buy order for NO tokens using SUI
    public fun place_buy_no_order(
        market: &Market,
        book: &mut OrderBook,
        payment: Coin<SUI>,
        price: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u64, Coin<SUI>) {
        // Validate market
        assert!(market_types::is_open(market), E_MARKET_NOT_OPEN);
        let market_id = market_types::market_id(market);
        assert!(trading_types::book_market_id(book) == market_id, E_MARKET_ID_MISMATCH);

        // Validate price
        assert!(price >= trading_types::min_price(), E_INVALID_PRICE);
        assert!(price <= trading_types::max_price(), E_INVALID_PRICE);

        // Calculate amount
        let payment_value = coin::value(&payment);
        let amount = (payment_value * trading_types::price_precision()) / price;

        assert!(amount >= trading_types::min_order_amount(), E_AMOUNT_TOO_SMALL);

        // Create order
        let order_id = trading_types::get_next_order_id(book);
        let order = trading_types::new_order(
            order_id,
            market_id,
            ctx.sender(),
            trading_types::side_buy(),
            trading_types::outcome_no(),
            price,
            amount,
            clock.timestamp_ms(),
            ctx,
        );

        trading_types::add_order(book, order);

        trading_events::emit_order_placed(
            order_id,
            market_id,
            ctx.sender(),
            trading_types::side_buy(),
            trading_types::outcome_no(),
            price,
            amount,
            clock.timestamp_ms(),
        );

        (order_id, payment)
    }

    /// Place a sell order for YES tokens
    public fun place_sell_yes_order(
        market: &Market,
        book: &mut OrderBook,
        yes_token: YesToken,
        price: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u64, YesToken) {
        // Validate market
        assert!(market_types::is_open(market), E_MARKET_NOT_OPEN);
        let market_id = market_types::market_id(market);
        assert!(trading_types::book_market_id(book) == market_id, E_MARKET_ID_MISMATCH);
        assert!(token_types::yes_token_market_id(&yes_token) == market_id, E_MARKET_ID_MISMATCH);

        // Validate price
        assert!(price >= trading_types::min_price(), E_INVALID_PRICE);
        assert!(price <= trading_types::max_price(), E_INVALID_PRICE);

        // Get amount from token
        let amount = token_types::yes_token_amount(&yes_token);
        assert!(amount >= trading_types::min_order_amount(), E_AMOUNT_TOO_SMALL);

        // Create order
        let order_id = trading_types::get_next_order_id(book);
        let order = trading_types::new_order(
            order_id,
            market_id,
            ctx.sender(),
            trading_types::side_sell(),
            trading_types::outcome_yes(),
            price,
            amount,
            clock.timestamp_ms(),
            ctx,
        );

        trading_types::add_order(book, order);

        trading_events::emit_order_placed(
            order_id,
            market_id,
            ctx.sender(),
            trading_types::side_sell(),
            trading_types::outcome_yes(),
            price,
            amount,
            clock.timestamp_ms(),
        );

        (order_id, yes_token)
    }

    /// Place a sell order for NO tokens
    public fun place_sell_no_order(
        market: &Market,
        book: &mut OrderBook,
        no_token: NoToken,
        price: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u64, NoToken) {
        // Validate market
        assert!(market_types::is_open(market), E_MARKET_NOT_OPEN);
        let market_id = market_types::market_id(market);
        assert!(trading_types::book_market_id(book) == market_id, E_MARKET_ID_MISMATCH);
        assert!(token_types::no_token_market_id(&no_token) == market_id, E_MARKET_ID_MISMATCH);

        // Validate price
        assert!(price >= trading_types::min_price(), E_INVALID_PRICE);
        assert!(price <= trading_types::max_price(), E_INVALID_PRICE);

        // Get amount from token
        let amount = token_types::no_token_amount(&no_token);
        assert!(amount >= trading_types::min_order_amount(), E_AMOUNT_TOO_SMALL);

        // Create order
        let order_id = trading_types::get_next_order_id(book);
        let order = trading_types::new_order(
            order_id,
            market_id,
            ctx.sender(),
            trading_types::side_sell(),
            trading_types::outcome_no(),
            price,
            amount,
            clock.timestamp_ms(),
            ctx,
        );

        trading_types::add_order(book, order);

        trading_events::emit_order_placed(
            order_id,
            market_id,
            ctx.sender(),
            trading_types::side_sell(),
            trading_types::outcome_no(),
            price,
            amount,
            clock.timestamp_ms(),
        );

        (order_id, no_token)
    }

    /// Cancel an open order
    public fun cancel_order(
        book: &mut OrderBook,
        order_id: u64,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        assert!(trading_types::book_has_order(book, order_id), E_ORDER_NOT_FOUND);

        let order = trading_types::book_get_order_mut(book, order_id);

        // Validate sender is maker
        assert!(trading_types::order_maker(order) == ctx.sender(), E_NOT_ORDER_MAKER);

        // Validate order is still open
        assert!(trading_types::order_is_open(order), E_ORDER_NOT_OPEN);

        let remaining = trading_types::order_remaining(order);
        let market_id = trading_types::order_market_id(order);
        let maker = trading_types::order_maker(order);

        // Mark as cancelled
        trading_types::set_cancelled(order);
        trading_types::decrease_open_count(book);

        trading_events::emit_order_cancelled(
            order_id,
            market_id,
            maker,
            remaining,
            clock.timestamp_ms(),
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 2: ORDER MATCHING
    // ═══════════════════════════════════════════════════════════════════════════

    /// Match a buy order with a sell order
    /// Returns the trade amount executed
    public fun match_orders(
        book: &mut OrderBook,
        buy_order_id: u64,
        sell_order_id: u64,
        clock: &Clock,
        _ctx: &TxContext,
    ): u64 {
        assert!(trading_types::book_has_order(book, buy_order_id), E_ORDER_NOT_FOUND);
        assert!(trading_types::book_has_order(book, sell_order_id), E_ORDER_NOT_FOUND);

        // Get order info (need to do this before mutable borrows)
        let (buy_is_open, buy_is_buy, buy_outcome, buy_price, buy_remaining, buy_maker) = {
            let buy_order = trading_types::book_get_order(book, buy_order_id);
            (
                trading_types::order_is_open(buy_order),
                trading_types::order_is_buy(buy_order),
                trading_types::order_outcome(buy_order),
                trading_types::order_price(buy_order),
                trading_types::order_remaining(buy_order),
                trading_types::order_maker(buy_order),
            )
        };

        let (sell_is_open, sell_is_sell, sell_outcome, sell_price, sell_remaining, sell_maker) = {
            let sell_order = trading_types::book_get_order(book, sell_order_id);
            (
                trading_types::order_is_open(sell_order),
                trading_types::order_is_sell(sell_order),
                trading_types::order_outcome(sell_order),
                trading_types::order_price(sell_order),
                trading_types::order_remaining(sell_order),
                trading_types::order_maker(sell_order),
            )
        };

        // Validate orders
        assert!(buy_is_open, E_ORDER_NOT_OPEN);
        assert!(sell_is_open, E_ORDER_NOT_OPEN);
        assert!(buy_is_buy, E_INVALID_SIDE);
        assert!(sell_is_sell, E_INVALID_SIDE);
        assert!(buy_outcome == sell_outcome, E_INVALID_OUTCOME);

        // Check price compatibility: buy price >= sell price
        assert!(buy_price >= sell_price, E_NO_MATCHING_ORDERS);

        // Calculate trade amount (minimum of both remaining)
        let trade_amount = if (buy_remaining < sell_remaining) {
            buy_remaining
        } else {
            sell_remaining
        };

        // Execute trade at sell price (price improvement for buyer)
        let execution_price = sell_price;
        let market_id = trading_types::book_market_id(book);

        // Update buy order
        {
            let buy_order = trading_types::book_get_order_mut(book, buy_order_id);
            trading_types::add_filled(buy_order, trade_amount);
            if (!trading_types::order_is_open(buy_order)) {
                trading_types::decrease_open_count(book);
            };
        };

        // Update sell order
        {
            let sell_order = trading_types::book_get_order_mut(book, sell_order_id);
            trading_types::add_filled(sell_order, trade_amount);
            if (!trading_types::order_is_open(sell_order)) {
                trading_types::decrease_open_count(book);
            };
        };

        // Update book stats
        trading_types::add_volume(book, trade_amount);
        let trade_id = trading_types::book_trade_count(book);
        trading_types::increment_trade_count(book);

        // Emit trade event
        trading_events::emit_trade_executed(
            trade_id,
            market_id,
            sell_order_id,
            sell_maker,
            buy_maker,
            trading_types::side_buy(),
            buy_outcome,
            execution_price,
            trade_amount,
            clock.timestamp_ms(),
        );

        trade_amount
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: MARKET ORDERS (Simplified - matches against best available)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Find best sell order for a given outcome
    /// Returns (order_id, price, remaining) or (0, 0, 0) if none found
    public fun find_best_sell_order(
        book: &OrderBook,
        outcome: u8,
    ): (u64, u64, u64) {
        let mut best_order_id: u64 = 0;
        let mut best_price: u64 = trading_types::price_precision() + 1; // Higher than max
        let mut best_remaining: u64 = 0;

        // Scan through orders to find best sell
        let mut i: u64 = 0;
        let next_id = trading_types::book_next_order_id(book);

        while (i < next_id) {
            if (trading_types::book_has_order(book, i)) {
                let order = trading_types::book_get_order(book, i);
                if (trading_types::order_is_open(order) &&
                    trading_types::order_is_sell(order) &&
                    trading_types::order_outcome(order) == outcome) {
                    let price = trading_types::order_price(order);
                    if (price < best_price) {
                        best_price = price;
                        best_order_id = i;
                        best_remaining = trading_types::order_remaining(order);
                    };
                };
            };
            i = i + 1;
        };

        if (best_order_id == 0 && best_price > trading_types::price_precision()) {
            (0, 0, 0)
        } else {
            (best_order_id, best_price, best_remaining)
        }
    }

    /// Find best buy order for a given outcome
    /// Returns (order_id, price, remaining) or (0, 0, 0) if none found
    public fun find_best_buy_order(
        book: &OrderBook,
        outcome: u8,
    ): (u64, u64, u64) {
        let mut best_order_id: u64 = 0;
        let mut best_price: u64 = 0;
        let mut best_remaining: u64 = 0;

        // Scan through orders to find best buy (highest price)
        let mut i: u64 = 0;
        let next_id = trading_types::book_next_order_id(book);

        while (i < next_id) {
            if (trading_types::book_has_order(book, i)) {
                let order = trading_types::book_get_order(book, i);
                if (trading_types::order_is_open(order) &&
                    trading_types::order_is_buy(order) &&
                    trading_types::order_outcome(order) == outcome) {
                    let price = trading_types::order_price(order);
                    if (price > best_price) {
                        best_price = price;
                        best_order_id = i;
                        best_remaining = trading_types::order_remaining(order);
                    };
                };
            };
            i = i + 1;
        };

        (best_order_id, best_price, best_remaining)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // QUERY FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get order book statistics
    /// Returns (open_orders, total_volume, trade_count)
    public fun get_book_stats(book: &OrderBook): (u64, u64, u64) {
        (
            trading_types::book_open_order_count(book),
            trading_types::book_total_volume(book),
            trading_types::book_trade_count(book),
        )
    }

    /// Get order details
    /// Returns (maker, side, outcome, price, amount, filled, status)
    public fun get_order_details(
        book: &OrderBook,
        order_id: u64,
    ): (address, u8, u8, u64, u64, u64, u8) {
        assert!(trading_types::book_has_order(book, order_id), E_ORDER_NOT_FOUND);
        let order = trading_types::book_get_order(book, order_id);
        (
            trading_types::order_maker(order),
            trading_types::order_side(order),
            trading_types::order_outcome(order),
            trading_types::order_price(order),
            trading_types::order_amount(order),
            trading_types::order_filled(order),
            trading_types::order_status(order),
        )
    }

    /// Check if an order exists and is open
    public fun is_order_active(book: &OrderBook, order_id: u64): bool {
        if (!trading_types::book_has_order(book, order_id)) {
            return false
        };
        let order = trading_types::book_get_order(book, order_id);
        trading_types::order_is_open(order)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 4: AMM LIQUIDITY POOL
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a new liquidity pool for a market
    public fun create_liquidity_pool(
        market_id: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): LiquidityPool {
        let pool = trading_types::new_liquidity_pool(market_id, ctx);

        trading_events::emit_liquidity_pool_created(
            market_id,
            clock.timestamp_ms(),
        );

        pool
    }

    /// Add liquidity to the pool (deposit YES + NO tokens)
    /// Returns the number of LP tokens minted
    public fun add_pool_liquidity(
        market: &Market,
        pool: &mut LiquidityPool,
        yes_token: YesToken,
        no_token: NoToken,
        clock: &Clock,
        ctx: &mut TxContext,
    ): LPToken {
        let market_id = market_types::market_id(market);
        assert!(trading_types::pool_market_id(pool) == market_id, E_MARKET_ID_MISMATCH);
        assert!(trading_types::pool_is_active(pool), E_POOL_NOT_ACTIVE);
        assert!(token_types::yes_token_market_id(&yes_token) == market_id, E_MARKET_ID_MISMATCH);
        assert!(token_types::no_token_market_id(&no_token) == market_id, E_MARKET_ID_MISMATCH);

        let yes_amount = token_types::yes_token_amount(&yes_token);
        let no_amount = token_types::no_token_amount(&no_token);

        assert!(yes_amount > 0, E_ZERO_AMOUNT);
        assert!(no_amount > 0, E_ZERO_AMOUNT);

        // Calculate LP tokens to mint
        let lp_tokens = if (trading_types::pool_total_lp_tokens(pool) == 0) {
            // First liquidity provider gets sqrt(yes_amount * no_amount) LP tokens
            // Using geometric mean as initial LP token amount
            sqrt_u128((yes_amount as u128) * (no_amount as u128))
        } else {
            // Subsequent providers get proportional LP tokens
            // Based on the smaller of the two proportions
            let yes_reserve = trading_types::pool_yes_reserve(pool);
            let no_reserve = trading_types::pool_no_reserve(pool);
            let total_lp = trading_types::pool_total_lp_tokens(pool);

            let lp_from_yes = (yes_amount * total_lp) / yes_reserve;
            let lp_from_no = (no_amount * total_lp) / no_reserve;

            if (lp_from_yes < lp_from_no) { lp_from_yes } else { lp_from_no }
        };

        assert!(lp_tokens >= trading_types::min_liquidity(), E_INSUFFICIENT_LIQUIDITY);

        // Update pool reserves
        trading_types::add_liquidity(pool, yes_amount, no_amount, lp_tokens);

        // Burn the tokens (in a real implementation, tokens would be held in escrow)
        token_types::burn_yes_token(yes_token);
        token_types::burn_no_token(no_token);

        // Emit event
        trading_events::emit_liquidity_added(
            market_id,
            ctx.sender(),
            yes_amount,
            no_amount,
            lp_tokens,
            clock.timestamp_ms(),
        );

        // Create and return LP token
        trading_types::new_lp_token(market_id, lp_tokens, ctx.sender(), ctx)
    }

    /// Remove liquidity from the pool (withdraw YES + NO tokens proportionally)
    /// Returns (yes_amount, no_amount) that would be withdrawn
    public fun remove_pool_liquidity(
        market: &Market,
        pool: &mut LiquidityPool,
        lp_token: LPToken,
        clock: &Clock,
        ctx: &TxContext,
    ): (u64, u64) {
        let market_id = market_types::market_id(market);
        assert!(trading_types::pool_market_id(pool) == market_id, E_MARKET_ID_MISMATCH);
        assert!(trading_types::lp_token_market_id(&lp_token) == market_id, E_INVALID_LP_TOKEN);

        let lp_amount = trading_types::lp_token_amount(&lp_token);
        assert!(lp_amount > 0, E_ZERO_AMOUNT);

        let total_lp = trading_types::pool_total_lp_tokens(pool);
        let yes_reserve = trading_types::pool_yes_reserve(pool);
        let no_reserve = trading_types::pool_no_reserve(pool);

        // Calculate proportional withdrawal using u128 to prevent overflow
        let yes_amount = (((lp_amount as u128) * (yes_reserve as u128)) / (total_lp as u128)) as u64;
        let no_amount = (((lp_amount as u128) * (no_reserve as u128)) / (total_lp as u128)) as u64;

        // Update pool reserves
        trading_types::remove_liquidity(pool, yes_amount, no_amount, lp_amount);

        // Destroy LP token
        trading_types::destroy_lp_token(lp_token);

        // Emit event
        trading_events::emit_liquidity_removed(
            market_id,
            ctx.sender(),
            yes_amount,
            no_amount,
            lp_amount,
            clock.timestamp_ms(),
        );

        // In production, this would mint and transfer YES/NO tokens back to provider
        (yes_amount, no_amount)
    }

    /// Swap YES tokens for NO tokens through the AMM
    /// Returns the amount of NO tokens received
    public fun swap_yes_for_no(
        market: &Market,
        pool: &mut LiquidityPool,
        yes_token: YesToken,
        min_output: u64,
        clock: &Clock,
        ctx: &TxContext,
    ): u64 {
        let market_id = market_types::market_id(market);
        assert!(trading_types::pool_market_id(pool) == market_id, E_MARKET_ID_MISMATCH);
        assert!(trading_types::pool_is_active(pool), E_POOL_NOT_ACTIVE);
        assert!(token_types::yes_token_market_id(&yes_token) == market_id, E_MARKET_ID_MISMATCH);

        let input_amount = token_types::yes_token_amount(&yes_token);
        assert!(input_amount > 0, E_ZERO_AMOUNT);

        let yes_reserve = trading_types::pool_yes_reserve(pool);
        let no_reserve = trading_types::pool_no_reserve(pool);

        // Calculate output using constant product formula: x * y = k
        // With fee: output = (no_reserve * input * (10000 - fee)) / (yes_reserve * 10000 + input * (10000 - fee))
        // Use u128 to prevent overflow
        let fee_bps = trading_types::amm_fee_bps();
        let input_with_fee = (input_amount as u128) * ((10000 - fee_bps) as u128);
        let numerator = (no_reserve as u128) * input_with_fee;
        let denominator = (yes_reserve as u128) * 10000 + input_with_fee;
        let output_amount = ((numerator / denominator) as u64);

        assert!(output_amount >= min_output, E_SLIPPAGE_EXCEEDED);
        assert!(output_amount < no_reserve, E_INSUFFICIENT_LIQUIDITY);

        // Calculate fee
        let fee_amount = (input_amount * fee_bps) / 10000;

        // Update reserves
        let new_yes_reserve = yes_reserve + input_amount;
        let new_no_reserve = no_reserve - output_amount;
        trading_types::update_reserves(pool, new_yes_reserve, new_no_reserve);
        trading_types::add_fees(pool, fee_amount);

        // Burn input token
        token_types::burn_yes_token(yes_token);

        // Emit event
        trading_events::emit_swap_executed(
            market_id,
            ctx.sender(),
            trading_types::outcome_yes(),
            input_amount,
            trading_types::outcome_no(),
            output_amount,
            fee_amount,
            clock.timestamp_ms(),
        );

        // In production, would mint and transfer NO tokens to user
        output_amount
    }

    /// Swap NO tokens for YES tokens through the AMM
    /// Returns the amount of YES tokens received
    public fun swap_no_for_yes(
        market: &Market,
        pool: &mut LiquidityPool,
        no_token: NoToken,
        min_output: u64,
        clock: &Clock,
        ctx: &TxContext,
    ): u64 {
        let market_id = market_types::market_id(market);
        assert!(trading_types::pool_market_id(pool) == market_id, E_MARKET_ID_MISMATCH);
        assert!(trading_types::pool_is_active(pool), E_POOL_NOT_ACTIVE);
        assert!(token_types::no_token_market_id(&no_token) == market_id, E_MARKET_ID_MISMATCH);

        let input_amount = token_types::no_token_amount(&no_token);
        assert!(input_amount > 0, E_ZERO_AMOUNT);

        let yes_reserve = trading_types::pool_yes_reserve(pool);
        let no_reserve = trading_types::pool_no_reserve(pool);

        // Calculate output using constant product formula
        // Use u128 to prevent overflow
        let fee_bps = trading_types::amm_fee_bps();
        let input_with_fee = (input_amount as u128) * ((10000 - fee_bps) as u128);
        let numerator = (yes_reserve as u128) * input_with_fee;
        let denominator = (no_reserve as u128) * 10000 + input_with_fee;
        let output_amount = ((numerator / denominator) as u64);

        assert!(output_amount >= min_output, E_SLIPPAGE_EXCEEDED);
        assert!(output_amount < yes_reserve, E_INSUFFICIENT_LIQUIDITY);

        // Calculate fee
        let fee_amount = (input_amount * fee_bps) / 10000;

        // Update reserves
        let new_yes_reserve = yes_reserve - output_amount;
        let new_no_reserve = no_reserve + input_amount;
        trading_types::update_reserves(pool, new_yes_reserve, new_no_reserve);
        trading_types::add_fees(pool, fee_amount);

        // Burn input token
        token_types::burn_no_token(no_token);

        // Emit event
        trading_events::emit_swap_executed(
            market_id,
            ctx.sender(),
            trading_types::outcome_no(),
            input_amount,
            trading_types::outcome_yes(),
            output_amount,
            fee_amount,
            clock.timestamp_ms(),
        );

        // In production, would mint and transfer YES tokens to user
        output_amount
    }

    /// Calculate expected output for a YES->NO swap (for UI preview)
    public fun quote_yes_for_no(
        pool: &LiquidityPool,
        input_amount: u64,
    ): (u64, u64) {
        let yes_reserve = trading_types::pool_yes_reserve(pool);
        let no_reserve = trading_types::pool_no_reserve(pool);

        if (yes_reserve == 0 || no_reserve == 0 || input_amount == 0) {
            return (0, 0)
        };

        // Use u128 to prevent overflow
        let fee_bps = trading_types::amm_fee_bps();
        let input_with_fee = (input_amount as u128) * ((10000 - fee_bps) as u128);
        let numerator = (no_reserve as u128) * input_with_fee;
        let denominator = (yes_reserve as u128) * 10000 + input_with_fee;
        let output_amount = ((numerator / denominator) as u64);
        let fee_amount = (input_amount * fee_bps) / 10000;

        (output_amount, fee_amount)
    }

    /// Calculate expected output for a NO->YES swap (for UI preview)
    public fun quote_no_for_yes(
        pool: &LiquidityPool,
        input_amount: u64,
    ): (u64, u64) {
        let yes_reserve = trading_types::pool_yes_reserve(pool);
        let no_reserve = trading_types::pool_no_reserve(pool);

        if (yes_reserve == 0 || no_reserve == 0 || input_amount == 0) {
            return (0, 0)
        };

        // Use u128 to prevent overflow
        let fee_bps = trading_types::amm_fee_bps();
        let input_with_fee = (input_amount as u128) * ((10000 - fee_bps) as u128);
        let numerator = (yes_reserve as u128) * input_with_fee;
        let denominator = (no_reserve as u128) * 10000 + input_with_fee;
        let output_amount = ((numerator / denominator) as u64);
        let fee_amount = (input_amount * fee_bps) / 10000;

        (output_amount, fee_amount)
    }

    /// Get pool statistics
    /// Returns (yes_reserve, no_reserve, total_lp_tokens, yes_price_bps, total_fees)
    public fun get_pool_stats(pool: &LiquidityPool): (u64, u64, u64, u64, u64) {
        (
            trading_types::pool_yes_reserve(pool),
            trading_types::pool_no_reserve(pool),
            trading_types::pool_total_lp_tokens(pool),
            trading_types::pool_yes_price(pool),
            trading_types::pool_total_fees(pool),
        )
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 6: ORDER BOOK QUERIES (Extended)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get order book depth for a specific outcome
    /// Returns (total_buy_amount, total_sell_amount, buy_order_count, sell_order_count)
    public fun get_order_book_depth(
        book: &OrderBook,
        outcome: u8,
    ): (u64, u64, u64, u64) {
        let mut total_buy_amount: u64 = 0;
        let mut total_sell_amount: u64 = 0;
        let mut buy_count: u64 = 0;
        let mut sell_count: u64 = 0;

        let mut i: u64 = 0;
        let next_id = trading_types::book_next_order_id(book);

        while (i < next_id) {
            if (trading_types::book_has_order(book, i)) {
                let order = trading_types::book_get_order(book, i);
                if (trading_types::order_is_open(order) &&
                    trading_types::order_outcome(order) == outcome) {
                    let remaining = trading_types::order_remaining(order);
                    if (trading_types::order_is_buy(order)) {
                        total_buy_amount = total_buy_amount + remaining;
                        buy_count = buy_count + 1;
                    } else {
                        total_sell_amount = total_sell_amount + remaining;
                        sell_count = sell_count + 1;
                    };
                };
            };
            i = i + 1;
        };

        (total_buy_amount, total_sell_amount, buy_count, sell_count)
    }

    /// Get best bid (highest buy) and best ask (lowest sell) prices
    /// Returns (best_bid_price, best_ask_price) or (0, 0) if no orders
    public fun get_bid_ask_prices(
        book: &OrderBook,
        outcome: u8,
    ): (u64, u64) {
        let (_bid_order_id, best_bid, _bid_remaining) = find_best_buy_order(book, outcome);
        let (_ask_order_id, best_ask, _ask_remaining) = find_best_sell_order(book, outcome);

        (best_bid, best_ask)
    }

    /// Get spread (difference between best ask and best bid)
    /// Returns spread in basis points, or 10000 if no valid spread
    public fun get_spread(
        book: &OrderBook,
        outcome: u8,
    ): u64 {
        let (best_bid, best_ask) = get_bid_ask_prices(book, outcome);

        if (best_bid == 0 || best_ask == 0) {
            return trading_types::price_precision() // No valid spread
        };

        if (best_ask > best_bid) {
            best_ask - best_bid
        } else {
            0 // Orders overlap (crossed book)
        }
    }

    /// Count user's open orders
    /// Returns (total_count, buy_count, sell_count)
    public fun count_user_orders(
        book: &OrderBook,
        user: address,
    ): (u64, u64, u64) {
        let mut total_count: u64 = 0;
        let mut buy_count: u64 = 0;
        let mut sell_count: u64 = 0;

        let mut i: u64 = 0;
        let next_id = trading_types::book_next_order_id(book);

        while (i < next_id) {
            if (trading_types::book_has_order(book, i)) {
                let order = trading_types::book_get_order(book, i);
                if (trading_types::order_is_open(order) &&
                    trading_types::order_maker(order) == user) {
                    total_count = total_count + 1;
                    if (trading_types::order_is_buy(order)) {
                        buy_count = buy_count + 1;
                    } else {
                        sell_count = sell_count + 1;
                    };
                };
            };
            i = i + 1;
        };

        (total_count, buy_count, sell_count)
    }

    /// Get market mid price (average of best bid and ask)
    /// Returns price in basis points, or 5000 (50%) if no orders
    public fun get_mid_price(
        book: &OrderBook,
        outcome: u8,
    ): u64 {
        let (best_bid, best_ask) = get_bid_ask_prices(book, outcome);

        if (best_bid == 0 && best_ask == 0) {
            return 5000 // Default to 50%
        };

        if (best_bid == 0) {
            return best_ask
        };

        if (best_ask == 0) {
            return best_bid
        };

        (best_bid + best_ask) / 2
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Integer square root for u128 (used for LP token calculation)
    fun sqrt_u128(x: u128): u64 {
        if (x == 0) {
            return 0
        };

        let mut z = (x + 1) / 2;
        let mut y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        };

        (y as u64)
    }
}
