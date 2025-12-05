/// Wallet Entries - Public entry functions (transaction endpoints)
///
/// These are the functions users call directly via transactions.
module predictionsmart::wallet_entries {
    use sui::clock::Clock;
    use sui::coin::Coin;
    use sui::sui::SUI;

    use predictionsmart::wallet_types::{Self, ProxyWallet, WalletFactory};
    use predictionsmart::wallet_operations;
    use predictionsmart::token_types::{YesToken, NoToken};
    use predictionsmart::trading_types::LPToken;

    // ═══════════════════════════════════════════════════════════════════════════
    // FACTORY INITIALIZATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Initialize the wallet factory (called once at deployment)
    entry fun initialize_factory(
        deployment_fee: u64,
        ctx: &mut TxContext,
    ) {
        let factory = wallet_operations::initialize_factory(
            ctx.sender(),
            deployment_fee,
            ctx,
        );
        wallet_types::share_wallet_factory(factory);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: PROXY WALLET FACTORY
    // ═══════════════════════════════════════════════════════════════════════════

    /// Deploy a new proxy wallet for the caller
    entry fun deploy_wallet(
        factory: &mut WalletFactory,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let owner = ctx.sender();
        let (wallet, change) = wallet_operations::deploy_wallet(
            factory,
            owner,
            payment,
            clock,
            ctx,
        );

        // Share the wallet
        wallet_types::share_proxy_wallet(wallet);

        // Return change to caller
        if (sui::coin::value(&change) > 0) {
            transfer::public_transfer(change, owner);
        } else {
            sui::coin::destroy_zero(change);
        };
    }

    /// Deploy a wallet for another user (useful for sponsored deployments)
    entry fun deploy_wallet_for(
        factory: &mut WalletFactory,
        owner: address,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let (wallet, change) = wallet_operations::deploy_wallet(
            factory,
            owner,
            payment,
            clock,
            ctx,
        );

        // Share the wallet
        wallet_types::share_proxy_wallet(wallet);

        // Return change to caller (sponsor)
        let caller = ctx.sender();
        if (sui::coin::value(&change) > 0) {
            transfer::public_transfer(change, caller);
        } else {
            sui::coin::destroy_zero(change);
        };
    }

    /// Update deployment fee (admin only)
    entry fun update_deployment_fee(
        factory: &mut WalletFactory,
        new_fee: u64,
        ctx: &TxContext,
    ) {
        wallet_operations::update_deployment_fee(factory, new_fee, ctx);
    }

    /// Transfer factory admin (admin only)
    entry fun transfer_factory_admin(
        factory: &mut WalletFactory,
        new_admin: address,
        ctx: &TxContext,
    ) {
        wallet_operations::transfer_factory_admin(factory, new_admin, ctx);
    }

    /// Withdraw collected fees (admin only)
    entry fun withdraw_factory_fees(
        factory: &mut WalletFactory,
        ctx: &mut TxContext,
    ) {
        let fees = wallet_operations::withdraw_factory_fees(factory, ctx);
        transfer::public_transfer(fees, ctx.sender());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 2: WALLET OWNERSHIP
    // ═══════════════════════════════════════════════════════════════════════════

    /// Transfer wallet ownership
    entry fun transfer_ownership(
        wallet: &mut ProxyWallet,
        new_owner: address,
        ctx: &TxContext,
    ) {
        wallet_operations::transfer_ownership(wallet, new_owner, ctx);
    }

    /// Lock wallet (emergency stop)
    entry fun lock_wallet(
        wallet: &mut ProxyWallet,
        ctx: &TxContext,
    ) {
        wallet_operations::lock_wallet(wallet, ctx);
    }

    /// Unlock wallet
    entry fun unlock_wallet(
        wallet: &mut ProxyWallet,
        ctx: &TxContext,
    ) {
        wallet_operations::unlock_wallet(wallet, ctx);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: ASSET CUSTODY - SUI
    // ═══════════════════════════════════════════════════════════════════════════

    /// Deposit SUI into wallet
    entry fun deposit_sui(
        wallet: &mut ProxyWallet,
        coin: Coin<SUI>,
        ctx: &TxContext,
    ) {
        wallet_operations::deposit_sui(wallet, coin, ctx);
    }

    /// Withdraw SUI from wallet (to owner)
    entry fun withdraw_sui(
        wallet: &mut ProxyWallet,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        let coin = wallet_operations::withdraw_sui(wallet, amount, ctx);
        transfer::public_transfer(coin, ctx.sender());
    }

    /// Withdraw SUI to a specific address (owner only)
    entry fun withdraw_sui_to(
        wallet: &mut ProxyWallet,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let coin = wallet_operations::withdraw_sui(wallet, amount, ctx);
        transfer::public_transfer(coin, recipient);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: ASSET CUSTODY - YES TOKENS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Deposit YES token into wallet
    entry fun deposit_yes_token(
        wallet: &mut ProxyWallet,
        token: YesToken,
        ctx: &TxContext,
    ) {
        wallet_operations::deposit_yes_token(wallet, token, ctx);
    }

    /// Withdraw YES token from wallet (to owner)
    entry fun withdraw_yes_token(
        wallet: &mut ProxyWallet,
        market_id: u64,
        ctx: &TxContext,
    ) {
        let token = wallet_operations::withdraw_yes_token(wallet, market_id, ctx);
        predictionsmart::token_types::transfer_yes_token(token, ctx.sender());
    }

    /// Withdraw YES token to a specific address (owner only)
    entry fun withdraw_yes_token_to(
        wallet: &mut ProxyWallet,
        market_id: u64,
        recipient: address,
        ctx: &TxContext,
    ) {
        let token = wallet_operations::withdraw_yes_token(wallet, market_id, ctx);
        predictionsmart::token_types::transfer_yes_token(token, recipient);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: ASSET CUSTODY - NO TOKENS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Deposit NO token into wallet
    entry fun deposit_no_token(
        wallet: &mut ProxyWallet,
        token: NoToken,
        ctx: &TxContext,
    ) {
        wallet_operations::deposit_no_token(wallet, token, ctx);
    }

    /// Withdraw NO token from wallet (to owner)
    entry fun withdraw_no_token(
        wallet: &mut ProxyWallet,
        market_id: u64,
        ctx: &TxContext,
    ) {
        let token = wallet_operations::withdraw_no_token(wallet, market_id, ctx);
        predictionsmart::token_types::transfer_no_token(token, ctx.sender());
    }

    /// Withdraw NO token to a specific address (owner only)
    entry fun withdraw_no_token_to(
        wallet: &mut ProxyWallet,
        market_id: u64,
        recipient: address,
        ctx: &TxContext,
    ) {
        let token = wallet_operations::withdraw_no_token(wallet, market_id, ctx);
        predictionsmart::token_types::transfer_no_token(token, recipient);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: ASSET CUSTODY - LP TOKENS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Deposit LP token into wallet
    entry fun deposit_lp_token(
        wallet: &mut ProxyWallet,
        token: LPToken,
        ctx: &TxContext,
    ) {
        wallet_operations::deposit_lp_token(wallet, token, ctx);
    }

    /// Withdraw LP token from wallet (to owner)
    entry fun withdraw_lp_token(
        wallet: &mut ProxyWallet,
        market_id: u64,
        ctx: &TxContext,
    ) {
        let token = wallet_operations::withdraw_lp_token(wallet, market_id, ctx);
        predictionsmart::trading_types::transfer_lp_token(token, ctx.sender());
    }

    /// Withdraw LP token to a specific address (owner only)
    entry fun withdraw_lp_token_to(
        wallet: &mut ProxyWallet,
        market_id: u64,
        recipient: address,
        ctx: &TxContext,
    ) {
        let token = wallet_operations::withdraw_lp_token(wallet, market_id, ctx);
        predictionsmart::trading_types::transfer_lp_token(token, recipient);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test_only]
    public fun initialize_factory_for_testing(
        deployment_fee: u64,
        ctx: &mut TxContext,
    ): WalletFactory {
        wallet_operations::initialize_factory(ctx.sender(), deployment_fee, ctx)
    }

    #[test_only]
    public fun deploy_wallet_for_testing(
        factory: &mut WalletFactory,
        owner: address,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (ProxyWallet, Coin<SUI>) {
        wallet_operations::deploy_wallet(factory, owner, payment, clock, ctx)
    }

    #[test_only]
    public fun transfer_ownership_for_testing(
        wallet: &mut ProxyWallet,
        new_owner: address,
        ctx: &TxContext,
    ) {
        wallet_operations::transfer_ownership(wallet, new_owner, ctx);
    }

    #[test_only]
    public fun lock_wallet_for_testing(
        wallet: &mut ProxyWallet,
        ctx: &TxContext,
    ) {
        wallet_operations::lock_wallet(wallet, ctx);
    }

    #[test_only]
    public fun unlock_wallet_for_testing(
        wallet: &mut ProxyWallet,
        ctx: &TxContext,
    ) {
        wallet_operations::unlock_wallet(wallet, ctx);
    }

    #[test_only]
    public fun deposit_sui_for_testing(
        wallet: &mut ProxyWallet,
        coin: Coin<SUI>,
        ctx: &TxContext,
    ) {
        wallet_operations::deposit_sui(wallet, coin, ctx);
    }

    #[test_only]
    public fun withdraw_sui_for_testing(
        wallet: &mut ProxyWallet,
        amount: u64,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        wallet_operations::withdraw_sui(wallet, amount, ctx)
    }

    #[test_only]
    public fun deposit_yes_token_for_testing(
        wallet: &mut ProxyWallet,
        token: YesToken,
        ctx: &TxContext,
    ) {
        wallet_operations::deposit_yes_token(wallet, token, ctx);
    }

    #[test_only]
    public fun withdraw_yes_token_for_testing(
        wallet: &mut ProxyWallet,
        market_id: u64,
        ctx: &TxContext,
    ): YesToken {
        wallet_operations::withdraw_yes_token(wallet, market_id, ctx)
    }

    #[test_only]
    public fun deposit_no_token_for_testing(
        wallet: &mut ProxyWallet,
        token: NoToken,
        ctx: &TxContext,
    ) {
        wallet_operations::deposit_no_token(wallet, token, ctx);
    }

    #[test_only]
    public fun withdraw_no_token_for_testing(
        wallet: &mut ProxyWallet,
        market_id: u64,
        ctx: &TxContext,
    ): NoToken {
        wallet_operations::withdraw_no_token(wallet, market_id, ctx)
    }

    #[test_only]
    public fun deposit_lp_token_for_testing(
        wallet: &mut ProxyWallet,
        token: LPToken,
        ctx: &TxContext,
    ) {
        wallet_operations::deposit_lp_token(wallet, token, ctx);
    }

    #[test_only]
    public fun withdraw_lp_token_for_testing(
        wallet: &mut ProxyWallet,
        market_id: u64,
        ctx: &TxContext,
    ): LPToken {
        wallet_operations::withdraw_lp_token(wallet, market_id, ctx)
    }
}
