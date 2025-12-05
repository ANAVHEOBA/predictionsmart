/// Market Entries - Public entry functions (transaction endpoints)
///
/// These are the functions users call directly via transactions.
/// They handle object sharing/transferring since that must happen
/// in the module that defines the types.
module predictionsmart::market_entries {
    use sui::clock::Clock;
    use sui::coin::Coin;
    use sui::sui::SUI;
    use std::string;

    use predictionsmart::market_types::{Self, Market, MarketRegistry, AdminCap};
    use predictionsmart::market_operations;

    // ═══════════════════════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Initialize the platform
    /// Call once after package deployment
    fun init(ctx: &mut TxContext) {
        let (registry, admin_cap) = market_operations::create_registry_and_admin(
            ctx.sender(),
            ctx,
        );

        // Share registry globally (must use types module function)
        market_types::share_registry(registry);

        // Transfer admin cap to deployer
        market_types::transfer_admin_cap(admin_cap, ctx.sender());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: CREATE MARKET
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a new binary market
    /// Anyone can call - pays creation fee
    entry fun create_market(
        registry: &mut MarketRegistry,
        fee_payment: Coin<SUI>,
        question: vector<u8>,
        description: vector<u8>,
        image_url: vector<u8>,
        category: vector<u8>,
        tags: vector<vector<u8>>,
        outcome_yes_label: vector<u8>,
        outcome_no_label: vector<u8>,
        end_time: u64,
        resolution_time: u64,
        timeframe: vector<u8>,
        resolution_type: u8,
        resolution_source: vector<u8>,
        fee_bps: u16,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        // Convert tags
        let mut string_tags = vector::empty<string::String>();
        let mut i = 0;
        let len = vector::length(&tags);
        while (i < len) {
            vector::push_back(&mut string_tags, string::utf8(*vector::borrow(&tags, i)));
            i = i + 1;
        };

        let market = market_operations::create_market(
            registry,
            fee_payment,
            string::utf8(question),
            string::utf8(description),
            string::utf8(image_url),
            string::utf8(category),
            string_tags,
            string::utf8(outcome_yes_label),
            string::utf8(outcome_no_label),
            end_time,
            resolution_time,
            string::utf8(timeframe),
            resolution_type,
            string::utf8(resolution_source),
            fee_bps,
            clock,
            ctx,
        );

        // Share market globally (must use types module function)
        market_types::share_market(market);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: END TRADING
    // ═══════════════════════════════════════════════════════════════════════════

    /// Check and end trading if time passed
    /// Anyone can call
    entry fun end_trading(
        market: &mut Market,
        clock: &Clock,
    ) {
        market_operations::check_and_end_trading(market, clock);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 4: RESOLVE MARKET
    // ═══════════════════════════════════════════════════════════════════════════

    /// Creator resolves their market
    entry fun resolve_by_creator(
        market: &mut Market,
        winning_outcome: u8,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        market_operations::resolve_by_creator(market, winning_outcome, clock, ctx);
    }

    /// Admin resolves any market
    entry fun resolve_by_admin(
        market: &mut Market,
        admin_cap: &AdminCap,
        winning_outcome: u8,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        market_operations::resolve_by_admin(market, admin_cap, winning_outcome, clock, ctx);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 5: VOID MARKET
    // ═══════════════════════════════════════════════════════════════════════════

    /// Creator voids their market (only if open)
    entry fun void_by_creator(
        market: &mut Market,
        reason: vector<u8>,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        market_operations::void_by_creator(
            market,
            string::utf8(reason),
            clock,
            ctx,
        );
    }

    /// Admin voids any market
    entry fun void_by_admin(
        market: &mut Market,
        admin_cap: &AdminCap,
        reason: vector<u8>,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        market_operations::void_by_admin(
            market,
            admin_cap,
            string::utf8(reason),
            clock,
            ctx,
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 6: ADMIN CONFIG
    // ═══════════════════════════════════════════════════════════════════════════

    /// Set creation fee
    entry fun set_creation_fee(
        registry: &mut MarketRegistry,
        admin_cap: &AdminCap,
        new_fee: u64,
    ) {
        market_operations::set_creation_fee(registry, admin_cap, new_fee);
    }

    /// Set treasury address
    entry fun set_treasury(
        registry: &mut MarketRegistry,
        admin_cap: &AdminCap,
        new_treasury: address,
    ) {
        market_operations::set_treasury(registry, admin_cap, new_treasury);
    }

    /// Pause platform
    entry fun pause(
        registry: &mut MarketRegistry,
        admin_cap: &AdminCap,
    ) {
        market_operations::pause(registry, admin_cap);
    }

    /// Unpause platform
    entry fun unpause(
        registry: &mut MarketRegistry,
        admin_cap: &AdminCap,
    ) {
        market_operations::unpause(registry, admin_cap);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public fun initialize_for_testing(ctx: &mut TxContext): (market_types::MarketRegistry, market_types::AdminCap) {
        market_operations::create_registry_and_admin(ctx.sender(), ctx)
    }

    #[test_only]
    public fun create_market_for_testing(
        registry: &mut market_types::MarketRegistry,
        question: std::string::String,
        description: std::string::String,
        image_url: std::string::String,
        category: std::string::String,
        tags: vector<std::string::String>,
        outcome_yes_label: std::string::String,
        outcome_no_label: std::string::String,
        end_time: u64,
        resolution_time: u64,
        timeframe: std::string::String,
        resolution_type: u8,
        resolution_source: std::string::String,
        fee_bps: u16,
        fee: sui::coin::Coin<sui::sui::SUI>,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ): market_types::Market {
        market_operations::create_market(
            registry,
            fee,
            question,
            description,
            image_url,
            category,
            tags,
            outcome_yes_label,
            outcome_no_label,
            end_time,
            resolution_time,
            timeframe,
            resolution_type,
            resolution_source,
            fee_bps,
            clock,
            ctx,
        )
    }
}
