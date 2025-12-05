/// Token Types - Structs, constants, getters, setters, constructors
///
/// This module defines data structures for outcome tokens (YES/NO).
/// Tokens represent positions in binary prediction markets.
module predictionsmart::token_types {
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Minimum mint amount (0.01 SUI = 10_000_000 MIST)
    const MIN_MINT_AMOUNT: u64 = 10_000_000;

    // ═══════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Token Vault - Holds collateral for a specific market
    /// One vault per market, stores SUI backing all tokens
    public struct TokenVault has key, store {
        id: UID,
        /// The market this vault belongs to
        market_id: u64,
        /// SUI collateral backing all tokens
        collateral: Balance<SUI>,
        /// Total YES tokens in circulation
        yes_supply: u64,
        /// Total NO tokens in circulation
        no_supply: u64,
    }

    /// YES Token - Represents a YES position in a market
    /// Fungible within the same market
    public struct YesToken has key, store {
        id: UID,
        /// The market this token belongs to
        market_id: u64,
        /// Token amount
        amount: u64,
    }

    /// NO Token - Represents a NO position in a market
    /// Fungible within the same market
    public struct NoToken has key, store {
        id: UID,
        /// The market this token belongs to
        market_id: u64,
        /// Token amount
        amount: u64,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANT GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    public fun min_mint_amount(): u64 { MIN_MINT_AMOUNT }

    // ═══════════════════════════════════════════════════════════════════════════
    // VAULT GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    public fun vault_market_id(v: &TokenVault): u64 { v.market_id }
    public fun vault_collateral_value(v: &TokenVault): u64 { balance::value(&v.collateral) }
    public fun vault_yes_supply(v: &TokenVault): u64 { v.yes_supply }
    public fun vault_no_supply(v: &TokenVault): u64 { v.no_supply }

    // ═══════════════════════════════════════════════════════════════════════════
    // YES TOKEN GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    public fun yes_token_market_id(t: &YesToken): u64 { t.market_id }
    public fun yes_token_amount(t: &YesToken): u64 { t.amount }

    // ═══════════════════════════════════════════════════════════════════════════
    // NO TOKEN GETTERS
    // ═══════════════════════════════════════════════════════════════════════════

    public fun no_token_market_id(t: &NoToken): u64 { t.market_id }
    public fun no_token_amount(t: &NoToken): u64 { t.amount }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTRUCTORS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a new TokenVault for a market
    public(package) fun new_vault(
        market_id: u64,
        ctx: &mut TxContext,
    ): TokenVault {
        TokenVault {
            id: object::new(ctx),
            market_id,
            collateral: balance::zero<SUI>(),
            yes_supply: 0,
            no_supply: 0,
        }
    }

    /// Create a new YesToken
    public(package) fun new_yes_token(
        market_id: u64,
        amount: u64,
        ctx: &mut TxContext,
    ): YesToken {
        YesToken {
            id: object::new(ctx),
            market_id,
            amount,
        }
    }

    /// Create a new NoToken
    public(package) fun new_no_token(
        market_id: u64,
        amount: u64,
        ctx: &mut TxContext,
    ): NoToken {
        NoToken {
            id: object::new(ctx),
            market_id,
            amount,
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VAULT SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Add collateral to vault
    public(package) fun add_collateral(v: &mut TokenVault, collateral: Balance<SUI>) {
        balance::join(&mut v.collateral, collateral);
    }

    /// Remove collateral from vault
    public(package) fun remove_collateral(v: &mut TokenVault, amount: u64): Balance<SUI> {
        balance::split(&mut v.collateral, amount)
    }

    /// Increase YES token supply
    public(package) fun increase_yes_supply(v: &mut TokenVault, amount: u64) {
        v.yes_supply = v.yes_supply + amount;
    }

    /// Decrease YES token supply
    public(package) fun decrease_yes_supply(v: &mut TokenVault, amount: u64) {
        v.yes_supply = v.yes_supply - amount;
    }

    /// Increase NO token supply
    public(package) fun increase_no_supply(v: &mut TokenVault, amount: u64) {
        v.no_supply = v.no_supply + amount;
    }

    /// Decrease NO token supply
    public(package) fun decrease_no_supply(v: &mut TokenVault, amount: u64) {
        v.no_supply = v.no_supply - amount;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TOKEN SETTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Add amount to YES token
    public(package) fun add_yes_amount(t: &mut YesToken, amount: u64) {
        t.amount = t.amount + amount;
    }

    /// Subtract amount from YES token
    public(package) fun subtract_yes_amount(t: &mut YesToken, amount: u64) {
        t.amount = t.amount - amount;
    }

    /// Add amount to NO token
    public(package) fun add_no_amount(t: &mut NoToken, amount: u64) {
        t.amount = t.amount + amount;
    }

    /// Subtract amount from NO token
    public(package) fun subtract_no_amount(t: &mut NoToken, amount: u64) {
        t.amount = t.amount - amount;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TRANSFER FUNCTIONS (must be in defining module)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Share a vault globally
    #[allow(lint(share_owned, custom_state_change))]
    public(package) fun share_vault(vault: TokenVault) {
        transfer::share_object(vault);
    }

    /// Transfer YES token to recipient
    #[allow(lint(custom_state_change))]
    public(package) fun transfer_yes_token(token: YesToken, recipient: address) {
        transfer::transfer(token, recipient);
    }

    /// Transfer NO token to recipient
    #[allow(lint(custom_state_change))]
    public(package) fun transfer_no_token(token: NoToken, recipient: address) {
        transfer::transfer(token, recipient);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DESTROY FUNCTIONS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Destroy a YES token (when burning/redeeming)
    public(package) fun destroy_yes_token(token: YesToken): (u64, u64) {
        let YesToken { id, market_id, amount } = token;
        object::delete(id);
        (market_id, amount)
    }

    /// Destroy a NO token (when burning/redeeming)
    public(package) fun destroy_no_token(token: NoToken): (u64, u64) {
        let NoToken { id, market_id, amount } = token;
        object::delete(id);
        (market_id, amount)
    }

    /// Burn a YES token (alias for destroy, for AMM operations)
    public(package) fun burn_yes_token(token: YesToken) {
        let YesToken { id, market_id: _, amount: _ } = token;
        object::delete(id);
    }

    /// Burn a NO token (alias for destroy, for AMM operations)
    public(package) fun burn_no_token(token: NoToken) {
        let NoToken { id, market_id: _, amount: _ } = token;
        object::delete(id);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test_only]
    public fun destroy_vault_for_testing(v: TokenVault) {
        let TokenVault { id, market_id: _, collateral, yes_supply: _, no_supply: _ } = v;
        balance::destroy_for_testing(collateral);
        object::delete(id);
    }

    #[test_only]
    public fun destroy_yes_token_for_testing(t: YesToken) {
        let YesToken { id, market_id: _, amount: _ } = t;
        object::delete(id);
    }

    #[test_only]
    public fun destroy_no_token_for_testing(t: NoToken) {
        let NoToken { id, market_id: _, amount: _ } = t;
        object::delete(id);
    }

    #[test_only]
    public fun new_token_vault_for_testing(market_id: u64, ctx: &mut TxContext): TokenVault {
        new_vault(market_id, ctx)
    }

    #[test_only]
    public fun mint_yes_for_testing(vault: &mut TokenVault, amount: u64, ctx: &mut TxContext): YesToken {
        vault.yes_supply = vault.yes_supply + amount;
        new_yes_token(vault.market_id, amount, ctx)
    }

    #[test_only]
    public fun mint_no_for_testing(vault: &mut TokenVault, amount: u64, ctx: &mut TxContext): NoToken {
        vault.no_supply = vault.no_supply + amount;
        new_no_token(vault.market_id, amount, ctx)
    }

    #[test_only]
    public fun destroy_token_vault_for_testing(v: TokenVault) {
        destroy_vault_for_testing(v)
    }
}
