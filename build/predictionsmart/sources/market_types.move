/// Market Types - Structs, constants, getters, setters, constructors
///
/// This module defines all data structures for binary markets.
/// Other modules use public(package) functions to interact with these types.
module predictionsmart::market_types {
    use std::string::String;

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    // --- Status ---
    const STATUS_OPEN: u8 = 0;
    const STATUS_TRADING_ENDED: u8 = 1;
    const STATUS_RESOLVED: u8 = 2;
    const STATUS_VOIDED: u8 = 3;

    // --- Outcome ---
    const OUTCOME_YES: u8 = 0;
    const OUTCOME_NO: u8 = 1;
    const OUTCOME_VOID: u8 = 2;
    const OUTCOME_UNSET: u8 = 255;

    // --- Resolution Type ---
    const RESOLUTION_ADMIN: u8 = 0;
    const RESOLUTION_ORACLE: u8 = 1;

    // --- Validation Limits ---
    const MIN_QUESTION_LENGTH: u64 = 10;
    const MAX_QUESTION_LENGTH: u64 = 500;
    const MAX_FEE_BPS: u16 = 1000;  // 10%
    const MIN_DURATION_MS: u64 = 3600000;  // 1 hour
    const DEFAULT_CREATION_FEE: u64 = 10_000_000;  // 0.01 SUI

    // ═══════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Binary Market - A Yes/No prediction market
    public struct Market has key, store {
        id: UID,

        // Identity
        market_id: u64,

        // Content
        question: String,
        description: String,
        image_url: String,
        category: String,
        tags: vector<String>,

        // Outcomes
        outcome_yes_label: String,
        outcome_no_label: String,

        // Timing
        created_at: u64,
        end_time: u64,
        resolution_time: u64,
        timeframe: String,

        // Resolution
        resolution_type: u8,
        resolution_source: String,
        winning_outcome: u8,
        resolved_at: u64,
        resolver: address,

        // Economics
        total_volume: u64,
        total_collateral: u64,
        fee_bps: u16,

        // State
        status: u8,

        // Ownership
        creator: address,
    }

    /// Market Registry - Global state tracking all markets
    public struct MarketRegistry has key {
        id: UID,
        market_count: u64,
        total_volume: u64,
        total_collateral: u64,
        creation_fee: u64,
        treasury: address,
        paused: bool,
    }

    /// Admin Capability - Grants admin powers
    public struct AdminCap has key, store {
        id: UID,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANT GETTERS (public - anyone can read)
    // ═══════════════════════════════════════════════════════════════════════════

    // --- Status ---
    public fun status_open(): u8 { STATUS_OPEN }
    public fun status_trading_ended(): u8 { STATUS_TRADING_ENDED }
    public fun status_resolved(): u8 { STATUS_RESOLVED }
    public fun status_voided(): u8 { STATUS_VOIDED }

    // --- Outcome ---
    public fun outcome_yes(): u8 { OUTCOME_YES }
    public fun outcome_no(): u8 { OUTCOME_NO }
    public fun outcome_void(): u8 { OUTCOME_VOID }
    public fun outcome_unset(): u8 { OUTCOME_UNSET }

    // --- Resolution Type ---
    public fun resolution_admin(): u8 { RESOLUTION_ADMIN }
    public fun resolution_oracle(): u8 { RESOLUTION_ORACLE }

    // --- Limits ---
    public fun min_question_length(): u64 { MIN_QUESTION_LENGTH }
    public fun max_question_length(): u64 { MAX_QUESTION_LENGTH }
    public fun max_fee_bps(): u16 { MAX_FEE_BPS }
    public fun min_duration_ms(): u64 { MIN_DURATION_MS }
    public fun default_creation_fee(): u64 { DEFAULT_CREATION_FEE }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARKET GETTERS (public - anyone can read)
    // ═══════════════════════════════════════════════════════════════════════════

    public fun market_id(m: &Market): u64 { m.market_id }
    public fun question(m: &Market): &String { &m.question }
    public fun description(m: &Market): &String { &m.description }
    public fun image_url(m: &Market): &String { &m.image_url }
    public fun category(m: &Market): &String { &m.category }
    public fun tags(m: &Market): &vector<String> { &m.tags }
    public fun outcome_yes_label(m: &Market): &String { &m.outcome_yes_label }
    public fun outcome_no_label(m: &Market): &String { &m.outcome_no_label }
    public fun created_at(m: &Market): u64 { m.created_at }
    public fun end_time(m: &Market): u64 { m.end_time }
    public fun resolution_time(m: &Market): u64 { m.resolution_time }
    public fun timeframe(m: &Market): &String { &m.timeframe }
    public fun resolution_type(m: &Market): u8 { m.resolution_type }
    public fun resolution_source(m: &Market): &String { &m.resolution_source }
    public fun winning_outcome(m: &Market): u8 { m.winning_outcome }
    public fun resolved_at(m: &Market): u64 { m.resolved_at }
    public fun resolver(m: &Market): address { m.resolver }
    public fun total_volume(m: &Market): u64 { m.total_volume }
    public fun total_collateral(m: &Market): u64 { m.total_collateral }
    public fun fee_bps(m: &Market): u16 { m.fee_bps }
    public fun status(m: &Market): u8 { m.status }
    public fun creator(m: &Market): address { m.creator }

    // --- Computed Getters ---
    public fun is_open(m: &Market): bool { m.status == STATUS_OPEN }
    public fun is_trading_ended(m: &Market): bool { m.status == STATUS_TRADING_ENDED }
    public fun is_resolved(m: &Market): bool { m.status == STATUS_RESOLVED }
    public fun is_voided(m: &Market): bool { m.status == STATUS_VOIDED }
    public fun can_trade(m: &Market): bool { m.status == STATUS_OPEN }
    public fun can_redeem(m: &Market): bool {
        m.status == STATUS_RESOLVED || m.status == STATUS_VOIDED
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // REGISTRY GETTERS (public - anyone can read)
    // ═══════════════════════════════════════════════════════════════════════════

    public fun registry_market_count(r: &MarketRegistry): u64 { r.market_count }
    public fun registry_total_volume(r: &MarketRegistry): u64 { r.total_volume }
    public fun registry_total_collateral(r: &MarketRegistry): u64 { r.total_collateral }
    public fun registry_creation_fee(r: &MarketRegistry): u64 { r.creation_fee }
    public fun registry_treasury(r: &MarketRegistry): address { r.treasury }
    public fun registry_paused(r: &MarketRegistry): bool { r.paused }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTORS (package-only - only this package can create)
    // UID must be created with object::new(ctx) directly in constructor
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a new Market
    public(package) fun new_market(
        market_id: u64,
        question: String,
        description: String,
        image_url: String,
        category: String,
        tags: vector<String>,
        outcome_yes_label: String,
        outcome_no_label: String,
        created_at: u64,
        end_time: u64,
        resolution_time: u64,
        timeframe: String,
        resolution_type: u8,
        resolution_source: String,
        fee_bps: u16,
        creator: address,
        ctx: &mut TxContext,
    ): Market {
        Market {
            id: object::new(ctx),
            market_id,
            question,
            description,
            image_url,
            category,
            tags,
            outcome_yes_label,
            outcome_no_label,
            created_at,
            end_time,
            resolution_time,
            timeframe,
            resolution_type,
            resolution_source,
            winning_outcome: OUTCOME_UNSET,
            resolved_at: 0,
            resolver: @0x0,
            total_volume: 0,
            total_collateral: 0,
            fee_bps,
            status: STATUS_OPEN,
            creator,
        }
    }

    /// Create a new MarketRegistry
    public(package) fun new_registry(
        treasury: address,
        ctx: &mut TxContext,
    ): MarketRegistry {
        MarketRegistry {
            id: object::new(ctx),
            market_count: 0,
            total_volume: 0,
            total_collateral: 0,
            creation_fee: DEFAULT_CREATION_FEE,
            treasury,
            paused: false,
        }
    }

    /// Create a new AdminCap
    public(package) fun new_admin_cap(ctx: &mut TxContext): AdminCap {
        AdminCap { id: object::new(ctx) }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARKET SETTERS (package-only - only this package can modify)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Set market status
    public(package) fun set_status(m: &mut Market, new_status: u8) {
        m.status = new_status;
    }

    /// Set winning outcome
    public(package) fun set_winning_outcome(m: &mut Market, outcome: u8) {
        m.winning_outcome = outcome;
    }

    /// Set resolved_at timestamp
    public(package) fun set_resolved_at(m: &mut Market, timestamp: u64) {
        m.resolved_at = timestamp;
    }

    /// Set resolver address
    public(package) fun set_resolver(m: &mut Market, addr: address) {
        m.resolver = addr;
    }

    /// Add to total volume
    public(package) fun add_volume(m: &mut Market, amount: u64) {
        m.total_volume = m.total_volume + amount;
    }

    /// Add to total collateral
    public(package) fun add_collateral(m: &mut Market, amount: u64) {
        m.total_collateral = m.total_collateral + amount;
    }

    /// Remove from total collateral
    public(package) fun remove_collateral(m: &mut Market, amount: u64) {
        m.total_collateral = m.total_collateral - amount;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // REGISTRY SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Increment market count and return new ID
    public(package) fun increment_market_count(r: &mut MarketRegistry): u64 {
        let id = r.market_count;
        r.market_count = r.market_count + 1;
        id
    }

    /// Add to registry total volume
    public(package) fun registry_add_volume(r: &mut MarketRegistry, amount: u64) {
        r.total_volume = r.total_volume + amount;
    }

    /// Add to registry total collateral
    public(package) fun registry_add_collateral(r: &mut MarketRegistry, amount: u64) {
        r.total_collateral = r.total_collateral + amount;
    }

    /// Remove from registry total collateral
    public(package) fun registry_remove_collateral(r: &mut MarketRegistry, amount: u64) {
        r.total_collateral = r.total_collateral - amount;
    }

    /// Set creation fee
    public(package) fun set_creation_fee(r: &mut MarketRegistry, fee: u64) {
        r.creation_fee = fee;
    }

    /// Set treasury address
    public(package) fun set_treasury(r: &mut MarketRegistry, addr: address) {
        r.treasury = addr;
    }

    /// Set paused state
    public(package) fun set_paused(r: &mut MarketRegistry, paused: bool) {
        r.paused = paused;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TRANSFER FUNCTIONS (must be in defining module)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Share a market globally
    #[allow(lint(share_owned, custom_state_change))]
    public(package) fun share_market(market: Market) {
        transfer::share_object(market);
    }

    /// Share registry globally
    #[allow(lint(share_owned, custom_state_change))]
    public(package) fun share_registry(registry: MarketRegistry) {
        transfer::share_object(registry);
    }

    /// Transfer admin cap to address
    #[allow(lint(custom_state_change))]
    public(package) fun transfer_admin_cap(cap: AdminCap, recipient: address) {
        transfer::transfer(cap, recipient);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test_only]
    public fun destroy_market_for_testing(m: Market) {
        let Market {
            id, market_id: _, question: _, description: _, image_url: _,
            category: _, tags: _, outcome_yes_label: _, outcome_no_label: _,
            created_at: _, end_time: _, resolution_time: _, timeframe: _,
            resolution_type: _, resolution_source: _, winning_outcome: _,
            resolved_at: _, resolver: _, total_volume: _, total_collateral: _,
            fee_bps: _, status: _, creator: _
        } = m;
        object::delete(id);
    }

    #[test_only]
    public fun destroy_registry_for_testing(r: MarketRegistry) {
        let MarketRegistry {
            id, market_count: _, total_volume: _, total_collateral: _,
            creation_fee: _, treasury: _, paused: _
        } = r;
        object::delete(id);
    }

    /// Alias for destroy_registry_for_testing (consistent naming)
    #[test_only]
    public fun destroy_market_registry_for_testing(r: MarketRegistry) {
        destroy_registry_for_testing(r);
    }

    #[test_only]
    public fun destroy_admin_cap_for_testing(cap: AdminCap) {
        let AdminCap { id } = cap;
        object::delete(id);
    }

    #[test_only]
    public fun set_status_for_testing(m: &mut Market, new_status: u8) {
        m.status = new_status;
    }
}
