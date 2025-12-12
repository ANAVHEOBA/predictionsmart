/// Fee Entries - Public entry functions (transaction endpoints)
///
/// These are the functions users call directly via transactions.
/// They handle object sharing/transferring since that must happen
/// in the module that defines the types.
module predictionsmart::fee_entries {
    use sui::clock::Clock;
    use std::string;

    use predictionsmart::fee_types::{Self, FeeRegistry, FeeAdminCap, ReferralRegistry, UserFeeStats, CreatorFeeConfig, ReferralConfig};
    use predictionsmart::fee_operations;

    // ═══════════════════════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Initialize the fee system
    /// Call once after package deployment
    /// Note: Full initialization should be done via initialize_fee_system entry function
    fun init(_ctx: &TxContext) {
        // No-op - initialization requires clock and treasury address
        // Use initialize_fee_system entry function after deployment
    }

    /// Initialize the fee system with treasury address
    entry fun initialize_fee_system(
        treasury: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let (registry, referral_registry, admin_cap) = fee_operations::create_fee_registry_and_admin(
            treasury,
            clock,
            ctx,
        );

        // Share registries globally
        fee_types::share_fee_registry(registry);
        fee_types::share_referral_registry(referral_registry);

        // Transfer admin cap to deployer
        fee_types::transfer_fee_admin_cap(admin_cap, ctx.sender());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: FEE REGISTRY MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════════

    /// Set base fee (admin only)
    entry fun set_base_fee(
        registry: &mut FeeRegistry,
        admin_cap: &FeeAdminCap,
        new_fee_bps: u16,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        fee_operations::set_base_fee(registry, admin_cap, new_fee_bps, clock, ctx);
    }

    /// Set protocol share (admin only)
    entry fun set_protocol_share(
        registry: &mut FeeRegistry,
        admin_cap: &FeeAdminCap,
        new_share_bps: u16,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        fee_operations::set_protocol_share(registry, admin_cap, new_share_bps, clock, ctx);
    }

    /// Set creator share (admin only)
    entry fun set_creator_share(
        registry: &mut FeeRegistry,
        admin_cap: &FeeAdminCap,
        new_share_bps: u16,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        fee_operations::set_creator_share(registry, admin_cap, new_share_bps, clock, ctx);
    }

    /// Set referral share (admin only)
    entry fun set_referral_share(
        registry: &mut FeeRegistry,
        admin_cap: &FeeAdminCap,
        new_share_bps: u16,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        fee_operations::set_referral_share(registry, admin_cap, new_share_bps, clock, ctx);
    }

    /// Set maker rebate (admin only)
    entry fun set_maker_rebate(
        registry: &mut FeeRegistry,
        admin_cap: &FeeAdminCap,
        new_rebate_bps: u16,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        fee_operations::set_maker_rebate(registry, admin_cap, new_rebate_bps, clock, ctx);
    }

    /// Set protocol treasury address (admin only)
    entry fun set_treasury(
        registry: &mut FeeRegistry,
        admin_cap: &FeeAdminCap,
        new_treasury: address,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        fee_operations::set_treasury(registry, admin_cap, new_treasury, clock, ctx);
    }

    /// Transfer admin to new address (admin only)
    entry fun transfer_admin(
        registry: &mut FeeRegistry,
        admin_cap: &FeeAdminCap,
        new_admin: address,
        clock: &Clock,
    ) {
        fee_operations::transfer_admin(registry, admin_cap, new_admin, clock);
    }

    /// Pause fee collection (admin only)
    entry fun pause_fees(
        registry: &mut FeeRegistry,
        admin_cap: &FeeAdminCap,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        fee_operations::pause_fees(registry, admin_cap, clock, ctx);
    }

    /// Unpause fee collection (admin only)
    entry fun unpause_fees(
        registry: &mut FeeRegistry,
        admin_cap: &FeeAdminCap,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        fee_operations::unpause_fees(registry, admin_cap, clock, ctx);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 2: FEE TIERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Add a new fee tier (admin only)
    entry fun add_fee_tier(
        registry: &mut FeeRegistry,
        admin_cap: &FeeAdminCap,
        name: vector<u8>,
        min_volume: u64,
        fee_bps: u16,
        maker_rebate_bps: u16,
        clock: &Clock,
    ) {
        fee_operations::add_fee_tier(
            registry,
            admin_cap,
            string::utf8(name),
            min_volume,
            fee_bps,
            maker_rebate_bps,
            clock,
        );
    }

    /// Update an existing fee tier (admin only)
    entry fun update_fee_tier(
        registry: &mut FeeRegistry,
        admin_cap: &FeeAdminCap,
        tier_index: u64,
        name: vector<u8>,
        min_volume: u64,
        fee_bps: u16,
        maker_rebate_bps: u16,
        clock: &Clock,
    ) {
        fee_operations::update_fee_tier(
            registry,
            admin_cap,
            tier_index,
            string::utf8(name),
            min_volume,
            fee_bps,
            maker_rebate_bps,
            clock,
        );
    }

    /// Remove a fee tier (admin only)
    entry fun remove_fee_tier(
        registry: &mut FeeRegistry,
        admin_cap: &FeeAdminCap,
        tier_index: u64,
        clock: &Clock,
    ) {
        fee_operations::remove_fee_tier(registry, admin_cap, tier_index, clock);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 4: USER FEE STATS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create user fee stats for tracking volume and tier
    entry fun create_user_stats(
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let stats = fee_operations::create_user_stats(ctx.sender(), clock, ctx);
        fee_types::transfer_user_fee_stats(stats, ctx.sender());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 5: CREATOR FEE MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create creator fee config
    entry fun create_creator_config(
        ctx: &mut TxContext,
    ) {
        let config = fee_operations::create_creator_config(ctx.sender(), ctx);
        fee_types::transfer_creator_fee_config(config, ctx.sender());
    }

    /// Set custom fee for creator's markets
    entry fun set_custom_creator_fee(
        config: &mut CreatorFeeConfig,
        fee_bps: u16,
        ctx: &TxContext,
    ) {
        fee_operations::set_custom_creator_fee(config, fee_bps, ctx);
    }

    /// Clear custom fee (revert to default)
    entry fun clear_custom_creator_fee(
        config: &mut CreatorFeeConfig,
        ctx: &TxContext,
    ) {
        fee_operations::clear_custom_creator_fee(config, ctx);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 6: REFERRAL SYSTEM
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a referral code
    entry fun create_referral_code(
        registry: &mut ReferralRegistry,
        code: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let config = fee_operations::create_referral_code(
            registry,
            string::utf8(code),
            clock,
            ctx,
        );
        fee_types::transfer_referral_config(config, ctx.sender());
    }

    /// Use a referral code (link user to referrer)
    entry fun use_referral_code(
        referral_registry: &mut ReferralRegistry,
        referral_config: &mut ReferralConfig,
        code: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        fee_operations::use_referral_code(
            referral_registry,
            referral_config,
            string::utf8(code),
            clock,
            ctx,
        );
    }

    /// Deactivate referral code (referrer only)
    entry fun deactivate_referral_code(
        config: &mut ReferralConfig,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        fee_operations::deactivate_referral_code(config, clock, ctx);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 7: FEE EXEMPTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Add fee exemption (admin only)
    entry fun add_fee_exemption(
        registry: &mut FeeRegistry,
        admin_cap: &FeeAdminCap,
        addr: address,
        reason: vector<u8>,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        fee_operations::add_fee_exemption(
            registry,
            admin_cap,
            addr,
            string::utf8(reason),
            clock,
            ctx,
        );
    }

    /// Remove fee exemption (admin only)
    entry fun remove_fee_exemption(
        registry: &mut FeeRegistry,
        admin_cap: &FeeAdminCap,
        addr: address,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        fee_operations::remove_fee_exemption(registry, admin_cap, addr, clock, ctx);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get user's current fee rate in basis points
    public fun get_user_fee_rate(
        registry: &FeeRegistry,
        user_stats: &UserFeeStats,
    ): u16 {
        fee_operations::get_user_fee_rate(registry, user_stats)
    }

    /// Check if user has a referrer
    public fun user_has_referrer(
        referral_registry: &ReferralRegistry,
        user: address,
    ): bool {
        fee_operations::user_has_referrer(referral_registry, user)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test_only]
    public fun init_for_testing(_ctx: &mut TxContext) {
        // No-op for testing - use initialize_for_testing instead
    }

    #[test_only]
    public fun initialize_for_testing(
        treasury: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (FeeRegistry, ReferralRegistry, FeeAdminCap) {
        fee_operations::create_fee_registry_and_admin(treasury, clock, ctx)
    }

    #[test_only]
    public fun create_user_stats_for_testing(
        user: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ): UserFeeStats {
        fee_operations::create_user_stats(user, clock, ctx)
    }

    #[test_only]
    public fun create_creator_config_for_testing(
        creator: address,
        ctx: &mut TxContext,
    ): CreatorFeeConfig {
        fee_operations::create_creator_config(creator, ctx)
    }

    #[test_only]
    public fun create_referral_config_for_testing(
        registry: &mut ReferralRegistry,
        code: std::string::String,
        clock: &Clock,
        ctx: &mut TxContext,
    ): ReferralConfig {
        fee_operations::create_referral_code(registry, code, clock, ctx)
    }
}
