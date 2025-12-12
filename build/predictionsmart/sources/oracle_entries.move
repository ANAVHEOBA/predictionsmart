/// Oracle Entries - Public entry functions for oracle module
///
/// This module provides entry points for oracle operations.
module predictionsmart::oracle_entries {
    use std::string::String;
    use sui::coin::Coin;
    use sui::sui::SUI;
    use sui::clock::Clock;

    use predictionsmart::oracle_types::{
        Self,
        OracleRegistry,
        OracleAdminCap,
        ResolutionRequest,
    };
    use predictionsmart::oracle_operations;
    use predictionsmart::market_types::Market;

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: ORACLE REGISTRY - ENTRY FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Initialize the oracle registry (one-time setup)
    entry fun initialize_registry(ctx: &mut TxContext) {
        let (registry, admin_cap) = oracle_operations::initialize_registry(ctx);
        oracle_types::share_oracle_registry(registry);
        oracle_types::transfer_admin_cap(admin_cap, ctx.sender());
    }

    /// Register a new oracle provider
    entry fun register_provider(
        registry: &mut OracleRegistry,
        admin_cap: &OracleAdminCap,
        name: String,
        provider_type: u8,
        min_bond: u64,
        dispute_window: u64,
        ctx: &TxContext,
    ) {
        oracle_operations::register_provider(
            registry,
            admin_cap,
            name,
            provider_type,
            min_bond,
            dispute_window,
            ctx,
        );
    }

    /// Update an existing provider's configuration
    entry fun update_provider(
        registry: &mut OracleRegistry,
        admin_cap: &OracleAdminCap,
        name: String,
        min_bond: u64,
        dispute_window: u64,
        is_active: bool,
        ctx: &TxContext,
    ) {
        oracle_operations::update_provider(
            registry,
            admin_cap,
            name,
            min_bond,
            dispute_window,
            is_active,
            ctx,
        );
    }

    /// Deactivate a provider
    entry fun deactivate_provider(
        registry: &mut OracleRegistry,
        admin_cap: &OracleAdminCap,
        name: String,
        ctx: &TxContext,
    ) {
        oracle_operations::deactivate_provider(
            registry,
            admin_cap,
            name,
            ctx,
        );
    }

    /// Set the default bond amount
    entry fun set_default_bond(
        registry: &mut OracleRegistry,
        admin_cap: &OracleAdminCap,
        new_bond: u64,
        ctx: &TxContext,
    ) {
        oracle_operations::set_default_bond(
            registry,
            admin_cap,
            new_bond,
            ctx,
        );
    }

    /// Set the default dispute window
    entry fun set_default_dispute_window(
        registry: &mut OracleRegistry,
        admin_cap: &OracleAdminCap,
        new_window: u64,
        ctx: &TxContext,
    ) {
        oracle_operations::set_default_dispute_window(
            registry,
            admin_cap,
            new_window,
            ctx,
        );
    }

    /// Transfer registry admin
    entry fun transfer_registry_admin(
        registry: &mut OracleRegistry,
        admin_cap: &OracleAdminCap,
        new_admin: address,
        ctx: &TxContext,
    ) {
        oracle_operations::transfer_registry_admin(
            registry,
            admin_cap,
            new_admin,
            ctx,
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 2: REQUEST RESOLUTION - ENTRY FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Request oracle resolution for a market
    entry fun request_resolution(
        registry: &mut OracleRegistry,
        market: &Market,
        bond: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let request = oracle_operations::request_resolution(
            registry,
            market,
            bond,
            clock,
            ctx,
        );
        oracle_types::share_resolution_request(request);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: PROPOSE OUTCOME - ENTRY FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Propose an outcome for a resolution request
    entry fun propose_outcome(
        registry: &OracleRegistry,
        request: &mut ResolutionRequest,
        proposed_outcome: u8,
        bond: Coin<SUI>,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        oracle_operations::propose_outcome(
            registry,
            request,
            proposed_outcome,
            bond,
            clock,
            ctx,
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 4: DISPUTE OUTCOME - ENTRY FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Dispute a proposed outcome
    entry fun dispute_outcome(
        registry: &OracleRegistry,
        request: &mut ResolutionRequest,
        bond: Coin<SUI>,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        oracle_operations::dispute_outcome(
            registry,
            request,
            bond,
            clock,
            ctx,
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 5: FINALIZE RESOLUTION - ENTRY FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Finalize undisputed resolution (anyone can call after dispute window)
    entry fun finalize_undisputed(
        registry: &mut OracleRegistry,
        request: &mut ResolutionRequest,
        market: &mut Market,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        oracle_operations::finalize_undisputed(
            registry,
            request,
            market,
            clock,
            ctx,
        );
    }

    /// Finalize disputed resolution (admin only)
    entry fun finalize_disputed(
        registry: &mut OracleRegistry,
        request: &mut ResolutionRequest,
        market: &mut Market,
        admin_cap: &OracleAdminCap,
        final_outcome: u8,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        oracle_operations::finalize_disputed(
            registry,
            request,
            market,
            admin_cap,
            final_outcome,
            clock,
            ctx,
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 6: PRICE FEED RESOLUTION - ENTRY FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Resolve market using price feed data (manual price submission)
    entry fun resolve_by_price_feed(
        registry: &mut OracleRegistry,
        market: &mut Market,
        admin_cap: &OracleAdminCap,
        price: u64,
        threshold: u64,
        comparison: u8,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        oracle_operations::resolve_by_price_feed(
            registry,
            market,
            admin_cap,
            price,
            threshold,
            comparison,
            clock,
            ctx,
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 6B: PYTH PRICE FEED RESOLUTION
    // ═══════════════════════════════════════════════════════════════════════════

    // Note: Pyth integration requires passing the PriceInfoObject
    // The actual Pyth resolution will be added once dependencies are resolved
    // Usage: Call pyth_adapter::resolve_price_condition() and pass result to resolve_by_price_feed

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 6C: SWITCHBOARD PRICE FEED RESOLUTION
    // ═══════════════════════════════════════════════════════════════════════════

    // Note: Switchboard integration requires passing the Aggregator object
    // The actual Switchboard resolution will be added once dependencies are resolved
    // Usage: Call switchboard_adapter::resolve_price_condition() and pass result to resolve_by_price_feed

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 7: EMERGENCY OVERRIDE - ENTRY FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emergency override for stuck requests
    entry fun emergency_override(
        registry: &mut OracleRegistry,
        request: &mut ResolutionRequest,
        market: &mut Market,
        admin_cap: &OracleAdminCap,
        final_outcome: u8,
        reason: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        oracle_operations::emergency_override(
            registry,
            request,
            market,
            admin_cap,
            final_outcome,
            std::string::utf8(reason),
            clock,
            ctx,
        );
    }

    /// Emergency void market
    entry fun emergency_void(
        registry: &mut OracleRegistry,
        request: &mut ResolutionRequest,
        market: &mut Market,
        admin_cap: &OracleAdminCap,
        reason: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        oracle_operations::emergency_void(
            registry,
            request,
            market,
            admin_cap,
            std::string::utf8(reason),
            clock,
            ctx,
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test_only]
    public fun initialize_registry_for_testing(
        ctx: &mut TxContext,
    ): (OracleRegistry, OracleAdminCap) {
        oracle_operations::initialize_registry(ctx)
    }

    #[test_only]
    public fun request_resolution_for_testing(
        registry: &mut OracleRegistry,
        market: &Market,
        bond: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): ResolutionRequest {
        oracle_operations::request_resolution(registry, market, bond, clock, ctx)
    }

    #[test_only]
    public fun propose_outcome_for_testing(
        registry: &OracleRegistry,
        request: &mut ResolutionRequest,
        proposed_outcome: u8,
        bond: Coin<SUI>,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        oracle_operations::propose_outcome(
            registry,
            request,
            proposed_outcome,
            bond,
            clock,
            ctx,
        );
    }

    #[test_only]
    public fun dispute_outcome_for_testing(
        registry: &OracleRegistry,
        request: &mut ResolutionRequest,
        bond: Coin<SUI>,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        oracle_operations::dispute_outcome(
            registry,
            request,
            bond,
            clock,
            ctx,
        );
    }

    #[test_only]
    public fun finalize_undisputed_for_testing(
        registry: &mut OracleRegistry,
        request: &mut ResolutionRequest,
        market: &mut Market,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        oracle_operations::finalize_undisputed(
            registry,
            request,
            market,
            clock,
            ctx,
        );
    }

    #[test_only]
    public fun finalize_disputed_for_testing(
        registry: &mut OracleRegistry,
        request: &mut ResolutionRequest,
        market: &mut Market,
        admin_cap: &OracleAdminCap,
        final_outcome: u8,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        oracle_operations::finalize_disputed(
            registry,
            request,
            market,
            admin_cap,
            final_outcome,
            clock,
            ctx,
        );
    }

    #[test_only]
    public fun resolve_by_price_feed_for_testing(
        registry: &mut OracleRegistry,
        market: &mut Market,
        admin_cap: &OracleAdminCap,
        price: u64,
        threshold: u64,
        comparison: u8,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        oracle_operations::resolve_by_price_feed(
            registry,
            market,
            admin_cap,
            price,
            threshold,
            comparison,
            clock,
            ctx,
        );
    }

    #[test_only]
    public fun emergency_override_for_testing(
        registry: &mut OracleRegistry,
        request: &mut ResolutionRequest,
        market: &mut Market,
        admin_cap: &OracleAdminCap,
        final_outcome: u8,
        reason: std::string::String,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        oracle_operations::emergency_override(
            registry,
            request,
            market,
            admin_cap,
            final_outcome,
            reason,
            clock,
            ctx,
        );
    }

    #[test_only]
    public fun emergency_void_for_testing(
        registry: &mut OracleRegistry,
        request: &mut ResolutionRequest,
        market: &mut Market,
        admin_cap: &OracleAdminCap,
        reason: std::string::String,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        oracle_operations::emergency_void(
            registry,
            request,
            market,
            admin_cap,
            reason,
            clock,
            ctx,
        );
    }
}
