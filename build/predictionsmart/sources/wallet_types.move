/// Wallet Types - Structs, constants, getters, setters, constructors
///
/// This module defines all data structures for the proxy wallet system.
module predictionsmart::wallet_types {
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};

    use predictionsmart::token_types::{YesToken, NoToken};
    use predictionsmart::trading_types::LPToken;

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    // --- Approval Scopes ---
    const SCOPE_NONE: u8 = 0;
    const SCOPE_TRADE: u8 = 1;
    const SCOPE_TRANSFER: u8 = 2;
    const SCOPE_LIQUIDITY: u8 = 3;
    const SCOPE_ALL: u8 = 255;

    // --- Wallet Status ---
    const STATUS_ACTIVE: u8 = 0;
    const STATUS_LOCKED: u8 = 1;

    // --- Action Types (for transaction execution) ---
    const ACTION_TRANSFER_SUI: u8 = 1;
    const ACTION_TRANSFER_YES: u8 = 2;
    const ACTION_TRANSFER_NO: u8 = 3;
    const ACTION_TRANSFER_LP: u8 = 4;
    const ACTION_PLACE_ORDER: u8 = 10;
    const ACTION_CANCEL_ORDER: u8 = 11;
    const ACTION_ADD_LIQUIDITY: u8 = 20;
    const ACTION_REMOVE_LIQUIDITY: u8 = 21;
    const ACTION_SWAP: u8 = 22;

    // --- Signature Schemes ---
    const SIG_SCHEME_ED25519: u8 = 0;
    const SIG_SCHEME_SECP256K1: u8 = 1;

    // --- Domain Separator (for signature verification) ---
    // "PredictionSmart Wallet v1"
    const DOMAIN_SEPARATOR: vector<u8> = b"PredictionSmart Wallet v1";

    // ═══════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// ProxyWallet - Smart contract wallet for a user
    public struct ProxyWallet has key, store {
        id: UID,
        /// EOA that controls this wallet
        owner: address,
        /// For replay protection on relayed transactions
        nonce: u64,
        /// Deployment timestamp
        created_at: u64,
        /// Wallet status (active/locked)
        status: u8,
        /// SUI balance held in wallet
        sui_balance: Balance<SUI>,
        /// YES tokens held (market_id -> token)
        yes_tokens: Table<u64, YesToken>,
        /// NO tokens held (market_id -> token)
        no_tokens: Table<u64, NoToken>,
        /// LP tokens held (market_id -> token)
        lp_tokens: Table<u64, LPToken>,
        /// Operator approvals (operator address -> Approval)
        approvals: Table<address, Approval>,
    }

    /// WalletFactory - Deploys and tracks proxy wallets
    public struct WalletFactory has key {
        id: UID,
        /// Factory admin
        admin: address,
        /// Total wallets deployed
        wallet_count: u64,
        /// Owner address -> Wallet object ID mapping
        wallet_registry: Table<address, address>,
        /// Fee to deploy wallet (can be 0)
        deployment_fee: u64,
        /// Collected fees
        collected_fees: Balance<SUI>,
    }

    /// Approval - Operator permissions for a wallet
    public struct Approval has store, drop, copy {
        /// Approved operator address
        operator: address,
        /// What actions are approved (scope)
        scope: u8,
        /// Spending/action limit
        limit: u64,
        /// Expiration timestamp (0 = no expiry)
        expiry: u64,
        /// Amount already used against limit
        used: u64,
    }

    /// WalletAction - Encoded action for execution
    public struct WalletAction has store, drop, copy {
        /// Action type (transfer, trade, etc.)
        action_type: u8,
        /// Target address (recipient for transfers)
        target: address,
        /// Amount (SUI amount or token amount)
        amount: u64,
        /// Market ID (for token operations)
        market_id: u64,
        /// Additional data (price for orders, etc.)
        data: u64,
    }

    /// RelayedTransaction - For gasless transaction execution
    public struct RelayedTransaction has store, drop, copy {
        /// Target wallet address
        wallet: address,
        /// Action to execute
        action: WalletAction,
        /// Wallet nonce at time of signing
        nonce: u64,
        /// Transaction deadline (timestamp)
        deadline: u64,
        /// Signature scheme (0 = ed25519, 1 = secp256k1)
        sig_scheme: u8,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANT GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    // --- Scopes ---
    public fun scope_none(): u8 { SCOPE_NONE }
    public fun scope_trade(): u8 { SCOPE_TRADE }
    public fun scope_transfer(): u8 { SCOPE_TRANSFER }
    public fun scope_liquidity(): u8 { SCOPE_LIQUIDITY }
    public fun scope_all(): u8 { SCOPE_ALL }

    // --- Status ---
    public fun status_active(): u8 { STATUS_ACTIVE }
    public fun status_locked(): u8 { STATUS_LOCKED }

    // --- Action Types ---
    public fun action_transfer_sui(): u8 { ACTION_TRANSFER_SUI }
    public fun action_transfer_yes(): u8 { ACTION_TRANSFER_YES }
    public fun action_transfer_no(): u8 { ACTION_TRANSFER_NO }
    public fun action_transfer_lp(): u8 { ACTION_TRANSFER_LP }
    public fun action_place_order(): u8 { ACTION_PLACE_ORDER }
    public fun action_cancel_order(): u8 { ACTION_CANCEL_ORDER }
    public fun action_add_liquidity(): u8 { ACTION_ADD_LIQUIDITY }
    public fun action_remove_liquidity(): u8 { ACTION_REMOVE_LIQUIDITY }
    public fun action_swap(): u8 { ACTION_SWAP }

    // --- Signature Schemes ---
    public fun sig_scheme_ed25519(): u8 { SIG_SCHEME_ED25519 }
    public fun sig_scheme_secp256k1(): u8 { SIG_SCHEME_SECP256K1 }

    // --- Domain Separator ---
    public fun domain_separator(): vector<u8> { DOMAIN_SEPARATOR }

    /// Get the scope required for an action type
    public fun action_to_scope(action_type: u8): u8 {
        if (action_type == ACTION_TRANSFER_SUI ||
            action_type == ACTION_TRANSFER_YES ||
            action_type == ACTION_TRANSFER_NO ||
            action_type == ACTION_TRANSFER_LP) {
            SCOPE_TRANSFER
        } else if (action_type == ACTION_PLACE_ORDER || action_type == ACTION_CANCEL_ORDER) {
            SCOPE_TRADE
        } else if (action_type == ACTION_ADD_LIQUIDITY ||
                   action_type == ACTION_REMOVE_LIQUIDITY ||
                   action_type == ACTION_SWAP) {
            SCOPE_LIQUIDITY
        } else {
            SCOPE_NONE
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PROXY WALLET GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    public fun wallet_owner(w: &ProxyWallet): address { w.owner }
    public fun wallet_nonce(w: &ProxyWallet): u64 { w.nonce }
    public fun wallet_created_at(w: &ProxyWallet): u64 { w.created_at }
    public fun wallet_status(w: &ProxyWallet): u8 { w.status }
    public fun wallet_is_active(w: &ProxyWallet): bool { w.status == STATUS_ACTIVE }
    public fun wallet_is_locked(w: &ProxyWallet): bool { w.status == STATUS_LOCKED }

    /// Get SUI balance in wallet
    public fun wallet_sui_balance(w: &ProxyWallet): u64 {
        balance::value(&w.sui_balance)
    }

    /// Check if wallet has YES tokens for a market
    public fun wallet_has_yes_token(w: &ProxyWallet, market_id: u64): bool {
        table::contains(&w.yes_tokens, market_id)
    }

    /// Check if wallet has NO tokens for a market
    public fun wallet_has_no_token(w: &ProxyWallet, market_id: u64): bool {
        table::contains(&w.no_tokens, market_id)
    }

    /// Check if wallet has LP tokens for a market
    public fun wallet_has_lp_token(w: &ProxyWallet, market_id: u64): bool {
        table::contains(&w.lp_tokens, market_id)
    }

    /// Get YES token reference for a market
    public fun wallet_get_yes_token(w: &ProxyWallet, market_id: u64): &YesToken {
        table::borrow(&w.yes_tokens, market_id)
    }

    /// Get NO token reference for a market
    public fun wallet_get_no_token(w: &ProxyWallet, market_id: u64): &NoToken {
        table::borrow(&w.no_tokens, market_id)
    }

    /// Get LP token reference for a market
    public fun wallet_get_lp_token(w: &ProxyWallet, market_id: u64): &LPToken {
        table::borrow(&w.lp_tokens, market_id)
    }

    /// Check if wallet has an approval for an operator
    public fun wallet_has_approval(w: &ProxyWallet, operator: address): bool {
        table::contains(&w.approvals, operator)
    }

    /// Get approval for an operator
    public fun wallet_get_approval(w: &ProxyWallet, operator: address): &Approval {
        table::borrow(&w.approvals, operator)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // WALLET FACTORY GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    public fun factory_admin(f: &WalletFactory): address { f.admin }
    public fun factory_wallet_count(f: &WalletFactory): u64 { f.wallet_count }
    public fun factory_deployment_fee(f: &WalletFactory): u64 { f.deployment_fee }
    public fun factory_collected_fees(f: &WalletFactory): u64 {
        balance::value(&f.collected_fees)
    }

    /// Check if user already has a wallet
    public fun factory_has_wallet(f: &WalletFactory, owner: address): bool {
        table::contains(&f.wallet_registry, owner)
    }

    /// Get wallet address for an owner
    public fun factory_get_wallet(f: &WalletFactory, owner: address): address {
        *table::borrow(&f.wallet_registry, owner)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // APPROVAL GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    public fun approval_operator(a: &Approval): address { a.operator }
    public fun approval_scope(a: &Approval): u8 { a.scope }
    public fun approval_limit(a: &Approval): u64 { a.limit }
    public fun approval_expiry(a: &Approval): u64 { a.expiry }
    public fun approval_used(a: &Approval): u64 { a.used }
    public fun approval_remaining(a: &Approval): u64 { a.limit - a.used }

    /// Check if approval is valid (not expired, has remaining limit)
    public fun approval_is_valid(a: &Approval, current_time: u64): bool {
        (a.expiry == 0 || current_time < a.expiry) && a.used < a.limit
    }

    /// Check if approval covers a specific scope
    public fun approval_has_scope(a: &Approval, scope: u8): bool {
        a.scope == SCOPE_ALL || a.scope == scope
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // WALLET ACTION GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    public fun action_type(a: &WalletAction): u8 { a.action_type }
    public fun action_target(a: &WalletAction): address { a.target }
    public fun action_amount(a: &WalletAction): u64 { a.amount }
    public fun action_market_id(a: &WalletAction): u64 { a.market_id }
    public fun action_data(a: &WalletAction): u64 { a.data }

    // ═══════════════════════════════════════════════════════════════════════════
    // RELAYED TRANSACTION GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    public fun relayed_tx_wallet(tx: &RelayedTransaction): address { tx.wallet }
    public fun relayed_tx_action(tx: &RelayedTransaction): &WalletAction { &tx.action }
    public fun relayed_tx_nonce(tx: &RelayedTransaction): u64 { tx.nonce }
    public fun relayed_tx_deadline(tx: &RelayedTransaction): u64 { tx.deadline }
    public fun relayed_tx_sig_scheme(tx: &RelayedTransaction): u8 { tx.sig_scheme }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTORS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a new ProxyWallet
    public(package) fun new_proxy_wallet(
        owner: address,
        created_at: u64,
        ctx: &mut TxContext,
    ): ProxyWallet {
        ProxyWallet {
            id: object::new(ctx),
            owner,
            nonce: 0,
            created_at,
            status: STATUS_ACTIVE,
            sui_balance: balance::zero(),
            yes_tokens: table::new(ctx),
            no_tokens: table::new(ctx),
            lp_tokens: table::new(ctx),
            approvals: table::new(ctx),
        }
    }

    /// Create a new WalletFactory
    public(package) fun new_wallet_factory(
        admin: address,
        deployment_fee: u64,
        ctx: &mut TxContext,
    ): WalletFactory {
        WalletFactory {
            id: object::new(ctx),
            admin,
            wallet_count: 0,
            wallet_registry: table::new(ctx),
            deployment_fee,
            collected_fees: balance::zero(),
        }
    }

    /// Create a new Approval
    public(package) fun new_approval(
        operator: address,
        scope: u8,
        limit: u64,
        expiry: u64,
    ): Approval {
        Approval {
            operator,
            scope,
            limit,
            expiry,
            used: 0,
        }
    }

    /// Create a new WalletAction
    public(package) fun new_wallet_action(
        action_type: u8,
        target: address,
        amount: u64,
        market_id: u64,
        data: u64,
    ): WalletAction {
        WalletAction {
            action_type,
            target,
            amount,
            market_id,
            data,
        }
    }

    /// Create a new RelayedTransaction
    public(package) fun new_relayed_transaction(
        wallet: address,
        action: WalletAction,
        nonce: u64,
        deadline: u64,
        sig_scheme: u8,
    ): RelayedTransaction {
        RelayedTransaction {
            wallet,
            action,
            nonce,
            deadline,
            sig_scheme,
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PROXY WALLET SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Transfer ownership of wallet
    public(package) fun set_wallet_owner(w: &mut ProxyWallet, new_owner: address) {
        w.owner = new_owner;
    }

    /// Increment nonce
    public(package) fun increment_nonce(w: &mut ProxyWallet) {
        w.nonce = w.nonce + 1;
    }

    /// Lock wallet
    public(package) fun lock_wallet(w: &mut ProxyWallet) {
        w.status = STATUS_LOCKED;
    }

    /// Unlock wallet
    public(package) fun unlock_wallet(w: &mut ProxyWallet) {
        w.status = STATUS_ACTIVE;
    }

    /// Deposit SUI into wallet
    public(package) fun deposit_sui(w: &mut ProxyWallet, coin: Coin<SUI>) {
        let coin_balance = coin::into_balance(coin);
        balance::join(&mut w.sui_balance, coin_balance);
    }

    /// Withdraw SUI from wallet
    public(package) fun withdraw_sui(w: &mut ProxyWallet, amount: u64, ctx: &mut TxContext): Coin<SUI> {
        let withdrawn = balance::split(&mut w.sui_balance, amount);
        coin::from_balance(withdrawn, ctx)
    }

    /// Deposit YES token into wallet
    public(package) fun deposit_yes_token(w: &mut ProxyWallet, market_id: u64, token: YesToken) {
        if (table::contains(&w.yes_tokens, market_id)) {
            // Would need to merge tokens - for now, abort if exists
            abort 0 // TODO: Implement token merging
        };
        table::add(&mut w.yes_tokens, market_id, token);
    }

    /// Withdraw YES token from wallet
    public(package) fun withdraw_yes_token(w: &mut ProxyWallet, market_id: u64): YesToken {
        table::remove(&mut w.yes_tokens, market_id)
    }

    /// Deposit NO token into wallet
    public(package) fun deposit_no_token(w: &mut ProxyWallet, market_id: u64, token: NoToken) {
        if (table::contains(&w.no_tokens, market_id)) {
            abort 0 // TODO: Implement token merging
        };
        table::add(&mut w.no_tokens, market_id, token);
    }

    /// Withdraw NO token from wallet
    public(package) fun withdraw_no_token(w: &mut ProxyWallet, market_id: u64): NoToken {
        table::remove(&mut w.no_tokens, market_id)
    }

    /// Deposit LP token into wallet
    public(package) fun deposit_lp_token(w: &mut ProxyWallet, market_id: u64, token: LPToken) {
        if (table::contains(&w.lp_tokens, market_id)) {
            abort 0 // TODO: Implement token merging
        };
        table::add(&mut w.lp_tokens, market_id, token);
    }

    /// Withdraw LP token from wallet
    public(package) fun withdraw_lp_token(w: &mut ProxyWallet, market_id: u64): LPToken {
        table::remove(&mut w.lp_tokens, market_id)
    }

    /// Grant an approval to an operator
    public(package) fun grant_approval(w: &mut ProxyWallet, approval: Approval) {
        let operator = approval.operator;
        if (table::contains(&w.approvals, operator)) {
            // Replace existing approval
            table::remove(&mut w.approvals, operator);
        };
        table::add(&mut w.approvals, operator, approval);
    }

    /// Revoke an approval from an operator
    public(package) fun revoke_approval(w: &mut ProxyWallet, operator: address) {
        if (table::contains(&w.approvals, operator)) {
            table::remove(&mut w.approvals, operator);
        };
    }

    /// Get mutable reference to approval for updating used amount
    public(package) fun get_approval_mut(w: &mut ProxyWallet, operator: address): &mut Approval {
        table::borrow_mut(&mut w.approvals, operator)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // WALLET FACTORY SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Register a new wallet in the factory
    public(package) fun register_wallet(
        f: &mut WalletFactory,
        owner: address,
        wallet_address: address,
    ) {
        table::add(&mut f.wallet_registry, owner, wallet_address);
        f.wallet_count = f.wallet_count + 1;
    }

    /// Set deployment fee
    public(package) fun set_deployment_fee(f: &mut WalletFactory, fee: u64) {
        f.deployment_fee = fee;
    }

    /// Set factory admin
    public(package) fun set_factory_admin(f: &mut WalletFactory, new_admin: address) {
        f.admin = new_admin;
    }

    /// Collect deployment fee
    public(package) fun collect_fee(f: &mut WalletFactory, payment: Coin<SUI>) {
        let payment_balance = coin::into_balance(payment);
        balance::join(&mut f.collected_fees, payment_balance);
    }

    /// Withdraw collected fees
    public(package) fun withdraw_fees(f: &mut WalletFactory, ctx: &mut TxContext): Coin<SUI> {
        let amount = balance::value(&f.collected_fees);
        let withdrawn = balance::split(&mut f.collected_fees, amount);
        coin::from_balance(withdrawn, ctx)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // APPROVAL SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Use some of the approval limit
    public(package) fun use_approval(a: &mut Approval, amount: u64) {
        a.used = a.used + amount;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TRANSFER FUNCTIONS (must be in defining module)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Share wallet factory globally
    #[allow(lint(share_owned))]
    public(package) fun share_wallet_factory(factory: WalletFactory) {
        transfer::share_object(factory);
    }

    /// Share proxy wallet globally
    #[allow(lint(share_owned, custom_state_change))]
    public(package) fun share_proxy_wallet(wallet: ProxyWallet) {
        transfer::share_object(wallet);
    }

    /// Get wallet object ID
    public fun wallet_id(w: &ProxyWallet): address {
        object::uid_to_address(&w.id)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test_only]
    /// Unregister a wallet from factory (for test cleanup)
    public fun unregister_wallet_for_testing(f: &mut WalletFactory, owner: address) {
        table::remove(&mut f.wallet_registry, owner);
        f.wallet_count = f.wallet_count - 1;
    }

    #[test_only]
    /// Remove YES token from wallet and return it (for test cleanup)
    public fun remove_yes_token_for_testing(w: &mut ProxyWallet, market_id: u64): YesToken {
        table::remove(&mut w.yes_tokens, market_id)
    }

    #[test_only]
    /// Remove NO token from wallet and return it (for test cleanup)
    public fun remove_no_token_for_testing(w: &mut ProxyWallet, market_id: u64): NoToken {
        table::remove(&mut w.no_tokens, market_id)
    }

    #[test_only]
    /// Remove LP token from wallet and return it (for test cleanup)
    public fun remove_lp_token_for_testing(w: &mut ProxyWallet, market_id: u64): LPToken {
        table::remove(&mut w.lp_tokens, market_id)
    }

    #[test_only]
    public fun destroy_proxy_wallet_for_testing(wallet: ProxyWallet) {
        // Note: Ensure all token tables and approvals are empty before calling this
        let ProxyWallet {
            id,
            owner: _,
            nonce: _,
            created_at: _,
            status: _,
            sui_balance,
            yes_tokens,
            no_tokens,
            lp_tokens,
            approvals,
        } = wallet;
        balance::destroy_for_testing(sui_balance);
        table::destroy_empty(yes_tokens);
        table::destroy_empty(no_tokens);
        table::destroy_empty(lp_tokens);
        table::destroy_empty(approvals);
        object::delete(id);
    }

    #[test_only]
    /// Remove approval for test cleanup
    public fun remove_approval_for_testing(w: &mut ProxyWallet, operator: address) {
        if (table::contains(&w.approvals, operator)) {
            table::remove(&mut w.approvals, operator);
        };
    }

    #[test_only]
    public fun destroy_wallet_factory_for_testing(factory: WalletFactory) {
        // Note: Ensure wallet_registry is empty before calling this
        let WalletFactory {
            id,
            admin: _,
            wallet_count: _,
            wallet_registry,
            deployment_fee: _,
            collected_fees,
        } = factory;
        table::destroy_empty(wallet_registry);
        balance::destroy_for_testing(collected_fees);
        object::delete(id);
    }
}
