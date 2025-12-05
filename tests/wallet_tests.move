/// Wallet Tests - Tests for wallet module Features 1-3
#[test_only]
module predictionsmart::wallet_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    use predictionsmart::wallet_types::{Self, WalletFactory};
    use predictionsmart::wallet_entries;
    use predictionsmart::wallet_operations;
    use predictionsmart::token_types::{Self, TokenVault, YesToken, NoToken};
    use predictionsmart::trading_types::{Self, LPToken};

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;
    const USER3: address = @0x3;

    const DEPLOYMENT_FEE: u64 = 1000; // 1000 MIST
    const MARKET_ID: u64 = 1;

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

    fun create_factory(scenario: &mut Scenario, fee: u64): WalletFactory {
        ts::next_tx(scenario, ADMIN);
        wallet_entries::initialize_factory_for_testing(fee, ts::ctx(scenario))
    }

    fun create_sui_coin(scenario: &mut Scenario, amount: u64, sender: address): Coin<SUI> {
        ts::next_tx(scenario, sender);
        coin::mint_for_testing<SUI>(amount, ts::ctx(scenario))
    }

    fun create_token_vault(scenario: &mut Scenario): TokenVault {
        ts::next_tx(scenario, ADMIN);
        token_types::new_token_vault_for_testing(MARKET_ID, ts::ctx(scenario))
    }

    fun create_yes_token(scenario: &mut Scenario, vault: &mut TokenVault, amount: u64): YesToken {
        ts::next_tx(scenario, ADMIN);
        token_types::mint_yes_for_testing(vault, amount, ts::ctx(scenario))
    }

    fun create_no_token(scenario: &mut Scenario, vault: &mut TokenVault, amount: u64): NoToken {
        ts::next_tx(scenario, ADMIN);
        token_types::mint_no_for_testing(vault, amount, ts::ctx(scenario))
    }

    fun create_lp_token(scenario: &mut Scenario, amount: u64): LPToken {
        ts::next_tx(scenario, ADMIN);
        trading_types::new_lp_token_for_testing(MARKET_ID, amount, ADMIN, ts::ctx(scenario))
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: PROXY WALLET FACTORY TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_initialize_factory() {
        let mut scenario = setup_test();
        let factory = create_factory(&mut scenario, DEPLOYMENT_FEE);

        // Verify factory state
        assert!(wallet_types::factory_admin(&factory) == ADMIN);
        assert!(wallet_types::factory_wallet_count(&factory) == 0);
        assert!(wallet_types::factory_deployment_fee(&factory) == DEPLOYMENT_FEE);
        assert!(wallet_types::factory_collected_fees(&factory) == 0);

        wallet_types::destroy_wallet_factory_for_testing(factory);
        ts::end(scenario);
    }

    #[test]
    fun test_initialize_factory_zero_fee() {
        let mut scenario = setup_test();
        let factory = create_factory(&mut scenario, 0);

        assert!(wallet_types::factory_deployment_fee(&factory) == 0);

        wallet_types::destroy_wallet_factory_for_testing(factory);
        ts::end(scenario);
    }

    #[test]
    fun test_deploy_wallet() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, DEPLOYMENT_FEE);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, DEPLOYMENT_FEE + 500, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Verify wallet state
        assert!(wallet_types::wallet_owner(&wallet) == USER1);
        assert!(wallet_types::wallet_nonce(&wallet) == 0);
        assert!(wallet_types::wallet_is_active(&wallet));
        assert!(wallet_types::wallet_sui_balance(&wallet) == 0);

        // Verify factory state
        assert!(wallet_types::factory_wallet_count(&factory) == 1);
        assert!(wallet_types::factory_has_wallet(&factory, USER1));
        assert!(wallet_types::factory_collected_fees(&factory) == DEPLOYMENT_FEE);

        // Verify change returned
        assert!(coin::value(&change) == 500);

        // Cleanup: unregister wallet before destroying factory
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_deploy_wallet_zero_fee() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Verify no fee collected
        assert!(wallet_types::factory_collected_fees(&factory) == 0);
        assert!(coin::value(&change) == 100);

        // Cleanup
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::EWalletAlreadyExists)]
    fun test_deploy_wallet_already_exists() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment1 = create_sui_coin(&mut scenario, 100, USER1);
        let payment2 = create_sui_coin(&mut scenario, 100, USER1);

        // Deploy first wallet
        ts::next_tx(&mut scenario, USER1);
        let (wallet1, change1) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment1,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Try to deploy second wallet - should fail
        ts::next_tx(&mut scenario, USER1);
        let (wallet2, change2) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment2,
            &clock,
            ts::ctx(&mut scenario),
        );

        coin::burn_for_testing(change1);
        coin::burn_for_testing(change2);
        wallet_types::destroy_proxy_wallet_for_testing(wallet1);
        wallet_types::destroy_proxy_wallet_for_testing(wallet2);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::EInsufficientPayment)]
    fun test_deploy_wallet_insufficient_payment() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, DEPLOYMENT_FEE);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, DEPLOYMENT_FEE - 1, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_deploy_multiple_wallets() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, DEPLOYMENT_FEE);
        let clock = create_clock(&mut scenario);

        // Deploy wallet for USER1
        let payment1 = create_sui_coin(&mut scenario, DEPLOYMENT_FEE, USER1);
        ts::next_tx(&mut scenario, USER1);
        let (wallet1, change1) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment1,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Deploy wallet for USER2
        let payment2 = create_sui_coin(&mut scenario, DEPLOYMENT_FEE, USER2);
        ts::next_tx(&mut scenario, USER2);
        let (wallet2, change2) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER2,
            payment2,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Verify factory state
        assert!(wallet_types::factory_wallet_count(&factory) == 2);
        assert!(wallet_types::factory_has_wallet(&factory, USER1));
        assert!(wallet_types::factory_has_wallet(&factory, USER2));
        assert!(!wallet_types::factory_has_wallet(&factory, USER3));
        assert!(wallet_types::factory_collected_fees(&factory) == DEPLOYMENT_FEE * 2);

        // Cleanup: unregister wallets before destroying factory
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);
        wallet_types::unregister_wallet_for_testing(&mut factory, USER2);

        coin::burn_for_testing(change1);
        coin::burn_for_testing(change2);
        wallet_types::destroy_proxy_wallet_for_testing(wallet1);
        wallet_types::destroy_proxy_wallet_for_testing(wallet2);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_update_deployment_fee() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, DEPLOYMENT_FEE);

        ts::next_tx(&mut scenario, ADMIN);
        wallet_operations::update_deployment_fee(&mut factory, 2000, ts::ctx(&mut scenario));

        assert!(wallet_types::factory_deployment_fee(&factory) == 2000);

        wallet_types::destroy_wallet_factory_for_testing(factory);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::ENotAdmin)]
    fun test_update_deployment_fee_not_admin() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, DEPLOYMENT_FEE);

        ts::next_tx(&mut scenario, USER1);
        wallet_operations::update_deployment_fee(&mut factory, 2000, ts::ctx(&mut scenario));

        wallet_types::destroy_wallet_factory_for_testing(factory);
        ts::end(scenario);
    }

    #[test]
    fun test_transfer_factory_admin() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, DEPLOYMENT_FEE);

        ts::next_tx(&mut scenario, ADMIN);
        wallet_operations::transfer_factory_admin(&mut factory, USER1, ts::ctx(&mut scenario));

        assert!(wallet_types::factory_admin(&factory) == USER1);

        wallet_types::destroy_wallet_factory_for_testing(factory);
        ts::end(scenario);
    }

    #[test]
    fun test_withdraw_factory_fees() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, DEPLOYMENT_FEE);
        let clock = create_clock(&mut scenario);

        // Deploy a wallet to collect fees
        let payment = create_sui_coin(&mut scenario, DEPLOYMENT_FEE, USER1);
        ts::next_tx(&mut scenario, USER1);
        let (wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Withdraw fees
        ts::next_tx(&mut scenario, ADMIN);
        let fees = wallet_operations::withdraw_factory_fees(&mut factory, ts::ctx(&mut scenario));

        assert!(coin::value(&fees) == DEPLOYMENT_FEE);
        assert!(wallet_types::factory_collected_fees(&factory) == 0);

        // Cleanup
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);

        coin::burn_for_testing(fees);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 2: WALLET OWNERSHIP TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_transfer_ownership() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Transfer ownership
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::transfer_ownership_for_testing(&mut wallet, USER2, ts::ctx(&mut scenario));

        assert!(wallet_types::wallet_owner(&wallet) == USER2);

        // Cleanup
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::ENotOwner)]
    fun test_transfer_ownership_not_owner() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Try to transfer as non-owner
        ts::next_tx(&mut scenario, USER2);
        wallet_entries::transfer_ownership_for_testing(&mut wallet, USER3, ts::ctx(&mut scenario));

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::ESameOwner)]
    fun test_transfer_ownership_same_owner() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Try to transfer to same owner
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::transfer_ownership_for_testing(&mut wallet, USER1, ts::ctx(&mut scenario));

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_lock_unlock_wallet() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Lock wallet
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::lock_wallet_for_testing(&mut wallet, ts::ctx(&mut scenario));
        assert!(wallet_types::wallet_is_locked(&wallet));
        assert!(!wallet_types::wallet_is_active(&wallet));

        // Unlock wallet
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::unlock_wallet_for_testing(&mut wallet, ts::ctx(&mut scenario));
        assert!(wallet_types::wallet_is_active(&wallet));
        assert!(!wallet_types::wallet_is_locked(&wallet));

        // Cleanup
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::ENotOwner)]
    fun test_lock_wallet_not_owner() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Try to lock as non-owner
        ts::next_tx(&mut scenario, USER2);
        wallet_entries::lock_wallet_for_testing(&mut wallet, ts::ctx(&mut scenario));

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: ASSET CUSTODY - SUI TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_deposit_sui() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Deposit SUI
        let deposit = create_sui_coin(&mut scenario, 5000, USER1);
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_sui_for_testing(&mut wallet, deposit, ts::ctx(&mut scenario));

        assert!(wallet_types::wallet_sui_balance(&wallet) == 5000);

        // Cleanup
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_deposit_sui_anyone_can_deposit() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // USER2 deposits into USER1's wallet
        let deposit = create_sui_coin(&mut scenario, 3000, USER2);
        ts::next_tx(&mut scenario, USER2);
        wallet_entries::deposit_sui_for_testing(&mut wallet, deposit, ts::ctx(&mut scenario));

        assert!(wallet_types::wallet_sui_balance(&wallet) == 3000);

        // Cleanup
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_withdraw_sui() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Deposit SUI
        let deposit = create_sui_coin(&mut scenario, 5000, USER1);
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_sui_for_testing(&mut wallet, deposit, ts::ctx(&mut scenario));

        // Withdraw SUI
        ts::next_tx(&mut scenario, USER1);
        let withdrawn = wallet_entries::withdraw_sui_for_testing(&mut wallet, 3000, ts::ctx(&mut scenario));

        assert!(coin::value(&withdrawn) == 3000);
        assert!(wallet_types::wallet_sui_balance(&wallet) == 2000);

        // Cleanup
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);

        coin::burn_for_testing(withdrawn);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::ENotOwner)]
    fun test_withdraw_sui_not_owner() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Deposit SUI
        let deposit = create_sui_coin(&mut scenario, 5000, USER1);
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_sui_for_testing(&mut wallet, deposit, ts::ctx(&mut scenario));

        // Try to withdraw as non-owner
        ts::next_tx(&mut scenario, USER2);
        let withdrawn = wallet_entries::withdraw_sui_for_testing(&mut wallet, 3000, ts::ctx(&mut scenario));

        coin::burn_for_testing(withdrawn);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::EWalletLocked)]
    fun test_withdraw_sui_wallet_locked() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Deposit SUI
        let deposit = create_sui_coin(&mut scenario, 5000, USER1);
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_sui_for_testing(&mut wallet, deposit, ts::ctx(&mut scenario));

        // Lock wallet
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::lock_wallet_for_testing(&mut wallet, ts::ctx(&mut scenario));

        // Try to withdraw while locked
        ts::next_tx(&mut scenario, USER1);
        let withdrawn = wallet_entries::withdraw_sui_for_testing(&mut wallet, 3000, ts::ctx(&mut scenario));

        coin::burn_for_testing(withdrawn);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::EInsufficientBalance)]
    fun test_withdraw_sui_insufficient_balance() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Deposit SUI
        let deposit = create_sui_coin(&mut scenario, 5000, USER1);
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_sui_for_testing(&mut wallet, deposit, ts::ctx(&mut scenario));

        // Try to withdraw more than balance
        ts::next_tx(&mut scenario, USER1);
        let withdrawn = wallet_entries::withdraw_sui_for_testing(&mut wallet, 10000, ts::ctx(&mut scenario));

        coin::burn_for_testing(withdrawn);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: ASSET CUSTODY - YES TOKEN TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_deposit_yes_token() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Create and deposit YES token
        let mut vault = create_token_vault(&mut scenario);
        let yes_token = create_yes_token(&mut scenario, &mut vault, 1000);

        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_yes_token_for_testing(&mut wallet, yes_token, ts::ctx(&mut scenario));

        assert!(wallet_types::wallet_has_yes_token(&wallet, MARKET_ID));

        // Cleanup: remove token before destroying wallet
        let removed_token = wallet_types::remove_yes_token_for_testing(&mut wallet, MARKET_ID);
        token_types::destroy_yes_token_for_testing(removed_token);
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        token_types::destroy_token_vault_for_testing(vault);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_withdraw_yes_token() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Create and deposit YES token
        let mut vault = create_token_vault(&mut scenario);
        let yes_token = create_yes_token(&mut scenario, &mut vault, 1000);

        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_yes_token_for_testing(&mut wallet, yes_token, ts::ctx(&mut scenario));

        // Withdraw YES token
        ts::next_tx(&mut scenario, USER1);
        let withdrawn = wallet_entries::withdraw_yes_token_for_testing(&mut wallet, MARKET_ID, ts::ctx(&mut scenario));

        assert!(token_types::yes_token_amount(&withdrawn) == 1000);
        assert!(!wallet_types::wallet_has_yes_token(&wallet, MARKET_ID));

        // Cleanup
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);

        token_types::destroy_yes_token_for_testing(withdrawn);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        token_types::destroy_token_vault_for_testing(vault);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::ETokenNotFound)]
    fun test_withdraw_yes_token_not_found() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Try to withdraw token that doesn't exist
        ts::next_tx(&mut scenario, USER1);
        let withdrawn = wallet_entries::withdraw_yes_token_for_testing(&mut wallet, MARKET_ID, ts::ctx(&mut scenario));

        token_types::destroy_yes_token_for_testing(withdrawn);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: ASSET CUSTODY - NO TOKEN TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_deposit_no_token() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Create and deposit NO token
        let mut vault = create_token_vault(&mut scenario);
        let no_token = create_no_token(&mut scenario, &mut vault, 1000);

        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_no_token_for_testing(&mut wallet, no_token, ts::ctx(&mut scenario));

        assert!(wallet_types::wallet_has_no_token(&wallet, MARKET_ID));

        // Cleanup: remove token before destroying wallet
        let removed_token = wallet_types::remove_no_token_for_testing(&mut wallet, MARKET_ID);
        token_types::destroy_no_token_for_testing(removed_token);
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        token_types::destroy_token_vault_for_testing(vault);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_withdraw_no_token() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Create and deposit NO token
        let mut vault = create_token_vault(&mut scenario);
        let no_token = create_no_token(&mut scenario, &mut vault, 1000);

        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_no_token_for_testing(&mut wallet, no_token, ts::ctx(&mut scenario));

        // Withdraw NO token
        ts::next_tx(&mut scenario, USER1);
        let withdrawn = wallet_entries::withdraw_no_token_for_testing(&mut wallet, MARKET_ID, ts::ctx(&mut scenario));

        assert!(token_types::no_token_amount(&withdrawn) == 1000);
        assert!(!wallet_types::wallet_has_no_token(&wallet, MARKET_ID));

        // Cleanup
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);

        token_types::destroy_no_token_for_testing(withdrawn);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        token_types::destroy_token_vault_for_testing(vault);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: ASSET CUSTODY - LP TOKEN TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_deposit_lp_token() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Create and deposit LP token
        let lp_token = create_lp_token(&mut scenario, 1000);

        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_lp_token_for_testing(&mut wallet, lp_token, ts::ctx(&mut scenario));

        assert!(wallet_types::wallet_has_lp_token(&wallet, MARKET_ID));

        // Cleanup: remove token before destroying wallet
        let removed_token = wallet_types::remove_lp_token_for_testing(&mut wallet, MARKET_ID);
        trading_types::destroy_lp_token_for_testing(removed_token);
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_withdraw_lp_token() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Create and deposit LP token
        let lp_token = create_lp_token(&mut scenario, 1000);

        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_lp_token_for_testing(&mut wallet, lp_token, ts::ctx(&mut scenario));

        // Withdraw LP token
        ts::next_tx(&mut scenario, USER1);
        let withdrawn = wallet_entries::withdraw_lp_token_for_testing(&mut wallet, MARKET_ID, ts::ctx(&mut scenario));

        assert!(trading_types::lp_token_amount(&withdrawn) == 1000);
        assert!(!wallet_types::wallet_has_lp_token(&wallet, MARKET_ID));

        // Cleanup
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);

        trading_types::destroy_lp_token_for_testing(withdrawn);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // QUERY FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_get_wallet_info() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        let (owner, nonce, _created_at, status, balance) = wallet_operations::get_wallet_info(&wallet);
        assert!(owner == USER1);
        assert!(nonce == 0);
        assert!(status == wallet_types::status_active());
        assert!(balance == 0);

        // Cleanup
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_get_factory_info() {
        let mut scenario = setup_test();
        let factory = create_factory(&mut scenario, DEPLOYMENT_FEE);

        let (admin, count, fee, collected) = wallet_operations::get_factory_info(&factory);
        assert!(admin == ADMIN);
        assert!(count == 0);
        assert!(fee == DEPLOYMENT_FEE);
        assert!(collected == 0);

        wallet_types::destroy_wallet_factory_for_testing(factory);
        ts::end(scenario);
    }

    #[test]
    fun test_wallet_has_tokens() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Check no tokens initially
        let (has_yes, has_no, has_lp) = wallet_operations::wallet_has_tokens(&wallet, MARKET_ID);
        assert!(!has_yes);
        assert!(!has_no);
        assert!(!has_lp);

        // Add YES token
        let mut vault = create_token_vault(&mut scenario);
        let yes_token = create_yes_token(&mut scenario, &mut vault, 1000);
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_yes_token_for_testing(&mut wallet, yes_token, ts::ctx(&mut scenario));

        let (has_yes, has_no, has_lp) = wallet_operations::wallet_has_tokens(&wallet, MARKET_ID);
        assert!(has_yes);
        assert!(!has_no);
        assert!(!has_lp);

        // Cleanup: remove token before destroying wallet
        let removed_token = wallet_types::remove_yes_token_for_testing(&mut wallet, MARKET_ID);
        token_types::destroy_yes_token_for_testing(removed_token);
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        token_types::destroy_token_vault_for_testing(vault);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 6: APPROVALS & ALLOWANCES TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_grant_approval() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        // Grant approval to USER2
        ts::next_tx(&mut scenario, USER1);
        wallet_operations::grant_approval(
            &mut wallet,
            USER2,
            wallet_types::scope_transfer(),
            10000,
            0,
            ts::ctx(&mut scenario),
        );

        assert!(wallet_types::wallet_has_approval(&wallet, USER2));
        let (scope, limit, expiry, used) = wallet_operations::get_approval_info(&wallet, USER2);
        assert!(scope == wallet_types::scope_transfer());
        assert!(limit == 10000);
        assert!(expiry == 0);
        assert!(used == 0);

        // Cleanup
        wallet_types::remove_approval_for_testing(&mut wallet, USER2);
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::ENotOwner)]
    fun test_grant_approval_not_owner() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, USER2);
        wallet_operations::grant_approval(
            &mut wallet,
            USER3,
            wallet_types::scope_transfer(),
            10000,
            0,
            ts::ctx(&mut scenario),
        );

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::ESelfApproval)]
    fun test_grant_approval_self() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, USER1);
        wallet_operations::grant_approval(
            &mut wallet,
            USER1,
            wallet_types::scope_transfer(),
            10000,
            0,
            ts::ctx(&mut scenario),
        );

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_revoke_approval() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, USER1);
        wallet_operations::grant_approval(
            &mut wallet,
            USER2,
            wallet_types::scope_transfer(),
            10000,
            0,
            ts::ctx(&mut scenario),
        );
        assert!(wallet_types::wallet_has_approval(&wallet, USER2));

        ts::next_tx(&mut scenario, USER1);
        wallet_operations::revoke_approval(&mut wallet, USER2, ts::ctx(&mut scenario));
        assert!(!wallet_types::wallet_has_approval(&wallet, USER2));

        // Cleanup
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::EApprovalNotFound)]
    fun test_revoke_approval_not_found() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, USER1);
        wallet_operations::revoke_approval(&mut wallet, USER2, ts::ctx(&mut scenario));

        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_check_approval_valid() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, USER1);
        wallet_operations::grant_approval(
            &mut wallet,
            USER2,
            wallet_types::scope_transfer(),
            10000,
            0,
            ts::ctx(&mut scenario),
        );

        let is_valid = wallet_operations::check_approval(
            &wallet,
            USER2,
            wallet_types::action_transfer_sui(),
            5000,
            0,
        );
        assert!(is_valid);

        // Cleanup
        wallet_types::remove_approval_for_testing(&mut wallet, USER2);
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_check_approval_scope_all() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, USER1);
        wallet_operations::grant_approval(
            &mut wallet,
            USER2,
            wallet_types::scope_all(),
            100000,
            0,
            ts::ctx(&mut scenario),
        );

        // All action types should be valid
        assert!(wallet_operations::check_approval(&wallet, USER2, wallet_types::action_transfer_sui(), 5000, 0));
        assert!(wallet_operations::check_approval(&wallet, USER2, wallet_types::action_place_order(), 5000, 0));
        assert!(wallet_operations::check_approval(&wallet, USER2, wallet_types::action_add_liquidity(), 5000, 0));

        // Cleanup
        wallet_types::remove_approval_for_testing(&mut wallet, USER2);
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 4: TRANSACTION EXECUTION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_execute_action_transfer_sui() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        let deposit = create_sui_coin(&mut scenario, 10000, USER1);
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_sui_for_testing(&mut wallet, deposit, ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, USER1);
        let result = wallet_operations::execute_action(
            &mut wallet,
            wallet_types::action_transfer_sui(),
            USER2,
            3000,
            0,
            0,
            ts::ctx(&mut scenario),
        );

        assert!(coin::value(&result) == 3000);
        assert!(wallet_types::wallet_sui_balance(&wallet) == 7000);
        assert!(wallet_types::wallet_nonce(&wallet) == 1);

        // Cleanup
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);
        coin::burn_for_testing(result);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::ENotOwner)]
    fun test_execute_action_not_owner() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        let deposit = create_sui_coin(&mut scenario, 10000, USER1);
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_sui_for_testing(&mut wallet, deposit, ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, USER2);
        let result = wallet_operations::execute_action(
            &mut wallet,
            wallet_types::action_transfer_sui(),
            USER3,
            3000,
            0,
            0,
            ts::ctx(&mut scenario),
        );

        coin::burn_for_testing(result);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::EWalletLocked)]
    fun test_execute_action_wallet_locked() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        let deposit = create_sui_coin(&mut scenario, 10000, USER1);
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_sui_for_testing(&mut wallet, deposit, ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, USER1);
        wallet_entries::lock_wallet_for_testing(&mut wallet, ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, USER1);
        let result = wallet_operations::execute_action(
            &mut wallet,
            wallet_types::action_transfer_sui(),
            USER2,
            3000,
            0,
            0,
            ts::ctx(&mut scenario),
        );

        coin::burn_for_testing(result);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_execute_as_operator() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let mut clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        let deposit = create_sui_coin(&mut scenario, 10000, USER1);
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_sui_for_testing(&mut wallet, deposit, ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, USER1);
        wallet_operations::grant_approval(
            &mut wallet,
            USER2,
            wallet_types::scope_transfer(),
            5000,
            0,
            ts::ctx(&mut scenario),
        );

        clock::set_for_testing(&mut clock, 100);

        ts::next_tx(&mut scenario, USER2);
        let result = wallet_operations::execute_as_operator(
            &mut wallet,
            wallet_types::action_transfer_sui(),
            USER3,
            2000,
            0,
            0,
            &clock,
            ts::ctx(&mut scenario),
        );

        assert!(coin::value(&result) == 2000);
        assert!(wallet_types::wallet_sui_balance(&wallet) == 8000);

        let (_scope, _limit, _expiry, used) = wallet_operations::get_approval_info(&wallet, USER2);
        assert!(used == 2000);

        // Cleanup
        wallet_types::remove_approval_for_testing(&mut wallet, USER2);
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);
        coin::burn_for_testing(result);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::ENotApproved)]
    fun test_execute_as_operator_not_approved() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        let deposit = create_sui_coin(&mut scenario, 10000, USER1);
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_sui_for_testing(&mut wallet, deposit, ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, USER2);
        let result = wallet_operations::execute_as_operator(
            &mut wallet,
            wallet_types::action_transfer_sui(),
            USER3,
            2000,
            0,
            0,
            &clock,
            ts::ctx(&mut scenario),
        );

        coin::burn_for_testing(result);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_execute_batch() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        let deposit = create_sui_coin(&mut scenario, 10000, USER1);
        ts::next_tx(&mut scenario, USER1);
        wallet_entries::deposit_sui_for_testing(&mut wallet, deposit, ts::ctx(&mut scenario));

        ts::next_tx(&mut scenario, USER1);
        let result = wallet_operations::execute_batch(
            &mut wallet,
            vector[wallet_types::action_transfer_sui(), wallet_types::action_transfer_sui()],
            vector[USER2, USER3],
            vector[1000u64, 2000u64],
            vector[0u64, 0u64],
            vector[0u64, 0u64],
            ts::ctx(&mut scenario),
        );

        assert!(coin::value(&result) == 3000);
        assert!(wallet_types::wallet_sui_balance(&wallet) == 7000);
        assert!(wallet_types::wallet_nonce(&wallet) == 1);

        // Cleanup
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);
        coin::burn_for_testing(result);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = wallet_operations::EEmptyBatch)]
    fun test_execute_batch_empty() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, USER1);
        let result = wallet_operations::execute_batch(
            &mut wallet,
            vector[],
            vector[],
            vector[],
            vector[],
            vector[],
            ts::ctx(&mut scenario),
        );

        coin::burn_for_testing(result);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_invalidate_nonce() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (mut wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        assert!(wallet_types::wallet_nonce(&wallet) == 0);

        ts::next_tx(&mut scenario, USER1);
        wallet_operations::invalidate_nonce(&mut wallet, ts::ctx(&mut scenario));

        assert!(wallet_types::wallet_nonce(&wallet) == 1);

        // Cleanup
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_get_nonce() {
        let mut scenario = setup_test();
        let mut factory = create_factory(&mut scenario, 0);
        let clock = create_clock(&mut scenario);
        let payment = create_sui_coin(&mut scenario, 100, USER1);

        ts::next_tx(&mut scenario, USER1);
        let (wallet, change) = wallet_entries::deploy_wallet_for_testing(
            &mut factory,
            USER1,
            payment,
            &clock,
            ts::ctx(&mut scenario),
        );

        assert!(wallet_operations::get_nonce(&wallet) == 0);

        // Cleanup
        wallet_types::unregister_wallet_for_testing(&mut factory, USER1);
        coin::burn_for_testing(change);
        wallet_types::destroy_proxy_wallet_for_testing(wallet);
        wallet_types::destroy_wallet_factory_for_testing(factory);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 7: SIGNATURE VERIFICATION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fun test_build_signing_message_consistency() {
        let message1 = wallet_operations::build_signing_message(
            @0x1,
            wallet_types::action_transfer_sui(),
            @0x2,
            1000,
            0,
            0,
            0,
        );

        let message2 = wallet_operations::build_signing_message(
            @0x1,
            wallet_types::action_transfer_sui(),
            @0x2,
            1000,
            0,
            0,
            0,
        );

        assert!(message1 == message2);

        let message3 = wallet_operations::build_signing_message(
            @0x1,
            wallet_types::action_transfer_sui(),
            @0x2,
            2000,
            0,
            0,
            0,
        );
        assert!(message1 != message3);
    }

    #[test]
    fun test_build_signing_message_includes_domain() {
        let message = wallet_operations::build_signing_message(
            @0x1,
            wallet_types::action_transfer_sui(),
            @0x2,
            1000,
            0,
            0,
            0,
        );

        let domain = wallet_types::domain_separator();
        let domain_len = vector::length(&domain);

        let mut i = 0;
        while (i < domain_len) {
            assert!(*vector::borrow(&message, i) == *vector::borrow(&domain, i));
            i = i + 1;
        };
    }

    #[test]
    fun test_action_to_scope() {
        // Transfer actions -> SCOPE_TRANSFER
        assert!(wallet_types::action_to_scope(wallet_types::action_transfer_sui()) == wallet_types::scope_transfer());
        assert!(wallet_types::action_to_scope(wallet_types::action_transfer_yes()) == wallet_types::scope_transfer());
        assert!(wallet_types::action_to_scope(wallet_types::action_transfer_no()) == wallet_types::scope_transfer());
        assert!(wallet_types::action_to_scope(wallet_types::action_transfer_lp()) == wallet_types::scope_transfer());

        // Trade actions -> SCOPE_TRADE
        assert!(wallet_types::action_to_scope(wallet_types::action_place_order()) == wallet_types::scope_trade());
        assert!(wallet_types::action_to_scope(wallet_types::action_cancel_order()) == wallet_types::scope_trade());

        // Liquidity actions -> SCOPE_LIQUIDITY
        assert!(wallet_types::action_to_scope(wallet_types::action_add_liquidity()) == wallet_types::scope_liquidity());
        assert!(wallet_types::action_to_scope(wallet_types::action_remove_liquidity()) == wallet_types::scope_liquidity());
        assert!(wallet_types::action_to_scope(wallet_types::action_swap()) == wallet_types::scope_liquidity());

        // Unknown action -> SCOPE_NONE
        assert!(wallet_types::action_to_scope(99) == wallet_types::scope_none());
    }
}
