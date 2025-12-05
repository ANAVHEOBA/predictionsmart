/// Market Module Tests
///
/// Tests for Binary Market features:
/// - Feature 1: Create Market
/// - Feature 2: Get Market Info
/// - Feature 3: End Trading
/// - Feature 4: Resolve Market
/// - Feature 5: Void Market
/// - Feature 6: Admin Config
#[test_only]
module predictionsmart::market_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    use predictionsmart::market_types::{Self, Market, MarketRegistry, AdminCap};
    use predictionsmart::market_entries;

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;

    // Time constants (in milliseconds)
    const HOUR_MS: u64 = 3_600_000;
    const DAY_MS: u64 = 86_400_000;

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Initialize the platform and return scenario
    fun setup(): Scenario {
        let mut scenario = ts::begin(ADMIN);

        // Initialize platform
        {
            market_entries::init_for_testing(ts::ctx(&mut scenario));
        };

        scenario
    }

    /// Create a test clock with given timestamp
    fun create_clock(scenario: &mut Scenario, timestamp_ms: u64): Clock {
        ts::next_tx(scenario, ADMIN);
        let mut clock = clock::create_for_testing(ts::ctx(scenario));
        clock::set_for_testing(&mut clock, timestamp_ms);
        clock
    }

    /// Create test SUI coins
    fun mint_sui(scenario: &mut Scenario, amount: u64): Coin<SUI> {
        coin::mint_for_testing<SUI>(amount, ts::ctx(scenario))
    }

    /// Default market parameters
    fun default_question(): vector<u8> { b"Will Bitcoin be above $100,000 on December 31, 2025?" }
    fun default_description(): vector<u8> { b"Resolves YES if BTC/USD >= 100000" }
    fun default_image_url(): vector<u8> { b"https://example.com/btc.png" }
    fun default_category(): vector<u8> { b"Crypto" }
    fun default_tags(): vector<vector<u8>> { vector[b"Bitcoin", b"Price"] }
    fun default_yes_label(): vector<u8> { b"Yes" }
    fun default_no_label(): vector<u8> { b"No" }
    fun default_timeframe(): vector<u8> { b"annual" }
    fun default_resolution_source(): vector<u8> { b"" }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: CREATE MARKET TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_create_market_success() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64; // Some timestamp
        let clock = create_clock(&mut scenario, now);

        // Create market as USER1
        ts::next_tx(&mut scenario, USER1);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let fee = mint_sui(&mut scenario, 1_000_000_000); // 1 SUI

            let end_time = now + (2 * DAY_MS); // 2 days from now
            let resolution_time = end_time + HOUR_MS; // 1 hour after end

            market_entries::create_market(
                &mut registry,
                fee,
                default_question(),
                default_description(),
                default_image_url(),
                default_category(),
                default_tags(),
                default_yes_label(),
                default_no_label(),
                end_time,
                resolution_time,
                default_timeframe(),
                market_types::resolution_creator(), // Creator resolved
                default_resolution_source(),
                100, // 1% fee
                &clock,
                ts::ctx(&mut scenario),
            );

            // Check registry updated
            assert!(market_types::registry_market_count(&registry) == 1, 0);

            ts::return_shared(registry);
        };

        // Verify market exists and has correct data
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);

            assert!(market_types::market_id(&market) == 0, 1);
            assert!(market_types::is_open(&market), 2);
            assert!(market_types::creator(&market) == USER1, 3);
            assert!(market_types::fee_bps(&market) == 100, 4);
            assert!(market_types::resolution_type(&market) == market_types::resolution_creator(), 5);

            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = predictionsmart::market_operations)] // E_INSUFFICIENT_FEE
    fun test_create_market_insufficient_fee() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        ts::next_tx(&mut scenario, USER1);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let fee = mint_sui(&mut scenario, 100); // Only 100 MIST, not enough

            market_entries::create_market(
                &mut registry,
                fee,
                default_question(),
                default_description(),
                default_image_url(),
                default_category(),
                default_tags(),
                default_yes_label(),
                default_no_label(),
                now + (2 * DAY_MS),
                now + (2 * DAY_MS) + HOUR_MS,
                default_timeframe(),
                market_types::resolution_creator(),
                default_resolution_source(),
                100,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(registry);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = predictionsmart::market_operations)] // E_QUESTION_TOO_SHORT
    fun test_create_market_question_too_short() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        ts::next_tx(&mut scenario, USER1);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let fee = mint_sui(&mut scenario, 1_000_000_000);

            market_entries::create_market(
                &mut registry,
                fee,
                b"Short?", // Too short (< 10 chars)
                default_description(),
                default_image_url(),
                default_category(),
                default_tags(),
                default_yes_label(),
                default_no_label(),
                now + (2 * DAY_MS),
                now + (2 * DAY_MS) + HOUR_MS,
                default_timeframe(),
                market_types::resolution_creator(),
                default_resolution_source(),
                100,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(registry);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 5, location = predictionsmart::market_operations)] // E_INVALID_END_TIME
    fun test_create_market_end_time_too_soon() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        ts::next_tx(&mut scenario, USER1);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let fee = mint_sui(&mut scenario, 1_000_000_000);

            market_entries::create_market(
                &mut registry,
                fee,
                default_question(),
                default_description(),
                default_image_url(),
                default_category(),
                default_tags(),
                default_yes_label(),
                default_no_label(),
                now + 1000, // Only 1 second from now (< 1 hour minimum)
                now + 2000,
                default_timeframe(),
                market_types::resolution_creator(),
                default_resolution_source(),
                100,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(registry);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: END TRADING TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_end_trading_after_time() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let mut clock = create_clock(&mut scenario, now);

        let end_time = now + (2 * DAY_MS);

        // Create market
        ts::next_tx(&mut scenario, USER1);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let fee = mint_sui(&mut scenario, 1_000_000_000);

            market_entries::create_market(
                &mut registry,
                fee,
                default_question(),
                default_description(),
                default_image_url(),
                default_category(),
                default_tags(),
                default_yes_label(),
                default_no_label(),
                end_time,
                end_time + HOUR_MS,
                default_timeframe(),
                market_types::resolution_creator(),
                default_resolution_source(),
                100,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(registry);
        };

        // Fast forward time past end_time
        clock::set_for_testing(&mut clock, end_time + 1000);

        // End trading
        ts::next_tx(&mut scenario, USER2); // Anyone can call
        {
            let mut market = ts::take_shared<Market>(&scenario);

            assert!(market_types::is_open(&market), 0); // Still open before call

            market_entries::end_trading(&mut market, &clock);

            assert!(market_types::is_trading_ended(&market), 1); // Now ended

            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_end_trading_before_time_no_effect() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        let end_time = now + (2 * DAY_MS);

        // Create market
        ts::next_tx(&mut scenario, USER1);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let fee = mint_sui(&mut scenario, 1_000_000_000);

            market_entries::create_market(
                &mut registry,
                fee,
                default_question(),
                default_description(),
                default_image_url(),
                default_category(),
                default_tags(),
                default_yes_label(),
                default_no_label(),
                end_time,
                end_time + HOUR_MS,
                default_timeframe(),
                market_types::resolution_creator(),
                default_resolution_source(),
                100,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(registry);
        };

        // Try to end trading before time (should have no effect)
        ts::next_tx(&mut scenario, USER2);
        {
            let mut market = ts::take_shared<Market>(&scenario);

            market_entries::end_trading(&mut market, &clock);

            assert!(market_types::is_open(&market), 0); // Still open

            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 4: RESOLVE MARKET TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_resolve_by_creator_success() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let mut clock = create_clock(&mut scenario, now);

        let end_time = now + (2 * DAY_MS);
        let resolution_time = end_time + HOUR_MS;

        // Create market
        ts::next_tx(&mut scenario, USER1);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let fee = mint_sui(&mut scenario, 1_000_000_000);

            market_entries::create_market(
                &mut registry,
                fee,
                default_question(),
                default_description(),
                default_image_url(),
                default_category(),
                default_tags(),
                default_yes_label(),
                default_no_label(),
                end_time,
                resolution_time,
                default_timeframe(),
                market_types::resolution_creator(),
                default_resolution_source(),
                100,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(registry);
        };

        // Fast forward to resolution time
        clock::set_for_testing(&mut clock, resolution_time + 1000);

        // End trading first
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            market_entries::end_trading(&mut market, &clock);
            ts::return_shared(market);
        };

        // Creator resolves
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);

            market_entries::resolve_by_creator(
                &mut market,
                market_types::outcome_yes(),
                &clock,
                ts::ctx(&mut scenario),
            );

            assert!(market_types::is_resolved(&market), 0);
            assert!(market_types::winning_outcome(&market) == market_types::outcome_yes(), 1);
            assert!(market_types::resolver(&market) == USER1, 2);

            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 9, location = predictionsmart::market_operations)] // E_NOT_CREATOR
    fun test_resolve_by_creator_wrong_user() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let mut clock = create_clock(&mut scenario, now);

        let end_time = now + (2 * DAY_MS);
        let resolution_time = end_time + HOUR_MS;

        // Create market as USER1
        ts::next_tx(&mut scenario, USER1);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let fee = mint_sui(&mut scenario, 1_000_000_000);

            market_entries::create_market(
                &mut registry,
                fee,
                default_question(),
                default_description(),
                default_image_url(),
                default_category(),
                default_tags(),
                default_yes_label(),
                default_no_label(),
                end_time,
                resolution_time,
                default_timeframe(),
                market_types::resolution_creator(),
                default_resolution_source(),
                100,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(registry);
        };

        clock::set_for_testing(&mut clock, resolution_time + 1000);

        // End trading
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            market_entries::end_trading(&mut market, &clock);
            ts::return_shared(market);
        };

        // USER2 tries to resolve (should fail)
        ts::next_tx(&mut scenario, USER2);
        {
            let mut market = ts::take_shared<Market>(&scenario);

            market_entries::resolve_by_creator(
                &mut market,
                market_types::outcome_yes(),
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_resolve_by_admin_success() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let mut clock = create_clock(&mut scenario, now);

        let end_time = now + (2 * DAY_MS);
        let resolution_time = end_time + HOUR_MS;

        // Create market as USER1
        ts::next_tx(&mut scenario, USER1);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let fee = mint_sui(&mut scenario, 1_000_000_000);

            market_entries::create_market(
                &mut registry,
                fee,
                default_question(),
                default_description(),
                default_image_url(),
                default_category(),
                default_tags(),
                default_yes_label(),
                default_no_label(),
                end_time,
                resolution_time,
                default_timeframe(),
                market_types::resolution_admin(), // Admin resolved
                default_resolution_source(),
                100,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(registry);
        };

        clock::set_for_testing(&mut clock, resolution_time + 1000);

        // End trading
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            market_entries::end_trading(&mut market, &clock);
            ts::return_shared(market);
        };

        // Admin resolves
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            market_entries::resolve_by_admin(
                &mut market,
                &admin_cap,
                market_types::outcome_no(),
                &clock,
                ts::ctx(&mut scenario),
            );

            assert!(market_types::is_resolved(&market), 0);
            assert!(market_types::winning_outcome(&market) == market_types::outcome_no(), 1);

            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 5: VOID MARKET TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_void_by_creator_success() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        // Create market
        ts::next_tx(&mut scenario, USER1);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let fee = mint_sui(&mut scenario, 1_000_000_000);

            market_entries::create_market(
                &mut registry,
                fee,
                default_question(),
                default_description(),
                default_image_url(),
                default_category(),
                default_tags(),
                default_yes_label(),
                default_no_label(),
                now + (2 * DAY_MS),
                now + (2 * DAY_MS) + HOUR_MS,
                default_timeframe(),
                market_types::resolution_creator(),
                default_resolution_source(),
                100,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(registry);
        };

        // Creator voids while still open
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);

            market_entries::void_by_creator(
                &mut market,
                b"Event cancelled",
                &clock,
                ts::ctx(&mut scenario),
            );

            assert!(market_types::is_voided(&market), 0);
            assert!(market_types::winning_outcome(&market) == market_types::outcome_void(), 1);

            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 11, location = predictionsmart::market_operations)] // E_MARKET_NOT_OPEN
    fun test_void_by_creator_after_trading_ended() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let mut clock = create_clock(&mut scenario, now);

        let end_time = now + (2 * DAY_MS);

        // Create market
        ts::next_tx(&mut scenario, USER1);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let fee = mint_sui(&mut scenario, 1_000_000_000);

            market_entries::create_market(
                &mut registry,
                fee,
                default_question(),
                default_description(),
                default_image_url(),
                default_category(),
                default_tags(),
                default_yes_label(),
                default_no_label(),
                end_time,
                end_time + HOUR_MS,
                default_timeframe(),
                market_types::resolution_creator(),
                default_resolution_source(),
                100,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(registry);
        };

        // Fast forward and end trading
        clock::set_for_testing(&mut clock, end_time + 1000);

        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            market_entries::end_trading(&mut market, &clock);
            ts::return_shared(market);
        };

        // Try to void after trading ended (should fail)
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);

            market_entries::void_by_creator(
                &mut market,
                b"Too late",
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_void_by_admin_anytime() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let mut clock = create_clock(&mut scenario, now);

        let end_time = now + (2 * DAY_MS);

        // Create market
        ts::next_tx(&mut scenario, USER1);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let fee = mint_sui(&mut scenario, 1_000_000_000);

            market_entries::create_market(
                &mut registry,
                fee,
                default_question(),
                default_description(),
                default_image_url(),
                default_category(),
                default_tags(),
                default_yes_label(),
                default_no_label(),
                end_time,
                end_time + HOUR_MS,
                default_timeframe(),
                market_types::resolution_creator(),
                default_resolution_source(),
                100,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(registry);
        };

        // Fast forward and end trading
        clock::set_for_testing(&mut clock, end_time + 1000);

        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            market_entries::end_trading(&mut market, &clock);
            ts::return_shared(market);
        };

        // Admin can still void even after trading ended
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            market_entries::void_by_admin(
                &mut market,
                &admin_cap,
                b"Emergency void",
                &clock,
                ts::ctx(&mut scenario),
            );

            assert!(market_types::is_voided(&market), 0);

            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 6: ADMIN CONFIG TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_set_creation_fee() {
        let mut scenario = setup();

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            // Check default fee
            assert!(market_types::registry_creation_fee(&registry) == 1_000_000_000, 0);

            // Set new fee
            market_entries::set_creation_fee(&mut registry, &admin_cap, 2_000_000_000);

            assert!(market_types::registry_creation_fee(&registry) == 2_000_000_000, 1);

            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_pause_unpause() {
        let mut scenario = setup();

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            // Check not paused
            assert!(!market_types::registry_paused(&registry), 0);

            // Pause
            market_entries::pause(&mut registry, &admin_cap);
            assert!(market_types::registry_paused(&registry), 1);

            // Unpause
            market_entries::unpause(&mut registry, &admin_cap);
            assert!(!market_types::registry_paused(&registry), 2);

            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = predictionsmart::market_operations)] // E_PLATFORM_PAUSED
    fun test_create_market_when_paused() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        // Pause platform
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            market_entries::pause(&mut registry, &admin_cap);

            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(registry);
        };

        // Try to create market (should fail)
        ts::next_tx(&mut scenario, USER1);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let fee = mint_sui(&mut scenario, 1_000_000_000);

            market_entries::create_market(
                &mut registry,
                fee,
                default_question(),
                default_description(),
                default_image_url(),
                default_category(),
                default_tags(),
                default_yes_label(),
                default_no_label(),
                now + (2 * DAY_MS),
                now + (2 * DAY_MS) + HOUR_MS,
                default_timeframe(),
                market_types::resolution_creator(),
                default_resolution_source(),
                100,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(registry);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
}
