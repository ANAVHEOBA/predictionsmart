/// Fee Types - Structs, constants, getters, setters, constructors
///
/// This module defines all data structures for the dynamic fee system.
/// Other modules use public(package) functions to interact with these types.
module predictionsmart::fee_types {
    use std::string::String;
    use sui::table::{Self, Table};
    use sui::vec_map::{Self, VecMap};

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    // --- Fee Limits ---
    const MAX_FEE_BPS: u16 = 1000;           // 10% max fee
    const MIN_FEE_BPS: u16 = 0;              // 0% min fee
    const MAX_MAKER_REBATE_BPS: u16 = 50;    // 0.5% max rebate
    const BPS_PRECISION: u64 = 10000;        // 100% = 10000 basis points

    // --- Default Shares (must sum to 10000) ---
    const DEFAULT_PROTOCOL_SHARE_BPS: u16 = 5000;   // 50%
    const DEFAULT_CREATOR_SHARE_BPS: u16 = 4000;    // 40%
    const DEFAULT_REFERRAL_SHARE_BPS: u16 = 1000;   // 10%

    // --- Default Rates ---
    const DEFAULT_BASE_FEE_BPS: u16 = 100;      // 1%
    const DEFAULT_MAKER_REBATE_BPS: u16 = 5;    // 0.05%

    // --- Volume Window ---
    const VOLUME_WINDOW_MS: u64 = 2_592_000_000; // 30 days in ms

    // --- Referral ---
    const MAX_REFERRAL_CODE_LENGTH: u64 = 20;
    const MIN_REFERRAL_CODE_LENGTH: u64 = 4;

    // --- Tier Indices ---
    const TIER_BRONZE: u8 = 0;
    const TIER_SILVER: u8 = 1;
    const TIER_GOLD: u8 = 2;
    const TIER_PLATINUM: u8 = 3;
    const TIER_DIAMOND: u8 = 4;

    // ═══════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// FeeRegistry - Global fee configuration (shared object)
    public struct FeeRegistry has key {
        id: UID,
        /// Admin address
        admin: address,
        /// Protocol fee recipient
        protocol_treasury: address,
        /// Default trading fee in basis points
        base_fee_bps: u16,
        /// Protocol's share of fees (in BPS of total fee)
        protocol_share_bps: u16,
        /// Creator's share of fees (in BPS of total fee)
        creator_share_bps: u16,
        /// Referrer's share of fees (in BPS of total fee)
        referral_share_bps: u16,
        /// Rebate for makers (limit order fillers)
        maker_rebate_bps: u16,
        /// Volume-based fee tiers
        tiers: vector<FeeTier>,
        /// Total fees collected lifetime
        total_fees_collected: u64,
        /// Exempted addresses (no fees)
        exemptions: VecMap<address, bool>,
        /// Whether fee collection is paused
        paused: bool,
    }

    /// FeeTier - Volume-based fee discount tier
    public struct FeeTier has copy, drop, store {
        /// Tier name
        name: String,
        /// Minimum 30-day volume to qualify
        min_volume: u64,
        /// Fee rate in basis points
        fee_bps: u16,
        /// Maker rebate in basis points
        maker_rebate_bps: u16,
    }

    /// UserFeeStats - Tracks individual user fee statistics
    public struct UserFeeStats has key, store {
        id: UID,
        /// User address
        user: address,
        /// 30-day rolling trading volume
        volume_30d: u64,
        /// Lifetime trading volume
        volume_lifetime: u64,
        /// Total fees paid
        fees_paid: u64,
        /// Total rebates earned
        rebates_earned: u64,
        /// Earnings from referrals
        referral_earnings: u64,
        /// Current fee tier index
        current_tier: u8,
        /// Last volume update timestamp
        last_updated: u64,
    }

    /// CreatorFeeConfig - Market creator fee configuration
    public struct CreatorFeeConfig has key, store {
        id: UID,
        /// Market creator address
        creator: address,
        /// Custom fee override (if set)
        custom_fee_bps: Option<u16>,
        /// Unclaimed earnings
        earnings: u64,
        /// Lifetime earnings
        total_earned: u64,
        /// Markets created by this creator
        market_count: u64,
    }

    /// ReferralConfig - Referral code configuration
    public struct ReferralConfig has key, store {
        id: UID,
        /// Referrer address
        referrer: address,
        /// Unique referral code
        referral_code: String,
        /// Users who used this code
        referred_users: vector<address>,
        /// Unclaimed earnings
        earnings: u64,
        /// Lifetime earnings
        total_earned: u64,
        /// Whether code is active
        is_active: bool,
    }

    /// FeeAdminCap - Admin capability for fee management
    public struct FeeAdminCap has key, store {
        id: UID,
    }

    /// UserReferralLink - Links user to their referrer (owned by user)
    public struct UserReferralLink has key, store {
        id: UID,
        /// User who was referred
        user: address,
        /// Referrer address
        referrer: address,
        /// Timestamp when linked
        linked_at: u64,
    }

    /// ReferralRegistry - Tracks all referral codes (shared object)
    public struct ReferralRegistry has key {
        id: UID,
        /// Maps referral code to referrer address
        codes: Table<String, address>,
        /// Maps user to their referrer (if any)
        user_referrers: Table<address, address>,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANT GETTERS (public - anyone can read)
    // ═══════════════════════════════════════════════════════════════════════════

    // --- Fee Limits ---
    public fun max_fee_bps(): u16 { MAX_FEE_BPS }
    public fun min_fee_bps(): u16 { MIN_FEE_BPS }
    public fun max_maker_rebate_bps(): u16 { MAX_MAKER_REBATE_BPS }
    public fun bps_precision(): u64 { BPS_PRECISION }

    // --- Default Shares ---
    public fun default_protocol_share_bps(): u16 { DEFAULT_PROTOCOL_SHARE_BPS }
    public fun default_creator_share_bps(): u16 { DEFAULT_CREATOR_SHARE_BPS }
    public fun default_referral_share_bps(): u16 { DEFAULT_REFERRAL_SHARE_BPS }

    // --- Default Rates ---
    public fun default_base_fee_bps(): u16 { DEFAULT_BASE_FEE_BPS }
    public fun default_maker_rebate_bps(): u16 { DEFAULT_MAKER_REBATE_BPS }

    // --- Volume Window ---
    public fun volume_window_ms(): u64 { VOLUME_WINDOW_MS }

    // --- Referral Limits ---
    public fun max_referral_code_length(): u64 { MAX_REFERRAL_CODE_LENGTH }
    public fun min_referral_code_length(): u64 { MIN_REFERRAL_CODE_LENGTH }

    // --- Tier Indices ---
    public fun tier_bronze(): u8 { TIER_BRONZE }
    public fun tier_silver(): u8 { TIER_SILVER }
    public fun tier_gold(): u8 { TIER_GOLD }
    public fun tier_platinum(): u8 { TIER_PLATINUM }
    public fun tier_diamond(): u8 { TIER_DIAMOND }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEE REGISTRY GETTERS (public - anyone can read)
    // ═══════════════════════════════════════════════════════════════════════════

    public fun registry_admin(r: &FeeRegistry): address { r.admin }
    public fun registry_protocol_treasury(r: &FeeRegistry): address { r.protocol_treasury }
    public fun registry_base_fee_bps(r: &FeeRegistry): u16 { r.base_fee_bps }
    public fun registry_protocol_share_bps(r: &FeeRegistry): u16 { r.protocol_share_bps }
    public fun registry_creator_share_bps(r: &FeeRegistry): u16 { r.creator_share_bps }
    public fun registry_referral_share_bps(r: &FeeRegistry): u16 { r.referral_share_bps }
    public fun registry_maker_rebate_bps(r: &FeeRegistry): u16 { r.maker_rebate_bps }
    public fun registry_total_fees_collected(r: &FeeRegistry): u64 { r.total_fees_collected }
    public fun registry_paused(r: &FeeRegistry): bool { r.paused }
    public fun registry_tier_count(r: &FeeRegistry): u64 { vector::length(&r.tiers) }

    /// Get tier at index
    public fun registry_get_tier(r: &FeeRegistry, index: u64): &FeeTier {
        vector::borrow(&r.tiers, index)
    }

    /// Check if address is exempted from fees
    public fun registry_is_exempt(r: &FeeRegistry, addr: address): bool {
        vec_map::contains(&r.exemptions, &addr)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEE TIER GETTERS (public - anyone can read)
    // ═══════════════════════════════════════════════════════════════════════════

    public fun tier_name(t: &FeeTier): &String { &t.name }
    public fun tier_min_volume(t: &FeeTier): u64 { t.min_volume }
    public fun tier_fee_bps(t: &FeeTier): u16 { t.fee_bps }
    public fun tier_maker_rebate_bps(t: &FeeTier): u16 { t.maker_rebate_bps }

    // ═══════════════════════════════════════════════════════════════════════════
    // USER FEE STATS GETTERS (public - anyone can read)
    // ═══════════════════════════════════════════════════════════════════════════

    public fun stats_user(s: &UserFeeStats): address { s.user }
    public fun stats_volume_30d(s: &UserFeeStats): u64 { s.volume_30d }
    public fun stats_volume_lifetime(s: &UserFeeStats): u64 { s.volume_lifetime }
    public fun stats_fees_paid(s: &UserFeeStats): u64 { s.fees_paid }
    public fun stats_rebates_earned(s: &UserFeeStats): u64 { s.rebates_earned }
    public fun stats_referral_earnings(s: &UserFeeStats): u64 { s.referral_earnings }
    public fun stats_current_tier(s: &UserFeeStats): u8 { s.current_tier }
    public fun stats_last_updated(s: &UserFeeStats): u64 { s.last_updated }

    // ═══════════════════════════════════════════════════════════════════════════
    // CREATOR FEE CONFIG GETTERS (public - anyone can read)
    // ═══════════════════════════════════════════════════════════════════════════

    public fun creator_config_creator(c: &CreatorFeeConfig): address { c.creator }
    public fun creator_config_custom_fee_bps(c: &CreatorFeeConfig): &Option<u16> { &c.custom_fee_bps }
    public fun creator_config_earnings(c: &CreatorFeeConfig): u64 { c.earnings }
    public fun creator_config_total_earned(c: &CreatorFeeConfig): u64 { c.total_earned }
    public fun creator_config_market_count(c: &CreatorFeeConfig): u64 { c.market_count }

    // ═══════════════════════════════════════════════════════════════════════════
    // REFERRAL CONFIG GETTERS (public - anyone can read)
    // ═══════════════════════════════════════════════════════════════════════════

    public fun referral_config_referrer(r: &ReferralConfig): address { r.referrer }
    public fun referral_config_code(r: &ReferralConfig): &String { &r.referral_code }
    public fun referral_config_referred_count(r: &ReferralConfig): u64 { vector::length(&r.referred_users) }
    public fun referral_config_earnings(r: &ReferralConfig): u64 { r.earnings }
    public fun referral_config_total_earned(r: &ReferralConfig): u64 { r.total_earned }
    public fun referral_config_is_active(r: &ReferralConfig): bool { r.is_active }

    // ═══════════════════════════════════════════════════════════════════════════
    // USER REFERRAL LINK GETTERS (public - anyone can read)
    // ═══════════════════════════════════════════════════════════════════════════

    public fun referral_link_user(l: &UserReferralLink): address { l.user }
    public fun referral_link_referrer(l: &UserReferralLink): address { l.referrer }
    public fun referral_link_timestamp(l: &UserReferralLink): u64 { l.linked_at }

    // ═══════════════════════════════════════════════════════════════════════════
    // REFERRAL REGISTRY GETTERS (public - anyone can read)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Check if referral code exists
    public fun referral_registry_has_code(r: &ReferralRegistry, code: &String): bool {
        table::contains(&r.codes, *code)
    }

    /// Get referrer address for a code
    public fun referral_registry_get_referrer(r: &ReferralRegistry, code: &String): address {
        *table::borrow(&r.codes, *code)
    }

    /// Check if user has a referrer
    public fun referral_registry_has_referrer(r: &ReferralRegistry, user: address): bool {
        table::contains(&r.user_referrers, user)
    }

    /// Get user's referrer address
    public fun referral_registry_get_user_referrer(r: &ReferralRegistry, user: address): address {
        *table::borrow(&r.user_referrers, user)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTORS (package-only - only this package can create)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a new FeeRegistry with default settings
    public(package) fun new_fee_registry(
        admin: address,
        protocol_treasury: address,
        ctx: &mut TxContext,
    ): FeeRegistry {
        let mut registry = FeeRegistry {
            id: object::new(ctx),
            admin,
            protocol_treasury,
            base_fee_bps: DEFAULT_BASE_FEE_BPS,
            protocol_share_bps: DEFAULT_PROTOCOL_SHARE_BPS,
            creator_share_bps: DEFAULT_CREATOR_SHARE_BPS,
            referral_share_bps: DEFAULT_REFERRAL_SHARE_BPS,
            maker_rebate_bps: DEFAULT_MAKER_REBATE_BPS,
            tiers: vector::empty(),
            total_fees_collected: 0,
            exemptions: vec_map::empty(),
            paused: false,
        };

        // Add default tiers
        vector::push_back(&mut registry.tiers, new_fee_tier(
            std::string::utf8(b"Bronze"), 0, 100, 5
        ));
        vector::push_back(&mut registry.tiers, new_fee_tier(
            std::string::utf8(b"Silver"), 1_000_000_000_000, 80, 10 // 1,000 SUI
        ));
        vector::push_back(&mut registry.tiers, new_fee_tier(
            std::string::utf8(b"Gold"), 10_000_000_000_000, 60, 15 // 10,000 SUI
        ));
        vector::push_back(&mut registry.tiers, new_fee_tier(
            std::string::utf8(b"Platinum"), 100_000_000_000_000, 40, 20 // 100,000 SUI
        ));
        vector::push_back(&mut registry.tiers, new_fee_tier(
            std::string::utf8(b"Diamond"), 1_000_000_000_000_000, 20, 25 // 1,000,000 SUI
        ));

        registry
    }

    /// Create a new FeeTier
    public(package) fun new_fee_tier(
        name: String,
        min_volume: u64,
        fee_bps: u16,
        maker_rebate_bps: u16,
    ): FeeTier {
        FeeTier {
            name,
            min_volume,
            fee_bps,
            maker_rebate_bps,
        }
    }

    /// Create a new FeeAdminCap
    public(package) fun new_fee_admin_cap(ctx: &mut TxContext): FeeAdminCap {
        FeeAdminCap { id: object::new(ctx) }
    }

    /// Create a new UserFeeStats
    public(package) fun new_user_fee_stats(
        user: address,
        ctx: &mut TxContext,
    ): UserFeeStats {
        UserFeeStats {
            id: object::new(ctx),
            user,
            volume_30d: 0,
            volume_lifetime: 0,
            fees_paid: 0,
            rebates_earned: 0,
            referral_earnings: 0,
            current_tier: TIER_BRONZE,
            last_updated: 0,
        }
    }

    /// Create a new CreatorFeeConfig
    public(package) fun new_creator_fee_config(
        creator: address,
        ctx: &mut TxContext,
    ): CreatorFeeConfig {
        CreatorFeeConfig {
            id: object::new(ctx),
            creator,
            custom_fee_bps: option::none(),
            earnings: 0,
            total_earned: 0,
            market_count: 0,
        }
    }

    /// Create a new ReferralConfig
    public(package) fun new_referral_config(
        referrer: address,
        referral_code: String,
        ctx: &mut TxContext,
    ): ReferralConfig {
        ReferralConfig {
            id: object::new(ctx),
            referrer,
            referral_code,
            referred_users: vector::empty(),
            earnings: 0,
            total_earned: 0,
            is_active: true,
        }
    }

    /// Create a new UserReferralLink
    public(package) fun new_user_referral_link(
        user: address,
        referrer: address,
        linked_at: u64,
        ctx: &mut TxContext,
    ): UserReferralLink {
        UserReferralLink {
            id: object::new(ctx),
            user,
            referrer,
            linked_at,
        }
    }

    /// Create a new ReferralRegistry
    public(package) fun new_referral_registry(ctx: &mut TxContext): ReferralRegistry {
        ReferralRegistry {
            id: object::new(ctx),
            codes: table::new(ctx),
            user_referrers: table::new(ctx),
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEE REGISTRY SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Set admin address
    public(package) fun set_registry_admin(r: &mut FeeRegistry, admin: address) {
        r.admin = admin;
    }

    /// Set protocol treasury address
    public(package) fun set_protocol_treasury(r: &mut FeeRegistry, treasury: address) {
        r.protocol_treasury = treasury;
    }

    /// Set base fee in basis points
    public(package) fun set_base_fee_bps(r: &mut FeeRegistry, fee_bps: u16) {
        r.base_fee_bps = fee_bps;
    }

    /// Set protocol share in basis points
    public(package) fun set_protocol_share_bps(r: &mut FeeRegistry, share_bps: u16) {
        r.protocol_share_bps = share_bps;
    }

    /// Set creator share in basis points
    public(package) fun set_creator_share_bps(r: &mut FeeRegistry, share_bps: u16) {
        r.creator_share_bps = share_bps;
    }

    /// Set referral share in basis points
    public(package) fun set_referral_share_bps(r: &mut FeeRegistry, share_bps: u16) {
        r.referral_share_bps = share_bps;
    }

    /// Set maker rebate in basis points
    public(package) fun set_maker_rebate_bps(r: &mut FeeRegistry, rebate_bps: u16) {
        r.maker_rebate_bps = rebate_bps;
    }

    /// Add to total fees collected
    public(package) fun add_total_fees(r: &mut FeeRegistry, amount: u64) {
        r.total_fees_collected = r.total_fees_collected + amount;
    }

    /// Set paused state
    public(package) fun set_paused(r: &mut FeeRegistry, paused: bool) {
        r.paused = paused;
    }

    /// Add fee exemption
    public(package) fun add_exemption(r: &mut FeeRegistry, addr: address) {
        if (!vec_map::contains(&r.exemptions, &addr)) {
            vec_map::insert(&mut r.exemptions, addr, true);
        };
    }

    /// Remove fee exemption
    public(package) fun remove_exemption(r: &mut FeeRegistry, addr: address) {
        if (vec_map::contains(&r.exemptions, &addr)) {
            vec_map::remove(&mut r.exemptions, &addr);
        };
    }

    /// Add a new fee tier
    public(package) fun add_tier(r: &mut FeeRegistry, tier: FeeTier) {
        vector::push_back(&mut r.tiers, tier);
    }

    /// Update tier at index
    public(package) fun update_tier(r: &mut FeeRegistry, index: u64, tier: FeeTier) {
        *vector::borrow_mut(&mut r.tiers, index) = tier;
    }

    /// Remove tier at index
    public(package) fun remove_tier(r: &mut FeeRegistry, index: u64): FeeTier {
        vector::remove(&mut r.tiers, index)
    }

    /// Get mutable reference to tiers
    public(package) fun tiers_mut(r: &mut FeeRegistry): &mut vector<FeeTier> {
        &mut r.tiers
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // USER FEE STATS SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Add to 30-day volume
    public(package) fun add_volume_30d(s: &mut UserFeeStats, amount: u64) {
        s.volume_30d = s.volume_30d + amount;
    }

    /// Set 30-day volume (for decay)
    public(package) fun set_volume_30d(s: &mut UserFeeStats, amount: u64) {
        s.volume_30d = amount;
    }

    /// Add to lifetime volume
    public(package) fun add_volume_lifetime(s: &mut UserFeeStats, amount: u64) {
        s.volume_lifetime = s.volume_lifetime + amount;
    }

    /// Add to fees paid
    public(package) fun add_fees_paid(s: &mut UserFeeStats, amount: u64) {
        s.fees_paid = s.fees_paid + amount;
    }

    /// Add to rebates earned
    public(package) fun add_rebates_earned(s: &mut UserFeeStats, amount: u64) {
        s.rebates_earned = s.rebates_earned + amount;
    }

    /// Add to referral earnings
    public(package) fun add_referral_earnings(s: &mut UserFeeStats, amount: u64) {
        s.referral_earnings = s.referral_earnings + amount;
    }

    /// Set current tier
    public(package) fun set_current_tier(s: &mut UserFeeStats, tier: u8) {
        s.current_tier = tier;
    }

    /// Set last updated timestamp
    public(package) fun set_last_updated(s: &mut UserFeeStats, timestamp: u64) {
        s.last_updated = timestamp;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CREATOR FEE CONFIG SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Set custom fee for creator
    public(package) fun set_custom_fee(c: &mut CreatorFeeConfig, fee_bps: Option<u16>) {
        c.custom_fee_bps = fee_bps;
    }

    /// Add to creator earnings
    public(package) fun add_creator_earnings(c: &mut CreatorFeeConfig, amount: u64) {
        c.earnings = c.earnings + amount;
        c.total_earned = c.total_earned + amount;
    }

    /// Reset creator earnings (after claim)
    public(package) fun reset_creator_earnings(c: &mut CreatorFeeConfig): u64 {
        let amount = c.earnings;
        c.earnings = 0;
        amount
    }

    /// Increment market count
    public(package) fun increment_market_count(c: &mut CreatorFeeConfig) {
        c.market_count = c.market_count + 1;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // REFERRAL CONFIG SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Add referred user
    public(package) fun add_referred_user(r: &mut ReferralConfig, user: address) {
        vector::push_back(&mut r.referred_users, user);
    }

    /// Add to referral earnings
    public(package) fun add_referral_config_earnings(r: &mut ReferralConfig, amount: u64) {
        r.earnings = r.earnings + amount;
        r.total_earned = r.total_earned + amount;
    }

    /// Reset referral earnings (after claim)
    public(package) fun reset_referral_earnings(r: &mut ReferralConfig): u64 {
        let amount = r.earnings;
        r.earnings = 0;
        amount
    }

    /// Set referral code active state
    public(package) fun set_referral_active(r: &mut ReferralConfig, active: bool) {
        r.is_active = active;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // REFERRAL REGISTRY SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Register a referral code
    public(package) fun register_code(r: &mut ReferralRegistry, code: String, referrer: address) {
        table::add(&mut r.codes, code, referrer);
    }

    /// Link user to referrer
    public(package) fun link_user_referrer(r: &mut ReferralRegistry, user: address, referrer: address) {
        table::add(&mut r.user_referrers, user, referrer);
    }

    /// Remove referral code
    public(package) fun remove_code(r: &mut ReferralRegistry, code: String) {
        table::remove(&mut r.codes, code);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TRANSFER FUNCTIONS (must be in defining module)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Share fee registry globally
    #[allow(lint(share_owned, custom_state_change))]
    public(package) fun share_fee_registry(registry: FeeRegistry) {
        transfer::share_object(registry);
    }

    /// Share referral registry globally
    #[allow(lint(share_owned, custom_state_change))]
    public(package) fun share_referral_registry(registry: ReferralRegistry) {
        transfer::share_object(registry);
    }

    /// Transfer fee admin cap
    #[allow(lint(custom_state_change))]
    public(package) fun transfer_fee_admin_cap(cap: FeeAdminCap, recipient: address) {
        transfer::transfer(cap, recipient);
    }

    /// Transfer user fee stats
    #[allow(lint(custom_state_change))]
    public(package) fun transfer_user_fee_stats(stats: UserFeeStats, recipient: address) {
        transfer::transfer(stats, recipient);
    }

    /// Transfer creator fee config
    #[allow(lint(custom_state_change))]
    public(package) fun transfer_creator_fee_config(config: CreatorFeeConfig, recipient: address) {
        transfer::transfer(config, recipient);
    }

    /// Transfer referral config
    #[allow(lint(custom_state_change))]
    public(package) fun transfer_referral_config(config: ReferralConfig, recipient: address) {
        transfer::transfer(config, recipient);
    }

    /// Transfer user referral link
    #[allow(lint(custom_state_change))]
    public(package) fun transfer_user_referral_link(link: UserReferralLink, recipient: address) {
        transfer::transfer(link, recipient);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test_only]
    public fun destroy_fee_registry_for_testing(r: FeeRegistry) {
        let FeeRegistry {
            id, admin: _, protocol_treasury: _, base_fee_bps: _, protocol_share_bps: _,
            creator_share_bps: _, referral_share_bps: _, maker_rebate_bps: _, tiers: _,
            total_fees_collected: _, exemptions: _, paused: _
        } = r;
        object::delete(id);
    }

    #[test_only]
    public fun destroy_fee_admin_cap_for_testing(cap: FeeAdminCap) {
        let FeeAdminCap { id } = cap;
        object::delete(id);
    }

    #[test_only]
    public fun destroy_user_fee_stats_for_testing(s: UserFeeStats) {
        let UserFeeStats {
            id, user: _, volume_30d: _, volume_lifetime: _, fees_paid: _,
            rebates_earned: _, referral_earnings: _, current_tier: _, last_updated: _
        } = s;
        object::delete(id);
    }

    #[test_only]
    public fun destroy_creator_fee_config_for_testing(c: CreatorFeeConfig) {
        let CreatorFeeConfig {
            id, creator: _, custom_fee_bps: _, earnings: _, total_earned: _, market_count: _
        } = c;
        object::delete(id);
    }

    #[test_only]
    public fun destroy_referral_config_for_testing(r: ReferralConfig) {
        let ReferralConfig {
            id, referrer: _, referral_code: _, referred_users: _, earnings: _,
            total_earned: _, is_active: _
        } = r;
        object::delete(id);
    }

    #[test_only]
    public fun destroy_user_referral_link_for_testing(l: UserReferralLink) {
        let UserReferralLink { id, user: _, referrer: _, linked_at: _ } = l;
        object::delete(id);
    }

    #[test_only]
    public fun destroy_referral_registry_for_testing(r: ReferralRegistry) {
        let ReferralRegistry { id, codes, user_referrers } = r;
        table::drop(codes);
        table::drop(user_referrers);
        object::delete(id);
    }

    #[test_only]
    public fun new_fee_registry_for_testing(
        admin: address,
        treasury: address,
        ctx: &mut TxContext,
    ): FeeRegistry {
        new_fee_registry(admin, treasury, ctx)
    }

    #[test_only]
    public fun new_user_fee_stats_for_testing(
        user: address,
        ctx: &mut TxContext,
    ): UserFeeStats {
        new_user_fee_stats(user, ctx)
    }
}
