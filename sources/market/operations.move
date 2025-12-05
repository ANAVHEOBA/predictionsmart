/// Market Operations - Core business logic
///
/// This module contains all the business logic for binary markets.
/// It uses types.move for data and events.move for broadcasting.
module predictionsmart::market_operations {
    use sui::clock::Clock;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use std::string::{Self, String};

    use predictionsmart::market_types::{
        Self,
        Market,
        MarketRegistry,
        AdminCap,
    };
    use predictionsmart::market_events;

    // ═══════════════════════════════════════════════════════════════════════════
    // ERROR CODES
    // ═══════════════════════════════════════════════════════════════════════════

    const E_PLATFORM_PAUSED: u64 = 1;
    const E_INSUFFICIENT_FEE: u64 = 2;
    const E_QUESTION_TOO_SHORT: u64 = 3;
    const E_QUESTION_TOO_LONG: u64 = 4;
    const E_INVALID_END_TIME: u64 = 5;
    const E_INVALID_RESOLUTION_TIME: u64 = 6;
    const E_INVALID_FEE: u64 = 7;
    const E_INVALID_RESOLUTION_TYPE: u64 = 8;
    const E_NOT_CREATOR: u64 = 9;
    const E_NOT_AUTHORIZED: u64 = 10;
    const E_MARKET_NOT_OPEN: u64 = 11;
    const E_TRADING_NOT_ENDED: u64 = 12;
    const E_ALREADY_RESOLVED: u64 = 13;
    const E_INVALID_OUTCOME: u64 = 14;
    const E_TOO_EARLY: u64 = 15;

    // ═══════════════════════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create initial registry and admin cap
    /// Returns them so caller can share/transfer appropriately
    public fun create_registry_and_admin(
        treasury: address,
        ctx: &mut TxContext,
    ): (MarketRegistry, AdminCap) {
        let registry = market_types::new_registry(treasury, ctx);
        let admin_cap = market_types::new_admin_cap(ctx);

        (registry, admin_cap)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: CREATE MARKET
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a new binary market
    /// Anyone can call - pays creation fee
    public fun create_market(
        registry: &mut MarketRegistry,
        fee_payment: Coin<SUI>,
        question: String,
        description: String,
        image_url: String,
        category: String,
        tags: vector<String>,
        outcome_yes_label: String,
        outcome_no_label: String,
        end_time: u64,
        resolution_time: u64,
        timeframe: String,
        resolution_type: u8,
        resolution_source: String,
        fee_bps: u16,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Market {
        // Check platform not paused
        assert!(!market_types::registry_paused(registry), E_PLATFORM_PAUSED);

        // Check creation fee
        let fee_required = market_types::registry_creation_fee(registry);
        assert!(coin::value(&fee_payment) >= fee_required, E_INSUFFICIENT_FEE);

        // Validate question length
        let question_len = string::length(&question);
        assert!(question_len >= market_types::min_question_length(), E_QUESTION_TOO_SHORT);
        assert!(question_len <= market_types::max_question_length(), E_QUESTION_TOO_LONG);

        // Validate timing
        let now = clock.timestamp_ms();
        assert!(end_time > now + market_types::min_duration_ms(), E_INVALID_END_TIME);
        assert!(resolution_time >= end_time, E_INVALID_RESOLUTION_TIME);

        // Validate fee
        assert!(fee_bps <= market_types::max_fee_bps(), E_INVALID_FEE);

        // Validate resolution type
        assert!(resolution_type <= market_types::resolution_oracle(), E_INVALID_RESOLUTION_TYPE);

        // Transfer fee to treasury
        let treasury = market_types::registry_treasury(registry);
        transfer::public_transfer(fee_payment, treasury);

        // Get new market ID
        let market_id = market_types::increment_market_count(registry);

        // Create market
        let market = market_types::new_market(
            market_id,
            question,
            description,
            image_url,
            category,
            tags,
            outcome_yes_label,
            outcome_no_label,
            now,
            end_time,
            resolution_time,
            timeframe,
            resolution_type,
            resolution_source,
            fee_bps,
            ctx.sender(),
            ctx,
        );

        // Emit event
        market_events::emit_market_created(
            market_id,
            *market_types::question(&market),
            *market_types::category(&market),
            market_types::creator(&market),
            end_time,
            resolution_time,
            resolution_type,
            fee_bps,
            now,
        );

        market
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: END TRADING
    // ═══════════════════════════════════════════════════════════════════════════

    /// Check and end trading if time has passed
    /// Anyone can call to trigger state transition
    public fun check_and_end_trading(
        market: &mut Market,
        clock: &Clock,
    ): bool {
        // Only if still open
        if (!market_types::is_open(market)) {
            return false
        };

        let now = clock.timestamp_ms();
        if (now >= market_types::end_time(market)) {
            // Transition to trading ended
            market_types::set_status(market, market_types::status_trading_ended());

            // Emit event
            market_events::emit_trading_ended(
                market_types::market_id(market),
                market_types::total_volume(market),
                market_types::total_collateral(market),
                now,
            );

            return true
        };

        false
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 4: RESOLVE MARKET
    // ═══════════════════════════════════════════════════════════════════════════

    /// Resolve market by creator (only for creator-resolved markets)
    public fun resolve_by_creator(
        market: &mut Market,
        winning_outcome: u8,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        let sender = ctx.sender();

        // Must be creator
        assert!(sender == market_types::creator(market), E_NOT_CREATOR);

        // Must be creator resolution type
        assert!(
            market_types::resolution_type(market) == market_types::resolution_creator(),
            E_NOT_AUTHORIZED
        );

        resolve_internal(market, winning_outcome, sender, clock);
    }

    /// Resolve market by admin (can resolve any market)
    public fun resolve_by_admin(
        market: &mut Market,
        _admin_cap: &AdminCap,
        winning_outcome: u8,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        resolve_internal(market, winning_outcome, ctx.sender(), clock);
    }

    /// Internal resolution logic
    fun resolve_internal(
        market: &mut Market,
        winning_outcome: u8,
        resolver: address,
        clock: &Clock,
    ) {
        let now = clock.timestamp_ms();

        // Auto-end trading if needed
        if (market_types::is_open(market) && now >= market_types::end_time(market)) {
            market_types::set_status(market, market_types::status_trading_ended());
        };

        // Validate state
        assert!(market_types::is_trading_ended(market), E_TRADING_NOT_ENDED);
        assert!(market_types::winning_outcome(market) == market_types::outcome_unset(), E_ALREADY_RESOLVED);
        assert!(winning_outcome <= market_types::outcome_no(), E_INVALID_OUTCOME);
        assert!(now >= market_types::resolution_time(market), E_TOO_EARLY);

        // Update market
        market_types::set_winning_outcome(market, winning_outcome);
        market_types::set_resolved_at(market, now);
        market_types::set_resolver(market, resolver);
        market_types::set_status(market, market_types::status_resolved());

        // Emit event
        market_events::emit_market_resolved(
            market_types::market_id(market),
            winning_outcome,
            resolver,
            now,
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 5: VOID MARKET
    // ═══════════════════════════════════════════════════════════════════════════

    /// Void market by creator (only if still open)
    public fun void_by_creator(
        market: &mut Market,
        reason: String,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        let sender = ctx.sender();

        // Must be creator
        assert!(sender == market_types::creator(market), E_NOT_CREATOR);

        // Can only void if still open
        assert!(market_types::is_open(market), E_MARKET_NOT_OPEN);

        void_internal(market, reason, sender, clock);
    }

    /// Void market by admin (can void anytime)
    public fun void_by_admin(
        market: &mut Market,
        _admin_cap: &AdminCap,
        reason: String,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        void_internal(market, reason, ctx.sender(), clock);
    }

    /// Internal void logic
    fun void_internal(
        market: &mut Market,
        reason: String,
        voided_by: address,
        clock: &Clock,
    ) {
        let now = clock.timestamp_ms();

        // Update market
        market_types::set_status(market, market_types::status_voided());
        market_types::set_winning_outcome(market, market_types::outcome_void());
        market_types::set_resolved_at(market, now);
        market_types::set_resolver(market, voided_by);

        // Emit event
        market_events::emit_market_voided(
            market_types::market_id(market),
            reason,
            voided_by,
            now,
        );
    }

    /// Resolve market by oracle module
    /// Can only be called by the oracle module for oracle-type markets
    public(package) fun resolve_by_oracle(
        market: &mut Market,
        winning_outcome: u8,
        clock: &Clock,
    ) {
        // Must be oracle resolution type
        assert!(
            market_types::resolution_type(market) == market_types::resolution_oracle(),
            E_NOT_AUTHORIZED
        );

        // Use @0x0 as resolver address since this is oracle-resolved
        // The actual oracle address would be in the oracle module's events
        resolve_internal(market, winning_outcome, @0x0, clock);
    }

    /// Void market by oracle module (for emergency situations)
    public(package) fun void_by_oracle(
        market: &mut Market,
        reason: String,
        clock: &Clock,
    ) {
        void_internal(market, reason, @0x0, clock);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 6: ADMIN CONFIG
    // ═══════════════════════════════════════════════════════════════════════════

    /// Set creation fee (admin only)
    public fun set_creation_fee(
        registry: &mut MarketRegistry,
        _admin_cap: &AdminCap,
        new_fee: u64,
    ) {
        market_types::set_creation_fee(registry, new_fee);
    }

    /// Set treasury address (admin only)
    public fun set_treasury(
        registry: &mut MarketRegistry,
        _admin_cap: &AdminCap,
        new_treasury: address,
    ) {
        market_types::set_treasury(registry, new_treasury);
    }

    /// Pause platform (admin only)
    public fun pause(
        registry: &mut MarketRegistry,
        _admin_cap: &AdminCap,
    ) {
        market_types::set_paused(registry, true);
    }

    /// Unpause platform (admin only)
    public fun unpause(
        registry: &mut MarketRegistry,
        _admin_cap: &AdminCap,
    ) {
        market_types::set_paused(registry, false);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INTERNAL: VOLUME & COLLATERAL UPDATES
    // Called by token/trading modules
    // ═══════════════════════════════════════════════════════════════════════════

    /// Add volume (called when trade happens)
    public(package) fun add_volume(
        market: &mut Market,
        registry: &mut MarketRegistry,
        amount: u64,
        clock: &Clock,
    ) {
        market_types::add_volume(market, amount);
        market_types::registry_add_volume(registry, amount);

        market_events::emit_volume_updated(
            market_types::market_id(market),
            amount,
            market_types::total_volume(market),
            clock.timestamp_ms(),
        );
    }

    /// Add collateral (called when tokens minted)
    public(package) fun add_collateral(
        market: &mut Market,
        registry: &mut MarketRegistry,
        amount: u64,
        clock: &Clock,
    ) {
        market_types::add_collateral(market, amount);
        market_types::registry_add_collateral(registry, amount);

        market_events::emit_collateral_updated(
            market_types::market_id(market),
            amount,
            true,
            market_types::total_collateral(market),
            clock.timestamp_ms(),
        );
    }

    /// Remove collateral (called when tokens redeemed)
    public(package) fun remove_collateral(
        market: &mut Market,
        registry: &mut MarketRegistry,
        amount: u64,
        clock: &Clock,
    ) {
        market_types::remove_collateral(market, amount);
        market_types::registry_remove_collateral(registry, amount);

        market_events::emit_collateral_updated(
            market_types::market_id(market),
            amount,
            false,
            market_types::total_collateral(market),
            clock.timestamp_ms(),
        );
    }
}
