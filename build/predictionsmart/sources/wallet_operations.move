/// Wallet Operations - Business logic for wallet operations
///
/// This module implements Features 1-3:
/// - Feature 1: Proxy Wallet Factory
/// - Feature 2: Wallet Ownership
/// - Feature 3: Asset Custody
module predictionsmart::wallet_operations {
    use sui::clock::Clock;
    use sui::coin::Coin;
    use sui::sui::SUI;

    use predictionsmart::wallet_types::{Self, ProxyWallet, WalletFactory};
    use predictionsmart::wallet_events;
    use predictionsmart::token_types::{Self, YesToken, NoToken};
    use predictionsmart::trading_types::{Self, LPToken};

    // ═══════════════════════════════════════════════════════════════════════════
    // ERROR CODES
    // ═══════════════════════════════════════════════════════════════════════════

    const ENotOwner: u64 = 1;
    const ENotAdmin: u64 = 2;
    const EWalletAlreadyExists: u64 = 3;
    const EWalletNotFound: u64 = 4;
    const EWalletLocked: u64 = 5;
    const EInsufficientBalance: u64 = 6;
    const EInsufficientPayment: u64 = 7;
    const ETokenNotFound: u64 = 8;
    const ESameOwner: u64 = 9;
    const EZeroAmount: u64 = 10;
    // Feature 4-7 error codes
    const ENotApproved: u64 = 11;
    const EInvalidScope: u64 = 14;
    const EInvalidNonce: u64 = 15;
    const ETransactionExpired: u64 = 16;
    const EInvalidSignature: u64 = 17;
    const EInvalidActionType: u64 = 18;
    const ESelfApproval: u64 = 19;
    const EApprovalNotFound: u64 = 20;
    const EEmptyBatch: u64 = 21;
    const EInvalidSigScheme: u64 = 22;

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: PROXY WALLET FACTORY
    // ═══════════════════════════════════════════════════════════════════════════

    /// Initialize the wallet factory (called once at deployment)
    public fun initialize_factory(
        admin: address,
        deployment_fee: u64,
        ctx: &mut TxContext,
    ): WalletFactory {
        wallet_types::new_wallet_factory(admin, deployment_fee, ctx)
    }

    /// Deploy a new proxy wallet for a user
    public fun deploy_wallet(
        factory: &mut WalletFactory,
        owner: address,
        mut payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (ProxyWallet, Coin<SUI>) {
        // Check user doesn't already have a wallet
        assert!(!wallet_types::factory_has_wallet(factory, owner), EWalletAlreadyExists);

        // Check payment covers deployment fee
        let fee = wallet_types::factory_deployment_fee(factory);
        let payment_value = sui::coin::value(&payment);
        assert!(payment_value >= fee, EInsufficientPayment);

        // Collect fee if any
        if (fee > 0) {
            let fee_coin = sui::coin::split(&mut payment, fee, ctx);
            wallet_types::collect_fee(factory, fee_coin);
        };

        // Create the wallet
        let created_at = sui::clock::timestamp_ms(clock);
        let wallet = wallet_types::new_proxy_wallet(owner, created_at, ctx);
        let wallet_address = wallet_types::wallet_id(&wallet);

        // Register wallet in factory
        wallet_types::register_wallet(factory, owner, wallet_address);

        // Emit event
        wallet_events::emit_wallet_created(wallet_address, owner, created_at);

        (wallet, payment)
    }

    /// Update the deployment fee (admin only)
    public fun update_deployment_fee(
        factory: &mut WalletFactory,
        new_fee: u64,
        ctx: &TxContext,
    ) {
        let admin = wallet_types::factory_admin(factory);
        assert!(ctx.sender() == admin, ENotAdmin);

        let old_fee = wallet_types::factory_deployment_fee(factory);
        wallet_types::set_deployment_fee(factory, new_fee);

        wallet_events::emit_deployment_fee_changed(old_fee, new_fee);
    }

    /// Transfer factory admin (admin only)
    public fun transfer_factory_admin(
        factory: &mut WalletFactory,
        new_admin: address,
        ctx: &TxContext,
    ) {
        let old_admin = wallet_types::factory_admin(factory);
        assert!(ctx.sender() == old_admin, ENotAdmin);

        wallet_types::set_factory_admin(factory, new_admin);

        wallet_events::emit_factory_admin_changed(old_admin, new_admin);
    }

    /// Withdraw collected fees from factory (admin only)
    public fun withdraw_factory_fees(
        factory: &mut WalletFactory,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        let admin = wallet_types::factory_admin(factory);
        assert!(ctx.sender() == admin, ENotAdmin);

        let amount = wallet_types::factory_collected_fees(factory);
        let fees = wallet_types::withdraw_fees(factory, ctx);

        wallet_events::emit_factory_fees_withdrawn(admin, amount);

        fees
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 2: WALLET OWNERSHIP
    // ═══════════════════════════════════════════════════════════════════════════

    /// Transfer ownership of wallet to a new owner
    public fun transfer_ownership(
        wallet: &mut ProxyWallet,
        new_owner: address,
        ctx: &TxContext,
    ) {
        let old_owner = wallet_types::wallet_owner(wallet);
        assert!(ctx.sender() == old_owner, ENotOwner);
        assert!(new_owner != old_owner, ESameOwner);

        wallet_types::set_wallet_owner(wallet, new_owner);

        let wallet_address = wallet_types::wallet_id(wallet);
        wallet_events::emit_ownership_transferred(wallet_address, old_owner, new_owner);
    }

    /// Lock wallet (emergency stop)
    public fun lock_wallet(
        wallet: &mut ProxyWallet,
        ctx: &TxContext,
    ) {
        let owner = wallet_types::wallet_owner(wallet);
        assert!(ctx.sender() == owner, ENotOwner);

        wallet_types::lock_wallet(wallet);

        let wallet_address = wallet_types::wallet_id(wallet);
        wallet_events::emit_wallet_locked(wallet_address, owner);
    }

    /// Unlock wallet
    public fun unlock_wallet(
        wallet: &mut ProxyWallet,
        ctx: &TxContext,
    ) {
        let owner = wallet_types::wallet_owner(wallet);
        assert!(ctx.sender() == owner, ENotOwner);

        wallet_types::unlock_wallet(wallet);

        let wallet_address = wallet_types::wallet_id(wallet);
        wallet_events::emit_wallet_unlocked(wallet_address, owner);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: ASSET CUSTODY - SUI
    // ═══════════════════════════════════════════════════════════════════════════

    /// Deposit SUI into wallet (anyone can deposit)
    public fun deposit_sui(
        wallet: &mut ProxyWallet,
        coin: Coin<SUI>,
        ctx: &TxContext,
    ) {
        let amount = sui::coin::value(&coin);
        assert!(amount > 0, EZeroAmount);

        wallet_types::deposit_sui(wallet, coin);

        let wallet_address = wallet_types::wallet_id(wallet);
        wallet_events::emit_sui_deposited(wallet_address, ctx.sender(), amount);
    }

    /// Withdraw SUI from wallet (owner only)
    public fun withdraw_sui(
        wallet: &mut ProxyWallet,
        amount: u64,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        let owner = wallet_types::wallet_owner(wallet);
        assert!(ctx.sender() == owner, ENotOwner);
        assert!(wallet_types::wallet_is_active(wallet), EWalletLocked);
        assert!(amount > 0, EZeroAmount);

        let balance = wallet_types::wallet_sui_balance(wallet);
        assert!(balance >= amount, EInsufficientBalance);

        let coin = wallet_types::withdraw_sui(wallet, amount, ctx);

        let wallet_address = wallet_types::wallet_id(wallet);
        wallet_events::emit_sui_withdrawn(wallet_address, owner, amount);

        coin
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: ASSET CUSTODY - YES TOKENS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Deposit YES token into wallet
    public fun deposit_yes_token(
        wallet: &mut ProxyWallet,
        token: YesToken,
        _ctx: &TxContext,
    ) {
        let market_id = token_types::yes_token_market_id(&token);
        let amount = token_types::yes_token_amount(&token);
        assert!(amount > 0, EZeroAmount);

        wallet_types::deposit_yes_token(wallet, market_id, token);

        let wallet_address = wallet_types::wallet_id(wallet);
        wallet_events::emit_yes_token_deposited(wallet_address, market_id, amount);
    }

    /// Withdraw YES token from wallet (owner only)
    public fun withdraw_yes_token(
        wallet: &mut ProxyWallet,
        market_id: u64,
        ctx: &TxContext,
    ): YesToken {
        let owner = wallet_types::wallet_owner(wallet);
        assert!(ctx.sender() == owner, ENotOwner);
        assert!(wallet_types::wallet_is_active(wallet), EWalletLocked);
        assert!(wallet_types::wallet_has_yes_token(wallet, market_id), ETokenNotFound);

        let token = wallet_types::withdraw_yes_token(wallet, market_id);
        let amount = token_types::yes_token_amount(&token);

        let wallet_address = wallet_types::wallet_id(wallet);
        wallet_events::emit_yes_token_withdrawn(wallet_address, market_id, amount);

        token
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: ASSET CUSTODY - NO TOKENS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Deposit NO token into wallet
    public fun deposit_no_token(
        wallet: &mut ProxyWallet,
        token: NoToken,
        _ctx: &TxContext,
    ) {
        let market_id = token_types::no_token_market_id(&token);
        let amount = token_types::no_token_amount(&token);
        assert!(amount > 0, EZeroAmount);

        wallet_types::deposit_no_token(wallet, market_id, token);

        let wallet_address = wallet_types::wallet_id(wallet);
        wallet_events::emit_no_token_deposited(wallet_address, market_id, amount);
    }

    /// Withdraw NO token from wallet (owner only)
    public fun withdraw_no_token(
        wallet: &mut ProxyWallet,
        market_id: u64,
        ctx: &TxContext,
    ): NoToken {
        let owner = wallet_types::wallet_owner(wallet);
        assert!(ctx.sender() == owner, ENotOwner);
        assert!(wallet_types::wallet_is_active(wallet), EWalletLocked);
        assert!(wallet_types::wallet_has_no_token(wallet, market_id), ETokenNotFound);

        let token = wallet_types::withdraw_no_token(wallet, market_id);
        let amount = token_types::no_token_amount(&token);

        let wallet_address = wallet_types::wallet_id(wallet);
        wallet_events::emit_no_token_withdrawn(wallet_address, market_id, amount);

        token
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: ASSET CUSTODY - LP TOKENS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Deposit LP token into wallet
    public fun deposit_lp_token(
        wallet: &mut ProxyWallet,
        token: LPToken,
        _ctx: &TxContext,
    ) {
        let market_id = trading_types::lp_token_market_id(&token);
        let amount = trading_types::lp_token_amount(&token);
        assert!(amount > 0, EZeroAmount);

        wallet_types::deposit_lp_token(wallet, market_id, token);

        let wallet_address = wallet_types::wallet_id(wallet);
        wallet_events::emit_lp_token_deposited(wallet_address, market_id, amount);
    }

    /// Withdraw LP token from wallet (owner only)
    public fun withdraw_lp_token(
        wallet: &mut ProxyWallet,
        market_id: u64,
        ctx: &TxContext,
    ): LPToken {
        let owner = wallet_types::wallet_owner(wallet);
        assert!(ctx.sender() == owner, ENotOwner);
        assert!(wallet_types::wallet_is_active(wallet), EWalletLocked);
        assert!(wallet_types::wallet_has_lp_token(wallet, market_id), ETokenNotFound);

        let token = wallet_types::withdraw_lp_token(wallet, market_id);
        let amount = trading_types::lp_token_amount(&token);

        let wallet_address = wallet_types::wallet_id(wallet);
        wallet_events::emit_lp_token_withdrawn(wallet_address, market_id, amount);

        token
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // QUERY FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get wallet info
    public fun get_wallet_info(wallet: &ProxyWallet): (address, u64, u64, u8, u64) {
        (
            wallet_types::wallet_owner(wallet),
            wallet_types::wallet_nonce(wallet),
            wallet_types::wallet_created_at(wallet),
            wallet_types::wallet_status(wallet),
            wallet_types::wallet_sui_balance(wallet),
        )
    }

    /// Get factory info
    public fun get_factory_info(factory: &WalletFactory): (address, u64, u64, u64) {
        (
            wallet_types::factory_admin(factory),
            wallet_types::factory_wallet_count(factory),
            wallet_types::factory_deployment_fee(factory),
            wallet_types::factory_collected_fees(factory),
        )
    }

    /// Check if user has a wallet
    public fun user_has_wallet(factory: &WalletFactory, user: address): bool {
        wallet_types::factory_has_wallet(factory, user)
    }

    /// Get wallet address for a user
    public fun get_user_wallet(factory: &WalletFactory, user: address): address {
        assert!(wallet_types::factory_has_wallet(factory, user), EWalletNotFound);
        wallet_types::factory_get_wallet(factory, user)
    }

    /// Check if wallet has a specific token type for a market
    public fun wallet_has_tokens(
        wallet: &ProxyWallet,
        market_id: u64,
    ): (bool, bool, bool) {
        (
            wallet_types::wallet_has_yes_token(wallet, market_id),
            wallet_types::wallet_has_no_token(wallet, market_id),
            wallet_types::wallet_has_lp_token(wallet, market_id),
        )
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 6: APPROVALS & ALLOWANCES
    // ═══════════════════════════════════════════════════════════════════════════

    /// Grant approval to an operator (owner only)
    public fun grant_approval(
        wallet: &mut ProxyWallet,
        operator: address,
        scope: u8,
        limit: u64,
        expiry: u64,
        ctx: &TxContext,
    ) {
        let owner = wallet_types::wallet_owner(wallet);
        assert!(ctx.sender() == owner, ENotOwner);
        assert!(operator != owner, ESelfApproval);
        assert!(wallet_types::wallet_is_active(wallet), EWalletLocked);
        // Validate scope
        assert!(
            scope == wallet_types::scope_none() ||
            scope == wallet_types::scope_trade() ||
            scope == wallet_types::scope_transfer() ||
            scope == wallet_types::scope_liquidity() ||
            scope == wallet_types::scope_all(),
            EInvalidScope
        );

        let approval = wallet_types::new_approval(operator, scope, limit, expiry);
        wallet_types::grant_approval(wallet, approval);

        let wallet_address = wallet_types::wallet_id(wallet);
        wallet_events::emit_approval_granted(wallet_address, operator, scope, limit, expiry);
    }

    /// Revoke approval from an operator (owner only)
    public fun revoke_approval(
        wallet: &mut ProxyWallet,
        operator: address,
        ctx: &TxContext,
    ) {
        let owner = wallet_types::wallet_owner(wallet);
        assert!(ctx.sender() == owner, ENotOwner);
        assert!(wallet_types::wallet_has_approval(wallet, operator), EApprovalNotFound);

        wallet_types::revoke_approval(wallet, operator);

        let wallet_address = wallet_types::wallet_id(wallet);
        wallet_events::emit_approval_revoked(wallet_address, operator);
    }

    /// Check if an operator has valid approval for an action
    public fun check_approval(
        wallet: &ProxyWallet,
        operator: address,
        action_type: u8,
        amount: u64,
        current_time: u64,
    ): bool {
        if (!wallet_types::wallet_has_approval(wallet, operator)) {
            return false
        };

        let approval = wallet_types::wallet_get_approval(wallet, operator);
        let required_scope = wallet_types::action_to_scope(action_type);

        // Check if approval is valid
        if (!wallet_types::approval_is_valid(approval, current_time)) {
            return false
        };

        // Check scope
        if (!wallet_types::approval_has_scope(approval, required_scope)) {
            return false
        };

        // Check remaining limit
        let remaining = wallet_types::approval_remaining(approval);
        if (amount > remaining) {
            return false
        };

        true
    }

    /// Get approval info for an operator
    public fun get_approval_info(
        wallet: &ProxyWallet,
        operator: address,
    ): (u8, u64, u64, u64) {
        assert!(wallet_types::wallet_has_approval(wallet, operator), EApprovalNotFound);
        let approval = wallet_types::wallet_get_approval(wallet, operator);
        (
            wallet_types::approval_scope(approval),
            wallet_types::approval_limit(approval),
            wallet_types::approval_expiry(approval),
            wallet_types::approval_used(approval),
        )
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 4: TRANSACTION EXECUTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Execute a single action (owner only)
    /// This is for direct execution by the wallet owner
    public fun execute_action(
        wallet: &mut ProxyWallet,
        action_type: u8,
        target: address,
        amount: u64,
        _market_id: u64,
        _data: u64,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        let owner = wallet_types::wallet_owner(wallet);
        assert!(ctx.sender() == owner, ENotOwner);
        assert!(wallet_types::wallet_is_active(wallet), EWalletLocked);

        // Validate action type
        assert!(
            action_type >= wallet_types::action_transfer_sui() &&
            action_type <= wallet_types::action_swap(),
            EInvalidActionType
        );

        let wallet_address = wallet_types::wallet_id(wallet);
        let old_nonce = wallet_types::wallet_nonce(wallet);

        // Execute based on action type
        let result = if (action_type == wallet_types::action_transfer_sui()) {
            // Transfer SUI
            assert!(amount > 0, EZeroAmount);
            assert!(wallet_types::wallet_sui_balance(wallet) >= amount, EInsufficientBalance);
            let coin = wallet_types::withdraw_sui(wallet, amount, ctx);
            wallet_events::emit_sui_withdrawn(wallet_address, target, amount);
            coin
        } else {
            // For non-SUI actions, return zero coin (actual token transfers handled separately)
            sui::coin::zero<SUI>(ctx)
        };

        // Increment nonce
        wallet_types::increment_nonce(wallet);
        let new_nonce = wallet_types::wallet_nonce(wallet);

        // Emit events
        wallet_events::emit_transaction_executed(wallet_address, owner, action_type, amount, new_nonce);
        wallet_events::emit_nonce_incremented(wallet_address, old_nonce, new_nonce);

        result
    }

    /// Execute action as an approved operator
    public fun execute_as_operator(
        wallet: &mut ProxyWallet,
        action_type: u8,
        target: address,
        amount: u64,
        _market_id: u64,
        _data: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        let operator = ctx.sender();
        let wallet_address = wallet_types::wallet_id(wallet);

        assert!(wallet_types::wallet_is_active(wallet), EWalletLocked);
        assert!(wallet_types::wallet_has_approval(wallet, operator), ENotApproved);

        let current_time = sui::clock::timestamp_ms(clock);

        // Verify approval
        assert!(check_approval(wallet, operator, action_type, amount, current_time), ENotApproved);

        // Update approval usage
        {
            let approval = wallet_types::get_approval_mut(wallet, operator);
            wallet_types::use_approval(approval, amount);
            let remaining = wallet_types::approval_remaining(approval);
            wallet_events::emit_approval_used(wallet_address, operator, amount, remaining);
        };

        // Execute based on action type
        let result = if (action_type == wallet_types::action_transfer_sui()) {
            assert!(amount > 0, EZeroAmount);
            assert!(wallet_types::wallet_sui_balance(wallet) >= amount, EInsufficientBalance);
            let coin = wallet_types::withdraw_sui(wallet, amount, ctx);
            wallet_events::emit_sui_withdrawn(wallet_address, target, amount);
            coin
        } else {
            sui::coin::zero<SUI>(ctx)
        };

        wallet_events::emit_operator_executed(wallet_address, operator, action_type, amount);

        result
    }

    /// Execute batch of actions (owner only)
    public fun execute_batch(
        wallet: &mut ProxyWallet,
        action_types: vector<u8>,
        targets: vector<address>,
        amounts: vector<u64>,
        market_ids: vector<u64>,
        _data: vector<u64>,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        let owner = wallet_types::wallet_owner(wallet);
        assert!(ctx.sender() == owner, ENotOwner);
        assert!(wallet_types::wallet_is_active(wallet), EWalletLocked);

        let action_count = vector::length(&action_types);
        assert!(action_count > 0, EEmptyBatch);
        assert!(vector::length(&targets) == action_count, EInvalidActionType);
        assert!(vector::length(&amounts) == action_count, EInvalidActionType);
        assert!(vector::length(&market_ids) == action_count, EInvalidActionType);

        let wallet_address = wallet_types::wallet_id(wallet);
        let old_nonce = wallet_types::wallet_nonce(wallet);

        // Accumulate SUI to transfer
        let mut total_sui: u64 = 0;
        let mut i = 0;
        while (i < action_count) {
            let action_type = *vector::borrow(&action_types, i);
            let amount = *vector::borrow(&amounts, i);

            if (action_type == wallet_types::action_transfer_sui()) {
                total_sui = total_sui + amount;
            };
            i = i + 1;
        };

        // Withdraw total SUI if needed
        let result = if (total_sui > 0) {
            assert!(wallet_types::wallet_sui_balance(wallet) >= total_sui, EInsufficientBalance);
            wallet_types::withdraw_sui(wallet, total_sui, ctx)
        } else {
            sui::coin::zero<SUI>(ctx)
        };

        // Increment nonce
        wallet_types::increment_nonce(wallet);
        let new_nonce = wallet_types::wallet_nonce(wallet);

        // Emit events
        wallet_events::emit_batch_executed(wallet_address, owner, action_count, new_nonce);
        wallet_events::emit_nonce_incremented(wallet_address, old_nonce, new_nonce);

        result
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 5: GASLESS TRANSACTIONS (RELAYED EXECUTION)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Execute a relayed (gasless) transaction
    /// The relayer pays gas, but the action is authorized by the wallet owner's signature
    public fun execute_relayed(
        wallet: &mut ProxyWallet,
        action_type: u8,
        target: address,
        amount: u64,
        market_id: u64,
        _data: u64,
        nonce: u64,
        deadline: u64,
        sig_scheme: u8,
        signature: vector<u8>,
        public_key: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        let wallet_address = wallet_types::wallet_id(wallet);
        let relayer = ctx.sender();

        assert!(wallet_types::wallet_is_active(wallet), EWalletLocked);

        // Validate nonce
        let current_nonce = wallet_types::wallet_nonce(wallet);
        assert!(nonce == current_nonce, EInvalidNonce);

        // Validate deadline
        let current_time = sui::clock::timestamp_ms(clock);
        assert!(deadline == 0 || current_time < deadline, ETransactionExpired);

        // Validate signature scheme
        assert!(
            sig_scheme == wallet_types::sig_scheme_ed25519() ||
            sig_scheme == wallet_types::sig_scheme_secp256k1(),
            EInvalidSigScheme
        );

        // Verify signature
        let owner = wallet_types::wallet_owner(wallet);
        let is_valid = verify_relayed_signature(
            wallet_address,
            action_type,
            target,
            amount,
            market_id,
            nonce,
            deadline,
            sig_scheme,
            signature,
            public_key,
            owner,
        );
        assert!(is_valid, EInvalidSignature);

        let old_nonce = current_nonce;

        // Execute based on action type
        let result = if (action_type == wallet_types::action_transfer_sui()) {
            assert!(amount > 0, EZeroAmount);
            assert!(wallet_types::wallet_sui_balance(wallet) >= amount, EInsufficientBalance);
            let coin = wallet_types::withdraw_sui(wallet, amount, ctx);
            wallet_events::emit_sui_withdrawn(wallet_address, target, amount);
            coin
        } else {
            sui::coin::zero<SUI>(ctx)
        };

        // Increment nonce
        wallet_types::increment_nonce(wallet);
        let new_nonce = wallet_types::wallet_nonce(wallet);

        // Emit events
        wallet_events::emit_relayed_transaction_executed(
            wallet_address,
            relayer,
            owner,
            action_type,
            amount,
            new_nonce,
        );
        wallet_events::emit_nonce_incremented(wallet_address, old_nonce, new_nonce);

        result
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 7: SIGNATURE VERIFICATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Build the message to sign for a relayed transaction
    /// Uses domain separation for security
    public fun build_signing_message(
        wallet_address: address,
        action_type: u8,
        target: address,
        amount: u64,
        market_id: u64,
        nonce: u64,
        deadline: u64,
    ): vector<u8> {
        let mut message = wallet_types::domain_separator();

        // Append wallet address (32 bytes)
        let wallet_bytes = std::bcs::to_bytes(&wallet_address);
        vector::append(&mut message, wallet_bytes);

        // Append action type (1 byte)
        vector::push_back(&mut message, action_type);

        // Append target address (32 bytes)
        let target_bytes = std::bcs::to_bytes(&target);
        vector::append(&mut message, target_bytes);

        // Append amount (8 bytes, big-endian)
        let amount_bytes = std::bcs::to_bytes(&amount);
        vector::append(&mut message, amount_bytes);

        // Append market_id (8 bytes)
        let market_bytes = std::bcs::to_bytes(&market_id);
        vector::append(&mut message, market_bytes);

        // Append nonce (8 bytes)
        let nonce_bytes = std::bcs::to_bytes(&nonce);
        vector::append(&mut message, nonce_bytes);

        // Append deadline (8 bytes)
        let deadline_bytes = std::bcs::to_bytes(&deadline);
        vector::append(&mut message, deadline_bytes);

        message
    }

    /// Verify a signature for a relayed transaction
    fun verify_relayed_signature(
        wallet_address: address,
        action_type: u8,
        target: address,
        amount: u64,
        market_id: u64,
        nonce: u64,
        deadline: u64,
        sig_scheme: u8,
        signature: vector<u8>,
        public_key: vector<u8>,
        expected_signer: address,
    ): bool {
        // Build the message that was signed
        let message = build_signing_message(
            wallet_address,
            action_type,
            target,
            amount,
            market_id,
            nonce,
            deadline,
        );

        // Verify based on signature scheme
        if (sig_scheme == wallet_types::sig_scheme_ed25519()) {
            verify_ed25519_signature(&message, &signature, &public_key, expected_signer)
        } else if (sig_scheme == wallet_types::sig_scheme_secp256k1()) {
            verify_secp256k1_signature(&message, &signature, &public_key, expected_signer)
        } else {
            false
        }
    }

    /// Verify an Ed25519 signature
    fun verify_ed25519_signature(
        message: &vector<u8>,
        signature: &vector<u8>,
        public_key: &vector<u8>,
        expected_signer: address,
    ): bool {
        // Verify signature length (64 bytes for Ed25519)
        if (vector::length(signature) != 64) {
            return false
        };

        // Verify public key length (32 bytes for Ed25519)
        if (vector::length(public_key) != 32) {
            return false
        };

        // Verify the signature using Sui's ed25519 module
        let is_valid = sui::ed25519::ed25519_verify(signature, public_key, message);
        if (!is_valid) {
            return false
        };

        // Derive address from public key and verify it matches expected signer
        // In Sui, address is derived from public key with scheme flag
        let derived_address = derive_address_from_ed25519_pubkey(public_key);
        derived_address == expected_signer
    }

    /// Verify a Secp256k1 signature
    fun verify_secp256k1_signature(
        message: &vector<u8>,
        signature: &vector<u8>,
        public_key: &vector<u8>,
        expected_signer: address,
    ): bool {
        // Verify signature length (64 bytes for secp256k1 without recovery)
        if (vector::length(signature) != 64) {
            return false
        };

        // Verify public key length (33 bytes compressed)
        if (vector::length(public_key) != 33) {
            return false
        };

        // Hash the message with keccak256 for secp256k1
        let message_hash = sui::hash::keccak256(message);

        // Verify using Sui's ecdsa_k1 module
        let is_valid = sui::ecdsa_k1::secp256k1_verify(signature, public_key, &message_hash, 0);
        if (!is_valid) {
            return false
        };

        // Derive address from public key and verify it matches expected signer
        let derived_address = derive_address_from_secp256k1_pubkey(public_key);
        derived_address == expected_signer
    }

    /// Derive Sui address from Ed25519 public key
    fun derive_address_from_ed25519_pubkey(public_key: &vector<u8>): address {
        // Sui address derivation: BLAKE2b-256(flag || public_key)
        // Flag for Ed25519 is 0x00
        let mut data = vector::empty<u8>();
        vector::push_back(&mut data, 0x00); // Ed25519 flag
        let mut i = 0;
        while (i < vector::length(public_key)) {
            vector::push_back(&mut data, *vector::borrow(public_key, i));
            i = i + 1;
        };

        let hash = sui::hash::blake2b256(&data);
        sui::address::from_bytes(hash)
    }

    /// Derive Sui address from Secp256k1 public key
    fun derive_address_from_secp256k1_pubkey(public_key: &vector<u8>): address {
        // Sui address derivation: BLAKE2b-256(flag || public_key)
        // Flag for Secp256k1 is 0x01
        let mut data = vector::empty<u8>();
        vector::push_back(&mut data, 0x01); // Secp256k1 flag
        let mut i = 0;
        while (i < vector::length(public_key)) {
            vector::push_back(&mut data, *vector::borrow(public_key, i));
            i = i + 1;
        };

        let hash = sui::hash::blake2b256(&data);
        sui::address::from_bytes(hash)
    }

    /// Get the current nonce for a wallet (useful for building relayed transactions)
    public fun get_nonce(wallet: &ProxyWallet): u64 {
        wallet_types::wallet_nonce(wallet)
    }

    /// Manually increment nonce (owner only) - useful for invalidating pending transactions
    public fun invalidate_nonce(
        wallet: &mut ProxyWallet,
        ctx: &TxContext,
    ) {
        let owner = wallet_types::wallet_owner(wallet);
        assert!(ctx.sender() == owner, ENotOwner);

        let wallet_address = wallet_types::wallet_id(wallet);
        let old_nonce = wallet_types::wallet_nonce(wallet);

        wallet_types::increment_nonce(wallet);

        let new_nonce = wallet_types::wallet_nonce(wallet);
        wallet_events::emit_nonce_incremented(wallet_address, old_nonce, new_nonce);
    }
}
