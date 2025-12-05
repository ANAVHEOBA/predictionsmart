/// Trading Module Tests
///
/// Tests for Trading features:
/// - Feature 1: Limit Orders
/// - Feature 2: Order Matching
/// - Feature 3: Market Orders (queries)
#[test_only]
module predictionsmart::trading_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    use predictionsmart::market_types::{Self, Market, MarketRegistry};
    use predictionsmart::market_entries;
    use predictionsmart::token_types::{TokenVault, YesToken, NoToken};
    use predictionsmart::token_entries;
    use predictionsmart::trading_types::{Self as trading_types, OrderBook};
    use predictionsmart::trading_entries;
    use predictionsmart::trading_operations;

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;

    // Time constants (in milliseconds)
    const HOUR_MS: u64 = 3_600_000;
    const DAY_MS: u64 = 86_400_000;

    // Amount constants
    const ONE_SUI: u64 = 1_000_000_000;

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

    /// Create a market, vault, and order book for testing
    fun create_market_with_trading(
        scenario: &mut Scenario,
        clock: &Clock,
    ) {
        let now = clock.timestamp_ms();

        // Create market as USER1
        ts::next_tx(scenario, USER1);
        {
            let mut registry = ts::take_shared<MarketRegistry>(scenario);
            let fee = mint_sui(scenario, ONE_SUI);

            let end_time = now + (2 * DAY_MS);
            let resolution_time = end_time + HOUR_MS;

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
                100, // 1% fee
                clock,
                ts::ctx(scenario),
            );

            ts::return_shared(registry);
        };

        // Create vault for market 0
        ts::next_tx(scenario, ADMIN);
        {
            token_entries::create_vault(0, clock, ts::ctx(scenario));
        };

        // Create order book for market 0
        ts::next_tx(scenario, ADMIN);
        {
            trading_entries::create_order_book(0, clock, ts::ctx(scenario));
        };
    }

    /// Mint tokens for a user
    fun mint_tokens_for_user(
        scenario: &mut Scenario,
        user: address,
        amount: u64,
        clock: &Clock,
    ) {
        ts::next_tx(scenario, user);
        {
            let mut market = ts::take_shared<Market>(scenario);
            let mut registry = ts::take_shared<MarketRegistry>(scenario);
            let mut vault = ts::take_shared<TokenVault>(scenario);

            let payment = mint_sui(scenario, amount);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment, clock, ts::ctx(scenario));

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ORDER BOOK CREATION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_create_order_book_success() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        // Create market
        ts::next_tx(&mut scenario, USER1);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let fee = mint_sui(&mut scenario, ONE_SUI);

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

        // Create order book
        ts::next_tx(&mut scenario, ADMIN);
        {
            trading_entries::create_order_book(0, &clock, ts::ctx(&mut scenario));
        };

        // Verify order book exists
        ts::next_tx(&mut scenario, ADMIN);
        {
            let book = ts::take_shared<OrderBook>(&scenario);

            assert!(trading_types::book_market_id(&book) == 0, 0);
            assert!(trading_types::book_open_order_count(&book) == 0, 1);
            assert!(trading_types::book_total_volume(&book) == 0, 2);

            ts::return_shared(book);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: LIMIT ORDERS TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_place_buy_yes_order() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Place buy order for YES at 65% (6500 basis points)
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI); // 1 SUI

            let (order_id, payment) = trading_entries::place_buy_yes_for_testing(
                &market,
                &mut book,
                payment,
                6500, // 65% price
                &clock,
                ts::ctx(&mut scenario),
            );

            assert!(order_id == 0, 0);
            assert!(trading_types::book_open_order_count(&book) == 1, 1);

            // Check order details
            let (maker, side, outcome, price, amount, filled, status) =
                trading_operations::get_order_details(&book, order_id);

            assert!(maker == USER1, 2);
            assert!(side == trading_types::side_buy(), 3);
            assert!(outcome == trading_types::outcome_yes(), 4);
            assert!(price == 6500, 5);
            // amount = 1 SUI * 10000 / 6500 = 1.538... tokens
            assert!(amount == 1_538_461_538, 6);
            assert!(filled == 0, 7);
            assert!(status == trading_types::status_open(), 8);

            // Clean up payment
            transfer::public_transfer(payment, USER1);

            ts::return_shared(book);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_place_sell_yes_order() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Mint tokens for USER1
        mint_tokens_for_user(&mut scenario, USER1, ONE_SUI, &clock);

        // Place sell order for YES at 70%
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);
            let yes_token = ts::take_from_sender<YesToken>(&scenario);

            let (order_id, yes_token) = trading_entries::place_sell_yes_for_testing(
                &market,
                &mut book,
                yes_token,
                7000, // 70% price
                &clock,
                ts::ctx(&mut scenario),
            );

            assert!(order_id == 0, 0);
            assert!(trading_types::book_open_order_count(&book) == 1, 1);

            let (maker, side, outcome, price, amount, _filled, _status) =
                trading_operations::get_order_details(&book, order_id);

            assert!(maker == USER1, 2);
            assert!(side == trading_types::side_sell(), 3);
            assert!(outcome == trading_types::outcome_yes(), 4);
            assert!(price == 7000, 5);
            assert!(amount == ONE_SUI, 6); // Full token amount

            ts::return_to_sender(&scenario, yes_token);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_cancel_order() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Place buy order
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);
            let payment = mint_sui(&mut scenario, ONE_SUI);

            let (order_id, payment) = trading_entries::place_buy_yes_for_testing(
                &market,
                &mut book,
                payment,
                6500,
                &clock,
                ts::ctx(&mut scenario),
            );

            assert!(trading_types::book_open_order_count(&book) == 1, 0);

            // Cancel the order
            trading_operations::cancel_order(&mut book, order_id, &clock, ts::ctx(&mut scenario));

            assert!(trading_types::book_open_order_count(&book) == 0, 1);

            // Check order is cancelled
            let (_maker, _side, _outcome, _price, _amount, _filled, status) =
                trading_operations::get_order_details(&book, order_id);
            assert!(status == trading_types::status_cancelled(), 2);

            transfer::public_transfer(payment, USER1);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 204, location = predictionsmart::trading_operations)] // E_NOT_ORDER_MAKER
    fun test_cancel_order_not_maker() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // USER1 places order
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);
            let payment = mint_sui(&mut scenario, ONE_SUI);

            let (_order_id, payment) = trading_entries::place_buy_yes_for_testing(
                &market,
                &mut book,
                payment,
                6500,
                &clock,
                ts::ctx(&mut scenario),
            );

            transfer::public_transfer(payment, USER1);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        // USER2 tries to cancel USER1's order (should fail)
        ts::next_tx(&mut scenario, USER2);
        {
            let mut book = ts::take_shared<OrderBook>(&scenario);

            trading_operations::cancel_order(&mut book, 0, &clock, ts::ctx(&mut scenario));

            ts::return_shared(book);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 201, location = predictionsmart::trading_operations)] // E_INVALID_PRICE
    fun test_place_order_invalid_price() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Try to place order with price > 9999
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);
            let payment = mint_sui(&mut scenario, ONE_SUI);

            let (_order_id, payment) = trading_entries::place_buy_yes_for_testing(
                &market,
                &mut book,
                payment,
                10000, // Invalid: max is 9999
                &clock,
                ts::ctx(&mut scenario),
            );

            transfer::public_transfer(payment, USER1);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 2: ORDER MATCHING TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_match_orders_success() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Mint tokens for USER2 (seller)
        mint_tokens_for_user(&mut scenario, USER2, ONE_SUI, &clock);

        // USER1 places buy order at 6500
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);
            let payment = mint_sui(&mut scenario, ONE_SUI);

            let (_buy_order_id, payment) = trading_entries::place_buy_yes_for_testing(
                &market,
                &mut book,
                payment,
                6500,
                &clock,
                ts::ctx(&mut scenario),
            );

            transfer::public_transfer(payment, USER1);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        // USER2 places sell order at 6000 (lower than buy price = matchable)
        ts::next_tx(&mut scenario, USER2);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);
            let yes_token = ts::take_from_sender<YesToken>(&scenario);

            let (_sell_order_id, yes_token) = trading_entries::place_sell_yes_for_testing(
                &market,
                &mut book,
                yes_token,
                6000, // Below buy price
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_to_sender(&scenario, yes_token);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        // Match the orders
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut book = ts::take_shared<OrderBook>(&scenario);

            let trade_amount = trading_operations::match_orders(
                &mut book,
                0, // buy order
                1, // sell order
                &clock,
                ts::ctx(&mut scenario),
            );

            // Trade should execute for the smaller of the two amounts
            // Buy order: 1 SUI at 6500 = 1,538,461,538 tokens
            // Sell order: 1 SUI tokens
            // Trade amount = min(1,538,461,538, 1,000,000,000) = 1,000,000,000
            assert!(trade_amount == ONE_SUI, 0);

            // Check book stats
            assert!(trading_types::book_total_volume(&book) == ONE_SUI, 1);
            assert!(trading_types::book_trade_count(&book) == 1, 2);

            ts::return_shared(book);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 210, location = predictionsmart::trading_operations)] // E_NO_MATCHING_ORDERS
    fun test_match_orders_price_mismatch() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Mint tokens for USER2
        mint_tokens_for_user(&mut scenario, USER2, ONE_SUI, &clock);

        // USER1 places buy order at 5000
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);
            let payment = mint_sui(&mut scenario, ONE_SUI);

            let (_order_id, payment) = trading_entries::place_buy_yes_for_testing(
                &market,
                &mut book,
                payment,
                5000,
                &clock,
                ts::ctx(&mut scenario),
            );

            transfer::public_transfer(payment, USER1);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        // USER2 places sell order at 6000 (higher than buy price = not matchable)
        ts::next_tx(&mut scenario, USER2);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);
            let yes_token = ts::take_from_sender<YesToken>(&scenario);

            let (_order_id, yes_token) = trading_entries::place_sell_yes_for_testing(
                &market,
                &mut book,
                yes_token,
                6000, // Above buy price
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_to_sender(&scenario, yes_token);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        // Try to match (should fail)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut book = ts::take_shared<OrderBook>(&scenario);

            trading_operations::match_orders(
                &mut book,
                0,
                1,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(book);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: MARKET ORDER QUERIES TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_find_best_sell_order() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Mint tokens for USER1 and USER2
        mint_tokens_for_user(&mut scenario, USER1, ONE_SUI, &clock);
        mint_tokens_for_user(&mut scenario, USER2, ONE_SUI, &clock);

        // USER1 places sell at 7000
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);
            let yes_token = ts::take_from_sender<YesToken>(&scenario);

            let (_order_id, yes_token) = trading_entries::place_sell_yes_for_testing(
                &market,
                &mut book,
                yes_token,
                7000,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_to_sender(&scenario, yes_token);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        // USER2 places sell at 6500 (better price)
        ts::next_tx(&mut scenario, USER2);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);
            let yes_token = ts::take_from_sender<YesToken>(&scenario);

            let (_order_id, yes_token) = trading_entries::place_sell_yes_for_testing(
                &market,
                &mut book,
                yes_token,
                6500,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_to_sender(&scenario, yes_token);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        // Find best sell (should be USER2's at 6500)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let book = ts::take_shared<OrderBook>(&scenario);

            let (best_order_id, best_price, _remaining) = trading_operations::find_best_sell_order(
                &book,
                trading_types::outcome_yes(),
            );

            assert!(best_order_id == 1, 0); // Second order
            assert!(best_price == 6500, 1);

            ts::return_shared(book);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_find_best_buy_order() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // USER1 places buy at 5000
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);
            let payment = mint_sui(&mut scenario, ONE_SUI);

            let (_order_id, payment) = trading_entries::place_buy_yes_for_testing(
                &market,
                &mut book,
                payment,
                5000,
                &clock,
                ts::ctx(&mut scenario),
            );

            transfer::public_transfer(payment, USER1);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        // USER2 places buy at 6000 (better price for sellers)
        ts::next_tx(&mut scenario, USER2);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);
            let payment = mint_sui(&mut scenario, ONE_SUI);

            let (_order_id, payment) = trading_entries::place_buy_yes_for_testing(
                &market,
                &mut book,
                payment,
                6000,
                &clock,
                ts::ctx(&mut scenario),
            );

            transfer::public_transfer(payment, USER2);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        // Find best buy (should be USER2's at 6000)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let book = ts::take_shared<OrderBook>(&scenario);

            let (best_order_id, best_price, _remaining) = trading_operations::find_best_buy_order(
                &book,
                trading_types::outcome_yes(),
            );

            assert!(best_order_id == 1, 0); // Second order
            assert!(best_price == 6000, 1);

            ts::return_shared(book);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_get_book_stats() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Place multiple orders
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);

            let payment1 = mint_sui(&mut scenario, ONE_SUI);
            let (_id1, payment1) = trading_entries::place_buy_yes_for_testing(
                &market, &mut book, payment1, 5000, &clock, ts::ctx(&mut scenario)
            );

            let payment2 = mint_sui(&mut scenario, ONE_SUI);
            let (_id2, payment2) = trading_entries::place_buy_yes_for_testing(
                &market, &mut book, payment2, 6000, &clock, ts::ctx(&mut scenario)
            );

            let (open_orders, total_volume, trade_count) = trading_operations::get_book_stats(&book);
            assert!(open_orders == 2, 0);
            assert!(total_volume == 0, 1);
            assert!(trade_count == 0, 2);

            transfer::public_transfer(payment1, USER1);
            transfer::public_transfer(payment2, USER1);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_is_order_active() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);
            let payment = mint_sui(&mut scenario, ONE_SUI);

            let (order_id, payment) = trading_entries::place_buy_yes_for_testing(
                &market, &mut book, payment, 5000, &clock, ts::ctx(&mut scenario)
            );

            // Order should be active
            assert!(trading_operations::is_order_active(&book, order_id), 0);

            // Cancel order
            trading_operations::cancel_order(&mut book, order_id, &clock, ts::ctx(&mut scenario));

            // Order should no longer be active
            assert!(!trading_operations::is_order_active(&book, order_id), 1);

            // Non-existent order should not be active
            assert!(!trading_operations::is_order_active(&book, 999), 2);

            transfer::public_transfer(payment, USER1);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 4: AMM LIQUIDITY POOL TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_create_liquidity_pool() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Create liquidity pool
        ts::next_tx(&mut scenario, ADMIN);
        {
            let pool = trading_entries::create_liquidity_pool_for_testing(0, &clock, ts::ctx(&mut scenario));

            assert!(trading_types::pool_market_id(&pool) == 0, 0);
            assert!(trading_types::pool_yes_reserve(&pool) == 0, 1);
            assert!(trading_types::pool_no_reserve(&pool) == 0, 2);
            assert!(trading_types::pool_total_lp_tokens(&pool) == 0, 3);
            assert!(trading_types::pool_is_active(&pool), 4);

            trading_types::destroy_liquidity_pool_for_testing(pool);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_add_liquidity() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Mint tokens for USER1
        mint_tokens_for_user(&mut scenario, USER1, 10 * ONE_SUI, &clock);

        // Create and add liquidity
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut pool = trading_entries::create_liquidity_pool_for_testing(0, &clock, ts::ctx(&mut scenario));

            let yes_token = ts::take_from_sender<YesToken>(&scenario);
            let no_token = ts::take_from_sender<NoToken>(&scenario);

            let lp_token = trading_entries::add_liquidity_for_testing(
                &market,
                &mut pool,
                yes_token,
                no_token,
                &clock,
                ts::ctx(&mut scenario),
            );

            // Check pool state
            assert!(trading_types::pool_yes_reserve(&pool) == 10 * ONE_SUI, 0);
            assert!(trading_types::pool_no_reserve(&pool) == 10 * ONE_SUI, 1);
            assert!(trading_types::pool_total_lp_tokens(&pool) > 0, 2);

            // Check LP token
            assert!(trading_types::lp_token_market_id(&lp_token) == 0, 3);
            assert!(trading_types::lp_token_amount(&lp_token) > 0, 4);

            trading_types::destroy_lp_token_for_testing(lp_token);
            trading_types::destroy_liquidity_pool_for_testing(pool);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_remove_liquidity() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Mint tokens for USER1
        mint_tokens_for_user(&mut scenario, USER1, 10 * ONE_SUI, &clock);

        // Create and add liquidity
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut pool = trading_entries::create_liquidity_pool_for_testing(0, &clock, ts::ctx(&mut scenario));

            let yes_token = ts::take_from_sender<YesToken>(&scenario);
            let no_token = ts::take_from_sender<NoToken>(&scenario);

            let lp_token = trading_entries::add_liquidity_for_testing(
                &market,
                &mut pool,
                yes_token,
                no_token,
                &clock,
                ts::ctx(&mut scenario),
            );

            // Remove liquidity
            let (yes_amount, no_amount) = trading_entries::remove_liquidity_for_testing(
                &market,
                &mut pool,
                lp_token,
                &clock,
                ts::ctx(&mut scenario),
            );

            // Should get back all liquidity
            assert!(yes_amount == 10 * ONE_SUI, 0);
            assert!(no_amount == 10 * ONE_SUI, 1);

            // Pool should be empty
            assert!(trading_types::pool_yes_reserve(&pool) == 0, 2);
            assert!(trading_types::pool_no_reserve(&pool) == 0, 3);
            assert!(trading_types::pool_total_lp_tokens(&pool) == 0, 4);

            trading_types::destroy_liquidity_pool_for_testing(pool);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_swap_yes_for_no() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Mint tokens for USER1 (liquidity provider) and USER2 (swapper)
        mint_tokens_for_user(&mut scenario, USER1, 10 * ONE_SUI, &clock);
        mint_tokens_for_user(&mut scenario, USER2, ONE_SUI, &clock);

        // USER1 adds liquidity
        ts::next_tx(&mut scenario, USER1);
        let mut pool = {
            let market = ts::take_shared<Market>(&scenario);
            let mut pool = trading_entries::create_liquidity_pool_for_testing(0, &clock, ts::ctx(&mut scenario));

            let yes_token = ts::take_from_sender<YesToken>(&scenario);
            let no_token = ts::take_from_sender<NoToken>(&scenario);

            let lp_token = trading_entries::add_liquidity_for_testing(
                &market,
                &mut pool,
                yes_token,
                no_token,
                &clock,
                ts::ctx(&mut scenario),
            );

            trading_types::destroy_lp_token_for_testing(lp_token);
            ts::return_shared(market);
            pool
        };

        // USER2 swaps YES for NO
        ts::next_tx(&mut scenario, USER2);
        {
            let market = ts::take_shared<Market>(&scenario);
            let yes_token = ts::take_from_sender<YesToken>(&scenario);

            // Quote the swap first
            let (expected_output, _fee) = trading_operations::quote_yes_for_no(&pool, ONE_SUI);
            assert!(expected_output > 0, 0);

            // Perform swap with 0 min_output for testing
            let output = trading_entries::swap_yes_for_no_for_testing(
                &market,
                &mut pool,
                yes_token,
                0,
                &clock,
                ts::ctx(&mut scenario),
            );

            // Should get roughly expected output (accounting for precision)
            assert!(output == expected_output, 1);

            // Pool reserves should have changed
            assert!(trading_types::pool_yes_reserve(&pool) == 10 * ONE_SUI + ONE_SUI, 2);
            assert!(trading_types::pool_no_reserve(&pool) < 10 * ONE_SUI, 3);

            // Note: In a real implementation, the swap would mint NO tokens for the user
            // but since we don't mint in tests, we just verify the reserves changed

            ts::return_shared(market);
        };

        trading_types::destroy_liquidity_pool_for_testing(pool);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_swap_no_for_yes() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Mint tokens for USER1 (liquidity provider) and USER2 (swapper)
        mint_tokens_for_user(&mut scenario, USER1, 10 * ONE_SUI, &clock);
        mint_tokens_for_user(&mut scenario, USER2, ONE_SUI, &clock);

        // USER1 adds liquidity
        ts::next_tx(&mut scenario, USER1);
        let mut pool = {
            let market = ts::take_shared<Market>(&scenario);
            let mut pool = trading_entries::create_liquidity_pool_for_testing(0, &clock, ts::ctx(&mut scenario));

            let yes_token = ts::take_from_sender<YesToken>(&scenario);
            let no_token = ts::take_from_sender<NoToken>(&scenario);

            let lp_token = trading_entries::add_liquidity_for_testing(
                &market,
                &mut pool,
                yes_token,
                no_token,
                &clock,
                ts::ctx(&mut scenario),
            );

            trading_types::destroy_lp_token_for_testing(lp_token);
            ts::return_shared(market);
            pool
        };

        // USER2 swaps NO for YES
        ts::next_tx(&mut scenario, USER2);
        {
            let market = ts::take_shared<Market>(&scenario);
            let no_token = ts::take_from_sender<NoToken>(&scenario);

            // Quote the swap first
            let (expected_output, _fee) = trading_operations::quote_no_for_yes(&pool, ONE_SUI);
            assert!(expected_output > 0, 0);

            // Perform swap
            let output = trading_entries::swap_no_for_yes_for_testing(
                &market,
                &mut pool,
                no_token,
                0,
                &clock,
                ts::ctx(&mut scenario),
            );

            assert!(output == expected_output, 1);

            // Pool reserves should have changed
            assert!(trading_types::pool_no_reserve(&pool) == 10 * ONE_SUI + ONE_SUI, 2);
            assert!(trading_types::pool_yes_reserve(&pool) < 10 * ONE_SUI, 3);

            // Note: In a real implementation, the swap would mint YES tokens for the user
            // but since we don't mint in tests, we just verify the reserves changed

            ts::return_shared(market);
        };

        trading_types::destroy_liquidity_pool_for_testing(pool);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 216, location = predictionsmart::trading_operations)] // E_SLIPPAGE_EXCEEDED
    fun test_swap_slippage_protection() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Mint tokens
        mint_tokens_for_user(&mut scenario, USER1, 10 * ONE_SUI, &clock);
        mint_tokens_for_user(&mut scenario, USER2, ONE_SUI, &clock);

        // USER1 adds liquidity
        ts::next_tx(&mut scenario, USER1);
        let mut pool = {
            let market = ts::take_shared<Market>(&scenario);
            let mut pool = trading_entries::create_liquidity_pool_for_testing(0, &clock, ts::ctx(&mut scenario));

            let yes_token = ts::take_from_sender<YesToken>(&scenario);
            let no_token = ts::take_from_sender<NoToken>(&scenario);

            let lp_token = trading_entries::add_liquidity_for_testing(
                &market,
                &mut pool,
                yes_token,
                no_token,
                &clock,
                ts::ctx(&mut scenario),
            );

            trading_types::destroy_lp_token_for_testing(lp_token);
            ts::return_shared(market);
            pool
        };

        // USER2 swaps with unreasonably high min_output (should fail)
        ts::next_tx(&mut scenario, USER2);
        {
            let market = ts::take_shared<Market>(&scenario);
            let yes_token = ts::take_from_sender<YesToken>(&scenario);

            // Set min_output to more than possible (should fail)
            let _output = trading_entries::swap_yes_for_no_for_testing(
                &market,
                &mut pool,
                yes_token,
                10 * ONE_SUI, // Way more than possible
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(market);
        };

        trading_types::destroy_liquidity_pool_for_testing(pool);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_pool_price_calculation() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Mint tokens for USER1
        mint_tokens_for_user(&mut scenario, USER1, 10 * ONE_SUI, &clock);

        // Create pool with equal reserves
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut pool = trading_entries::create_liquidity_pool_for_testing(0, &clock, ts::ctx(&mut scenario));

            let yes_token = ts::take_from_sender<YesToken>(&scenario);
            let no_token = ts::take_from_sender<NoToken>(&scenario);

            let lp_token = trading_entries::add_liquidity_for_testing(
                &market,
                &mut pool,
                yes_token,
                no_token,
                &clock,
                ts::ctx(&mut scenario),
            );

            // With equal reserves, price should be 50%
            let yes_price = trading_types::pool_yes_price(&pool);
            let no_price = trading_types::pool_no_price(&pool);

            assert!(yes_price == 5000, 0); // 50%
            assert!(no_price == 5000, 1);  // 50%
            assert!(yes_price + no_price == 10000, 2); // Should sum to 100%

            trading_types::destroy_lp_token_for_testing(lp_token);
            trading_types::destroy_liquidity_pool_for_testing(pool);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 6: ORDER BOOK QUERIES TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_get_order_book_depth() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Mint tokens for selling
        mint_tokens_for_user(&mut scenario, USER1, ONE_SUI, &clock);

        // Place multiple orders
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);
            let yes_token = ts::take_from_sender<YesToken>(&scenario);

            // Place buy order
            let payment1 = mint_sui(&mut scenario, ONE_SUI);
            let (_id1, payment1) = trading_entries::place_buy_yes_for_testing(
                &market, &mut book, payment1, 5000, &clock, ts::ctx(&mut scenario)
            );

            // Place sell order
            let (_id2, yes_token) = trading_entries::place_sell_yes_for_testing(
                &market, &mut book, yes_token, 6000, &clock, ts::ctx(&mut scenario)
            );

            // Get depth
            let (total_buy, total_sell, buy_count, sell_count) =
                trading_operations::get_order_book_depth(&book, trading_types::outcome_yes());

            assert!(total_buy > 0, 0);
            assert!(total_sell > 0, 1);
            assert!(buy_count == 1, 2);
            assert!(sell_count == 1, 3);

            transfer::public_transfer(payment1, USER1);
            ts::return_to_sender(&scenario, yes_token);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_get_bid_ask_prices() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Mint tokens for selling
        mint_tokens_for_user(&mut scenario, USER1, ONE_SUI, &clock);

        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);
            let yes_token = ts::take_from_sender<YesToken>(&scenario);

            // Place buy order at 5000
            let payment = mint_sui(&mut scenario, ONE_SUI);
            let (_id1, payment) = trading_entries::place_buy_yes_for_testing(
                &market, &mut book, payment, 5000, &clock, ts::ctx(&mut scenario)
            );

            // Place sell order at 6000
            let (_id2, yes_token) = trading_entries::place_sell_yes_for_testing(
                &market, &mut book, yes_token, 6000, &clock, ts::ctx(&mut scenario)
            );

            // Get bid/ask
            let (bid, ask) = trading_operations::get_bid_ask_prices(&book, trading_types::outcome_yes());

            assert!(bid == 5000, 0);
            assert!(ask == 6000, 1);

            // Get spread
            let spread = trading_operations::get_spread(&book, trading_types::outcome_yes());
            assert!(spread == 1000, 2); // 10%

            // Get mid price
            let mid = trading_operations::get_mid_price(&book, trading_types::outcome_yes());
            assert!(mid == 5500, 3); // (5000 + 6000) / 2

            transfer::public_transfer(payment, USER1);
            ts::return_to_sender(&scenario, yes_token);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_count_user_orders() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Mint tokens for selling
        mint_tokens_for_user(&mut scenario, USER1, ONE_SUI, &clock);

        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut book = ts::take_shared<OrderBook>(&scenario);
            let yes_token = ts::take_from_sender<YesToken>(&scenario);

            // Place buy order
            let payment1 = mint_sui(&mut scenario, ONE_SUI);
            let (_id1, payment1) = trading_entries::place_buy_yes_for_testing(
                &market, &mut book, payment1, 5000, &clock, ts::ctx(&mut scenario)
            );

            // Place another buy order
            let payment2 = mint_sui(&mut scenario, ONE_SUI);
            let (_id2, payment2) = trading_entries::place_buy_yes_for_testing(
                &market, &mut book, payment2, 4500, &clock, ts::ctx(&mut scenario)
            );

            // Place sell order
            let (_id3, yes_token) = trading_entries::place_sell_yes_for_testing(
                &market, &mut book, yes_token, 6000, &clock, ts::ctx(&mut scenario)
            );

            // Count orders
            let (total, buys, sells) = trading_operations::count_user_orders(&book, USER1);

            assert!(total == 3, 0);
            assert!(buys == 2, 1);
            assert!(sells == 1, 2);

            // USER2 should have 0 orders
            let (total2, _buys2, _sells2) = trading_operations::count_user_orders(&book, USER2);
            assert!(total2 == 0, 3);

            transfer::public_transfer(payment1, USER1);
            transfer::public_transfer(payment2, USER1);
            ts::return_to_sender(&scenario, yes_token);
            ts::return_shared(book);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_get_pool_stats() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_trading(&mut scenario, &clock);

        // Mint tokens for USER1
        mint_tokens_for_user(&mut scenario, USER1, 10 * ONE_SUI, &clock);

        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut pool = trading_entries::create_liquidity_pool_for_testing(0, &clock, ts::ctx(&mut scenario));

            let yes_token = ts::take_from_sender<YesToken>(&scenario);
            let no_token = ts::take_from_sender<NoToken>(&scenario);

            let lp_token = trading_entries::add_liquidity_for_testing(
                &market,
                &mut pool,
                yes_token,
                no_token,
                &clock,
                ts::ctx(&mut scenario),
            );

            // Get pool stats
            let (yes_reserve, no_reserve, total_lp, yes_price, total_fees) =
                trading_operations::get_pool_stats(&pool);

            assert!(yes_reserve == 10 * ONE_SUI, 0);
            assert!(no_reserve == 10 * ONE_SUI, 1);
            assert!(total_lp > 0, 2);
            assert!(yes_price == 5000, 3); // 50%
            assert!(total_fees == 0, 4);

            trading_types::destroy_lp_token_for_testing(lp_token);
            trading_types::destroy_liquidity_pool_for_testing(pool);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
}
