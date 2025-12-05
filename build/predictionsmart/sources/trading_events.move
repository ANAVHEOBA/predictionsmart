/// Trading Events - Event structs and emit functions
///
/// All events related to trading operations.
module predictionsmart::trading_events {
    use sui::event;

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENT STRUCTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emitted when an order book is created for a market
    public struct OrderBookCreated has copy, drop {
        market_id: u64,
        timestamp: u64,
    }

    /// Emitted when a new order is placed
    public struct OrderPlaced has copy, drop {
        order_id: u64,
        market_id: u64,
        maker: address,
        side: u8,
        outcome: u8,
        price: u64,
        amount: u64,
        timestamp: u64,
    }

    /// Emitted when an order is cancelled
    public struct OrderCancelled has copy, drop {
        order_id: u64,
        market_id: u64,
        maker: address,
        remaining_amount: u64,
        timestamp: u64,
    }

    /// Emitted when a trade is executed
    public struct TradeExecuted has copy, drop {
        trade_id: u64,
        market_id: u64,
        maker_order_id: u64,
        maker: address,
        taker: address,
        side: u8,
        outcome: u8,
        price: u64,
        amount: u64,
        timestamp: u64,
    }

    /// Emitted when an order is fully filled
    public struct OrderFilled has copy, drop {
        order_id: u64,
        market_id: u64,
        maker: address,
        total_filled: u64,
        timestamp: u64,
    }

    // --- Liquidity Pool Events ---

    /// Emitted when a liquidity pool is created
    public struct LiquidityPoolCreated has copy, drop {
        market_id: u64,
        timestamp: u64,
    }

    /// Emitted when liquidity is added to a pool
    public struct LiquidityAdded has copy, drop {
        market_id: u64,
        provider: address,
        yes_amount: u64,
        no_amount: u64,
        lp_tokens_minted: u64,
        timestamp: u64,
    }

    /// Emitted when liquidity is removed from a pool
    public struct LiquidityRemoved has copy, drop {
        market_id: u64,
        provider: address,
        yes_amount: u64,
        no_amount: u64,
        lp_tokens_burned: u64,
        timestamp: u64,
    }

    /// Emitted when a swap is executed through the AMM
    public struct SwapExecuted has copy, drop {
        market_id: u64,
        trader: address,
        input_outcome: u8,
        input_amount: u64,
        output_outcome: u8,
        output_amount: u64,
        fee_amount: u64,
        timestamp: u64,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EMIT FUNCTIONS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    public(package) fun emit_order_book_created(
        market_id: u64,
        timestamp: u64,
    ) {
        event::emit(OrderBookCreated {
            market_id,
            timestamp,
        });
    }

    public(package) fun emit_order_placed(
        order_id: u64,
        market_id: u64,
        maker: address,
        side: u8,
        outcome: u8,
        price: u64,
        amount: u64,
        timestamp: u64,
    ) {
        event::emit(OrderPlaced {
            order_id,
            market_id,
            maker,
            side,
            outcome,
            price,
            amount,
            timestamp,
        });
    }

    public(package) fun emit_order_cancelled(
        order_id: u64,
        market_id: u64,
        maker: address,
        remaining_amount: u64,
        timestamp: u64,
    ) {
        event::emit(OrderCancelled {
            order_id,
            market_id,
            maker,
            remaining_amount,
            timestamp,
        });
    }

    public(package) fun emit_trade_executed(
        trade_id: u64,
        market_id: u64,
        maker_order_id: u64,
        maker: address,
        taker: address,
        side: u8,
        outcome: u8,
        price: u64,
        amount: u64,
        timestamp: u64,
    ) {
        event::emit(TradeExecuted {
            trade_id,
            market_id,
            maker_order_id,
            maker,
            taker,
            side,
            outcome,
            price,
            amount,
            timestamp,
        });
    }

    public(package) fun emit_order_filled(
        order_id: u64,
        market_id: u64,
        maker: address,
        total_filled: u64,
        timestamp: u64,
    ) {
        event::emit(OrderFilled {
            order_id,
            market_id,
            maker,
            total_filled,
            timestamp,
        });
    }

    // --- Liquidity Pool Event Emitters ---

    public(package) fun emit_liquidity_pool_created(
        market_id: u64,
        timestamp: u64,
    ) {
        event::emit(LiquidityPoolCreated {
            market_id,
            timestamp,
        });
    }

    public(package) fun emit_liquidity_added(
        market_id: u64,
        provider: address,
        yes_amount: u64,
        no_amount: u64,
        lp_tokens_minted: u64,
        timestamp: u64,
    ) {
        event::emit(LiquidityAdded {
            market_id,
            provider,
            yes_amount,
            no_amount,
            lp_tokens_minted,
            timestamp,
        });
    }

    public(package) fun emit_liquidity_removed(
        market_id: u64,
        provider: address,
        yes_amount: u64,
        no_amount: u64,
        lp_tokens_burned: u64,
        timestamp: u64,
    ) {
        event::emit(LiquidityRemoved {
            market_id,
            provider,
            yes_amount,
            no_amount,
            lp_tokens_burned,
            timestamp,
        });
    }

    public(package) fun emit_swap_executed(
        market_id: u64,
        trader: address,
        input_outcome: u8,
        input_amount: u64,
        output_outcome: u8,
        output_amount: u64,
        fee_amount: u64,
        timestamp: u64,
    ) {
        event::emit(SwapExecuted {
            market_id,
            trader,
            input_outcome,
            input_amount,
            output_outcome,
            output_amount,
            fee_amount,
            timestamp,
        });
    }
}
