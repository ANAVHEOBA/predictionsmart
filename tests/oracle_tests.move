/// Oracle Tests - Tests for oracle module Features 1-3
#[test_only]
module predictionsmart::oracle_tests {
    use std::string;
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    use predictionsmart::oracle_types::{Self, OracleRegistry, OracleAdminCap};
    use predictionsmart::oracle_entries;
    use predictionsmart::oracle_operations;
    use predictionsmart::market_types::{Self, Market, MarketRegistry, AdminCap};
    use predictionsmart::market_entries;

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;
    const USER3: address = @0x3;

    const ONE_SUI: u64 = 1_000_000_000;
    const DEFAULT_BOND: u64 = 1_000_000_000;
    const DEFAULT_DISPUTE_WINDOW: u64 = 7_200_000; // 2 hours

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

    fun create_sui_coin(scenario: &mut Scenario, amount: u64, sender: address): Coin<SUI> {
        ts::next_tx(scenario, sender);
        coin::mint_for_testing<SUI>(amount, ts::ctx(scenario))
    }

    fun create_oracle_registry(scenario: &mut Scenario): (OracleRegistry, OracleAdminCap) {
        ts::next_tx(scenario, ADMIN);
        oracle_entries::initialize_registry_for_testing(ts::ctx(scenario))
    }

    fun create_market_registry(scenario: &mut Scenario): (MarketRegistry, AdminCap) {
        ts::next_tx(scenario, ADMIN);
        market_entries::initialize_for_testing(ts::ctx(scenario))
    }

    fun create_oracle_market(
        scenario: &mut Scenario,
        market_registry: &mut MarketRegistry,
        clock: &Clock,
    ): Market {
        let fee = create_sui_coin(scenario, ONE_SUI, USER1);
        ts::next_tx(scenario, USER1);

        let now = clock::timestamp_ms(clock);
        // Need end_time > now + min_duration_ms (3600000), so add extra time
        let end_time = now + 7_200_000; // 2 hours from now
        let resolution_time = end_time;

        market_entries::create_market_for_testing(
            market_registry,
            string::utf8(b"Will BTC reach $100k?"),
            string::utf8(b"Description"),
            string::utf8(b"https://image.url"),
            string::utf8(b"Crypto"),
            vector[string::utf8(b"BTC")],
            string::utf8(b"Yes"),
            string::utf8(b"No"),
            end_time,
            resolution_time,
            string::utf8(b"daily"),
            market_types::resolution_oracle(), // Oracle resolution type
            string::utf8(b"pyth:BTC/USD"),
            100, // 1% fee
            fee,
            clock,
            ts::ctx(scenario),
        )
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: ORACLE REGISTRY TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_initialize_registry() {
        let mut scenario = setup_test();
        let (registry, admin_cap) = create_oracle_registry(&mut scenario);

        // Verify registry state
        let (admin, default_bond, default_window, total_requests) =
            oracle_operations::get_registry_info(&registry);

        assert!(admin == ADMIN);
        assert!(default_bond == DEFAULT_BOND);
        assert!(default_window == DEFAULT_DISPUTE_WINDOW);
        assert!(total_requests == 0);

        // Cleanup
        oracle_types::destroy_oracle_registry_for_testing(registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(admin_cap);
        ts::end(scenario);
    }

    #[test]
    fun test_register_provider() {
        let mut scenario = setup_test();
        let (mut registry, admin_cap) = create_oracle_registry(&mut scenario);

        // Register provider
        ts::next_tx(&mut scenario, ADMIN);
        oracle_operations::register_provider(
            &mut registry,
            &admin_cap,
            string::utf8(b"pyth"),
            oracle_types::provider_price_feed(),
            ONE_SUI,
            DEFAULT_DISPUTE_WINDOW,
            ts::ctx(&mut scenario),
        );

        // Verify provider exists
        assert!(oracle_types::registry_has_provider(&registry, string::utf8(b"pyth")));

        // Get provider info
        let (provider_type, is_active, min_bond, dispute_window, total_resolutions) =
            oracle_operations::get_provider_info(&registry, string::utf8(b"pyth"));

        assert!(provider_type == oracle_types::provider_price_feed());
        assert!(is_active == true);
        assert!(min_bond == ONE_SUI);
        assert!(dispute_window == DEFAULT_DISPUTE_WINDOW);
        assert!(total_resolutions == 0);

        // Cleanup
        oracle_types::remove_provider_for_testing(&mut registry, string::utf8(b"pyth"));
        oracle_types::destroy_oracle_registry_for_testing(registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(admin_cap);
        ts::end(scenario);
    }

    #[test]
    fun test_register_multiple_providers() {
        let mut scenario = setup_test();
        let (mut registry, admin_cap) = create_oracle_registry(&mut scenario);

        // Register pyth provider
        ts::next_tx(&mut scenario, ADMIN);
        oracle_operations::register_provider(
            &mut registry,
            &admin_cap,
            string::utf8(b"pyth"),
            oracle_types::provider_price_feed(),
            ONE_SUI,
            DEFAULT_DISPUTE_WINDOW,
            ts::ctx(&mut scenario),
        );

        // Register uma provider
        ts::next_tx(&mut scenario, ADMIN);
        oracle_operations::register_provider(
            &mut registry,
            &admin_cap,
            string::utf8(b"uma"),
            oracle_types::provider_optimistic(),
            ONE_SUI * 2,
            DEFAULT_DISPUTE_WINDOW * 2,
            ts::ctx(&mut scenario),
        );

        // Verify both exist
        assert!(oracle_types::registry_has_provider(&registry, string::utf8(b"pyth")));
        assert!(oracle_types::registry_has_provider(&registry, string::utf8(b"uma")));

        // Cleanup
        oracle_types::remove_provider_for_testing(&mut registry, string::utf8(b"pyth"));
        oracle_types::remove_provider_for_testing(&mut registry, string::utf8(b"uma"));
        oracle_types::destroy_oracle_registry_for_testing(registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(admin_cap);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = oracle_operations::E_PROVIDER_EXISTS)]
    fun test_register_provider_already_exists() {
        let mut scenario = setup_test();
        let (mut registry, admin_cap) = create_oracle_registry(&mut scenario);

        // Register provider
        ts::next_tx(&mut scenario, ADMIN);
        oracle_operations::register_provider(
            &mut registry,
            &admin_cap,
            string::utf8(b"pyth"),
            oracle_types::provider_price_feed(),
            ONE_SUI,
            DEFAULT_DISPUTE_WINDOW,
            ts::ctx(&mut scenario),
        );

        // Try to register again - should fail
        ts::next_tx(&mut scenario, ADMIN);
        oracle_operations::register_provider(
            &mut registry,
            &admin_cap,
            string::utf8(b"pyth"),
            oracle_types::provider_price_feed(),
            ONE_SUI,
            DEFAULT_DISPUTE_WINDOW,
            ts::ctx(&mut scenario),
        );

        oracle_types::destroy_oracle_registry_for_testing(registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(admin_cap);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = oracle_operations::E_NOT_ADMIN)]
    fun test_register_provider_not_admin() {
        let mut scenario = setup_test();
        let (mut registry, admin_cap) = create_oracle_registry(&mut scenario);

        // Try to register as non-admin
        ts::next_tx(&mut scenario, USER1);
        oracle_operations::register_provider(
            &mut registry,
            &admin_cap,
            string::utf8(b"pyth"),
            oracle_types::provider_price_feed(),
            ONE_SUI,
            DEFAULT_DISPUTE_WINDOW,
            ts::ctx(&mut scenario),
        );

        oracle_types::destroy_oracle_registry_for_testing(registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(admin_cap);
        ts::end(scenario);
    }

    #[test]
    fun test_update_provider() {
        let mut scenario = setup_test();
        let (mut registry, admin_cap) = create_oracle_registry(&mut scenario);

        // Register provider
        ts::next_tx(&mut scenario, ADMIN);
        oracle_operations::register_provider(
            &mut registry,
            &admin_cap,
            string::utf8(b"pyth"),
            oracle_types::provider_price_feed(),
            ONE_SUI,
            DEFAULT_DISPUTE_WINDOW,
            ts::ctx(&mut scenario),
        );

        // Update provider
        ts::next_tx(&mut scenario, ADMIN);
        oracle_operations::update_provider(
            &mut registry,
            &admin_cap,
            string::utf8(b"pyth"),
            ONE_SUI * 2, // new min bond
            DEFAULT_DISPUTE_WINDOW * 2, // new window
            true,
            ts::ctx(&mut scenario),
        );

        // Verify update
        let (_, is_active, min_bond, dispute_window, _) =
            oracle_operations::get_provider_info(&registry, string::utf8(b"pyth"));

        assert!(min_bond == ONE_SUI * 2);
        assert!(dispute_window == DEFAULT_DISPUTE_WINDOW * 2);
        assert!(is_active == true);

        // Cleanup
        oracle_types::remove_provider_for_testing(&mut registry, string::utf8(b"pyth"));
        oracle_types::destroy_oracle_registry_for_testing(registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(admin_cap);
        ts::end(scenario);
    }

    #[test]
    fun test_deactivate_provider() {
        let mut scenario = setup_test();
        let (mut registry, admin_cap) = create_oracle_registry(&mut scenario);

        // Register provider
        ts::next_tx(&mut scenario, ADMIN);
        oracle_operations::register_provider(
            &mut registry,
            &admin_cap,
            string::utf8(b"pyth"),
            oracle_types::provider_price_feed(),
            ONE_SUI,
            DEFAULT_DISPUTE_WINDOW,
            ts::ctx(&mut scenario),
        );

        // Verify active
        assert!(oracle_operations::is_provider_active(&registry, string::utf8(b"pyth")));

        // Deactivate
        ts::next_tx(&mut scenario, ADMIN);
        oracle_operations::deactivate_provider(
            &mut registry,
            &admin_cap,
            string::utf8(b"pyth"),
            ts::ctx(&mut scenario),
        );

        // Verify inactive
        assert!(!oracle_operations::is_provider_active(&registry, string::utf8(b"pyth")));

        // Cleanup
        oracle_types::remove_provider_for_testing(&mut registry, string::utf8(b"pyth"));
        oracle_types::destroy_oracle_registry_for_testing(registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(admin_cap);
        ts::end(scenario);
    }

    #[test]
    fun test_set_default_bond() {
        let mut scenario = setup_test();
        let (mut registry, admin_cap) = create_oracle_registry(&mut scenario);

        // Set new default bond
        ts::next_tx(&mut scenario, ADMIN);
        oracle_operations::set_default_bond(
            &mut registry,
            &admin_cap,
            ONE_SUI * 5,
            ts::ctx(&mut scenario),
        );

        // Verify
        let (_, default_bond, _, _) = oracle_operations::get_registry_info(&registry);
        assert!(default_bond == ONE_SUI * 5);

        // Cleanup
        oracle_types::destroy_oracle_registry_for_testing(registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(admin_cap);
        ts::end(scenario);
    }

    #[test]
    fun test_set_default_dispute_window() {
        let mut scenario = setup_test();
        let (mut registry, admin_cap) = create_oracle_registry(&mut scenario);

        // Set new default dispute window
        ts::next_tx(&mut scenario, ADMIN);
        oracle_operations::set_default_dispute_window(
            &mut registry,
            &admin_cap,
            14_400_000, // 4 hours
            ts::ctx(&mut scenario),
        );

        // Verify
        let (_, _, default_window, _) = oracle_operations::get_registry_info(&registry);
        assert!(default_window == 14_400_000);

        // Cleanup
        oracle_types::destroy_oracle_registry_for_testing(registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(admin_cap);
        ts::end(scenario);
    }

    #[test]
    fun test_transfer_registry_admin() {
        let mut scenario = setup_test();
        let (mut registry, admin_cap) = create_oracle_registry(&mut scenario);

        // Transfer admin
        ts::next_tx(&mut scenario, ADMIN);
        oracle_operations::transfer_registry_admin(
            &mut registry,
            &admin_cap,
            USER1,
            ts::ctx(&mut scenario),
        );

        // Verify
        let (admin, _, _, _) = oracle_operations::get_registry_info(&registry);
        assert!(admin == USER1);

        // Cleanup
        oracle_types::destroy_oracle_registry_for_testing(registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(admin_cap);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 2: REQUEST RESOLUTION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_request_resolution() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        // Create oracle-type market
        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        // Advance time past end time and resolution time
        clock::increment_for_testing(&mut clock, 7_300_000); // 2 hours + some extra

        // End trading
        ts::next_tx(&mut scenario, USER1);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        // Request resolution
        let bond = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Verify request
        let (request_id, market_id, requester, requester_bond, status, _, _, _, _) =
            oracle_operations::get_request_info(&request);

        assert!(request_id == 1);
        assert!(market_id == market_types::market_id(&market));
        assert!(requester == USER2);
        assert!(requester_bond == ONE_SUI);
        assert!(status == oracle_types::status_pending());

        // Verify active request registered
        assert!(oracle_operations::has_active_request(&oracle_registry, market_types::market_id(&market)));

        // Cleanup
        oracle_types::remove_active_request_for_testing(&mut oracle_registry, market_types::market_id(&market));
        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = oracle_operations::E_MARKET_NOT_ORACLE_TYPE)]
    fun test_request_resolution_not_oracle_type() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        // Create creator-resolved market (not oracle type)
        let fee = create_sui_coin(&mut scenario, ONE_SUI, USER1);
        ts::next_tx(&mut scenario, USER1);

        let now = clock::timestamp_ms(&clock);
        // Need end_time > now + min_duration_ms (3600000), so add extra time
        let end_time = now + 7_200_000; // 2 hours from now

        let mut market = market_entries::create_market_for_testing(
            &mut market_registry,
            string::utf8(b"Will something happen?"),
            string::utf8(b"Description"),
            string::utf8(b"https://image.url"),
            string::utf8(b"Category"),
            vector[],
            string::utf8(b"Yes"),
            string::utf8(b"No"),
            end_time,
            end_time,
            string::utf8(b"daily"),
            market_types::resolution_creator(), // Creator resolution, NOT oracle
            string::utf8(b""),
            100,
            fee,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Advance time and end trading
        clock::increment_for_testing(&mut clock, 7_300_000); // 2 hours + some extra
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        // Try to request resolution - should fail
        let bond = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond,
            &clock,
            ts::ctx(&mut scenario),
        );

        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = oracle_operations::E_INSUFFICIENT_BOND)]
    fun test_request_resolution_insufficient_bond() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        // Try with insufficient bond
        let bond = create_sui_coin(&mut scenario, ONE_SUI / 2, USER2); // Only 0.5 SUI
        ts::next_tx(&mut scenario, USER2);
        let request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond,
            &clock,
            ts::ctx(&mut scenario),
        );

        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: PROPOSE OUTCOME TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_propose_outcome() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        // Request resolution
        let bond1 = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let mut request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond1,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Propose outcome
        let bond2 = create_sui_coin(&mut scenario, ONE_SUI, USER3);
        ts::next_tx(&mut scenario, USER3);
        oracle_entries::propose_outcome_for_testing(
            &oracle_registry,
            &mut request,
            oracle_types::outcome_yes(),
            bond2,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Verify proposal
        let (_, _, _, _, status, proposed_outcome, proposer, proposer_bond, dispute_deadline) =
            oracle_operations::get_request_info(&request);

        assert!(status == oracle_types::status_proposed());
        assert!(proposed_outcome == oracle_types::outcome_yes());
        assert!(proposer == USER3);
        assert!(proposer_bond == ONE_SUI);
        assert!(dispute_deadline > clock::timestamp_ms(&clock));

        // Cleanup
        oracle_types::remove_active_request_for_testing(&mut oracle_registry, market_types::market_id(&market));
        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_propose_outcome_no() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        let bond1 = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let mut request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond1,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Propose NO outcome
        let bond2 = create_sui_coin(&mut scenario, ONE_SUI, USER3);
        ts::next_tx(&mut scenario, USER3);
        oracle_entries::propose_outcome_for_testing(
            &oracle_registry,
            &mut request,
            oracle_types::outcome_no(),
            bond2,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Verify
        let (_, _, _, _, _, proposed_outcome, _, _, _) = oracle_operations::get_request_info(&request);
        assert!(proposed_outcome == oracle_types::outcome_no());

        // Cleanup
        oracle_types::remove_active_request_for_testing(&mut oracle_registry, market_types::market_id(&market));
        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = oracle_operations::E_INVALID_STATUS)]
    fun test_propose_outcome_already_proposed() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        let bond1 = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let mut request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond1,
            &clock,
            ts::ctx(&mut scenario),
        );

        // First proposal
        let bond2 = create_sui_coin(&mut scenario, ONE_SUI, USER3);
        ts::next_tx(&mut scenario, USER3);
        oracle_entries::propose_outcome_for_testing(
            &oracle_registry,
            &mut request,
            oracle_types::outcome_yes(),
            bond2,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Second proposal - should fail
        let bond3 = create_sui_coin(&mut scenario, ONE_SUI, USER1);
        ts::next_tx(&mut scenario, USER1);
        oracle_entries::propose_outcome_for_testing(
            &oracle_registry,
            &mut request,
            oracle_types::outcome_no(),
            bond3,
            &clock,
            ts::ctx(&mut scenario),
        );

        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = oracle_operations::E_INVALID_OUTCOME)]
    fun test_propose_outcome_invalid() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        let bond1 = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let mut request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond1,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Propose invalid outcome (255)
        let bond2 = create_sui_coin(&mut scenario, ONE_SUI, USER3);
        ts::next_tx(&mut scenario, USER3);
        oracle_entries::propose_outcome_for_testing(
            &oracle_registry,
            &mut request,
            255, // Invalid
            bond2,
            &clock,
            ts::ctx(&mut scenario),
        );

        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = oracle_operations::E_INSUFFICIENT_BOND)]
    fun test_propose_outcome_insufficient_bond() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        let bond1 = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let mut request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond1,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Propose with insufficient bond
        let bond2 = create_sui_coin(&mut scenario, ONE_SUI / 2, USER3);
        ts::next_tx(&mut scenario, USER3);
        oracle_entries::propose_outcome_for_testing(
            &oracle_registry,
            &mut request,
            oracle_types::outcome_yes(),
            bond2,
            &clock,
            ts::ctx(&mut scenario),
        );

        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 4: DISPUTE OUTCOME TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_dispute_outcome() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        // Request resolution
        let bond1 = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let mut request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond1,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Propose outcome
        let bond2 = create_sui_coin(&mut scenario, ONE_SUI, USER3);
        ts::next_tx(&mut scenario, USER3);
        oracle_entries::propose_outcome_for_testing(
            &oracle_registry,
            &mut request,
            oracle_types::outcome_yes(),
            bond2,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Dispute outcome (by USER1, different from proposer USER3)
        let bond3 = create_sui_coin(&mut scenario, ONE_SUI, USER1);
        ts::next_tx(&mut scenario, USER1);
        oracle_entries::dispute_outcome_for_testing(
            &oracle_registry,
            &mut request,
            bond3,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Verify dispute
        assert!(oracle_types::request_is_disputed(&request));
        assert!(oracle_types::request_disputer(&request) == USER1);
        assert!(oracle_types::request_disputer_bond_value(&request) == ONE_SUI);

        // Cleanup
        oracle_types::remove_active_request_for_testing(&mut oracle_registry, market_types::market_id(&market));
        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = oracle_operations::E_SELF_DISPUTE)]
    fun test_dispute_outcome_self_dispute() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        let bond1 = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let mut request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond1,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Propose outcome as USER3
        let bond2 = create_sui_coin(&mut scenario, ONE_SUI, USER3);
        ts::next_tx(&mut scenario, USER3);
        oracle_entries::propose_outcome_for_testing(
            &oracle_registry,
            &mut request,
            oracle_types::outcome_yes(),
            bond2,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Try to dispute as USER3 (same as proposer) - should fail
        let bond3 = create_sui_coin(&mut scenario, ONE_SUI, USER3);
        ts::next_tx(&mut scenario, USER3);
        oracle_entries::dispute_outcome_for_testing(
            &oracle_registry,
            &mut request,
            bond3,
            &clock,
            ts::ctx(&mut scenario),
        );

        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = oracle_operations::E_DISPUTE_WINDOW_PASSED)]
    fun test_dispute_outcome_window_passed() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        let bond1 = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let mut request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond1,
            &clock,
            ts::ctx(&mut scenario),
        );

        let bond2 = create_sui_coin(&mut scenario, ONE_SUI, USER3);
        ts::next_tx(&mut scenario, USER3);
        oracle_entries::propose_outcome_for_testing(
            &oracle_registry,
            &mut request,
            oracle_types::outcome_yes(),
            bond2,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Advance past dispute window (2 hours + buffer)
        clock::increment_for_testing(&mut clock, DEFAULT_DISPUTE_WINDOW + 1000);

        // Try to dispute after window passed - should fail
        let bond3 = create_sui_coin(&mut scenario, ONE_SUI, USER1);
        ts::next_tx(&mut scenario, USER1);
        oracle_entries::dispute_outcome_for_testing(
            &oracle_registry,
            &mut request,
            bond3,
            &clock,
            ts::ctx(&mut scenario),
        );

        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 5: FINALIZE RESOLUTION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_finalize_undisputed() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        let bond1 = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let mut request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond1,
            &clock,
            ts::ctx(&mut scenario),
        );

        let bond2 = create_sui_coin(&mut scenario, ONE_SUI, USER3);
        ts::next_tx(&mut scenario, USER3);
        oracle_entries::propose_outcome_for_testing(
            &oracle_registry,
            &mut request,
            oracle_types::outcome_yes(),
            bond2,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Advance past dispute window
        clock::increment_for_testing(&mut clock, DEFAULT_DISPUTE_WINDOW + 1000);

        // Finalize (anyone can call)
        ts::next_tx(&mut scenario, USER1);
        oracle_entries::finalize_undisputed_for_testing(
            &mut oracle_registry,
            &mut request,
            &mut market,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Verify finalized
        assert!(oracle_types::request_is_finalized(&request));
        assert!(oracle_types::request_final_outcome(&request) == oracle_types::outcome_yes());

        // Verify market resolved
        assert!(market_types::is_resolved(&market));
        assert!(market_types::winning_outcome(&market) == oracle_types::outcome_yes());

        // Cleanup
        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = oracle_operations::E_DISPUTE_WINDOW_ACTIVE)]
    fun test_finalize_undisputed_window_active() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        let bond1 = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let mut request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond1,
            &clock,
            ts::ctx(&mut scenario),
        );

        let bond2 = create_sui_coin(&mut scenario, ONE_SUI, USER3);
        ts::next_tx(&mut scenario, USER3);
        oracle_entries::propose_outcome_for_testing(
            &oracle_registry,
            &mut request,
            oracle_types::outcome_yes(),
            bond2,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Try to finalize before dispute window ends - should fail
        ts::next_tx(&mut scenario, USER1);
        oracle_entries::finalize_undisputed_for_testing(
            &mut oracle_registry,
            &mut request,
            &mut market,
            &clock,
            ts::ctx(&mut scenario),
        );

        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_finalize_disputed_proposer_wins() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        let bond1 = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let mut request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond1,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Propose YES
        let bond2 = create_sui_coin(&mut scenario, ONE_SUI, USER3);
        ts::next_tx(&mut scenario, USER3);
        oracle_entries::propose_outcome_for_testing(
            &oracle_registry,
            &mut request,
            oracle_types::outcome_yes(),
            bond2,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Dispute
        let bond3 = create_sui_coin(&mut scenario, ONE_SUI, USER1);
        ts::next_tx(&mut scenario, USER1);
        oracle_entries::dispute_outcome_for_testing(
            &oracle_registry,
            &mut request,
            bond3,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Admin finalizes with YES (proposer was correct)
        ts::next_tx(&mut scenario, ADMIN);
        oracle_entries::finalize_disputed_for_testing(
            &mut oracle_registry,
            &mut request,
            &mut market,
            &oracle_admin_cap,
            oracle_types::outcome_yes(),
            &clock,
            ts::ctx(&mut scenario),
        );

        // Verify finalized
        assert!(oracle_types::request_is_finalized(&request));
        assert!(oracle_types::request_final_outcome(&request) == oracle_types::outcome_yes());
        assert!(market_types::is_resolved(&market));

        // Cleanup
        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_finalize_disputed_disputer_wins() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        let bond1 = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let mut request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond1,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Propose YES
        let bond2 = create_sui_coin(&mut scenario, ONE_SUI, USER3);
        ts::next_tx(&mut scenario, USER3);
        oracle_entries::propose_outcome_for_testing(
            &oracle_registry,
            &mut request,
            oracle_types::outcome_yes(),
            bond2,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Dispute
        let bond3 = create_sui_coin(&mut scenario, ONE_SUI, USER1);
        ts::next_tx(&mut scenario, USER1);
        oracle_entries::dispute_outcome_for_testing(
            &oracle_registry,
            &mut request,
            bond3,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Admin finalizes with NO (disputer was correct)
        ts::next_tx(&mut scenario, ADMIN);
        oracle_entries::finalize_disputed_for_testing(
            &mut oracle_registry,
            &mut request,
            &mut market,
            &oracle_admin_cap,
            oracle_types::outcome_no(),
            &clock,
            ts::ctx(&mut scenario),
        );

        // Verify finalized with NO
        assert!(oracle_types::request_is_finalized(&request));
        assert!(oracle_types::request_final_outcome(&request) == oracle_types::outcome_no());
        assert!(market_types::winning_outcome(&market) == oracle_types::outcome_no());

        // Cleanup
        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 6: PRICE FEED RESOLUTION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_resolve_by_price_feed_greater() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        // Resolve with price > threshold -> YES
        ts::next_tx(&mut scenario, ADMIN);
        oracle_entries::resolve_by_price_feed_for_testing(
            &mut oracle_registry,
            &mut market,
            &oracle_admin_cap,
            110_000, // price
            100_000, // threshold
            oracle_types::compare_greater(), // comparison
            &clock,
            ts::ctx(&mut scenario),
        );

        // Verify resolved to YES
        assert!(market_types::is_resolved(&market));
        assert!(market_types::winning_outcome(&market) == oracle_types::outcome_yes());

        // Cleanup
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_resolve_by_price_feed_less() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        // Resolve with price < threshold -> YES
        ts::next_tx(&mut scenario, ADMIN);
        oracle_entries::resolve_by_price_feed_for_testing(
            &mut oracle_registry,
            &mut market,
            &oracle_admin_cap,
            90_000, // price
            100_000, // threshold
            oracle_types::compare_less(), // comparison
            &clock,
            ts::ctx(&mut scenario),
        );

        // Verify resolved to YES
        assert!(market_types::is_resolved(&market));
        assert!(market_types::winning_outcome(&market) == oracle_types::outcome_yes());

        // Cleanup
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_resolve_by_price_feed_condition_not_met() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        // Resolve with price <= threshold (not greater) -> NO
        ts::next_tx(&mut scenario, ADMIN);
        oracle_entries::resolve_by_price_feed_for_testing(
            &mut oracle_registry,
            &mut market,
            &oracle_admin_cap,
            100_000, // price (equal, not greater)
            100_000, // threshold
            oracle_types::compare_greater(), // comparison
            &clock,
            ts::ctx(&mut scenario),
        );

        // Verify resolved to NO (condition not met)
        assert!(market_types::is_resolved(&market));
        assert!(market_types::winning_outcome(&market) == oracle_types::outcome_no());

        // Cleanup
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 7: EMERGENCY OVERRIDE TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_emergency_override_pending() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        let bond1 = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let mut request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond1,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Emergency override while pending
        ts::next_tx(&mut scenario, ADMIN);
        oracle_entries::emergency_override_for_testing(
            &mut oracle_registry,
            &mut request,
            &mut market,
            &oracle_admin_cap,
            oracle_types::outcome_yes(),
            string::utf8(b"Oracle service unavailable"),
            &clock,
            ts::ctx(&mut scenario),
        );

        // Verify resolved
        assert!(oracle_types::request_is_finalized(&request));
        assert!(market_types::is_resolved(&market));

        // Cleanup
        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_emergency_void() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        let bond1 = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let mut request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond1,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Emergency void
        ts::next_tx(&mut scenario, ADMIN);
        oracle_entries::emergency_void_for_testing(
            &mut oracle_registry,
            &mut request,
            &mut market,
            &oracle_admin_cap,
            string::utf8(b"Market question ambiguous"),
            &clock,
            ts::ctx(&mut scenario),
        );

        // Verify voided
        assert!(oracle_types::request_is_cancelled(&request));
        assert!(market_types::is_voided(&market));

        // Cleanup
        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = oracle_operations::E_NOT_ADMIN)]
    fun test_emergency_override_not_admin() {
        let mut scenario = setup_test();
        let (mut oracle_registry, oracle_admin_cap) = create_oracle_registry(&mut scenario);
        let (mut market_registry, market_admin_cap) = create_market_registry(&mut scenario);
        let mut clock = create_clock(&mut scenario);

        let mut market = create_oracle_market(&mut scenario, &mut market_registry, &clock);

        clock::increment_for_testing(&mut clock, 7_300_000);
        market_types::set_status_for_testing(&mut market, market_types::status_trading_ended());

        let bond1 = create_sui_coin(&mut scenario, ONE_SUI, USER2);
        ts::next_tx(&mut scenario, USER2);
        let mut request = oracle_entries::request_resolution_for_testing(
            &mut oracle_registry,
            &market,
            bond1,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Try emergency override as non-admin - should fail
        ts::next_tx(&mut scenario, USER1);
        oracle_entries::emergency_override_for_testing(
            &mut oracle_registry,
            &mut request,
            &mut market,
            &oracle_admin_cap,
            oracle_types::outcome_yes(),
            string::utf8(b"Not authorized"),
            &clock,
            ts::ctx(&mut scenario),
        );

        oracle_types::destroy_resolution_request_for_testing(request);
        oracle_types::destroy_oracle_registry_for_testing(oracle_registry);
        oracle_types::destroy_oracle_admin_cap_for_testing(oracle_admin_cap);
        market_types::destroy_market_for_testing(market);
        market_types::destroy_market_registry_for_testing(market_registry);
        market_types::destroy_admin_cap_for_testing(market_admin_cap);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
}
