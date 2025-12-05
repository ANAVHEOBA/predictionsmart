/// Wallet Events - All events emitted by the wallet module
///
/// This module defines events for wallet operations.
module predictionsmart::wallet_events {
    use sui::event;

    // ═══════════════════════════════════════════════════════════════════════════
    // WALLET FACTORY EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emitted when a new proxy wallet is created
    public struct WalletCreated has copy, drop {
        wallet_address: address,
        owner: address,
        created_at: u64,
    }

    /// Emitted when the factory admin is changed
    public struct FactoryAdminChanged has copy, drop {
        old_admin: address,
        new_admin: address,
    }

    /// Emitted when the deployment fee is changed
    public struct DeploymentFeeChanged has copy, drop {
        old_fee: u64,
        new_fee: u64,
    }

    /// Emitted when fees are withdrawn from factory
    public struct FactoryFeesWithdrawn has copy, drop {
        admin: address,
        amount: u64,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // WALLET OWNERSHIP EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emitted when wallet ownership is transferred
    public struct OwnershipTransferred has copy, drop {
        wallet_address: address,
        old_owner: address,
        new_owner: address,
    }

    /// Emitted when wallet is locked
    public struct WalletLocked has copy, drop {
        wallet_address: address,
        locked_by: address,
    }

    /// Emitted when wallet is unlocked
    public struct WalletUnlocked has copy, drop {
        wallet_address: address,
        unlocked_by: address,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ASSET CUSTODY EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emitted when SUI is deposited into wallet
    public struct SuiDeposited has copy, drop {
        wallet_address: address,
        depositor: address,
        amount: u64,
    }

    /// Emitted when SUI is withdrawn from wallet
    public struct SuiWithdrawn has copy, drop {
        wallet_address: address,
        recipient: address,
        amount: u64,
    }

    /// Emitted when YES token is deposited into wallet
    public struct YesTokenDeposited has copy, drop {
        wallet_address: address,
        market_id: u64,
        amount: u64,
    }

    /// Emitted when YES token is withdrawn from wallet
    public struct YesTokenWithdrawn has copy, drop {
        wallet_address: address,
        market_id: u64,
        amount: u64,
    }

    /// Emitted when NO token is deposited into wallet
    public struct NoTokenDeposited has copy, drop {
        wallet_address: address,
        market_id: u64,
        amount: u64,
    }

    /// Emitted when NO token is withdrawn from wallet
    public struct NoTokenWithdrawn has copy, drop {
        wallet_address: address,
        market_id: u64,
        amount: u64,
    }

    /// Emitted when LP token is deposited into wallet
    public struct LpTokenDeposited has copy, drop {
        wallet_address: address,
        market_id: u64,
        amount: u64,
    }

    /// Emitted when LP token is withdrawn from wallet
    public struct LpTokenWithdrawn has copy, drop {
        wallet_address: address,
        market_id: u64,
        amount: u64,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // APPROVAL EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emitted when an operator approval is granted
    public struct ApprovalGranted has copy, drop {
        wallet_address: address,
        operator: address,
        scope: u8,
        limit: u64,
        expiry: u64,
    }

    /// Emitted when an operator approval is revoked
    public struct ApprovalRevoked has copy, drop {
        wallet_address: address,
        operator: address,
    }

    /// Emitted when an operator uses their approval
    public struct ApprovalUsed has copy, drop {
        wallet_address: address,
        operator: address,
        amount_used: u64,
        remaining: u64,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TRANSACTION EXECUTION EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emitted when a transaction is executed directly by owner
    public struct TransactionExecuted has copy, drop {
        wallet_address: address,
        executor: address,
        action_type: u8,
        amount: u64,
        nonce: u64,
    }

    /// Emitted when a batch transaction is executed
    public struct BatchExecuted has copy, drop {
        wallet_address: address,
        executor: address,
        action_count: u64,
        nonce: u64,
    }

    /// Emitted when an operator executes on behalf of owner
    public struct OperatorExecuted has copy, drop {
        wallet_address: address,
        operator: address,
        action_type: u8,
        amount: u64,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // RELAYED TRANSACTION EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emitted when a relayed (gasless) transaction is executed
    public struct RelayedTransactionExecuted has copy, drop {
        wallet_address: address,
        relayer: address,
        signer: address,
        action_type: u8,
        amount: u64,
        nonce: u64,
    }

    /// Emitted when nonce is incremented
    public struct NonceIncremented has copy, drop {
        wallet_address: address,
        old_nonce: u64,
        new_nonce: u64,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENT EMITTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    // --- Factory Events ---

    public(package) fun emit_wallet_created(
        wallet_address: address,
        owner: address,
        created_at: u64,
    ) {
        event::emit(WalletCreated {
            wallet_address,
            owner,
            created_at,
        });
    }

    public(package) fun emit_factory_admin_changed(
        old_admin: address,
        new_admin: address,
    ) {
        event::emit(FactoryAdminChanged {
            old_admin,
            new_admin,
        });
    }

    public(package) fun emit_deployment_fee_changed(
        old_fee: u64,
        new_fee: u64,
    ) {
        event::emit(DeploymentFeeChanged {
            old_fee,
            new_fee,
        });
    }

    public(package) fun emit_factory_fees_withdrawn(
        admin: address,
        amount: u64,
    ) {
        event::emit(FactoryFeesWithdrawn {
            admin,
            amount,
        });
    }

    // --- Ownership Events ---

    public(package) fun emit_ownership_transferred(
        wallet_address: address,
        old_owner: address,
        new_owner: address,
    ) {
        event::emit(OwnershipTransferred {
            wallet_address,
            old_owner,
            new_owner,
        });
    }

    public(package) fun emit_wallet_locked(
        wallet_address: address,
        locked_by: address,
    ) {
        event::emit(WalletLocked {
            wallet_address,
            locked_by,
        });
    }

    public(package) fun emit_wallet_unlocked(
        wallet_address: address,
        unlocked_by: address,
    ) {
        event::emit(WalletUnlocked {
            wallet_address,
            unlocked_by,
        });
    }

    // --- Asset Custody Events ---

    public(package) fun emit_sui_deposited(
        wallet_address: address,
        depositor: address,
        amount: u64,
    ) {
        event::emit(SuiDeposited {
            wallet_address,
            depositor,
            amount,
        });
    }

    public(package) fun emit_sui_withdrawn(
        wallet_address: address,
        recipient: address,
        amount: u64,
    ) {
        event::emit(SuiWithdrawn {
            wallet_address,
            recipient,
            amount,
        });
    }

    public(package) fun emit_yes_token_deposited(
        wallet_address: address,
        market_id: u64,
        amount: u64,
    ) {
        event::emit(YesTokenDeposited {
            wallet_address,
            market_id,
            amount,
        });
    }

    public(package) fun emit_yes_token_withdrawn(
        wallet_address: address,
        market_id: u64,
        amount: u64,
    ) {
        event::emit(YesTokenWithdrawn {
            wallet_address,
            market_id,
            amount,
        });
    }

    public(package) fun emit_no_token_deposited(
        wallet_address: address,
        market_id: u64,
        amount: u64,
    ) {
        event::emit(NoTokenDeposited {
            wallet_address,
            market_id,
            amount,
        });
    }

    public(package) fun emit_no_token_withdrawn(
        wallet_address: address,
        market_id: u64,
        amount: u64,
    ) {
        event::emit(NoTokenWithdrawn {
            wallet_address,
            market_id,
            amount,
        });
    }

    public(package) fun emit_lp_token_deposited(
        wallet_address: address,
        market_id: u64,
        amount: u64,
    ) {
        event::emit(LpTokenDeposited {
            wallet_address,
            market_id,
            amount,
        });
    }

    public(package) fun emit_lp_token_withdrawn(
        wallet_address: address,
        market_id: u64,
        amount: u64,
    ) {
        event::emit(LpTokenWithdrawn {
            wallet_address,
            market_id,
            amount,
        });
    }

    // --- Approval Events ---

    public(package) fun emit_approval_granted(
        wallet_address: address,
        operator: address,
        scope: u8,
        limit: u64,
        expiry: u64,
    ) {
        event::emit(ApprovalGranted {
            wallet_address,
            operator,
            scope,
            limit,
            expiry,
        });
    }

    public(package) fun emit_approval_revoked(
        wallet_address: address,
        operator: address,
    ) {
        event::emit(ApprovalRevoked {
            wallet_address,
            operator,
        });
    }

    public(package) fun emit_approval_used(
        wallet_address: address,
        operator: address,
        amount_used: u64,
        remaining: u64,
    ) {
        event::emit(ApprovalUsed {
            wallet_address,
            operator,
            amount_used,
            remaining,
        });
    }

    // --- Transaction Execution Events ---

    public(package) fun emit_transaction_executed(
        wallet_address: address,
        executor: address,
        action_type: u8,
        amount: u64,
        nonce: u64,
    ) {
        event::emit(TransactionExecuted {
            wallet_address,
            executor,
            action_type,
            amount,
            nonce,
        });
    }

    public(package) fun emit_batch_executed(
        wallet_address: address,
        executor: address,
        action_count: u64,
        nonce: u64,
    ) {
        event::emit(BatchExecuted {
            wallet_address,
            executor,
            action_count,
            nonce,
        });
    }

    public(package) fun emit_operator_executed(
        wallet_address: address,
        operator: address,
        action_type: u8,
        amount: u64,
    ) {
        event::emit(OperatorExecuted {
            wallet_address,
            operator,
            action_type,
            amount,
        });
    }

    // --- Relayed Transaction Events ---

    public(package) fun emit_relayed_transaction_executed(
        wallet_address: address,
        relayer: address,
        signer: address,
        action_type: u8,
        amount: u64,
        nonce: u64,
    ) {
        event::emit(RelayedTransactionExecuted {
            wallet_address,
            relayer,
            signer,
            action_type,
            amount,
            nonce,
        });
    }

    public(package) fun emit_nonce_incremented(
        wallet_address: address,
        old_nonce: u64,
        new_nonce: u64,
    ) {
        event::emit(NonceIncremented {
            wallet_address,
            old_nonce,
            new_nonce,
        });
    }
}
