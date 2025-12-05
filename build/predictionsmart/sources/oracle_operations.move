/// Oracle Operations - Business logic for oracle module
///
/// This module implements Features 1-7:
/// - Feature 1: Oracle Registry
/// - Feature 2: Request Resolution
/// - Feature 3: Propose Outcome
/// - Feature 4: Dispute Outcome
/// - Feature 5: Finalize Resolution
/// - Feature 6: Price Feed Resolution
/// - Feature 7: Emergency Override
module predictionsmart::oracle_operations {
    use std::string::{Self, String};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::Clock;

    use predictionsmart::oracle_types::{
        Self,
        OracleRegistry,
        OracleAdminCap,
        ResolutionRequest,
    };
    use predictionsmart::oracle_events;
    use predictionsmart::market_types::{Self, Market};
    use predictionsmart::market_operations;

    // ═══════════════════════════════════════════════════════════════════════════
    // ERROR CODES
    // ═══════════════════════════════════════════════════════════════════════════

    const E_NOT_ADMIN: u64 = 1;
    const E_PROVIDER_EXISTS: u64 = 2;
    const E_PROVIDER_NOT_FOUND: u64 = 3;
    const E_MARKET_NOT_ORACLE_TYPE: u64 = 6;
    const E_MARKET_ALREADY_RESOLVED: u64 = 7;
    const E_TRADING_NOT_ENDED: u64 = 8;
    const E_TOO_EARLY: u64 = 9;
    const E_INSUFFICIENT_BOND: u64 = 10;
    const E_REQUEST_EXISTS: u64 = 11;
    const E_INVALID_STATUS: u64 = 12;
    const E_INVALID_OUTCOME: u64 = 13;
    const E_INVALID_BOND: u64 = 14;
    const E_INVALID_DISPUTE_WINDOW: u64 = 15;
    const E_INVALID_PROVIDER_TYPE: u64 = 16;
    const E_DISPUTE_WINDOW_PASSED: u64 = 17;
    const E_DISPUTE_WINDOW_ACTIVE: u64 = 18;
    const E_SELF_DISPUTE: u64 = 19;
    const E_NOT_DISPUTED: u64 = 20;
    const E_MARKET_MISMATCH: u64 = 21;
    const E_INSUFFICIENT_TIME_PASSED: u64 = 22;

    // --- Emergency override time threshold (24 hours after dispute) ---
    const EMERGENCY_OVERRIDE_DELAY: u64 = 86_400_000; // 24 hours in ms

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: ORACLE REGISTRY
    // ═══════════════════════════════════════════════════════════════════════════

    /// Initialize the oracle registry
    /// Returns registry and admin cap
    public fun initialize_registry(
        ctx: &mut TxContext,
    ): (OracleRegistry, OracleAdminCap) {
        let admin = ctx.sender();
        let registry = oracle_types::new_oracle_registry(admin, ctx);
        let admin_cap = oracle_types::new_oracle_admin_cap(ctx);

        oracle_events::emit_registry_initialized(
            admin,
            oracle_types::default_bond(),
            oracle_types::default_dispute_window(),
        );

        (registry, admin_cap)
    }

    /// Register a new oracle provider
    public fun register_provider(
        registry: &mut OracleRegistry,
        _admin_cap: &OracleAdminCap,
        name: String,
        provider_type: u8,
        min_bond: u64,
        dispute_window: u64,
        ctx: &TxContext,
    ) {
        // Validate admin
        assert!(ctx.sender() == oracle_types::registry_admin(registry), E_NOT_ADMIN);

        // Validate provider doesn't exist
        assert!(!oracle_types::registry_has_provider(registry, name), E_PROVIDER_EXISTS);

        // Validate provider type
        assert!(
            provider_type <= oracle_types::provider_api(),
            E_INVALID_PROVIDER_TYPE
        );

        // Validate bond
        assert!(min_bond >= oracle_types::min_bond(), E_INVALID_BOND);

        // Validate dispute window
        assert!(
            dispute_window > 0 && dispute_window <= oracle_types::max_dispute_window(),
            E_INVALID_DISPUTE_WINDOW
        );

        // Create and add provider
        let provider = oracle_types::new_oracle_provider(
            name,
            provider_type,
            min_bond,
            dispute_window,
        );
        oracle_types::add_provider(registry, provider);

        oracle_events::emit_provider_registered(
            name,
            provider_type,
            min_bond,
            dispute_window,
        );
    }

    /// Update an existing provider's configuration
    public fun update_provider(
        registry: &mut OracleRegistry,
        _admin_cap: &OracleAdminCap,
        name: String,
        min_bond: u64,
        dispute_window: u64,
        is_active: bool,
        ctx: &TxContext,
    ) {
        // Validate admin
        assert!(ctx.sender() == oracle_types::registry_admin(registry), E_NOT_ADMIN);

        // Validate provider exists
        assert!(oracle_types::registry_has_provider(registry, name), E_PROVIDER_NOT_FOUND);

        // Validate bond
        assert!(min_bond >= oracle_types::min_bond(), E_INVALID_BOND);

        // Validate dispute window
        assert!(
            dispute_window > 0 && dispute_window <= oracle_types::max_dispute_window(),
            E_INVALID_DISPUTE_WINDOW
        );

        // Update provider
        let provider = oracle_types::get_provider_mut(registry, name);
        oracle_types::set_provider_min_bond(provider, min_bond);
        oracle_types::set_provider_dispute_window(provider, dispute_window);
        oracle_types::set_provider_active(provider, is_active);

        oracle_events::emit_provider_updated(
            name,
            min_bond,
            dispute_window,
            is_active,
        );
    }

    /// Deactivate a provider
    public fun deactivate_provider(
        registry: &mut OracleRegistry,
        _admin_cap: &OracleAdminCap,
        name: String,
        ctx: &TxContext,
    ) {
        // Validate admin
        assert!(ctx.sender() == oracle_types::registry_admin(registry), E_NOT_ADMIN);

        // Validate provider exists
        assert!(oracle_types::registry_has_provider(registry, name), E_PROVIDER_NOT_FOUND);

        // Deactivate
        let provider = oracle_types::get_provider_mut(registry, name);
        oracle_types::set_provider_active(provider, false);

        oracle_events::emit_provider_deactivated(name);
    }

    /// Set the default bond amount
    public fun set_default_bond(
        registry: &mut OracleRegistry,
        _admin_cap: &OracleAdminCap,
        new_bond: u64,
        ctx: &TxContext,
    ) {
        // Validate admin
        assert!(ctx.sender() == oracle_types::registry_admin(registry), E_NOT_ADMIN);

        // Validate bond
        assert!(new_bond >= oracle_types::min_bond(), E_INVALID_BOND);

        let old_bond = oracle_types::registry_default_bond(registry);
        oracle_types::set_default_bond(registry, new_bond);

        oracle_events::emit_default_bond_changed(old_bond, new_bond);
    }

    /// Set the default dispute window
    public fun set_default_dispute_window(
        registry: &mut OracleRegistry,
        _admin_cap: &OracleAdminCap,
        new_window: u64,
        ctx: &TxContext,
    ) {
        // Validate admin
        assert!(ctx.sender() == oracle_types::registry_admin(registry), E_NOT_ADMIN);

        // Validate window
        assert!(
            new_window > 0 && new_window <= oracle_types::max_dispute_window(),
            E_INVALID_DISPUTE_WINDOW
        );

        let old_window = oracle_types::registry_default_dispute_window(registry);
        oracle_types::set_default_dispute_window(registry, new_window);

        oracle_events::emit_default_dispute_window_changed(old_window, new_window);
    }

    /// Transfer registry admin
    public fun transfer_registry_admin(
        registry: &mut OracleRegistry,
        _admin_cap: &OracleAdminCap,
        new_admin: address,
        ctx: &TxContext,
    ) {
        // Validate admin
        assert!(ctx.sender() == oracle_types::registry_admin(registry), E_NOT_ADMIN);

        let old_admin = oracle_types::registry_admin(registry);
        oracle_types::set_registry_admin(registry, new_admin);

        oracle_events::emit_registry_admin_changed(old_admin, new_admin);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 2: REQUEST RESOLUTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Request oracle resolution for a market
    public fun request_resolution(
        registry: &mut OracleRegistry,
        market: &Market,
        bond: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): ResolutionRequest {
        let market_id = market_types::market_id(market);
        let oracle_source = *market_types::resolution_source(market);
        let requester = ctx.sender();
        let now = clock.timestamp_ms();

        // Validate market is oracle type
        assert!(
            market_types::resolution_type(market) == market_types::resolution_oracle(),
            E_MARKET_NOT_ORACLE_TYPE
        );

        // Validate trading has ended
        assert!(market_types::is_trading_ended(market), E_TRADING_NOT_ENDED);

        // Validate market not already resolved
        assert!(
            market_types::winning_outcome(market) == market_types::outcome_unset(),
            E_MARKET_ALREADY_RESOLVED
        );

        // Validate resolution time has passed
        assert!(now >= market_types::resolution_time(market), E_TOO_EARLY);

        // Validate no existing request for this market
        assert!(
            !oracle_types::registry_has_active_request(registry, market_id),
            E_REQUEST_EXISTS
        );

        // Validate bond amount
        let bond_amount = coin::value(&bond);
        let required_bond = oracle_types::registry_default_bond(registry);
        assert!(bond_amount >= required_bond, E_INSUFFICIENT_BOND);

        // Create request
        let request_id = oracle_types::increment_total_requests(registry);
        let request = oracle_types::new_resolution_request(
            request_id,
            market_id,
            oracle_source,
            requester,
            coin::into_balance(bond),
            now,
            ctx,
        );

        // Register active request
        oracle_types::register_active_request(registry, market_id, request_id);

        oracle_events::emit_resolution_requested(
            request_id,
            market_id,
            oracle_source,
            requester,
            bond_amount,
            now,
        );

        request
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: PROPOSE OUTCOME
    // ═══════════════════════════════════════════════════════════════════════════

    /// Propose an outcome for a resolution request
    public fun propose_outcome(
        registry: &OracleRegistry,
        request: &mut ResolutionRequest,
        proposed_outcome: u8,
        bond: Coin<SUI>,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        let proposer = ctx.sender();
        let now = clock.timestamp_ms();

        // Validate request is pending
        assert!(oracle_types::request_is_pending(request), E_INVALID_STATUS);

        // Validate outcome is valid (YES or NO)
        assert!(
            proposed_outcome == oracle_types::outcome_yes() ||
            proposed_outcome == oracle_types::outcome_no(),
            E_INVALID_OUTCOME
        );

        // Validate bond amount
        let bond_amount = coin::value(&bond);
        let required_bond = oracle_types::registry_default_bond(registry);
        assert!(bond_amount >= required_bond, E_INSUFFICIENT_BOND);

        // Calculate dispute deadline
        let dispute_window = oracle_types::registry_default_dispute_window(registry);
        let dispute_deadline = now + dispute_window;

        // Set proposal
        oracle_types::set_proposed_outcome(
            request,
            proposed_outcome,
            proposer,
            coin::into_balance(bond),
            now,
            dispute_deadline,
        );

        let request_id = oracle_types::request_id(request);
        let market_id = oracle_types::request_market_id(request);

        oracle_events::emit_outcome_proposed(
            request_id,
            market_id,
            proposer,
            proposed_outcome,
            bond_amount,
            now,
            dispute_deadline,
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 4: DISPUTE OUTCOME
    // ═══════════════════════════════════════════════════════════════════════════

    /// Dispute a proposed outcome
    /// Anyone (except the proposer) can dispute during the dispute window
    public fun dispute_outcome(
        registry: &OracleRegistry,
        request: &mut ResolutionRequest,
        bond: Coin<SUI>,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        let disputer = ctx.sender();
        let now = clock.timestamp_ms();

        // Validate request is in proposed state
        assert!(oracle_types::request_is_proposed(request), E_INVALID_STATUS);

        // Validate within dispute window
        let dispute_deadline = oracle_types::request_dispute_deadline(request);
        assert!(now < dispute_deadline, E_DISPUTE_WINDOW_PASSED);

        // Validate disputer is not the proposer (can't dispute your own proposal)
        let proposer = oracle_types::request_proposer(request);
        assert!(disputer != proposer, E_SELF_DISPUTE);

        // Validate bond amount (must match or exceed proposer bond)
        let bond_amount = coin::value(&bond);
        let required_bond = oracle_types::registry_default_bond(registry);
        assert!(bond_amount >= required_bond, E_INSUFFICIENT_BOND);

        // Set disputer
        oracle_types::set_disputer(
            request,
            disputer,
            coin::into_balance(bond),
        );

        let request_id = oracle_types::request_id(request);
        let market_id = oracle_types::request_market_id(request);

        oracle_events::emit_outcome_disputed(
            request_id,
            market_id,
            disputer,
            bond_amount,
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 5: FINALIZE RESOLUTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Finalize a resolution that was not disputed
    /// Anyone can call after dispute window passes
    public fun finalize_undisputed(
        registry: &mut OracleRegistry,
        request: &mut ResolutionRequest,
        market: &mut Market,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let now = clock.timestamp_ms();

        // Validate request is in proposed state (not disputed)
        assert!(oracle_types::request_is_proposed(request), E_INVALID_STATUS);

        // Validate dispute window has passed
        let dispute_deadline = oracle_types::request_dispute_deadline(request);
        assert!(now >= dispute_deadline, E_DISPUTE_WINDOW_ACTIVE);

        // Validate market matches request
        let request_market_id = oracle_types::request_market_id(request);
        assert!(market_types::market_id(market) == request_market_id, E_MARKET_MISMATCH);

        // Get the proposed outcome as final
        let final_outcome = oracle_types::request_proposed_outcome(request);

        // Finalize request
        oracle_types::set_final_outcome(request, final_outcome, now);

        // Resolve market
        market_operations::resolve_by_oracle(market, final_outcome, clock);

        // Remove from active requests
        oracle_types::remove_active_request(registry, request_market_id);

        // Return bonds to requester and proposer
        let requester = oracle_types::request_requester(request);
        let proposer = oracle_types::request_proposer(request);
        let request_id = oracle_types::request_id(request);

        // Return requester bond
        let requester_bond = oracle_types::withdraw_requester_bond(request);
        let requester_amount = sui::balance::value(&requester_bond);
        if (requester_amount > 0) {
            let requester_coin = coin::from_balance(requester_bond, ctx);
            transfer::public_transfer(requester_coin, requester);
            oracle_events::emit_bond_distributed(
                request_id,
                requester,
                requester_amount,
                string::utf8(b"requester_refund"),
            );
        } else {
            sui::balance::destroy_zero(requester_bond);
        };

        // Return proposer bond
        let proposer_bond = oracle_types::withdraw_proposer_bond(request);
        let proposer_amount = sui::balance::value(&proposer_bond);
        if (proposer_amount > 0) {
            let proposer_coin = coin::from_balance(proposer_bond, ctx);
            transfer::public_transfer(proposer_coin, proposer);
            oracle_events::emit_bond_distributed(
                request_id,
                proposer,
                proposer_amount,
                string::utf8(b"proposer_refund"),
            );
        } else {
            sui::balance::destroy_zero(proposer_bond);
        };

        oracle_events::emit_resolution_finalized(
            request_id,
            request_market_id,
            final_outcome,
            ctx.sender(),
            now,
        );
    }

    /// Finalize a disputed resolution (admin only)
    /// Admin determines the correct outcome and awards bonds
    public fun finalize_disputed(
        registry: &mut OracleRegistry,
        request: &mut ResolutionRequest,
        market: &mut Market,
        admin_cap: &OracleAdminCap,
        final_outcome: u8,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let admin = ctx.sender();
        let now = clock.timestamp_ms();

        // Validate admin
        assert!(admin == oracle_types::registry_admin(registry), E_NOT_ADMIN);
        let _ = admin_cap; // Use admin_cap to prove admin capability

        // Validate request is in disputed state
        assert!(oracle_types::request_is_disputed(request), E_NOT_DISPUTED);

        // Validate outcome is valid (YES or NO)
        assert!(
            final_outcome == oracle_types::outcome_yes() ||
            final_outcome == oracle_types::outcome_no(),
            E_INVALID_OUTCOME
        );

        // Validate market matches request
        let request_market_id = oracle_types::request_market_id(request);
        assert!(market_types::market_id(market) == request_market_id, E_MARKET_MISMATCH);

        // Finalize request
        oracle_types::set_final_outcome(request, final_outcome, now);

        // Resolve market
        market_operations::resolve_by_oracle(market, final_outcome, clock);

        // Remove from active requests
        oracle_types::remove_active_request(registry, request_market_id);

        let request_id = oracle_types::request_id(request);
        let proposer = oracle_types::request_proposer(request);
        let disputer = oracle_types::request_disputer(request);
        let proposed_outcome = oracle_types::request_proposed_outcome(request);

        // Return requester bond (always returned)
        let requester = oracle_types::request_requester(request);
        let requester_bond = oracle_types::withdraw_requester_bond(request);
        let requester_amount = sui::balance::value(&requester_bond);
        if (requester_amount > 0) {
            let requester_coin = coin::from_balance(requester_bond, ctx);
            transfer::public_transfer(requester_coin, requester);
            oracle_events::emit_bond_distributed(
                request_id,
                requester,
                requester_amount,
                string::utf8(b"requester_refund"),
            );
        } else {
            sui::balance::destroy_zero(requester_bond);
        };

        // Determine winner and distribute bonds
        let mut proposer_bond = oracle_types::withdraw_proposer_bond(request);
        let mut disputer_bond = oracle_types::withdraw_disputer_bond(request);
        let proposer_amount = sui::balance::value(&proposer_bond);
        let disputer_amount = sui::balance::value(&disputer_bond);

        if (final_outcome == proposed_outcome) {
            // Proposer was correct - gets both bonds
            sui::balance::join(&mut proposer_bond, disputer_bond);
            let total = sui::balance::value(&proposer_bond);
            if (total > 0) {
                let winner_coin = coin::from_balance(proposer_bond, ctx);
                transfer::public_transfer(winner_coin, proposer);
                oracle_events::emit_bond_slashed(
                    request_id,
                    disputer,
                    proposer,
                    disputer_amount,
                );
            } else {
                sui::balance::destroy_zero(proposer_bond);
            };
        } else {
            // Disputer was correct - gets both bonds
            sui::balance::join(&mut disputer_bond, proposer_bond);
            let total = sui::balance::value(&disputer_bond);
            if (total > 0) {
                let winner_coin = coin::from_balance(disputer_bond, ctx);
                transfer::public_transfer(winner_coin, disputer);
                oracle_events::emit_bond_slashed(
                    request_id,
                    proposer,
                    disputer,
                    proposer_amount,
                );
            } else {
                sui::balance::destroy_zero(disputer_bond);
            };
        };

        oracle_events::emit_resolution_finalized(
            request_id,
            request_market_id,
            final_outcome,
            admin,
            now,
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 6: PRICE FEED RESOLUTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Resolve a market using verified price data
    /// This is a simplified version - real implementation would integrate with Pyth/Switchboard
    /// For now, this allows admin to submit verified price data
    public fun resolve_by_price_feed(
        registry: &mut OracleRegistry,
        market: &mut Market,
        admin_cap: &OracleAdminCap,
        price: u64,
        threshold: u64,
        comparison: u8,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        let admin = ctx.sender();
        let now = clock.timestamp_ms();

        // Validate admin
        assert!(admin == oracle_types::registry_admin(registry), E_NOT_ADMIN);
        let _ = admin_cap;

        // Validate market is oracle type
        assert!(
            market_types::resolution_type(market) == market_types::resolution_oracle(),
            E_MARKET_NOT_ORACLE_TYPE
        );

        // Validate trading has ended
        assert!(market_types::is_trading_ended(market), E_TRADING_NOT_ENDED);

        // Validate market not already resolved
        assert!(
            market_types::winning_outcome(market) == market_types::outcome_unset(),
            E_MARKET_ALREADY_RESOLVED
        );

        // Validate resolution time has passed
        assert!(now >= market_types::resolution_time(market), E_TOO_EARLY);

        // Determine outcome based on price comparison
        let outcome = if (comparison == oracle_types::compare_greater()) {
            if (price > threshold) { oracle_types::outcome_yes() } else { oracle_types::outcome_no() }
        } else if (comparison == oracle_types::compare_less()) {
            if (price < threshold) { oracle_types::outcome_yes() } else { oracle_types::outcome_no() }
        } else if (comparison == oracle_types::compare_equal()) {
            if (price == threshold) { oracle_types::outcome_yes() } else { oracle_types::outcome_no() }
        } else if (comparison == oracle_types::compare_greater_or_equal()) {
            if (price >= threshold) { oracle_types::outcome_yes() } else { oracle_types::outcome_no() }
        } else {
            // compare_less_or_equal
            if (price <= threshold) { oracle_types::outcome_yes() } else { oracle_types::outcome_no() }
        };

        // Resolve market directly (no dispute period for price feeds)
        market_operations::resolve_by_oracle(market, outcome, clock);

        // Remove from active requests if one exists
        let market_id = market_types::market_id(market);
        if (oracle_types::registry_has_active_request(registry, market_id)) {
            oracle_types::remove_active_request(registry, market_id);
        };

        oracle_events::emit_resolution_finalized(
            0, // No request ID for direct price feed resolution
            market_id,
            outcome,
            admin,
            now,
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 7: EMERGENCY OVERRIDE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emergency override for stuck or failed oracle requests
    /// Admin can force resolve and return all bonds
    public fun emergency_override(
        registry: &mut OracleRegistry,
        request: &mut ResolutionRequest,
        market: &mut Market,
        admin_cap: &OracleAdminCap,
        final_outcome: u8,
        reason: String,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let admin = ctx.sender();
        let now = clock.timestamp_ms();

        // Validate admin
        assert!(admin == oracle_types::registry_admin(registry), E_NOT_ADMIN);
        let _ = admin_cap;

        // Validate outcome is valid (YES or NO)
        assert!(
            final_outcome == oracle_types::outcome_yes() ||
            final_outcome == oracle_types::outcome_no(),
            E_INVALID_OUTCOME
        );

        // Validate market matches request
        let request_market_id = oracle_types::request_market_id(request);
        assert!(market_types::market_id(market) == request_market_id, E_MARKET_MISMATCH);

        // For disputed requests, require 24 hours to have passed since dispute
        if (oracle_types::request_is_disputed(request)) {
            let dispute_deadline = oracle_types::request_dispute_deadline(request);
            assert!(
                now >= dispute_deadline + EMERGENCY_OVERRIDE_DELAY,
                E_INSUFFICIENT_TIME_PASSED
            );
        };

        // Finalize request
        oracle_types::set_final_outcome(request, final_outcome, now);

        // Resolve market
        market_operations::resolve_by_oracle(market, final_outcome, clock);

        // Remove from active requests
        oracle_types::remove_active_request(registry, request_market_id);

        let request_id = oracle_types::request_id(request);

        // Return all bonds to original depositors (no penalty in emergency)
        let requester = oracle_types::request_requester(request);
        let requester_bond = oracle_types::withdraw_requester_bond(request);
        let requester_amount = sui::balance::value(&requester_bond);
        if (requester_amount > 0) {
            let requester_coin = coin::from_balance(requester_bond, ctx);
            transfer::public_transfer(requester_coin, requester);
            oracle_events::emit_bond_distributed(
                request_id,
                requester,
                requester_amount,
                string::utf8(b"emergency_refund"),
            );
        } else {
            sui::balance::destroy_zero(requester_bond);
        };

        let proposer = oracle_types::request_proposer(request);
        let proposer_bond = oracle_types::withdraw_proposer_bond(request);
        let proposer_amount = sui::balance::value(&proposer_bond);
        if (proposer_amount > 0) {
            let proposer_coin = coin::from_balance(proposer_bond, ctx);
            transfer::public_transfer(proposer_coin, proposer);
            oracle_events::emit_bond_distributed(
                request_id,
                proposer,
                proposer_amount,
                string::utf8(b"emergency_refund"),
            );
        } else {
            sui::balance::destroy_zero(proposer_bond);
        };

        let disputer = oracle_types::request_disputer(request);
        let disputer_bond = oracle_types::withdraw_disputer_bond(request);
        let disputer_amount = sui::balance::value(&disputer_bond);
        if (disputer_amount > 0) {
            let disputer_coin = coin::from_balance(disputer_bond, ctx);
            transfer::public_transfer(disputer_coin, disputer);
            oracle_events::emit_bond_distributed(
                request_id,
                disputer,
                disputer_amount,
                string::utf8(b"emergency_refund"),
            );
        } else {
            sui::balance::destroy_zero(disputer_bond);
        };

        oracle_events::emit_emergency_override(
            request_id,
            request_market_id,
            final_outcome,
            admin,
            reason,
        );
    }

    /// Emergency void - void a market through emergency override
    /// Returns all bonds without resolving to a specific outcome
    public fun emergency_void(
        registry: &mut OracleRegistry,
        request: &mut ResolutionRequest,
        market: &mut Market,
        admin_cap: &OracleAdminCap,
        reason: String,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let admin = ctx.sender();

        // Validate admin
        assert!(admin == oracle_types::registry_admin(registry), E_NOT_ADMIN);
        let _ = admin_cap;

        // Validate market matches request
        let request_market_id = oracle_types::request_market_id(request);
        assert!(market_types::market_id(market) == request_market_id, E_MARKET_MISMATCH);

        // Cancel request
        oracle_types::set_request_status(request, oracle_types::status_cancelled());

        // Void market through market operations
        market_operations::void_by_oracle(market, reason, clock);

        // Remove from active requests
        oracle_types::remove_active_request(registry, request_market_id);

        let request_id = oracle_types::request_id(request);

        // Return all bonds to original depositors
        let requester = oracle_types::request_requester(request);
        let requester_bond = oracle_types::withdraw_requester_bond(request);
        let requester_amount = sui::balance::value(&requester_bond);
        if (requester_amount > 0) {
            let requester_coin = coin::from_balance(requester_bond, ctx);
            transfer::public_transfer(requester_coin, requester);
            oracle_events::emit_bond_distributed(
                request_id,
                requester,
                requester_amount,
                string::utf8(b"void_refund"),
            );
        } else {
            sui::balance::destroy_zero(requester_bond);
        };

        let proposer = oracle_types::request_proposer(request);
        let proposer_bond = oracle_types::withdraw_proposer_bond(request);
        let proposer_amount = sui::balance::value(&proposer_bond);
        if (proposer_amount > 0) {
            let proposer_coin = coin::from_balance(proposer_bond, ctx);
            transfer::public_transfer(proposer_coin, proposer);
            oracle_events::emit_bond_distributed(
                request_id,
                proposer,
                proposer_amount,
                string::utf8(b"void_refund"),
            );
        } else {
            sui::balance::destroy_zero(proposer_bond);
        };

        let disputer = oracle_types::request_disputer(request);
        let disputer_bond = oracle_types::withdraw_disputer_bond(request);
        let disputer_amount = sui::balance::value(&disputer_bond);
        if (disputer_amount > 0) {
            let disputer_coin = coin::from_balance(disputer_bond, ctx);
            transfer::public_transfer(disputer_coin, disputer);
            oracle_events::emit_bond_distributed(
                request_id,
                disputer,
                disputer_amount,
                string::utf8(b"void_refund"),
            );
        } else {
            sui::balance::destroy_zero(disputer_bond);
        };

        oracle_events::emit_resolution_cancelled(
            request_id,
            request_market_id,
            reason,
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // QUERY FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get registry info
    public fun get_registry_info(registry: &OracleRegistry): (address, u64, u64, u64) {
        (
            oracle_types::registry_admin(registry),
            oracle_types::registry_default_bond(registry),
            oracle_types::registry_default_dispute_window(registry),
            oracle_types::registry_total_requests(registry),
        )
    }

    /// Get provider info
    public fun get_provider_info(
        registry: &OracleRegistry,
        name: String,
    ): (u8, bool, u64, u64, u64) {
        assert!(oracle_types::registry_has_provider(registry, name), E_PROVIDER_NOT_FOUND);
        let provider = oracle_types::registry_get_provider(registry, name);
        (
            oracle_types::provider_type(provider),
            oracle_types::provider_is_active(provider),
            oracle_types::provider_min_bond(provider),
            oracle_types::provider_dispute_window(provider),
            oracle_types::provider_total_resolutions(provider),
        )
    }

    /// Get request info
    public fun get_request_info(request: &ResolutionRequest): (
        u64,  // request_id
        u64,  // market_id
        address,  // requester
        u64,  // requester_bond
        u8,   // status
        u8,   // proposed_outcome
        address,  // proposer
        u64,  // proposer_bond
        u64,  // dispute_deadline
    ) {
        (
            oracle_types::request_id(request),
            oracle_types::request_market_id(request),
            oracle_types::request_requester(request),
            oracle_types::request_requester_bond_value(request),
            oracle_types::request_status(request),
            oracle_types::request_proposed_outcome(request),
            oracle_types::request_proposer(request),
            oracle_types::request_proposer_bond_value(request),
            oracle_types::request_dispute_deadline(request),
        )
    }

    /// Check if market has active resolution request
    public fun has_active_request(registry: &OracleRegistry, market_id: u64): bool {
        oracle_types::registry_has_active_request(registry, market_id)
    }

    /// Check if provider exists and is active
    public fun is_provider_active(registry: &OracleRegistry, name: String): bool {
        if (!oracle_types::registry_has_provider(registry, name)) {
            return false
        };
        let provider = oracle_types::registry_get_provider(registry, name);
        oracle_types::provider_is_active(provider)
    }
}
