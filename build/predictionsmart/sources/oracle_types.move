/// Oracle Types - Structs, constants, getters, setters, constructors
///
/// This module defines all data structures for the oracle system.
module predictionsmart::oracle_types {
    use std::string::String;
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    // --- Request Status ---
    const STATUS_PENDING: u8 = 0;
    const STATUS_PROPOSED: u8 = 1;
    const STATUS_DISPUTED: u8 = 2;
    const STATUS_FINALIZED: u8 = 3;
    const STATUS_CANCELLED: u8 = 4;

    // --- Oracle Provider Types ---
    const PROVIDER_OPTIMISTIC: u8 = 0;
    const PROVIDER_PRICE_FEED: u8 = 1;
    const PROVIDER_API: u8 = 2;

    // --- Price Comparison Types ---
    const COMPARE_GREATER: u8 = 0;
    const COMPARE_LESS: u8 = 1;
    const COMPARE_EQUAL: u8 = 2;
    const COMPARE_GREATER_OR_EQUAL: u8 = 3;
    const COMPARE_LESS_OR_EQUAL: u8 = 4;

    // --- Outcome (matches market module) ---
    const OUTCOME_YES: u8 = 0;
    const OUTCOME_NO: u8 = 1;
    const OUTCOME_UNSET: u8 = 255;

    // --- Defaults ---
    const DEFAULT_BOND: u64 = 10_000_000;           // 0.01 SUI
    const DEFAULT_DISPUTE_WINDOW: u64 = 7_200_000;  // 2 hours in ms
    const MIN_BOND: u64 = 1_000_000;                // 0.001 SUI
    const MAX_DISPUTE_WINDOW: u64 = 86_400_000;     // 24 hours in ms

    // ═══════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// OracleRegistry - Manages oracle providers and configuration
    public struct OracleRegistry has key {
        id: UID,
        /// Registry admin
        admin: address,
        /// Registered oracle providers (name -> provider)
        providers: Table<String, OracleProvider>,
        /// Default bond amount for requests
        default_bond: u64,
        /// Default dispute window duration (ms)
        default_dispute_window: u64,
        /// Total resolution requests created
        total_requests: u64,
        /// Market ID -> Request ID mapping (one active request per market)
        active_requests: Table<u64, u64>,
    }

    /// OracleProvider - Configuration for an oracle provider
    public struct OracleProvider has store, drop, copy {
        /// Provider identifier
        name: String,
        /// Type of oracle (optimistic, price feed, api)
        provider_type: u8,
        /// Whether provider can accept requests
        is_active: bool,
        /// Minimum bond for this provider
        min_bond: u64,
        /// Dispute window for this provider (ms)
        dispute_window: u64,
        /// Total successful resolutions
        total_resolutions: u64,
    }

    /// ResolutionRequest - A request to resolve a market via oracle
    public struct ResolutionRequest has key, store {
        id: UID,
        /// Sequential request number
        request_id: u64,
        /// Target market ID
        market_id: u64,
        /// Oracle source identifier (e.g., "pyth:BTC/USD")
        oracle_source: String,
        /// Who requested resolution
        requester: address,
        /// Requester's bond
        requester_bond: Balance<SUI>,
        /// When resolution was requested
        request_time: u64,
        /// Current request status
        status: u8,
        /// Proposed outcome (YES/NO)
        proposed_outcome: u8,
        /// Who proposed the outcome
        proposer: address,
        /// Proposer's bond
        proposer_bond: Balance<SUI>,
        /// When outcome was proposed
        proposal_time: u64,
        /// Deadline for disputes
        dispute_deadline: u64,
        /// Who disputed (if any)
        disputer: address,
        /// Disputer's bond
        disputer_bond: Balance<SUI>,
        /// Final verified outcome
        final_outcome: u8,
        /// When request was finalized
        resolved_time: u64,
    }

    /// AdminCap - Capability for oracle admin operations
    public struct OracleAdminCap has key, store {
        id: UID,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANT GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    // --- Status ---
    public fun status_pending(): u8 { STATUS_PENDING }
    public fun status_proposed(): u8 { STATUS_PROPOSED }
    public fun status_disputed(): u8 { STATUS_DISPUTED }
    public fun status_finalized(): u8 { STATUS_FINALIZED }
    public fun status_cancelled(): u8 { STATUS_CANCELLED }

    // --- Provider Types ---
    public fun provider_optimistic(): u8 { PROVIDER_OPTIMISTIC }
    public fun provider_price_feed(): u8 { PROVIDER_PRICE_FEED }
    public fun provider_api(): u8 { PROVIDER_API }

    // --- Comparison Types ---
    public fun compare_greater(): u8 { COMPARE_GREATER }
    public fun compare_less(): u8 { COMPARE_LESS }
    public fun compare_equal(): u8 { COMPARE_EQUAL }
    public fun compare_greater_or_equal(): u8 { COMPARE_GREATER_OR_EQUAL }
    public fun compare_less_or_equal(): u8 { COMPARE_LESS_OR_EQUAL }

    // --- Outcomes ---
    public fun outcome_yes(): u8 { OUTCOME_YES }
    public fun outcome_no(): u8 { OUTCOME_NO }
    public fun outcome_unset(): u8 { OUTCOME_UNSET }

    // --- Defaults ---
    public fun default_bond(): u64 { DEFAULT_BOND }
    public fun default_dispute_window(): u64 { DEFAULT_DISPUTE_WINDOW }
    public fun min_bond(): u64 { MIN_BOND }
    public fun max_dispute_window(): u64 { MAX_DISPUTE_WINDOW }

    // ═══════════════════════════════════════════════════════════════════════════
    // ORACLE REGISTRY GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    public fun registry_admin(r: &OracleRegistry): address { r.admin }
    public fun registry_default_bond(r: &OracleRegistry): u64 { r.default_bond }
    public fun registry_default_dispute_window(r: &OracleRegistry): u64 { r.default_dispute_window }
    public fun registry_total_requests(r: &OracleRegistry): u64 { r.total_requests }

    /// Check if a provider exists
    public fun registry_has_provider(r: &OracleRegistry, name: String): bool {
        table::contains(&r.providers, name)
    }

    /// Get provider by name
    public fun registry_get_provider(r: &OracleRegistry, name: String): &OracleProvider {
        table::borrow(&r.providers, name)
    }

    /// Check if market has active request
    public fun registry_has_active_request(r: &OracleRegistry, market_id: u64): bool {
        table::contains(&r.active_requests, market_id)
    }

    /// Get active request ID for market
    public fun registry_get_active_request(r: &OracleRegistry, market_id: u64): u64 {
        *table::borrow(&r.active_requests, market_id)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ORACLE PROVIDER GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    public fun provider_name(p: &OracleProvider): String { p.name }
    public fun provider_type(p: &OracleProvider): u8 { p.provider_type }
    public fun provider_is_active(p: &OracleProvider): bool { p.is_active }
    public fun provider_min_bond(p: &OracleProvider): u64 { p.min_bond }
    public fun provider_dispute_window(p: &OracleProvider): u64 { p.dispute_window }
    public fun provider_total_resolutions(p: &OracleProvider): u64 { p.total_resolutions }

    // ═══════════════════════════════════════════════════════════════════════════
    // RESOLUTION REQUEST GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    public fun request_id(r: &ResolutionRequest): u64 { r.request_id }
    public fun request_market_id(r: &ResolutionRequest): u64 { r.market_id }
    public fun request_oracle_source(r: &ResolutionRequest): String { r.oracle_source }
    public fun request_requester(r: &ResolutionRequest): address { r.requester }
    public fun request_requester_bond_value(r: &ResolutionRequest): u64 { balance::value(&r.requester_bond) }
    public fun request_time(r: &ResolutionRequest): u64 { r.request_time }
    public fun request_status(r: &ResolutionRequest): u8 { r.status }
    public fun request_proposed_outcome(r: &ResolutionRequest): u8 { r.proposed_outcome }
    public fun request_proposer(r: &ResolutionRequest): address { r.proposer }
    public fun request_proposer_bond_value(r: &ResolutionRequest): u64 { balance::value(&r.proposer_bond) }
    public fun request_proposal_time(r: &ResolutionRequest): u64 { r.proposal_time }
    public fun request_dispute_deadline(r: &ResolutionRequest): u64 { r.dispute_deadline }
    public fun request_disputer(r: &ResolutionRequest): address { r.disputer }
    public fun request_disputer_bond_value(r: &ResolutionRequest): u64 { balance::value(&r.disputer_bond) }
    public fun request_final_outcome(r: &ResolutionRequest): u8 { r.final_outcome }
    public fun request_resolved_time(r: &ResolutionRequest): u64 { r.resolved_time }

    // --- Status checks ---
    public fun request_is_pending(r: &ResolutionRequest): bool { r.status == STATUS_PENDING }
    public fun request_is_proposed(r: &ResolutionRequest): bool { r.status == STATUS_PROPOSED }
    public fun request_is_disputed(r: &ResolutionRequest): bool { r.status == STATUS_DISPUTED }
    public fun request_is_finalized(r: &ResolutionRequest): bool { r.status == STATUS_FINALIZED }
    public fun request_is_cancelled(r: &ResolutionRequest): bool { r.status == STATUS_CANCELLED }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTORS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a new OracleRegistry
    public(package) fun new_oracle_registry(
        admin: address,
        ctx: &mut TxContext,
    ): OracleRegistry {
        OracleRegistry {
            id: object::new(ctx),
            admin,
            providers: table::new(ctx),
            default_bond: DEFAULT_BOND,
            default_dispute_window: DEFAULT_DISPUTE_WINDOW,
            total_requests: 0,
            active_requests: table::new(ctx),
        }
    }

    /// Create a new OracleProvider
    public(package) fun new_oracle_provider(
        name: String,
        provider_type: u8,
        min_bond: u64,
        dispute_window: u64,
    ): OracleProvider {
        OracleProvider {
            name,
            provider_type,
            is_active: true,
            min_bond,
            dispute_window,
            total_resolutions: 0,
        }
    }

    /// Create a new ResolutionRequest
    public(package) fun new_resolution_request(
        request_id: u64,
        market_id: u64,
        oracle_source: String,
        requester: address,
        requester_bond: Balance<SUI>,
        request_time: u64,
        ctx: &mut TxContext,
    ): ResolutionRequest {
        ResolutionRequest {
            id: object::new(ctx),
            request_id,
            market_id,
            oracle_source,
            requester,
            requester_bond,
            request_time,
            status: STATUS_PENDING,
            proposed_outcome: OUTCOME_UNSET,
            proposer: @0x0,
            proposer_bond: balance::zero(),
            proposal_time: 0,
            dispute_deadline: 0,
            disputer: @0x0,
            disputer_bond: balance::zero(),
            final_outcome: OUTCOME_UNSET,
            resolved_time: 0,
        }
    }

    /// Create admin capability
    public(package) fun new_oracle_admin_cap(ctx: &mut TxContext): OracleAdminCap {
        OracleAdminCap {
            id: object::new(ctx),
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ORACLE REGISTRY SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Set registry admin
    public(package) fun set_registry_admin(r: &mut OracleRegistry, new_admin: address) {
        r.admin = new_admin;
    }

    /// Set default bond
    public(package) fun set_default_bond(r: &mut OracleRegistry, bond: u64) {
        r.default_bond = bond;
    }

    /// Set default dispute window
    public(package) fun set_default_dispute_window(r: &mut OracleRegistry, window: u64) {
        r.default_dispute_window = window;
    }

    /// Increment total requests
    public(package) fun increment_total_requests(r: &mut OracleRegistry): u64 {
        r.total_requests = r.total_requests + 1;
        r.total_requests
    }

    /// Add provider to registry
    public(package) fun add_provider(r: &mut OracleRegistry, provider: OracleProvider) {
        let name = provider.name;
        table::add(&mut r.providers, name, provider);
    }

    /// Get mutable provider reference
    public(package) fun get_provider_mut(r: &mut OracleRegistry, name: String): &mut OracleProvider {
        table::borrow_mut(&mut r.providers, name)
    }

    /// Remove provider from registry
    public(package) fun remove_provider(r: &mut OracleRegistry, name: String): OracleProvider {
        table::remove(&mut r.providers, name)
    }

    /// Register active request for market
    public(package) fun register_active_request(r: &mut OracleRegistry, market_id: u64, request_id: u64) {
        table::add(&mut r.active_requests, market_id, request_id);
    }

    /// Remove active request for market
    public(package) fun remove_active_request(r: &mut OracleRegistry, market_id: u64) {
        table::remove(&mut r.active_requests, market_id);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ORACLE PROVIDER SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Set provider active status
    public(package) fun set_provider_active(p: &mut OracleProvider, is_active: bool) {
        p.is_active = is_active;
    }

    /// Set provider min bond
    public(package) fun set_provider_min_bond(p: &mut OracleProvider, min_bond: u64) {
        p.min_bond = min_bond;
    }

    /// Set provider dispute window
    public(package) fun set_provider_dispute_window(p: &mut OracleProvider, dispute_window: u64) {
        p.dispute_window = dispute_window;
    }

    /// Increment provider total resolutions
    public(package) fun increment_provider_resolutions(p: &mut OracleProvider) {
        p.total_resolutions = p.total_resolutions + 1;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // RESOLUTION REQUEST SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Set request status
    public(package) fun set_request_status(r: &mut ResolutionRequest, status: u8) {
        r.status = status;
    }

    /// Set proposed outcome
    public(package) fun set_proposed_outcome(
        r: &mut ResolutionRequest,
        outcome: u8,
        proposer: address,
        bond: Balance<SUI>,
        proposal_time: u64,
        dispute_deadline: u64,
    ) {
        r.proposed_outcome = outcome;
        r.proposer = proposer;
        balance::join(&mut r.proposer_bond, bond);
        r.proposal_time = proposal_time;
        r.dispute_deadline = dispute_deadline;
        r.status = STATUS_PROPOSED;
    }

    /// Set disputer
    public(package) fun set_disputer(
        r: &mut ResolutionRequest,
        disputer: address,
        bond: Balance<SUI>,
    ) {
        r.disputer = disputer;
        balance::join(&mut r.disputer_bond, bond);
        r.status = STATUS_DISPUTED;
    }

    /// Set final outcome
    public(package) fun set_final_outcome(
        r: &mut ResolutionRequest,
        outcome: u8,
        resolved_time: u64,
    ) {
        r.final_outcome = outcome;
        r.resolved_time = resolved_time;
        r.status = STATUS_FINALIZED;
    }

    /// Withdraw requester bond
    public(package) fun withdraw_requester_bond(r: &mut ResolutionRequest): Balance<SUI> {
        let amount = balance::value(&r.requester_bond);
        balance::split(&mut r.requester_bond, amount)
    }

    /// Withdraw proposer bond
    public(package) fun withdraw_proposer_bond(r: &mut ResolutionRequest): Balance<SUI> {
        let amount = balance::value(&r.proposer_bond);
        balance::split(&mut r.proposer_bond, amount)
    }

    /// Withdraw disputer bond
    public(package) fun withdraw_disputer_bond(r: &mut ResolutionRequest): Balance<SUI> {
        let amount = balance::value(&r.disputer_bond);
        balance::split(&mut r.disputer_bond, amount)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TRANSFER FUNCTIONS (must be in defining module)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Share oracle registry globally
    #[allow(lint(share_owned))]
    public(package) fun share_oracle_registry(registry: OracleRegistry) {
        transfer::share_object(registry);
    }

    /// Share resolution request globally
    #[allow(lint(share_owned, custom_state_change))]
    public(package) fun share_resolution_request(request: ResolutionRequest) {
        transfer::share_object(request);
    }

    /// Transfer admin cap to recipient
    #[allow(lint(custom_state_change))]
    public(package) fun transfer_admin_cap(cap: OracleAdminCap, recipient: address) {
        transfer::transfer(cap, recipient);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test_only]
    public fun destroy_oracle_registry_for_testing(registry: OracleRegistry) {
        let OracleRegistry {
            id,
            admin: _,
            providers,
            default_bond: _,
            default_dispute_window: _,
            total_requests: _,
            active_requests,
        } = registry;
        table::destroy_empty(providers);
        table::destroy_empty(active_requests);
        object::delete(id);
    }

    #[test_only]
    public fun destroy_resolution_request_for_testing(request: ResolutionRequest) {
        let ResolutionRequest {
            id,
            request_id: _,
            market_id: _,
            oracle_source: _,
            requester: _,
            requester_bond,
            request_time: _,
            status: _,
            proposed_outcome: _,
            proposer: _,
            proposer_bond,
            proposal_time: _,
            dispute_deadline: _,
            disputer: _,
            disputer_bond,
            final_outcome: _,
            resolved_time: _,
        } = request;
        balance::destroy_for_testing(requester_bond);
        balance::destroy_for_testing(proposer_bond);
        balance::destroy_for_testing(disputer_bond);
        object::delete(id);
    }

    #[test_only]
    public fun destroy_oracle_admin_cap_for_testing(cap: OracleAdminCap) {
        let OracleAdminCap { id } = cap;
        object::delete(id);
    }

    #[test_only]
    public fun remove_provider_for_testing(r: &mut OracleRegistry, name: String) {
        if (table::contains(&r.providers, name)) {
            table::remove(&mut r.providers, name);
        };
    }

    #[test_only]
    public fun remove_active_request_for_testing(r: &mut OracleRegistry, market_id: u64) {
        if (table::contains(&r.active_requests, market_id)) {
            table::remove(&mut r.active_requests, market_id);
        };
    }
}
