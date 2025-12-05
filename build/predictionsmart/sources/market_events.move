/// Market Events - Event structs and emit functions
///
/// Events must be defined in the same module that emits them.
/// Other modules call these emit functions to broadcast events.
module predictionsmart::market_events {
    use sui::event;
    use std::string::String;

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENT STRUCTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emitted when a new market is created
    public struct MarketCreated has copy, drop {
        market_id: u64,
        question: String,
        category: String,
        creator: address,
        end_time: u64,
        resolution_time: u64,
        resolution_type: u8,
        fee_bps: u16,
        timestamp: u64,
    }

    /// Emitted when trading period ends
    public struct TradingEnded has copy, drop {
        market_id: u64,
        total_volume: u64,
        total_collateral: u64,
        timestamp: u64,
    }

    /// Emitted when market is resolved
    public struct MarketResolved has copy, drop {
        market_id: u64,
        winning_outcome: u8,
        resolver: address,
        timestamp: u64,
    }

    /// Emitted when market is voided
    public struct MarketVoided has copy, drop {
        market_id: u64,
        reason: String,
        voided_by: address,
        timestamp: u64,
    }

    /// Emitted when volume is updated
    public struct VolumeUpdated has copy, drop {
        market_id: u64,
        amount: u64,
        new_total: u64,
        timestamp: u64,
    }

    /// Emitted when collateral changes
    public struct CollateralUpdated has copy, drop {
        market_id: u64,
        amount: u64,
        is_deposit: bool,
        new_total: u64,
        timestamp: u64,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EMIT FUNCTIONS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emit MarketCreated event
    public(package) fun emit_market_created(
        market_id: u64,
        question: String,
        category: String,
        creator: address,
        end_time: u64,
        resolution_time: u64,
        resolution_type: u8,
        fee_bps: u16,
        timestamp: u64,
    ) {
        event::emit(MarketCreated {
            market_id,
            question,
            category,
            creator,
            end_time,
            resolution_time,
            resolution_type,
            fee_bps,
            timestamp,
        });
    }

    /// Emit TradingEnded event
    public(package) fun emit_trading_ended(
        market_id: u64,
        total_volume: u64,
        total_collateral: u64,
        timestamp: u64,
    ) {
        event::emit(TradingEnded {
            market_id,
            total_volume,
            total_collateral,
            timestamp,
        });
    }

    /// Emit MarketResolved event
    public(package) fun emit_market_resolved(
        market_id: u64,
        winning_outcome: u8,
        resolver: address,
        timestamp: u64,
    ) {
        event::emit(MarketResolved {
            market_id,
            winning_outcome,
            resolver,
            timestamp,
        });
    }

    /// Emit MarketVoided event
    public(package) fun emit_market_voided(
        market_id: u64,
        reason: String,
        voided_by: address,
        timestamp: u64,
    ) {
        event::emit(MarketVoided {
            market_id,
            reason,
            voided_by,
            timestamp,
        });
    }

    /// Emit VolumeUpdated event
    public(package) fun emit_volume_updated(
        market_id: u64,
        amount: u64,
        new_total: u64,
        timestamp: u64,
    ) {
        event::emit(VolumeUpdated {
            market_id,
            amount,
            new_total,
            timestamp,
        });
    }

    /// Emit CollateralUpdated event
    public(package) fun emit_collateral_updated(
        market_id: u64,
        amount: u64,
        is_deposit: bool,
        new_total: u64,
        timestamp: u64,
    ) {
        event::emit(CollateralUpdated {
            market_id,
            amount,
            is_deposit,
            new_total,
            timestamp,
        });
    }
}
