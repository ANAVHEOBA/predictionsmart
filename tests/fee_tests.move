/// Fee Module Tests
///
/// Comprehensive tests for the fee system functionality.
#[test_only]
module predictionsmart::fee_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use std::string;

    use predictionsmart::fee_types::{Self, FeeRegistry, FeeAdminCap, ReferralRegistry};
    use predictionsmart::fee_operations;
    use predictionsmart::fee_entries;

    // Test addresses
    const ADMIN: address = @0xAD;
    const TREASURY: address = @0x100;
    const USER1: address = @0x1;
    #[allow(unused_const)]
    const USER2: address = @0x2;
    const CREATOR: address = @0xC1;
    const REFERRER: address = @0x200;

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    fun setup_test(): Scenario {
        ts::begin(ADMIN)
    }

    fun create_clock(scenario: &mut Scenario): Clock {
        ts::next_tx(scenario, ADMIN);
        clock::create_for_testing(ts::ctx(scenario))
    }

    fun setup_fee_system(scenario: &mut Scenario, clock: &Clock): (FeeRegistry, ReferralRegistry, FeeAdminCap) {
        ts::next_tx(scenario, ADMIN);
        fee_entries::initialize_for_testing(TREASURY, clock, ts::ctx(scenario))
    }

    #[allow(unused_function)]
    fun create_test_coin(scenario: &mut Scenario, amount: u64): Coin<SUI> {
        coin::mint_for_testing<SUI>(amount, ts::ctx(scenario))
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INITIALIZATION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_initialize_fee_registry() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        // Verify registry defaults
        assert!(fee_types::registry_admin(&registry) == ADMIN);
        assert!(fee_types::registry_protocol_treasury(&registry) == TREASURY);
        assert!(fee_types::registry_base_fee_bps(&registry) == 100); // 1%
        assert!(fee_types::registry_protocol_share_bps(&registry) == 5000); // 50%
        assert!(fee_types::registry_creator_share_bps(&registry) == 4000); // 40%
        assert!(fee_types::registry_referral_share_bps(&registry) == 1000); // 10%
        assert!(fee_types::registry_maker_rebate_bps(&registry) == 5); // 0.05%
        assert!(!fee_types::registry_paused(&registry));

        // Verify default tiers (5 tiers)
        assert!(fee_types::registry_tier_count(&registry) == 5);

        // Cleanup
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_default_tiers() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        // Bronze tier
        let tier0 = fee_types::registry_get_tier(&registry, 0);
        assert!(fee_types::tier_fee_bps(tier0) == 100); // 1%
        assert!(fee_types::tier_min_volume(tier0) == 0);

        // Silver tier
        let tier1 = fee_types::registry_get_tier(&registry, 1);
        assert!(fee_types::tier_fee_bps(tier1) == 80); // 0.8%

        // Gold tier
        let tier2 = fee_types::registry_get_tier(&registry, 2);
        assert!(fee_types::tier_fee_bps(tier2) == 60); // 0.6%

        // Platinum tier
        let tier3 = fee_types::registry_get_tier(&registry, 3);
        assert!(fee_types::tier_fee_bps(tier3) == 40); // 0.4%

        // Diamond tier
        let tier4 = fee_types::registry_get_tier(&registry, 4);
        assert!(fee_types::tier_fee_bps(tier4) == 20); // 0.2%

        // Cleanup
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEE CONFIG TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_set_base_fee() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (mut registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        // Set new base fee
        fee_operations::set_base_fee(&mut registry, &admin_cap, 200, &clock, ts::ctx(&mut scenario));

        assert!(fee_types::registry_base_fee_bps(&registry) == 200); // 2%

        // Cleanup
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = fee_operations::E_INVALID_FEE)]
    fun test_set_base_fee_too_high() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (mut registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        // Try to set fee > 10%
        fee_operations::set_base_fee(&mut registry, &admin_cap, 1001, &clock, ts::ctx(&mut scenario));

        // Cleanup (won't reach here)
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_set_shares() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (mut registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        // Set new shares - order matters! Must reduce first before increasing others
        // Initial: protocol=5000, creator=4000, referral=1000
        // Step 1: Lower referral first
        fee_operations::set_referral_share(&mut registry, &admin_cap, 500, &clock, ts::ctx(&mut scenario));
        // Step 2: Lower creator
        fee_operations::set_creator_share(&mut registry, &admin_cap, 3500, &clock, ts::ctx(&mut scenario));
        // Step 3: Now we can increase protocol (5000 + 3500 + 500 = 9000, can go up to 6000)
        fee_operations::set_protocol_share(&mut registry, &admin_cap, 6000, &clock, ts::ctx(&mut scenario));

        assert!(fee_types::registry_protocol_share_bps(&registry) == 6000);
        assert!(fee_types::registry_creator_share_bps(&registry) == 3500);
        assert!(fee_types::registry_referral_share_bps(&registry) == 500);

        // Cleanup
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = fee_operations::E_SHARES_EXCEED_100)]
    fun test_shares_exceed_100() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (mut registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        // Try to set shares > 100%
        fee_operations::set_protocol_share(&mut registry, &admin_cap, 9000, &clock, ts::ctx(&mut scenario));

        // Cleanup (won't reach here)
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_set_treasury() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (mut registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        let new_treasury = @0x300;
        fee_operations::set_treasury(&mut registry, &admin_cap, new_treasury, &clock, ts::ctx(&mut scenario));

        assert!(fee_types::registry_protocol_treasury(&registry) == new_treasury);

        // Cleanup
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_pause_unpause() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (mut registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        // Pause
        fee_operations::pause_fees(&mut registry, &admin_cap, &clock, ts::ctx(&mut scenario));
        assert!(fee_types::registry_paused(&registry));

        // Unpause
        fee_operations::unpause_fees(&mut registry, &admin_cap, &clock, ts::ctx(&mut scenario));
        assert!(!fee_types::registry_paused(&registry));

        // Cleanup
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEE TIER TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_update_fee_tier() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (mut registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        // Update Bronze tier
        fee_operations::update_fee_tier(
            &mut registry,
            &admin_cap,
            0,
            string::utf8(b"Bronze Updated"),
            0,
            90, // 0.9%
            10,
            &clock,
        );

        let tier0 = fee_types::registry_get_tier(&registry, 0);
        assert!(fee_types::tier_fee_bps(tier0) == 90);

        // Cleanup
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = fee_operations::E_TIER_NOT_FOUND)]
    fun test_update_invalid_tier() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (mut registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        // Try to update non-existent tier
        fee_operations::update_fee_tier(
            &mut registry,
            &admin_cap,
            99,
            string::utf8(b"Invalid"),
            0,
            50,
            10,
            &clock,
        );

        // Cleanup (won't reach here)
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEE CALCULATION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_calculate_fee() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        ts::next_tx(&mut scenario, USER1);
        let user_stats = fee_entries::create_user_stats_for_testing(USER1, &clock, ts::ctx(&mut scenario));

        // Calculate fee for 1000 SUI trade at Bronze tier (1%)
        let trade_amount = 1_000_000_000_000u64; // 1000 SUI
        let fee = fee_operations::calculate_fee(&registry, &user_stats, trade_amount);

        // Expected: 1000 * 0.01 = 10 SUI
        assert!(fee == 10_000_000_000);

        // Cleanup
        fee_types::destroy_user_fee_stats_for_testing(user_stats);
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_calculate_fee_simple() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        // Calculate fee without stats
        let trade_amount = 1_000_000_000_000u64; // 1000 SUI
        let fee = fee_operations::calculate_fee_simple(&registry, USER1, trade_amount);

        // Expected: 1000 * 0.01 = 10 SUI (base rate)
        assert!(fee == 10_000_000_000);

        // Cleanup
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_calculate_maker_rebate() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        ts::next_tx(&mut scenario, USER1);
        let user_stats = fee_entries::create_user_stats_for_testing(USER1, &clock, ts::ctx(&mut scenario));

        // Calculate rebate for 1000 SUI trade at Bronze tier (0.05%)
        let trade_amount = 1_000_000_000_000u64; // 1000 SUI
        let rebate = fee_operations::calculate_maker_rebate(&registry, &user_stats, trade_amount);

        // Expected: 1000 * 0.0005 = 0.5 SUI
        assert!(rebate == 500_000_000);

        // Cleanup
        fee_types::destroy_user_fee_stats_for_testing(user_stats);
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_distribute_fee() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        let total_fee = 10_000_000_000u64; // 10 SUI

        // Without referrer
        let (protocol_fee, creator_fee, referral_fee) = fee_operations::distribute_fee(&registry, total_fee, false);

        // Protocol: 50% + 10% (referral goes to protocol) = 60%
        assert!(protocol_fee == 6_000_000_000); // 6 SUI
        // Creator: 40%
        assert!(creator_fee == 4_000_000_000); // 4 SUI
        // Referrer: 0
        assert!(referral_fee == 0);

        // With referrer
        let (protocol_fee2, creator_fee2, referral_fee2) = fee_operations::distribute_fee(&registry, total_fee, true);

        // Protocol: 50%
        assert!(protocol_fee2 == 5_000_000_000); // 5 SUI
        // Creator: 40%
        assert!(creator_fee2 == 4_000_000_000); // 4 SUI
        // Referrer: 10%
        assert!(referral_fee2 == 1_000_000_000); // 1 SUI

        // Cleanup
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // USER FEE STATS TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_create_user_stats() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, USER1);
        let user_stats = fee_entries::create_user_stats_for_testing(USER1, &clock, ts::ctx(&mut scenario));

        assert!(fee_types::stats_user(&user_stats) == USER1);
        assert!(fee_types::stats_volume_30d(&user_stats) == 0);
        assert!(fee_types::stats_volume_lifetime(&user_stats) == 0);
        assert!(fee_types::stats_current_tier(&user_stats) == 0); // Bronze

        // Cleanup
        fee_types::destroy_user_fee_stats_for_testing(user_stats);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_update_user_volume() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        ts::next_tx(&mut scenario, USER1);
        let mut user_stats = fee_entries::create_user_stats_for_testing(USER1, &clock, ts::ctx(&mut scenario));

        // Add volume
        let volume = 1_000_000_000_000u64; // 1000 SUI
        fee_operations::update_user_volume(&registry, &mut user_stats, volume, &clock);

        assert!(fee_types::stats_volume_30d(&user_stats) == volume);
        assert!(fee_types::stats_volume_lifetime(&user_stats) == volume);

        // Cleanup
        fee_types::destroy_user_fee_stats_for_testing(user_stats);
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CREATOR FEE CONFIG TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_create_creator_config() {
        let mut scenario = setup_test();

        ts::next_tx(&mut scenario, CREATOR);
        let config = fee_entries::create_creator_config_for_testing(CREATOR, ts::ctx(&mut scenario));

        assert!(fee_types::creator_config_creator(&config) == CREATOR);
        assert!(fee_types::creator_config_earnings(&config) == 0);
        assert!(option::is_none(fee_types::creator_config_custom_fee_bps(&config)));

        // Cleanup
        fee_types::destroy_creator_fee_config_for_testing(config);
        ts::end(scenario);
    }

    #[test]
    fun test_set_custom_creator_fee() {
        let mut scenario = setup_test();

        ts::next_tx(&mut scenario, CREATOR);
        let mut config = fee_entries::create_creator_config_for_testing(CREATOR, ts::ctx(&mut scenario));

        // Set custom fee
        fee_operations::set_custom_creator_fee(&mut config, 150, ts::ctx(&mut scenario));

        let custom_fee = fee_types::creator_config_custom_fee_bps(&config);
        assert!(option::is_some(custom_fee));
        assert!(*option::borrow(custom_fee) == 150);

        // Clear custom fee
        fee_operations::clear_custom_creator_fee(&mut config, ts::ctx(&mut scenario));
        assert!(option::is_none(fee_types::creator_config_custom_fee_bps(&config)));

        // Cleanup
        fee_types::destroy_creator_fee_config_for_testing(config);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = fee_operations::E_NOT_CREATOR)]
    fun test_set_custom_fee_not_creator() {
        let mut scenario = setup_test();

        ts::next_tx(&mut scenario, CREATOR);
        let mut config = fee_entries::create_creator_config_for_testing(CREATOR, ts::ctx(&mut scenario));

        // Try to set fee as different user
        ts::next_tx(&mut scenario, USER1);
        fee_operations::set_custom_creator_fee(&mut config, 150, ts::ctx(&mut scenario));

        // Cleanup (won't reach here)
        fee_types::destroy_creator_fee_config_for_testing(config);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // REFERRAL SYSTEM TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_create_referral_code() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (registry, mut referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        ts::next_tx(&mut scenario, REFERRER);
        let code = string::utf8(b"MYCODE");
        let referral_config = fee_entries::create_referral_config_for_testing(
            &mut referral_registry,
            code,
            &clock,
            ts::ctx(&mut scenario),
        );

        assert!(fee_types::referral_config_referrer(&referral_config) == REFERRER);
        assert!(fee_types::referral_config_is_active(&referral_config));
        assert!(fee_types::referral_registry_has_code(&referral_registry, &code));

        // Cleanup
        fee_types::destroy_referral_config_for_testing(referral_config);
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = fee_operations::E_CODE_TOO_SHORT)]
    fun test_referral_code_too_short() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (registry, mut referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        ts::next_tx(&mut scenario, REFERRER);
        let code = string::utf8(b"AB"); // Too short
        let referral_config = fee_entries::create_referral_config_for_testing(
            &mut referral_registry,
            code,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Cleanup (won't reach here)
        fee_types::destroy_referral_config_for_testing(referral_config);
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = fee_operations::E_REFERRAL_CODE_EXISTS)]
    fun test_duplicate_referral_code() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (registry, mut referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        ts::next_tx(&mut scenario, REFERRER);
        let code = string::utf8(b"MYCODE");
        let referral_config1 = fee_entries::create_referral_config_for_testing(
            &mut referral_registry,
            code,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Try to create same code again
        ts::next_tx(&mut scenario, USER1);
        let referral_config2 = fee_entries::create_referral_config_for_testing(
            &mut referral_registry,
            string::utf8(b"MYCODE"),
            &clock,
            ts::ctx(&mut scenario),
        );

        // Cleanup (won't reach here)
        fee_types::destroy_referral_config_for_testing(referral_config1);
        fee_types::destroy_referral_config_for_testing(referral_config2);
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_use_referral_code() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (registry, mut referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        // Create referral code
        ts::next_tx(&mut scenario, REFERRER);
        let code = string::utf8(b"MYCODE");
        let mut referral_config = fee_entries::create_referral_config_for_testing(
            &mut referral_registry,
            code,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Use referral code
        ts::next_tx(&mut scenario, USER1);
        fee_operations::use_referral_code(
            &mut referral_registry,
            &mut referral_config,
            code,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Verify user is linked
        assert!(fee_types::referral_registry_has_referrer(&referral_registry, USER1));
        assert!(fee_types::referral_registry_get_user_referrer(&referral_registry, USER1) == REFERRER);
        assert!(fee_types::referral_config_referred_count(&referral_config) == 1);

        // Cleanup
        fee_types::destroy_referral_config_for_testing(referral_config);
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = fee_operations::E_SELF_REFERRAL)]
    fun test_self_referral() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (registry, mut referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        // Create referral code
        ts::next_tx(&mut scenario, REFERRER);
        let code = string::utf8(b"MYCODE");
        let mut referral_config = fee_entries::create_referral_config_for_testing(
            &mut referral_registry,
            code,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Try to use own code
        fee_operations::use_referral_code(
            &mut referral_registry,
            &mut referral_config,
            code,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Cleanup (won't reach here)
        fee_types::destroy_referral_config_for_testing(referral_config);
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_deactivate_referral_code() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (registry, mut referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        ts::next_tx(&mut scenario, REFERRER);
        let code = string::utf8(b"MYCODE");
        let mut referral_config = fee_entries::create_referral_config_for_testing(
            &mut referral_registry,
            code,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Deactivate
        fee_operations::deactivate_referral_code(&mut referral_config, &clock, ts::ctx(&mut scenario));
        assert!(!fee_types::referral_config_is_active(&referral_config));

        // Cleanup
        fee_types::destroy_referral_config_for_testing(referral_config);
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEE EXEMPTION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_add_fee_exemption() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (mut registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        // Add exemption
        fee_operations::add_fee_exemption(
            &mut registry,
            &admin_cap,
            USER1,
            string::utf8(b"Market maker"),
            &clock,
            ts::ctx(&mut scenario),
        );

        assert!(fee_types::registry_is_exempt(&registry, USER1));

        // Calculate fee - should be 0 for exempt user
        let fee = fee_operations::calculate_fee_simple(&registry, USER1, 1_000_000_000_000);
        assert!(fee == 0);

        // Remove exemption
        fee_operations::remove_fee_exemption(&mut registry, &admin_cap, USER1, &clock, ts::ctx(&mut scenario));
        assert!(!fee_types::registry_is_exempt(&registry, USER1));

        // Cleanup
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPER FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_get_user_fee_rate() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        ts::next_tx(&mut scenario, USER1);
        let user_stats = fee_entries::create_user_stats_for_testing(USER1, &clock, ts::ctx(&mut scenario));

        let fee_rate = fee_operations::get_user_fee_rate(&registry, &user_stats);
        assert!(fee_rate == 100); // 1% for Bronze tier

        // Cleanup
        fee_types::destroy_user_fee_stats_for_testing(user_stats);
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_user_has_referrer() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (registry, mut referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        // User without referrer
        assert!(!fee_operations::user_has_referrer(&referral_registry, USER1));

        // Create and use referral code
        ts::next_tx(&mut scenario, REFERRER);
        let code = string::utf8(b"MYCODE");
        let mut referral_config = fee_entries::create_referral_config_for_testing(
            &mut referral_registry,
            code,
            &clock,
            ts::ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, USER1);
        fee_operations::use_referral_code(
            &mut referral_registry,
            &mut referral_config,
            code,
            &clock,
            ts::ctx(&mut scenario),
        );

        // User with referrer
        assert!(fee_operations::user_has_referrer(&referral_registry, USER1));

        let referrer = fee_operations::get_user_referrer(&referral_registry, USER1);
        assert!(option::is_some(&referrer));
        assert!(*option::borrow(&referrer) == REFERRER);

        // Cleanup
        fee_types::destroy_referral_config_for_testing(referral_config);
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_transfer_admin() {
        let mut scenario = setup_test();
        let clock = create_clock(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        let (mut registry, referral_registry, admin_cap) = setup_fee_system(&mut scenario, &clock);

        // Transfer admin
        let new_admin = @0x400;
        fee_operations::transfer_admin(&mut registry, &admin_cap, new_admin, &clock);

        assert!(fee_types::registry_admin(&registry) == new_admin);

        // Cleanup
        fee_types::destroy_fee_registry_for_testing(registry);
        fee_types::destroy_referral_registry_for_testing(referral_registry);
        fee_types::destroy_fee_admin_cap_for_testing(admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
}
