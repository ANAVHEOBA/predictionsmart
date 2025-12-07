/// Fee Operations - Core business logic
///
/// This module contains all the business logic for the fee system.
/// It uses types.move for data and events.move for broadcasting.
module predictionsmart::fee_operations {
    use sui::clock::Clock;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use std::string::{Self, String};

    use predictionsmart::fee_types::{
        Self,
        FeeRegistry,
        FeeAdminCap,
        UserFeeStats,
        CreatorFeeConfig,
        ReferralConfig,
        ReferralRegistry,
    };
    use predictionsmart::fee_events;

    // ═══════════════════════════════════════════════════════════════════════════
    // ERROR CODES
    // ═══════════════════════════════════════════════════════════════════════════

    const E_INVALID_FEE: u64 = 2;
    const E_SHARES_EXCEED_100: u64 = 4;
    const E_TIER_NOT_FOUND: u64 = 6;
    const E_INVALID_TIER_ORDER: u64 = 7;
    const E_NOT_CREATOR: u64 = 8;
    const E_INSUFFICIENT_EARNINGS: u64 = 9;
    const E_REFERRAL_CODE_EXISTS: u64 = 10;
    const E_REFERRAL_CODE_NOT_FOUND: u64 = 11;
    const E_ALREADY_REFERRED: u64 = 12;
    const E_SELF_REFERRAL: u64 = 13;
    const E_CODE_TOO_SHORT: u64 = 14;
    const E_CODE_TOO_LONG: u64 = 15;
    const E_FEES_PAUSED: u64 = 16;
    const E_NOT_REFERRER: u64 = 17;
    const E_CODE_INACTIVE: u64 = 18;
    const E_INVALID_REBATE: u64 = 19;

    // ═══════════════════════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create initial fee registry, referral registry, and admin cap
    /// Returns them so caller can share/transfer appropriately
    public fun create_fee_registry_and_admin(
        treasury: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (FeeRegistry, ReferralRegistry, FeeAdminCap) {
        let admin = ctx.sender();
        let registry = fee_types::new_fee_registry(admin, treasury, ctx);
        let referral_registry = fee_types::new_referral_registry(ctx);
        let admin_cap = fee_types::new_fee_admin_cap(ctx);

        // Emit initialization event
        fee_events::emit_fee_registry_initialized(
            admin,
            treasury,
            fee_types::registry_base_fee_bps(&registry),
            fee_types::registry_protocol_share_bps(&registry),
            fee_types::registry_creator_share_bps(&registry),
            fee_types::registry_referral_share_bps(&registry),
            clock.timestamp_ms(),
        );

        (registry, referral_registry, admin_cap)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: FEE REGISTRY MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════════

    /// Set base fee (admin only)
    public fun set_base_fee(
        registry: &mut FeeRegistry,
        _admin_cap: &FeeAdminCap,
        new_fee_bps: u16,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        // Validate fee
        assert!(new_fee_bps <= fee_types::max_fee_bps(), E_INVALID_FEE);

        let old_fee = fee_types::registry_base_fee_bps(registry);
        fee_types::set_base_fee_bps(registry, new_fee_bps);

        fee_events::emit_fee_config_updated(
            string::utf8(b"base_fee_bps"),
            (old_fee as u64),
            (new_fee_bps as u64),
            ctx.sender(),
            clock.timestamp_ms(),
        );
    }

    /// Set protocol share (admin only)
    public fun set_protocol_share(
        registry: &mut FeeRegistry,
        _admin_cap: &FeeAdminCap,
        new_share_bps: u16,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        // Validate shares sum
        let creator_share = fee_types::registry_creator_share_bps(registry);
        let referral_share = fee_types::registry_referral_share_bps(registry);
        let total = (new_share_bps as u64) + (creator_share as u64) + (referral_share as u64);
        assert!(total <= 10000, E_SHARES_EXCEED_100);

        let old_share = fee_types::registry_protocol_share_bps(registry);
        fee_types::set_protocol_share_bps(registry, new_share_bps);

        fee_events::emit_fee_config_updated(
            string::utf8(b"protocol_share_bps"),
            (old_share as u64),
            (new_share_bps as u64),
            ctx.sender(),
            clock.timestamp_ms(),
        );
    }

    /// Set creator share (admin only)
    public fun set_creator_share(
        registry: &mut FeeRegistry,
        _admin_cap: &FeeAdminCap,
        new_share_bps: u16,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        // Validate shares sum
        let protocol_share = fee_types::registry_protocol_share_bps(registry);
        let referral_share = fee_types::registry_referral_share_bps(registry);
        let total = (protocol_share as u64) + (new_share_bps as u64) + (referral_share as u64);
        assert!(total <= 10000, E_SHARES_EXCEED_100);

        let old_share = fee_types::registry_creator_share_bps(registry);
        fee_types::set_creator_share_bps(registry, new_share_bps);

        fee_events::emit_fee_config_updated(
            string::utf8(b"creator_share_bps"),
            (old_share as u64),
            (new_share_bps as u64),
            ctx.sender(),
            clock.timestamp_ms(),
        );
    }

    /// Set referral share (admin only)
    public fun set_referral_share(
        registry: &mut FeeRegistry,
        _admin_cap: &FeeAdminCap,
        new_share_bps: u16,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        // Validate shares sum
        let protocol_share = fee_types::registry_protocol_share_bps(registry);
        let creator_share = fee_types::registry_creator_share_bps(registry);
        let total = (protocol_share as u64) + (creator_share as u64) + (new_share_bps as u64);
        assert!(total <= 10000, E_SHARES_EXCEED_100);

        let old_share = fee_types::registry_referral_share_bps(registry);
        fee_types::set_referral_share_bps(registry, new_share_bps);

        fee_events::emit_fee_config_updated(
            string::utf8(b"referral_share_bps"),
            (old_share as u64),
            (new_share_bps as u64),
            ctx.sender(),
            clock.timestamp_ms(),
        );
    }

    /// Set maker rebate (admin only)
    public fun set_maker_rebate(
        registry: &mut FeeRegistry,
        _admin_cap: &FeeAdminCap,
        new_rebate_bps: u16,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        assert!(new_rebate_bps <= fee_types::max_maker_rebate_bps(), E_INVALID_REBATE);

        let old_rebate = fee_types::registry_maker_rebate_bps(registry);
        fee_types::set_maker_rebate_bps(registry, new_rebate_bps);

        fee_events::emit_fee_config_updated(
            string::utf8(b"maker_rebate_bps"),
            (old_rebate as u64),
            (new_rebate_bps as u64),
            ctx.sender(),
            clock.timestamp_ms(),
        );
    }

    /// Set protocol treasury address (admin only)
    public fun set_treasury(
        registry: &mut FeeRegistry,
        _admin_cap: &FeeAdminCap,
        new_treasury: address,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        let old_treasury = fee_types::registry_protocol_treasury(registry);
        fee_types::set_protocol_treasury(registry, new_treasury);

        fee_events::emit_treasury_updated(
            old_treasury,
            new_treasury,
            ctx.sender(),
            clock.timestamp_ms(),
        );
    }

    /// Transfer admin to new address (admin only)
    public fun transfer_admin(
        registry: &mut FeeRegistry,
        _admin_cap: &FeeAdminCap,
        new_admin: address,
        clock: &Clock,
    ) {
        let old_admin = fee_types::registry_admin(registry);
        fee_types::set_registry_admin(registry, new_admin);

        fee_events::emit_admin_transferred(
            old_admin,
            new_admin,
            clock.timestamp_ms(),
        );
    }

    /// Pause fee collection (admin only)
    public fun pause_fees(
        registry: &mut FeeRegistry,
        _admin_cap: &FeeAdminCap,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        fee_types::set_paused(registry, true);

        fee_events::emit_fees_paused_state_changed(
            true,
            ctx.sender(),
            clock.timestamp_ms(),
        );
    }

    /// Unpause fee collection (admin only)
    public fun unpause_fees(
        registry: &mut FeeRegistry,
        _admin_cap: &FeeAdminCap,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        fee_types::set_paused(registry, false);

        fee_events::emit_fees_paused_state_changed(
            false,
            ctx.sender(),
            clock.timestamp_ms(),
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 2: FEE TIERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Add a new fee tier (admin only)
    public fun add_fee_tier(
        registry: &mut FeeRegistry,
        _admin_cap: &FeeAdminCap,
        name: String,
        min_volume: u64,
        fee_bps: u16,
        maker_rebate_bps: u16,
        clock: &Clock,
    ) {
        // Validate fee
        assert!(fee_bps <= fee_types::max_fee_bps(), E_INVALID_FEE);
        assert!(maker_rebate_bps <= fee_types::max_maker_rebate_bps(), E_INVALID_REBATE);

        // Validate tier order (volume must be higher than last tier)
        let tier_count = fee_types::registry_tier_count(registry);
        if (tier_count > 0) {
            let last_tier = fee_types::registry_get_tier(registry, tier_count - 1);
            assert!(min_volume > fee_types::tier_min_volume(last_tier), E_INVALID_TIER_ORDER);
            // Fee should decrease with higher tiers
            assert!(fee_bps < fee_types::tier_fee_bps(last_tier), E_INVALID_TIER_ORDER);
        };

        let tier = fee_types::new_fee_tier(name, min_volume, fee_bps, maker_rebate_bps);
        fee_types::add_tier(registry, tier);

        fee_events::emit_fee_tier_added(
            tier_count,
            name,
            min_volume,
            fee_bps,
            maker_rebate_bps,
            clock.timestamp_ms(),
        );
    }

    /// Update an existing fee tier (admin only)
    public fun update_fee_tier(
        registry: &mut FeeRegistry,
        _admin_cap: &FeeAdminCap,
        tier_index: u64,
        name: String,
        min_volume: u64,
        fee_bps: u16,
        maker_rebate_bps: u16,
        clock: &Clock,
    ) {
        let tier_count = fee_types::registry_tier_count(registry);
        assert!(tier_index < tier_count, E_TIER_NOT_FOUND);
        assert!(fee_bps <= fee_types::max_fee_bps(), E_INVALID_FEE);
        assert!(maker_rebate_bps <= fee_types::max_maker_rebate_bps(), E_INVALID_REBATE);

        let old_tier = fee_types::registry_get_tier(registry, tier_index);
        let old_fee_bps = fee_types::tier_fee_bps(old_tier);
        let old_min_volume = fee_types::tier_min_volume(old_tier);

        let new_tier = fee_types::new_fee_tier(name, min_volume, fee_bps, maker_rebate_bps);
        fee_types::update_tier(registry, tier_index, new_tier);

        fee_events::emit_fee_tier_updated(
            tier_index,
            old_fee_bps,
            fee_bps,
            old_min_volume,
            min_volume,
            clock.timestamp_ms(),
        );
    }

    /// Remove a fee tier (admin only)
    public fun remove_fee_tier(
        registry: &mut FeeRegistry,
        _admin_cap: &FeeAdminCap,
        tier_index: u64,
        clock: &Clock,
    ) {
        let tier_count = fee_types::registry_tier_count(registry);
        assert!(tier_index < tier_count, E_TIER_NOT_FOUND);

        let tier = fee_types::registry_get_tier(registry, tier_index);
        let name = *fee_types::tier_name(tier);

        fee_types::remove_tier(registry, tier_index);

        fee_events::emit_fee_tier_removed(
            tier_index,
            name,
            clock.timestamp_ms(),
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: CALCULATE & COLLECT FEES
    // ═══════════════════════════════════════════════════════════════════════════

    /// Calculate fee amount for a trade based on user's tier
    public fun calculate_fee(
        registry: &FeeRegistry,
        user_stats: &UserFeeStats,
        trade_amount: u64,
    ): u64 {
        // Check if user is exempt
        let user = fee_types::stats_user(user_stats);
        if (fee_types::registry_is_exempt(registry, user)) {
            return 0
        };

        // Get user's tier fee rate
        let tier_index = fee_types::stats_current_tier(user_stats);
        let fee_bps = if ((tier_index as u64) < fee_types::registry_tier_count(registry)) {
            let tier = fee_types::registry_get_tier(registry, (tier_index as u64));
            fee_types::tier_fee_bps(tier)
        } else {
            fee_types::registry_base_fee_bps(registry)
        };

        // Calculate fee: (amount * fee_bps) / 10000
        ((trade_amount as u128) * (fee_bps as u128) / 10000 as u64)
    }

    /// Calculate fee with exemption check but without stats
    public fun calculate_fee_simple(
        registry: &FeeRegistry,
        user: address,
        trade_amount: u64,
    ): u64 {
        // Check if user is exempt
        if (fee_types::registry_is_exempt(registry, user)) {
            return 0
        };

        // Use base fee rate
        let fee_bps = fee_types::registry_base_fee_bps(registry);
        ((trade_amount as u128) * (fee_bps as u128) / 10000 as u64)
    }

    /// Calculate maker rebate
    public fun calculate_maker_rebate(
        registry: &FeeRegistry,
        user_stats: &UserFeeStats,
        trade_amount: u64,
    ): u64 {
        let tier_index = fee_types::stats_current_tier(user_stats);
        let rebate_bps = if ((tier_index as u64) < fee_types::registry_tier_count(registry)) {
            let tier = fee_types::registry_get_tier(registry, (tier_index as u64));
            fee_types::tier_maker_rebate_bps(tier)
        } else {
            fee_types::registry_maker_rebate_bps(registry)
        };

        ((trade_amount as u128) * (rebate_bps as u128) / 10000 as u64)
    }

    /// Distribute collected fee to recipients
    /// Returns (protocol_fee, creator_fee, referral_fee)
    public fun distribute_fee(
        registry: &FeeRegistry,
        total_fee: u64,
        has_referrer: bool,
    ): (u64, u64, u64) {
        let protocol_share = fee_types::registry_protocol_share_bps(registry);
        let creator_share = fee_types::registry_creator_share_bps(registry);
        let referral_share = fee_types::registry_referral_share_bps(registry);

        let protocol_fee = ((total_fee as u128) * (protocol_share as u128) / 10000 as u64);
        let creator_fee = ((total_fee as u128) * (creator_share as u128) / 10000 as u64);

        let referral_fee = if (has_referrer) {
            ((total_fee as u128) * (referral_share as u128) / 10000 as u64)
        } else {
            0
        };

        // If no referrer, add referral share to protocol
        let final_protocol_fee = if (!has_referrer) {
            protocol_fee + ((total_fee as u128) * (referral_share as u128) / 10000 as u64)
        } else {
            protocol_fee
        };

        (final_protocol_fee, creator_fee, referral_fee)
    }

    /// Collect and distribute fee from a payment (without referrer)
    public fun collect_and_distribute_fee(
        registry: &mut FeeRegistry,
        payment: &mut Coin<SUI>,
        market_id: u64,
        user: address,
        trade_amount: u64,
        user_stats: &mut UserFeeStats,
        creator_config: &mut CreatorFeeConfig,
        is_maker: bool,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        assert!(!fee_types::registry_paused(registry), E_FEES_PAUSED);

        // Calculate fee
        let total_fee = calculate_fee(registry, user_stats, trade_amount);

        if (total_fee == 0) {
            return coin::zero(ctx)
        };

        // Calculate maker rebate if applicable
        let rebate = if (is_maker) {
            calculate_maker_rebate(registry, user_stats, trade_amount)
        } else {
            0
        };

        let net_fee = if (rebate < total_fee) { total_fee - rebate } else { 0 };

        // Distribute fee (no referrer)
        let (protocol_fee, creator_fee, _) = distribute_fee(registry, net_fee, false);

        // Split payment for fee
        let fee_coin = coin::split(payment, net_fee, ctx);

        // Update creator earnings
        fee_types::add_creator_earnings(creator_config, creator_fee);

        // Update user stats
        fee_types::add_fees_paid(user_stats, net_fee);
        if (rebate > 0) {
            fee_types::add_rebates_earned(user_stats, rebate);

            fee_events::emit_maker_rebate_paid(
                market_id,
                user,
                rebate,
                clock.timestamp_ms(),
            );
        };

        // Update registry totals
        fee_types::add_total_fees(registry, net_fee);

        // Emit fee collected event
        fee_events::emit_fee_collected(
            market_id,
            user,
            trade_amount,
            net_fee,
            protocol_fee,
            creator_fee,
            0, // no referral fee
            clock.timestamp_ms(),
        );

        fee_coin
    }

    /// Collect and distribute fee from a payment (with referrer)
    public fun collect_and_distribute_fee_with_referrer(
        registry: &mut FeeRegistry,
        payment: &mut Coin<SUI>,
        market_id: u64,
        user: address,
        trade_amount: u64,
        user_stats: &mut UserFeeStats,
        creator_config: &mut CreatorFeeConfig,
        referral_config: &mut ReferralConfig,
        is_maker: bool,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        assert!(!fee_types::registry_paused(registry), E_FEES_PAUSED);

        // Calculate fee
        let total_fee = calculate_fee(registry, user_stats, trade_amount);

        if (total_fee == 0) {
            return coin::zero(ctx)
        };

        // Calculate maker rebate if applicable
        let rebate = if (is_maker) {
            calculate_maker_rebate(registry, user_stats, trade_amount)
        } else {
            0
        };

        let net_fee = if (rebate < total_fee) { total_fee - rebate } else { 0 };

        // Distribute fee (with referrer)
        let (protocol_fee, creator_fee, referral_fee) = distribute_fee(registry, net_fee, true);

        // Split payment for fee
        let fee_coin = coin::split(payment, net_fee, ctx);

        // Update creator earnings
        fee_types::add_creator_earnings(creator_config, creator_fee);

        // Update referral earnings
        fee_types::add_referral_config_earnings(referral_config, referral_fee);

        // Update user stats
        fee_types::add_fees_paid(user_stats, net_fee);
        if (rebate > 0) {
            fee_types::add_rebates_earned(user_stats, rebate);

            fee_events::emit_maker_rebate_paid(
                market_id,
                user,
                rebate,
                clock.timestamp_ms(),
            );
        };

        // Update registry totals
        fee_types::add_total_fees(registry, net_fee);

        // Emit fee collected event
        fee_events::emit_fee_collected(
            market_id,
            user,
            trade_amount,
            net_fee,
            protocol_fee,
            creator_fee,
            referral_fee,
            clock.timestamp_ms(),
        );

        fee_coin
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 4: USER FEE STATS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create user fee stats
    public fun create_user_stats(
        user: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ): UserFeeStats {
        let stats = fee_types::new_user_fee_stats(user, ctx);

        fee_events::emit_user_fee_stats_created(
            user,
            clock.timestamp_ms(),
        );

        stats
    }

    /// Update user volume and tier
    public fun update_user_volume(
        registry: &FeeRegistry,
        stats: &mut UserFeeStats,
        amount: u64,
        clock: &Clock,
    ) {
        let now = clock.timestamp_ms();
        let last_updated = fee_types::stats_last_updated(stats);

        // Apply volume decay if needed (simplified: reset if > 30 days since last update)
        if (now - last_updated > fee_types::volume_window_ms()) {
            fee_types::set_volume_30d(stats, 0);
        };

        // Add new volume
        fee_types::add_volume_30d(stats, amount);
        fee_types::add_volume_lifetime(stats, amount);
        fee_types::set_last_updated(stats, now);

        // Update tier based on new volume
        let new_volume = fee_types::stats_volume_30d(stats);
        let old_tier = fee_types::stats_current_tier(stats);
        let new_tier = determine_tier(registry, new_volume);

        if (new_tier != old_tier) {
            fee_types::set_current_tier(stats, new_tier);

            fee_events::emit_tier_changed(
                fee_types::stats_user(stats),
                old_tier,
                new_tier,
                new_volume,
                now,
            );
        };

        fee_events::emit_volume_updated(
            fee_types::stats_user(stats),
            amount,
            fee_types::stats_volume_30d(stats),
            fee_types::stats_volume_lifetime(stats),
            now,
        );
    }

    /// Determine tier based on volume
    fun determine_tier(registry: &FeeRegistry, volume: u64): u8 {
        let tier_count = fee_types::registry_tier_count(registry);
        let mut tier_index: u8 = 0;

        let mut i = 0u64;
        while (i < tier_count) {
            let tier = fee_types::registry_get_tier(registry, i);
            if (volume >= fee_types::tier_min_volume(tier)) {
                tier_index = (i as u8);
            };
            i = i + 1;
        };

        tier_index
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 5: CREATOR FEE MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create creator fee config
    public fun create_creator_config(
        creator: address,
        ctx: &mut TxContext,
    ): CreatorFeeConfig {
        fee_types::new_creator_fee_config(creator, ctx)
    }

    /// Set custom fee for creator's markets (creator only)
    public fun set_custom_creator_fee(
        config: &mut CreatorFeeConfig,
        fee_bps: u16,
        ctx: &TxContext,
    ) {
        assert!(fee_types::creator_config_creator(config) == ctx.sender(), E_NOT_CREATOR);
        assert!(fee_bps <= fee_types::max_fee_bps(), E_INVALID_FEE);

        fee_types::set_custom_fee(config, option::some(fee_bps));
    }

    /// Clear custom fee (revert to default)
    public fun clear_custom_creator_fee(
        config: &mut CreatorFeeConfig,
        ctx: &TxContext,
    ) {
        assert!(fee_types::creator_config_creator(config) == ctx.sender(), E_NOT_CREATOR);

        fee_types::set_custom_fee(config, option::none());
    }

    /// Claim creator earnings
    public fun claim_creator_earnings(
        config: &mut CreatorFeeConfig,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        assert!(fee_types::creator_config_creator(config) == ctx.sender(), E_NOT_CREATOR);

        let amount = fee_types::reset_creator_earnings(config);
        assert!(amount > 0, E_INSUFFICIENT_EARNINGS);

        fee_events::emit_creator_earnings_claimed(
            ctx.sender(),
            amount,
            clock.timestamp_ms(),
        );

        // Note: In a real implementation, the fee would need to be transferred
        // from a fee pool. Here we create a zero coin as placeholder.
        // The actual transfer would happen in the entry function with proper coin handling.
        coin::zero(ctx)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 6: REFERRAL SYSTEM
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a referral code
    public fun create_referral_code(
        registry: &mut ReferralRegistry,
        code: String,
        clock: &Clock,
        ctx: &mut TxContext,
    ): ReferralConfig {
        let code_length = string::length(&code);
        assert!(code_length >= fee_types::min_referral_code_length(), E_CODE_TOO_SHORT);
        assert!(code_length <= fee_types::max_referral_code_length(), E_CODE_TOO_LONG);
        assert!(!fee_types::referral_registry_has_code(registry, &code), E_REFERRAL_CODE_EXISTS);

        let referrer = ctx.sender();

        // Register code in registry
        fee_types::register_code(registry, code, referrer);

        // Create referral config
        let config = fee_types::new_referral_config(referrer, code, ctx);

        fee_events::emit_referral_code_created(
            referrer,
            code,
            clock.timestamp_ms(),
        );

        config
    }

    /// Use a referral code (link user to referrer)
    public fun use_referral_code(
        referral_registry: &mut ReferralRegistry,
        referral_config: &mut ReferralConfig,
        code: String,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let user = ctx.sender();
        let referrer = fee_types::referral_config_referrer(referral_config);

        // Validations
        assert!(fee_types::referral_registry_has_code(referral_registry, &code), E_REFERRAL_CODE_NOT_FOUND);
        assert!(!fee_types::referral_registry_has_referrer(referral_registry, user), E_ALREADY_REFERRED);
        assert!(user != referrer, E_SELF_REFERRAL);
        assert!(fee_types::referral_config_is_active(referral_config), E_CODE_INACTIVE);

        // Link user to referrer
        fee_types::link_user_referrer(referral_registry, user, referrer);
        fee_types::add_referred_user(referral_config, user);

        fee_events::emit_user_referred(
            user,
            referrer,
            code,
            clock.timestamp_ms(),
        );
    }

    /// Claim referral earnings
    public fun claim_referral_earnings(
        config: &mut ReferralConfig,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        assert!(fee_types::referral_config_referrer(config) == ctx.sender(), E_NOT_REFERRER);

        let amount = fee_types::reset_referral_earnings(config);
        assert!(amount > 0, E_INSUFFICIENT_EARNINGS);

        fee_events::emit_referral_earnings_claimed(
            ctx.sender(),
            amount,
            clock.timestamp_ms(),
        );

        // Note: Same as creator earnings - actual transfer handled elsewhere
        coin::zero(ctx)
    }

    /// Deactivate referral code (referrer only)
    public fun deactivate_referral_code(
        config: &mut ReferralConfig,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        assert!(fee_types::referral_config_referrer(config) == ctx.sender(), E_NOT_REFERRER);

        fee_types::set_referral_active(config, false);

        fee_events::emit_referral_code_deactivated(
            ctx.sender(),
            *fee_types::referral_config_code(config),
            clock.timestamp_ms(),
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 7: FEE EXEMPTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Add fee exemption (admin only)
    public fun add_fee_exemption(
        registry: &mut FeeRegistry,
        _admin_cap: &FeeAdminCap,
        addr: address,
        reason: String,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        fee_types::add_exemption(registry, addr);

        fee_events::emit_fee_exemption_added(
            addr,
            ctx.sender(),
            reason,
            clock.timestamp_ms(),
        );
    }

    /// Remove fee exemption (admin only)
    public fun remove_fee_exemption(
        registry: &mut FeeRegistry,
        _admin_cap: &FeeAdminCap,
        addr: address,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        fee_types::remove_exemption(registry, addr);

        fee_events::emit_fee_exemption_removed(
            addr,
            ctx.sender(),
            clock.timestamp_ms(),
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get user's current fee rate in basis points
    public fun get_user_fee_rate(
        registry: &FeeRegistry,
        user_stats: &UserFeeStats,
    ): u16 {
        let user = fee_types::stats_user(user_stats);
        if (fee_types::registry_is_exempt(registry, user)) {
            return 0
        };

        let tier_index = fee_types::stats_current_tier(user_stats);
        if ((tier_index as u64) < fee_types::registry_tier_count(registry)) {
            let tier = fee_types::registry_get_tier(registry, (tier_index as u64));
            fee_types::tier_fee_bps(tier)
        } else {
            fee_types::registry_base_fee_bps(registry)
        }
    }

    /// Check if user has a referrer
    public fun user_has_referrer(
        referral_registry: &ReferralRegistry,
        user: address,
    ): bool {
        fee_types::referral_registry_has_referrer(referral_registry, user)
    }

    /// Get user's referrer address
    public fun get_user_referrer(
        referral_registry: &ReferralRegistry,
        user: address,
    ): Option<address> {
        if (fee_types::referral_registry_has_referrer(referral_registry, user)) {
            option::some(fee_types::referral_registry_get_user_referrer(referral_registry, user))
        } else {
            option::none()
        }
    }
}
