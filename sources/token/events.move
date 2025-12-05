/// Token Events - Event structs and emit functions
///
/// All events related to token operations (minting, merging, redemption).
module predictionsmart::token_events {
    use sui::event;

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENT STRUCTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emitted when a token vault is created for a market
    public struct VaultCreated has copy, drop {
        market_id: u64,
        timestamp: u64,
    }

    /// Emitted when tokens are minted (user deposits collateral)
    public struct TokensMinted has copy, drop {
        market_id: u64,
        minter: address,
        collateral_amount: u64,
        yes_amount: u64,
        no_amount: u64,
        timestamp: u64,
    }

    /// Emitted when tokens are merged (user returns YES + NO for collateral)
    public struct TokensMerged has copy, drop {
        market_id: u64,
        merger: address,
        yes_amount: u64,
        no_amount: u64,
        collateral_returned: u64,
        timestamp: u64,
    }

    /// Emitted when winning tokens are redeemed after resolution
    public struct TokensRedeemed has copy, drop {
        market_id: u64,
        redeemer: address,
        outcome: u8,
        token_amount: u64,
        collateral_received: u64,
        fee_paid: u64,
        timestamp: u64,
    }

    /// Emitted when tokens are redeemed from a voided market
    public struct VoidRedemption has copy, drop {
        market_id: u64,
        redeemer: address,
        yes_amount: u64,
        no_amount: u64,
        collateral_received: u64,
        timestamp: u64,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EMIT FUNCTIONS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    public(package) fun emit_vault_created(
        market_id: u64,
        timestamp: u64,
    ) {
        event::emit(VaultCreated {
            market_id,
            timestamp,
        });
    }

    public(package) fun emit_tokens_minted(
        market_id: u64,
        minter: address,
        collateral_amount: u64,
        yes_amount: u64,
        no_amount: u64,
        timestamp: u64,
    ) {
        event::emit(TokensMinted {
            market_id,
            minter,
            collateral_amount,
            yes_amount,
            no_amount,
            timestamp,
        });
    }

    public(package) fun emit_tokens_merged(
        market_id: u64,
        merger: address,
        yes_amount: u64,
        no_amount: u64,
        collateral_returned: u64,
        timestamp: u64,
    ) {
        event::emit(TokensMerged {
            market_id,
            merger,
            yes_amount,
            no_amount,
            collateral_returned,
            timestamp,
        });
    }

    public(package) fun emit_tokens_redeemed(
        market_id: u64,
        redeemer: address,
        outcome: u8,
        token_amount: u64,
        collateral_received: u64,
        fee_paid: u64,
        timestamp: u64,
    ) {
        event::emit(TokensRedeemed {
            market_id,
            redeemer,
            outcome,
            token_amount,
            collateral_received,
            fee_paid,
            timestamp,
        });
    }

    public(package) fun emit_void_redemption(
        market_id: u64,
        redeemer: address,
        yes_amount: u64,
        no_amount: u64,
        collateral_received: u64,
        timestamp: u64,
    ) {
        event::emit(VoidRedemption {
            market_id,
            redeemer,
            yes_amount,
            no_amount,
            collateral_received,
            timestamp,
        });
    }
}
