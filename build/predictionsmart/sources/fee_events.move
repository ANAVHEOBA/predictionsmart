/// Fee Events - Event structs and emit functions
///
/// Events must be defined in the same module that emits them.
/// Other modules call these emit functions to broadcast events.
module predictionsmart::fee_events {
    use sui::event;
    use std::string::String;

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENT STRUCTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emitted when fee registry is initialized
    public struct FeeRegistryInitialized has copy, drop {
        admin: address,
        protocol_treasury: address,
        base_fee_bps: u16,
        protocol_share_bps: u16,
        creator_share_bps: u16,
        referral_share_bps: u16,
        timestamp: u64,
    }

    /// Emitted when fee config is updated
    public struct FeeConfigUpdated has copy, drop {
        field: String,
        old_value: u64,
        new_value: u64,
        updated_by: address,
        timestamp: u64,
    }

    /// Emitted when a fee tier is added
    public struct FeeTierAdded has copy, drop {
        tier_index: u64,
        name: String,
        min_volume: u64,
        fee_bps: u16,
        maker_rebate_bps: u16,
        timestamp: u64,
    }

    /// Emitted when a fee tier is updated
    public struct FeeTierUpdated has copy, drop {
        tier_index: u64,
        old_fee_bps: u16,
        new_fee_bps: u16,
        old_min_volume: u64,
        new_min_volume: u64,
        timestamp: u64,
    }

    /// Emitted when a fee tier is removed
    public struct FeeTierRemoved has copy, drop {
        tier_index: u64,
        name: String,
        timestamp: u64,
    }

    /// Emitted when fee is collected from a trade
    public struct FeeCollected has copy, drop {
        market_id: u64,
        user: address,
        trade_amount: u64,
        total_fee: u64,
        protocol_fee: u64,
        creator_fee: u64,
        referral_fee: u64,
        timestamp: u64,
    }

    /// Emitted when maker rebate is paid
    public struct MakerRebatePaid has copy, drop {
        market_id: u64,
        user: address,
        rebate_amount: u64,
        timestamp: u64,
    }

    /// Emitted when user's fee tier changes
    public struct TierChanged has copy, drop {
        user: address,
        old_tier: u8,
        new_tier: u8,
        volume_30d: u64,
        timestamp: u64,
    }

    /// Emitted when creator claims earnings
    public struct CreatorEarningsClaimed has copy, drop {
        creator: address,
        amount: u64,
        timestamp: u64,
    }

    /// Emitted when referral code is created
    public struct ReferralCodeCreated has copy, drop {
        referrer: address,
        code: String,
        timestamp: u64,
    }

    /// Emitted when user is linked to referrer
    public struct UserReferred has copy, drop {
        user: address,
        referrer: address,
        code: String,
        timestamp: u64,
    }

    /// Emitted when referrer claims earnings
    public struct ReferralEarningsClaimed has copy, drop {
        referrer: address,
        amount: u64,
        timestamp: u64,
    }

    /// Emitted when fee exemption is added
    public struct FeeExemptionAdded has copy, drop {
        addr: address,
        added_by: address,
        reason: String,
        timestamp: u64,
    }

    /// Emitted when fee exemption is removed
    public struct FeeExemptionRemoved has copy, drop {
        addr: address,
        removed_by: address,
        timestamp: u64,
    }

    /// Emitted when user fee stats are created
    public struct UserFeeStatsCreated has copy, drop {
        user: address,
        timestamp: u64,
    }

    /// Emitted when user volume is updated
    public struct VolumeUpdated has copy, drop {
        user: address,
        amount: u64,
        new_volume_30d: u64,
        new_volume_lifetime: u64,
        timestamp: u64,
    }

    /// Emitted when fee collection is paused/unpaused
    public struct FeesPausedStateChanged has copy, drop {
        paused: bool,
        changed_by: address,
        timestamp: u64,
    }

    /// Emitted when referral code is deactivated
    public struct ReferralCodeDeactivated has copy, drop {
        referrer: address,
        code: String,
        timestamp: u64,
    }

    /// Emitted when protocol treasury is changed
    public struct TreasuryUpdated has copy, drop {
        old_treasury: address,
        new_treasury: address,
        updated_by: address,
        timestamp: u64,
    }

    /// Emitted when admin is transferred
    public struct AdminTransferred has copy, drop {
        old_admin: address,
        new_admin: address,
        timestamp: u64,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EMIT FUNCTIONS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emit FeeRegistryInitialized event
    public(package) fun emit_fee_registry_initialized(
        admin: address,
        protocol_treasury: address,
        base_fee_bps: u16,
        protocol_share_bps: u16,
        creator_share_bps: u16,
        referral_share_bps: u16,
        timestamp: u64,
    ) {
        event::emit(FeeRegistryInitialized {
            admin,
            protocol_treasury,
            base_fee_bps,
            protocol_share_bps,
            creator_share_bps,
            referral_share_bps,
            timestamp,
        });
    }

    /// Emit FeeConfigUpdated event
    public(package) fun emit_fee_config_updated(
        field: String,
        old_value: u64,
        new_value: u64,
        updated_by: address,
        timestamp: u64,
    ) {
        event::emit(FeeConfigUpdated {
            field,
            old_value,
            new_value,
            updated_by,
            timestamp,
        });
    }

    /// Emit FeeTierAdded event
    public(package) fun emit_fee_tier_added(
        tier_index: u64,
        name: String,
        min_volume: u64,
        fee_bps: u16,
        maker_rebate_bps: u16,
        timestamp: u64,
    ) {
        event::emit(FeeTierAdded {
            tier_index,
            name,
            min_volume,
            fee_bps,
            maker_rebate_bps,
            timestamp,
        });
    }

    /// Emit FeeTierUpdated event
    public(package) fun emit_fee_tier_updated(
        tier_index: u64,
        old_fee_bps: u16,
        new_fee_bps: u16,
        old_min_volume: u64,
        new_min_volume: u64,
        timestamp: u64,
    ) {
        event::emit(FeeTierUpdated {
            tier_index,
            old_fee_bps,
            new_fee_bps,
            old_min_volume,
            new_min_volume,
            timestamp,
        });
    }

    /// Emit FeeTierRemoved event
    public(package) fun emit_fee_tier_removed(
        tier_index: u64,
        name: String,
        timestamp: u64,
    ) {
        event::emit(FeeTierRemoved {
            tier_index,
            name,
            timestamp,
        });
    }

    /// Emit FeeCollected event
    public(package) fun emit_fee_collected(
        market_id: u64,
        user: address,
        trade_amount: u64,
        total_fee: u64,
        protocol_fee: u64,
        creator_fee: u64,
        referral_fee: u64,
        timestamp: u64,
    ) {
        event::emit(FeeCollected {
            market_id,
            user,
            trade_amount,
            total_fee,
            protocol_fee,
            creator_fee,
            referral_fee,
            timestamp,
        });
    }

    /// Emit MakerRebatePaid event
    public(package) fun emit_maker_rebate_paid(
        market_id: u64,
        user: address,
        rebate_amount: u64,
        timestamp: u64,
    ) {
        event::emit(MakerRebatePaid {
            market_id,
            user,
            rebate_amount,
            timestamp,
        });
    }

    /// Emit TierChanged event
    public(package) fun emit_tier_changed(
        user: address,
        old_tier: u8,
        new_tier: u8,
        volume_30d: u64,
        timestamp: u64,
    ) {
        event::emit(TierChanged {
            user,
            old_tier,
            new_tier,
            volume_30d,
            timestamp,
        });
    }

    /// Emit CreatorEarningsClaimed event
    public(package) fun emit_creator_earnings_claimed(
        creator: address,
        amount: u64,
        timestamp: u64,
    ) {
        event::emit(CreatorEarningsClaimed {
            creator,
            amount,
            timestamp,
        });
    }

    /// Emit ReferralCodeCreated event
    public(package) fun emit_referral_code_created(
        referrer: address,
        code: String,
        timestamp: u64,
    ) {
        event::emit(ReferralCodeCreated {
            referrer,
            code,
            timestamp,
        });
    }

    /// Emit UserReferred event
    public(package) fun emit_user_referred(
        user: address,
        referrer: address,
        code: String,
        timestamp: u64,
    ) {
        event::emit(UserReferred {
            user,
            referrer,
            code,
            timestamp,
        });
    }

    /// Emit ReferralEarningsClaimed event
    public(package) fun emit_referral_earnings_claimed(
        referrer: address,
        amount: u64,
        timestamp: u64,
    ) {
        event::emit(ReferralEarningsClaimed {
            referrer,
            amount,
            timestamp,
        });
    }

    /// Emit FeeExemptionAdded event
    public(package) fun emit_fee_exemption_added(
        addr: address,
        added_by: address,
        reason: String,
        timestamp: u64,
    ) {
        event::emit(FeeExemptionAdded {
            addr,
            added_by,
            reason,
            timestamp,
        });
    }

    /// Emit FeeExemptionRemoved event
    public(package) fun emit_fee_exemption_removed(
        addr: address,
        removed_by: address,
        timestamp: u64,
    ) {
        event::emit(FeeExemptionRemoved {
            addr,
            removed_by,
            timestamp,
        });
    }

    /// Emit UserFeeStatsCreated event
    public(package) fun emit_user_fee_stats_created(
        user: address,
        timestamp: u64,
    ) {
        event::emit(UserFeeStatsCreated {
            user,
            timestamp,
        });
    }

    /// Emit VolumeUpdated event
    public(package) fun emit_volume_updated(
        user: address,
        amount: u64,
        new_volume_30d: u64,
        new_volume_lifetime: u64,
        timestamp: u64,
    ) {
        event::emit(VolumeUpdated {
            user,
            amount,
            new_volume_30d,
            new_volume_lifetime,
            timestamp,
        });
    }

    /// Emit FeesPausedStateChanged event
    public(package) fun emit_fees_paused_state_changed(
        paused: bool,
        changed_by: address,
        timestamp: u64,
    ) {
        event::emit(FeesPausedStateChanged {
            paused,
            changed_by,
            timestamp,
        });
    }

    /// Emit ReferralCodeDeactivated event
    public(package) fun emit_referral_code_deactivated(
        referrer: address,
        code: String,
        timestamp: u64,
    ) {
        event::emit(ReferralCodeDeactivated {
            referrer,
            code,
            timestamp,
        });
    }

    /// Emit TreasuryUpdated event
    public(package) fun emit_treasury_updated(
        old_treasury: address,
        new_treasury: address,
        updated_by: address,
        timestamp: u64,
    ) {
        event::emit(TreasuryUpdated {
            old_treasury,
            new_treasury,
            updated_by,
            timestamp,
        });
    }

    /// Emit AdminTransferred event
    public(package) fun emit_admin_transferred(
        old_admin: address,
        new_admin: address,
        timestamp: u64,
    ) {
        event::emit(AdminTransferred {
            old_admin,
            new_admin,
            timestamp,
        });
    }
}
