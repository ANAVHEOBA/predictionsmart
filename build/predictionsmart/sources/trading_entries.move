/// Trading Entries - Public entry functions (transaction endpoints)
///
/// These are the functions users call directly via transactions.
module predictionsmart::trading_entries {
    use sui::clock::Clock;
    use sui::coin::Coin;
    use sui::sui::SUI;

    use predictionsmart::market_types::Market;
    use predictionsmart::token_types::{Self, YesToken, NoToken};
    use predictionsmart::trading_types::{Self, OrderBook, LiquidityPool, LPToken};
    use predictionsmart::trading_operations;

    // ═══════════════════════════════════════════════════════════════════════════
    // ORDER BOOK CREATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create an order book for a market
    entry fun create_order_book(
        market_id: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let book = trading_operations::create_order_book(market_id, clock, ctx);
        trading_types::share_order_book(book);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: LIMIT ORDERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Place a buy order for YES tokens
    /// Payment is held until order is filled or cancelled
    entry fun place_buy_yes(
        market: &Market,
        book: &mut OrderBook,
        payment: Coin<SUI>,
        price: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let (_order_id, payment) = trading_operations::place_buy_yes_order(
            market,
            book,
            payment,
            price,
            clock,
            ctx,
        );
        // Hold payment in escrow (transfer to a shared object or use dynamic fields)
        // For now, we'll transfer to a holding address
        // In production, this should be held in the order book
        transfer::public_transfer(payment, @0x0); // TODO: proper escrow
    }

    /// Place a buy order for NO tokens
    entry fun place_buy_no(
        market: &Market,
        book: &mut OrderBook,
        payment: Coin<SUI>,
        price: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let (_order_id, payment) = trading_operations::place_buy_no_order(
            market,
            book,
            payment,
            price,
            clock,
            ctx,
        );
        transfer::public_transfer(payment, @0x0); // TODO: proper escrow
    }

    /// Place a sell order for YES tokens
    entry fun place_sell_yes(
        market: &Market,
        book: &mut OrderBook,
        yes_token: YesToken,
        price: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let (_order_id, yes_token) = trading_operations::place_sell_yes_order(
            market,
            book,
            yes_token,
            price,
            clock,
            ctx,
        );
        // Hold token in escrow
        token_types::transfer_yes_token(yes_token, @0x0); // TODO: proper escrow
    }

    /// Place a sell order for NO tokens
    entry fun place_sell_no(
        market: &Market,
        book: &mut OrderBook,
        no_token: NoToken,
        price: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let (_order_id, no_token) = trading_operations::place_sell_no_order(
            market,
            book,
            no_token,
            price,
            clock,
            ctx,
        );
        token_types::transfer_no_token(no_token, @0x0); // TODO: proper escrow
    }

    /// Cancel an open order
    entry fun cancel_order(
        book: &mut OrderBook,
        order_id: u64,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        trading_operations::cancel_order(book, order_id, clock, ctx);
        // TODO: Return escrowed funds/tokens to maker
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 2: ORDER MATCHING
    // ═══════════════════════════════════════════════════════════════════════════

    /// Match two orders (can be called by anyone - keeper/bot)
    entry fun match_orders(
        book: &mut OrderBook,
        buy_order_id: u64,
        sell_order_id: u64,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        trading_operations::match_orders(book, buy_order_id, sell_order_id, clock, ctx);
        // TODO: Execute actual token/SUI transfers between parties
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 4: AMM LIQUIDITY POOL
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a liquidity pool for a market
    entry fun create_liquidity_pool(
        market_id: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let pool = trading_operations::create_liquidity_pool(market_id, clock, ctx);
        trading_types::share_liquidity_pool(pool);
    }

    /// Add liquidity to pool (deposit YES + NO tokens)
    entry fun add_liquidity(
        market: &Market,
        pool: &mut LiquidityPool,
        yes_token: YesToken,
        no_token: NoToken,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let lp_token = trading_operations::add_pool_liquidity(
            market,
            pool,
            yes_token,
            no_token,
            clock,
            ctx,
        );
        // Transfer LP token to provider
        trading_types::transfer_lp_token(lp_token, ctx.sender());
    }

    /// Remove liquidity from pool (withdraw YES + NO tokens)
    entry fun remove_liquidity(
        market: &Market,
        pool: &mut LiquidityPool,
        lp_token: LPToken,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        let (_yes_amount, _no_amount) = trading_operations::remove_pool_liquidity(
            market,
            pool,
            lp_token,
            clock,
            ctx,
        );
        // TODO: Mint and transfer YES/NO tokens back to provider
    }

    /// Swap YES tokens for NO tokens through the AMM
    entry fun swap_yes_for_no(
        market: &Market,
        pool: &mut LiquidityPool,
        yes_token: YesToken,
        min_output: u64,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        let _output_amount = trading_operations::swap_yes_for_no(
            market,
            pool,
            yes_token,
            min_output,
            clock,
            ctx,
        );
        // TODO: Mint and transfer NO tokens to user
    }

    /// Swap NO tokens for YES tokens through the AMM
    entry fun swap_no_for_yes(
        market: &Market,
        pool: &mut LiquidityPool,
        no_token: NoToken,
        min_output: u64,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        let _output_amount = trading_operations::swap_no_for_yes(
            market,
            pool,
            no_token,
            min_output,
            clock,
            ctx,
        );
        // TODO: Mint and transfer YES tokens to user
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test_only]
    public fun create_order_book_for_testing(
        market_id: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): OrderBook {
        trading_operations::create_order_book(market_id, clock, ctx)
    }

    #[test_only]
    public fun place_buy_yes_for_testing(
        market: &Market,
        book: &mut OrderBook,
        payment: Coin<SUI>,
        price: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u64, Coin<SUI>) {
        trading_operations::place_buy_yes_order(market, book, payment, price, clock, ctx)
    }

    #[test_only]
    public fun place_sell_yes_for_testing(
        market: &Market,
        book: &mut OrderBook,
        yes_token: YesToken,
        price: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u64, YesToken) {
        trading_operations::place_sell_yes_order(market, book, yes_token, price, clock, ctx)
    }

    #[test_only]
    public fun place_buy_no_for_testing(
        market: &Market,
        book: &mut OrderBook,
        payment: Coin<SUI>,
        price: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u64, Coin<SUI>) {
        trading_operations::place_buy_no_order(market, book, payment, price, clock, ctx)
    }

    #[test_only]
    public fun place_sell_no_for_testing(
        market: &Market,
        book: &mut OrderBook,
        no_token: NoToken,
        price: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u64, NoToken) {
        trading_operations::place_sell_no_order(market, book, no_token, price, clock, ctx)
    }

    #[test_only]
    public fun create_liquidity_pool_for_testing(
        market_id: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): LiquidityPool {
        trading_operations::create_liquidity_pool(market_id, clock, ctx)
    }

    #[test_only]
    public fun add_liquidity_for_testing(
        market: &Market,
        pool: &mut LiquidityPool,
        yes_token: YesToken,
        no_token: NoToken,
        clock: &Clock,
        ctx: &mut TxContext,
    ): LPToken {
        trading_operations::add_pool_liquidity(market, pool, yes_token, no_token, clock, ctx)
    }

    #[test_only]
    public fun remove_liquidity_for_testing(
        market: &Market,
        pool: &mut LiquidityPool,
        lp_token: LPToken,
        clock: &Clock,
        ctx: &TxContext,
    ): (u64, u64) {
        trading_operations::remove_pool_liquidity(market, pool, lp_token, clock, ctx)
    }

    #[test_only]
    public fun swap_yes_for_no_for_testing(
        market: &Market,
        pool: &mut LiquidityPool,
        yes_token: YesToken,
        min_output: u64,
        clock: &Clock,
        ctx: &TxContext,
    ): u64 {
        trading_operations::swap_yes_for_no(market, pool, yes_token, min_output, clock, ctx)
    }

    #[test_only]
    public fun swap_no_for_yes_for_testing(
        market: &Market,
        pool: &mut LiquidityPool,
        no_token: NoToken,
        min_output: u64,
        clock: &Clock,
        ctx: &TxContext,
    ): u64 {
        trading_operations::swap_no_for_yes(market, pool, no_token, min_output, clock, ctx)
    }
}
