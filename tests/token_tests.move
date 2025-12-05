/// Token Module Tests
///
/// Tests for Token features:
/// - Feature 1: Token Vault
/// - Feature 2: Mint Token Sets
#[test_only]
module predictionsmart::token_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    use predictionsmart::market_types::{Self, Market, MarketRegistry};
    use predictionsmart::market_entries;
    use predictionsmart::token_types::{Self, TokenVault, YesToken, NoToken};
    use predictionsmart::token_entries;
    use predictionsmart::token_operations;

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
    const MIN_MINT: u64 = 10_000_000; // 0.01 SUI

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

    /// Create a market and vault for testing
    fun create_market_with_vault(
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
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: TOKEN VAULT TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_create_vault_success() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        // Create market first
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

        // Create vault
        ts::next_tx(&mut scenario, ADMIN);
        {
            token_entries::create_vault(0, &clock, ts::ctx(&mut scenario));
        };

        // Verify vault exists and has correct data
        ts::next_tx(&mut scenario, ADMIN);
        {
            let vault = ts::take_shared<TokenVault>(&scenario);

            assert!(token_types::vault_market_id(&vault) == 0, 0);
            assert!(token_types::vault_collateral_value(&vault) == 0, 1);
            assert!(token_types::vault_yes_supply(&vault) == 0, 2);
            assert!(token_types::vault_no_supply(&vault) == 0, 3);

            ts::return_shared(vault);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 2: MINT TOKEN SETS TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_mint_tokens_success() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        // Mint tokens as USER2
        ts::next_tx(&mut scenario, USER2);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);

            token_entries::mint_tokens(
                &mut market,
                &mut registry,
                &mut vault,
                payment,
                &clock,
                ts::ctx(&mut scenario),
            );

            // Check vault updated
            assert!(token_types::vault_collateral_value(&vault) == ONE_SUI, 0);
            assert!(token_types::vault_yes_supply(&vault) == ONE_SUI, 1);
            assert!(token_types::vault_no_supply(&vault) == ONE_SUI, 2);

            // Check market updated
            assert!(market_types::total_collateral(&market) == ONE_SUI, 3);
            assert!(market_types::total_volume(&market) == ONE_SUI, 4);

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Verify USER2 received tokens
        ts::next_tx(&mut scenario, USER2);
        {
            let yes_token = ts::take_from_sender<YesToken>(&scenario);
            let no_token = ts::take_from_sender<NoToken>(&scenario);

            assert!(token_types::yes_token_market_id(&yes_token) == 0, 5);
            assert!(token_types::yes_token_amount(&yes_token) == ONE_SUI, 6);
            assert!(token_types::no_token_market_id(&no_token) == 0, 7);
            assert!(token_types::no_token_amount(&no_token) == ONE_SUI, 8);

            ts::return_to_sender(&scenario, yes_token);
            ts::return_to_sender(&scenario, no_token);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_mint_tokens_multiple_users() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        // USER1 mints
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);

            token_entries::mint_tokens(
                &mut market,
                &mut registry,
                &mut vault,
                payment,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // USER2 mints
        ts::next_tx(&mut scenario, USER2);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, 2 * ONE_SUI);

            token_entries::mint_tokens(
                &mut market,
                &mut registry,
                &mut vault,
                payment,
                &clock,
                ts::ctx(&mut scenario),
            );

            // Check totals
            assert!(token_types::vault_collateral_value(&vault) == 3 * ONE_SUI, 0);
            assert!(token_types::vault_yes_supply(&vault) == 3 * ONE_SUI, 1);
            assert!(token_types::vault_no_supply(&vault) == 3 * ONE_SUI, 2);

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 101, location = predictionsmart::token_operations)] // E_AMOUNT_TOO_SMALL
    fun test_mint_tokens_amount_too_small() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        // Try to mint with too little SUI
        ts::next_tx(&mut scenario, USER2);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, MIN_MINT - 1); // Just under minimum

            token_entries::mint_tokens(
                &mut market,
                &mut registry,
                &mut vault,
                payment,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 100, location = predictionsmart::token_operations)] // E_MARKET_NOT_OPEN
    fun test_mint_tokens_market_not_open() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let mut clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        let end_time = now + (2 * DAY_MS);

        // Fast forward past end time and end trading
        clock::set_for_testing(&mut clock, end_time + 1000);

        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            market_entries::end_trading(&mut market, &clock);
            ts::return_shared(market);
        };

        // Try to mint after trading ended
        ts::next_tx(&mut scenario, USER2);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);

            token_entries::mint_tokens(
                &mut market,
                &mut registry,
                &mut vault,
                payment,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 102, location = predictionsmart::token_operations)] // E_MARKET_ID_MISMATCH
    fun test_mint_tokens_wrong_vault() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        // Create first market
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

        // Create vault for market 0
        ts::next_tx(&mut scenario, ADMIN);
        {
            token_entries::create_vault(0, &clock, ts::ctx(&mut scenario));
        };

        // Create second market
        ts::next_tx(&mut scenario, USER1);
        {
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let fee = mint_sui(&mut scenario, ONE_SUI);

            market_entries::create_market(
                &mut registry,
                fee,
                b"Will Ethereum hit $10,000?",
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

        // Try to mint on market 1 using vault for market 0
        ts::next_tx(&mut scenario, USER2);
        {
            // Get market 1 (second market created)
            let mut market = ts::take_shared<Market>(&scenario);
            // This should be market_id = 1
            assert!(market_types::market_id(&market) == 1, 999);

            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);
            // Vault is for market 0
            assert!(token_types::vault_market_id(&vault) == 0, 998);

            let payment = mint_sui(&mut scenario, ONE_SUI);

            // This should fail with E_MARKET_ID_MISMATCH
            token_entries::mint_tokens(
                &mut market,
                &mut registry,
                &mut vault,
                payment,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TOKEN UTILITIES TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_split_yes_token() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        // Mint tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);

            token_entries::mint_tokens(
                &mut market,
                &mut registry,
                &mut vault,
                payment,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Split YES token and send half to USER2
        ts::next_tx(&mut scenario, USER1);
        {
            let mut yes_token = ts::take_from_sender<YesToken>(&scenario);

            token_entries::split_and_transfer_yes(
                &mut yes_token,
                ONE_SUI / 2,
                USER2,
                ts::ctx(&mut scenario),
            );

            // Original token should have half remaining
            assert!(token_types::yes_token_amount(&yes_token) == ONE_SUI / 2, 0);

            ts::return_to_sender(&scenario, yes_token);
        };

        // Verify USER2 received the split token
        ts::next_tx(&mut scenario, USER2);
        {
            let yes_token = ts::take_from_sender<YesToken>(&scenario);

            assert!(token_types::yes_token_amount(&yes_token) == ONE_SUI / 2, 1);
            assert!(token_types::yes_token_market_id(&yes_token) == 0, 2);

            ts::return_to_sender(&scenario, yes_token);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_split_no_token() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        // Mint tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);

            token_entries::mint_tokens(
                &mut market,
                &mut registry,
                &mut vault,
                payment,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Split NO token and send half to USER2
        ts::next_tx(&mut scenario, USER1);
        {
            let mut no_token = ts::take_from_sender<NoToken>(&scenario);

            token_entries::split_and_transfer_no(
                &mut no_token,
                ONE_SUI / 2,
                USER2,
                ts::ctx(&mut scenario),
            );

            assert!(token_types::no_token_amount(&no_token) == ONE_SUI / 2, 0);

            ts::return_to_sender(&scenario, no_token);
        };

        // Verify USER2 received the split token
        ts::next_tx(&mut scenario, USER2);
        {
            let no_token = ts::take_from_sender<NoToken>(&scenario);

            assert!(token_types::no_token_amount(&no_token) == ONE_SUI / 2, 1);

            ts::return_to_sender(&scenario, no_token);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_merge_yes_tokens() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        // Mint tokens twice
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment, &clock, ts::ctx(&mut scenario));

            let payment2 = mint_sui(&mut scenario, ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment2, &clock, ts::ctx(&mut scenario));

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Merge the two YES tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut yes_token1 = ts::take_from_sender<YesToken>(&scenario);
            let yes_token2 = ts::take_from_sender<YesToken>(&scenario);

            token_entries::merge_yes(&mut yes_token1, yes_token2);

            // Merged token should have combined amount
            assert!(token_types::yes_token_amount(&yes_token1) == 2 * ONE_SUI, 0);

            ts::return_to_sender(&scenario, yes_token1);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_merge_no_tokens() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        // Mint tokens twice
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment, &clock, ts::ctx(&mut scenario));

            let payment2 = mint_sui(&mut scenario, ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment2, &clock, ts::ctx(&mut scenario));

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Merge the two NO tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut no_token1 = ts::take_from_sender<NoToken>(&scenario);
            let no_token2 = ts::take_from_sender<NoToken>(&scenario);

            token_entries::merge_no(&mut no_token1, no_token2);

            assert!(token_types::no_token_amount(&no_token1) == 2 * ONE_SUI, 0);

            ts::return_to_sender(&scenario, no_token1);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 103, location = predictionsmart::token_operations)] // E_INSUFFICIENT_BALANCE
    fun test_split_more_than_balance() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        // Mint tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);

            token_entries::mint_tokens(
                &mut market,
                &mut registry,
                &mut vault,
                payment,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Try to split more than balance
        ts::next_tx(&mut scenario, USER1);
        {
            let mut yes_token = ts::take_from_sender<YesToken>(&scenario);

            // Try to split more than we have
            token_entries::split_and_transfer_yes(
                &mut yes_token,
                ONE_SUI + 1, // More than balance
                USER2,
                ts::ctx(&mut scenario),
            );

            ts::return_to_sender(&scenario, yes_token);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: MERGE TOKEN SETS TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_merge_token_set_success() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        // Mint tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment, &clock, ts::ctx(&mut scenario));

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Merge token set back to SUI
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let yes_token = ts::take_from_sender<YesToken>(&scenario);
            let no_token = ts::take_from_sender<NoToken>(&scenario);

            token_entries::merge_token_set(
                &mut market,
                &mut registry,
                &mut vault,
                yes_token,
                no_token,
                &clock,
                ts::ctx(&mut scenario),
            );

            // Vault should be empty
            assert!(token_types::vault_collateral_value(&vault) == 0, 0);
            assert!(token_types::vault_yes_supply(&vault) == 0, 1);
            assert!(token_types::vault_no_supply(&vault) == 0, 2);

            // Market collateral should be 0
            assert!(market_types::total_collateral(&market) == 0, 3);

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Verify USER1 received SUI back
        ts::next_tx(&mut scenario, USER1);
        {
            let refund = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&refund) == ONE_SUI, 4);
            ts::return_to_sender(&scenario, refund);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 100, location = predictionsmart::token_operations)] // E_MARKET_NOT_OPEN
    fun test_merge_token_set_market_closed() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let mut clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        let end_time = now + (2 * DAY_MS);

        // Mint tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment, &clock, ts::ctx(&mut scenario));

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // End trading
        clock::set_for_testing(&mut clock, end_time + 1000);
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            market_entries::end_trading(&mut market, &clock);
            ts::return_shared(market);
        };

        // Try to merge after trading ended (should fail)
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let yes_token = ts::take_from_sender<YesToken>(&scenario);
            let no_token = ts::take_from_sender<NoToken>(&scenario);

            token_entries::merge_token_set(
                &mut market,
                &mut registry,
                &mut vault,
                yes_token,
                no_token,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 4: REDEEM WINNING TOKENS TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_redeem_yes_tokens_success() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let mut clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        let end_time = now + (2 * DAY_MS);
        let resolution_time = end_time + HOUR_MS;

        // Mint tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment, &clock, ts::ctx(&mut scenario));

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Fast forward and resolve market to YES
        clock::set_for_testing(&mut clock, resolution_time + 1000);

        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            market_entries::end_trading(&mut market, &clock);
            market_entries::resolve_by_creator(&mut market, market_types::outcome_yes(), &clock, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };

        // Redeem winning YES tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let yes_token = ts::take_from_sender<YesToken>(&scenario);

            token_entries::redeem_yes(
                &market,
                &mut registry,
                &mut vault,
                yes_token,
                &clock,
                ts::ctx(&mut scenario),
            );

            // Vault YES supply should be 0
            assert!(token_types::vault_yes_supply(&vault) == 0, 0);

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Verify USER1 received payout (minus 1% fee)
        ts::next_tx(&mut scenario, USER1);
        {
            let payout = ts::take_from_sender<Coin<SUI>>(&scenario);
            // 1 SUI - 1% fee = 0.99 SUI = 990_000_000
            assert!(coin::value(&payout) == 990_000_000, 1);
            ts::return_to_sender(&scenario, payout);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_redeem_no_tokens_success() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let mut clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        let end_time = now + (2 * DAY_MS);
        let resolution_time = end_time + HOUR_MS;

        // Mint tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment, &clock, ts::ctx(&mut scenario));

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Fast forward and resolve market to NO
        clock::set_for_testing(&mut clock, resolution_time + 1000);

        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            market_entries::end_trading(&mut market, &clock);
            market_entries::resolve_by_creator(&mut market, market_types::outcome_no(), &clock, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };

        // Redeem winning NO tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let no_token = ts::take_from_sender<NoToken>(&scenario);

            token_entries::redeem_no(
                &market,
                &mut registry,
                &mut vault,
                no_token,
                &clock,
                ts::ctx(&mut scenario),
            );

            assert!(token_types::vault_no_supply(&vault) == 0, 0);

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Verify USER1 received payout (minus 1% fee)
        ts::next_tx(&mut scenario, USER1);
        {
            let payout = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&payout) == 990_000_000, 1);
            ts::return_to_sender(&scenario, payout);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 107, location = predictionsmart::token_operations)] // E_NOT_WINNING_OUTCOME
    fun test_redeem_losing_tokens_fails() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let mut clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        let end_time = now + (2 * DAY_MS);
        let resolution_time = end_time + HOUR_MS;

        // Mint tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment, &clock, ts::ctx(&mut scenario));

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Resolve to YES
        clock::set_for_testing(&mut clock, resolution_time + 1000);

        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            market_entries::end_trading(&mut market, &clock);
            market_entries::resolve_by_creator(&mut market, market_types::outcome_yes(), &clock, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };

        // Try to redeem NO tokens (losing outcome - should fail)
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let no_token = ts::take_from_sender<NoToken>(&scenario);

            token_entries::redeem_no(
                &market,
                &mut registry,
                &mut vault,
                no_token,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 105, location = predictionsmart::token_operations)] // E_MARKET_NOT_RESOLVED
    fun test_redeem_before_resolution_fails() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        // Mint tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment, &clock, ts::ctx(&mut scenario));

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Try to redeem before resolution (should fail)
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let yes_token = ts::take_from_sender<YesToken>(&scenario);

            token_entries::redeem_yes(
                &market,
                &mut registry,
                &mut vault,
                yes_token,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 5: REDEEM VOIDED MARKET TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_redeem_voided_success() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        // Mint tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment, &clock, ts::ctx(&mut scenario));

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Void market
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            market_entries::void_by_creator(&mut market, b"Event cancelled", &clock, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };

        // Redeem voided tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let yes_token = ts::take_from_sender<YesToken>(&scenario);
            let no_token = ts::take_from_sender<NoToken>(&scenario);

            token_entries::redeem_voided(
                &market,
                &mut registry,
                &mut vault,
                yes_token,
                no_token,
                &clock,
                ts::ctx(&mut scenario),
            );

            // Vault should be empty
            assert!(token_types::vault_collateral_value(&vault) == 0, 0);
            assert!(token_types::vault_yes_supply(&vault) == 0, 1);
            assert!(token_types::vault_no_supply(&vault) == 0, 2);

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Verify USER1 received full refund (no fee for voided)
        ts::next_tx(&mut scenario, USER1);
        {
            let refund = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&refund) == ONE_SUI, 3);
            ts::return_to_sender(&scenario, refund);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 106, location = predictionsmart::token_operations)] // E_MARKET_NOT_VOIDED
    fun test_redeem_voided_market_not_voided() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        // Mint tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment, &clock, ts::ctx(&mut scenario));

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Try to redeem voided without voiding market (should fail)
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let yes_token = ts::take_from_sender<YesToken>(&scenario);
            let no_token = ts::take_from_sender<NoToken>(&scenario);

            token_entries::redeem_voided(
                &market,
                &mut registry,
                &mut vault,
                yes_token,
                no_token,
                &clock,
                ts::ctx(&mut scenario),
            );

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_multiple_users_redeem_winning() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let mut clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        let end_time = now + (2 * DAY_MS);
        let resolution_time = end_time + HOUR_MS;

        // USER1 mints
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment, &clock, ts::ctx(&mut scenario));

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // USER2 mints
        ts::next_tx(&mut scenario, USER2);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, 2 * ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment, &clock, ts::ctx(&mut scenario));

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Resolve to YES
        clock::set_for_testing(&mut clock, resolution_time + 1000);

        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            market_entries::end_trading(&mut market, &clock);
            market_entries::resolve_by_creator(&mut market, market_types::outcome_yes(), &clock, ts::ctx(&mut scenario));
            ts::return_shared(market);
        };

        // USER1 redeems
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let yes_token = ts::take_from_sender<YesToken>(&scenario);
            token_entries::redeem_yes(&market, &mut registry, &mut vault, yes_token, &clock, ts::ctx(&mut scenario));

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // USER2 redeems
        ts::next_tx(&mut scenario, USER2);
        {
            let market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let yes_token = ts::take_from_sender<YesToken>(&scenario);
            token_entries::redeem_yes(&market, &mut registry, &mut vault, yes_token, &clock, ts::ctx(&mut scenario));

            // Both users redeemed, vault should have remaining NO tokens worth of collateral
            // But since NO tokens are worthless, only YES supply matters
            assert!(token_types::vault_yes_supply(&vault) == 0, 0);

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Verify USER1 got correct payout
        ts::next_tx(&mut scenario, USER1);
        {
            let payout = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&payout) == 990_000_000, 1); // 1 SUI - 1%
            ts::return_to_sender(&scenario, payout);
        };

        // Verify USER2 got correct payout
        ts::next_tx(&mut scenario, USER2);
        {
            let payout = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&payout) == 1_980_000_000, 2); // 2 SUI - 1%
            ts::return_to_sender(&scenario, payout);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 6: TOKEN BALANCE QUERIES TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_get_market_stats() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        // Mint tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment, &clock, ts::ctx(&mut scenario));

            // Check market stats
            let (collateral, yes_supply, no_supply) = token_operations::get_market_stats(&vault);
            assert!(collateral == ONE_SUI, 0);
            assert!(yes_supply == ONE_SUI, 1);
            assert!(no_supply == ONE_SUI, 2);

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_get_token_info() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        // Mint tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment, &clock, ts::ctx(&mut scenario));

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Check token info
        ts::next_tx(&mut scenario, USER1);
        {
            let yes_token = ts::take_from_sender<YesToken>(&scenario);
            let no_token = ts::take_from_sender<NoToken>(&scenario);

            let (yes_market_id, yes_amount) = token_operations::get_yes_token_info(&yes_token);
            assert!(yes_market_id == 0, 0);
            assert!(yes_amount == ONE_SUI, 1);

            let (no_market_id, no_amount) = token_operations::get_no_token_info(&no_token);
            assert!(no_market_id == 0, 2);
            assert!(no_amount == ONE_SUI, 3);

            // Check is_for_market helpers
            assert!(token_operations::yes_token_is_for_market(&yes_token, 0), 4);
            assert!(!token_operations::yes_token_is_for_market(&yes_token, 1), 5);
            assert!(token_operations::no_token_is_for_market(&no_token, 0), 6);
            assert!(!token_operations::no_token_is_for_market(&no_token, 1), 7);

            ts::return_to_sender(&scenario, yes_token);
            ts::return_to_sender(&scenario, no_token);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_calculate_payout() {
        let mut scenario = setup();
        let now = 1_000_000_000_000u64;
        let clock = create_clock(&mut scenario, now);

        create_market_with_vault(&mut scenario, &clock);

        // Mint tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut market = ts::take_shared<Market>(&scenario);
            let mut registry = ts::take_shared<MarketRegistry>(&scenario);
            let mut vault = ts::take_shared<TokenVault>(&scenario);

            let payment = mint_sui(&mut scenario, ONE_SUI);
            token_entries::mint_tokens(&mut market, &mut registry, &mut vault, payment, &clock, ts::ctx(&mut scenario));

            ts::return_shared(vault);
            ts::return_shared(registry);
            ts::return_shared(market);
        };

        // Check payout calculations
        ts::next_tx(&mut scenario, USER1);
        {
            let market = ts::take_shared<Market>(&scenario);
            let yes_token = ts::take_from_sender<YesToken>(&scenario);
            let no_token = ts::take_from_sender<NoToken>(&scenario);

            // Market has 1% fee (100 bps)
            let (yes_payout, yes_fee) = token_operations::calculate_yes_payout(&market, &yes_token);
            assert!(yes_payout == 990_000_000, 0); // 0.99 SUI
            assert!(yes_fee == 10_000_000, 1); // 0.01 SUI fee

            let (no_payout, no_fee) = token_operations::calculate_no_payout(&market, &no_token);
            assert!(no_payout == 990_000_000, 2);
            assert!(no_fee == 10_000_000, 3);

            ts::return_to_sender(&scenario, yes_token);
            ts::return_to_sender(&scenario, no_token);
            ts::return_shared(market);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
}
