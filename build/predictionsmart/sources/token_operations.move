/// Token Operations - Core business logic
///
/// This module contains all the business logic for token operations:
/// - Creating vaults
/// - Minting token sets
/// - Merging token sets
/// - Redeeming tokens
module predictionsmart::token_operations {
    use sui::clock::Clock;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance;

    use predictionsmart::market_types::{Self, Market, MarketRegistry};
    use predictionsmart::market_operations;
    use predictionsmart::token_types::{Self, TokenVault, YesToken, NoToken};
    use predictionsmart::token_events;

    // ═══════════════════════════════════════════════════════════════════════════
    // ERROR CODES
    // ═══════════════════════════════════════════════════════════════════════════

    const E_MARKET_NOT_OPEN: u64 = 100;
    const E_AMOUNT_TOO_SMALL: u64 = 101;
    const E_MARKET_ID_MISMATCH: u64 = 102;
    const E_INSUFFICIENT_BALANCE: u64 = 103;
    const E_AMOUNT_MISMATCH: u64 = 104;
    const E_MARKET_NOT_RESOLVED: u64 = 105;
    const E_MARKET_NOT_VOIDED: u64 = 106;
    const E_NOT_WINNING_OUTCOME: u64 = 107;
    const E_NO_TOKENS_TO_REDEEM: u64 = 108;

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: TOKEN VAULT
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a new token vault for a market
    /// Called when market is created
    public fun create_vault(
        market_id: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): TokenVault {
        let vault = token_types::new_vault(market_id, ctx);

        token_events::emit_vault_created(
            market_id,
            clock.timestamp_ms(),
        );

        vault
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 2: MINT TOKEN SETS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Mint YES and NO tokens by depositing collateral
    /// 1 SUI = 1 YES + 1 NO
    /// Returns (YesToken, NoToken) to be transferred to user
    public fun mint_token_set(
        market: &mut Market,
        registry: &mut MarketRegistry,
        vault: &mut TokenVault,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (YesToken, NoToken) {
        // Validate market is open
        assert!(market_types::is_open(market), E_MARKET_NOT_OPEN);

        // Validate vault matches market
        let market_id = market_types::market_id(market);
        assert!(token_types::vault_market_id(vault) == market_id, E_MARKET_ID_MISMATCH);

        // Validate amount
        let amount = coin::value(&payment);
        assert!(amount >= token_types::min_mint_amount(), E_AMOUNT_TOO_SMALL);

        // Add collateral to vault
        let collateral_balance = coin::into_balance(payment);
        token_types::add_collateral(vault, collateral_balance);

        // Update vault supply
        token_types::increase_yes_supply(vault, amount);
        token_types::increase_no_supply(vault, amount);

        // Update market tracking
        market_operations::add_collateral(market, registry, amount, clock);
        market_operations::add_volume(market, registry, amount, clock);

        // Create tokens
        let yes_token = token_types::new_yes_token(market_id, amount, ctx);
        let no_token = token_types::new_no_token(market_id, amount, ctx);

        // Emit event
        token_events::emit_tokens_minted(
            market_id,
            ctx.sender(),
            amount,
            amount,
            amount,
            clock.timestamp_ms(),
        );

        (yes_token, no_token)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TOKEN UTILITIES
    // ═══════════════════════════════════════════════════════════════════════════

    /// Split a YES token into two
    /// Returns (original with reduced amount, new token with split amount)
    public fun split_yes_token(
        token: &mut YesToken,
        split_amount: u64,
        ctx: &mut TxContext,
    ): YesToken {
        let current_amount = token_types::yes_token_amount(token);
        assert!(split_amount <= current_amount, E_INSUFFICIENT_BALANCE);

        token_types::subtract_yes_amount(token, split_amount);

        token_types::new_yes_token(
            token_types::yes_token_market_id(token),
            split_amount,
            ctx,
        )
    }

    /// Split a NO token into two
    /// Returns (original with reduced amount, new token with split amount)
    public fun split_no_token(
        token: &mut NoToken,
        split_amount: u64,
        ctx: &mut TxContext,
    ): NoToken {
        let current_amount = token_types::no_token_amount(token);
        assert!(split_amount <= current_amount, E_INSUFFICIENT_BALANCE);

        token_types::subtract_no_amount(token, split_amount);

        token_types::new_no_token(
            token_types::no_token_market_id(token),
            split_amount,
            ctx,
        )
    }

    /// Merge two YES tokens into one
    /// Destroys token_to_merge and adds its amount to token
    public fun merge_yes_tokens(
        token: &mut YesToken,
        token_to_merge: YesToken,
    ) {
        let (merge_market_id, merge_amount) = token_types::destroy_yes_token(token_to_merge);

        // Must be same market
        assert!(
            token_types::yes_token_market_id(token) == merge_market_id,
            E_MARKET_ID_MISMATCH
        );

        token_types::add_yes_amount(token, merge_amount);
    }

    /// Merge two NO tokens into one
    /// Destroys token_to_merge and adds its amount to token
    public fun merge_no_tokens(
        token: &mut NoToken,
        token_to_merge: NoToken,
    ) {
        let (merge_market_id, merge_amount) = token_types::destroy_no_token(token_to_merge);

        // Must be same market
        assert!(
            token_types::no_token_market_id(token) == merge_market_id,
            E_MARKET_ID_MISMATCH
        );

        token_types::add_no_amount(token, merge_amount);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: MERGE TOKEN SETS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Merge a YES and NO token set back into collateral
    /// Burns equal amounts of YES and NO tokens, returns SUI
    /// Can only be done while market is still open
    public fun merge_token_set(
        market: &mut Market,
        registry: &mut MarketRegistry,
        vault: &mut TokenVault,
        yes_token: YesToken,
        no_token: NoToken,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        // Validate market is open (can only merge while trading)
        assert!(market_types::is_open(market), E_MARKET_NOT_OPEN);

        let market_id = market_types::market_id(market);

        // Validate tokens belong to this market
        let (yes_market_id, yes_amount) = token_types::destroy_yes_token(yes_token);
        let (no_market_id, no_amount) = token_types::destroy_no_token(no_token);

        assert!(yes_market_id == market_id, E_MARKET_ID_MISMATCH);
        assert!(no_market_id == market_id, E_MARKET_ID_MISMATCH);

        // Must have equal amounts
        assert!(yes_amount == no_amount, E_AMOUNT_MISMATCH);

        let amount = yes_amount;
        assert!(amount > 0, E_NO_TOKENS_TO_REDEEM);

        // Update vault supply
        token_types::decrease_yes_supply(vault, amount);
        token_types::decrease_no_supply(vault, amount);

        // Remove collateral from vault
        let collateral_balance = token_types::remove_collateral(vault, amount);

        // Update market tracking
        market_operations::remove_collateral(market, registry, amount, clock);

        // Emit event
        token_events::emit_tokens_merged(
            market_id,
            ctx.sender(),
            amount,
            amount,
            amount,
            clock.timestamp_ms(),
        );

        // Convert balance to coin and return
        coin::from_balance(collateral_balance, ctx)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 4: REDEEM WINNING TOKENS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Redeem winning YES tokens after market resolves to YES
    /// Burns YES tokens, returns proportional collateral minus fee
    public fun redeem_yes_tokens(
        market: &Market,
        registry: &mut MarketRegistry,
        vault: &mut TokenVault,
        yes_token: YesToken,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        // Validate market is resolved
        assert!(market_types::is_resolved(market), E_MARKET_NOT_RESOLVED);

        // Validate YES is the winning outcome
        assert!(
            market_types::winning_outcome(market) == market_types::outcome_yes(),
            E_NOT_WINNING_OUTCOME
        );

        let market_id = market_types::market_id(market);

        // Validate token belongs to this market
        let (token_market_id, amount) = token_types::destroy_yes_token(yes_token);
        assert!(token_market_id == market_id, E_MARKET_ID_MISMATCH);
        assert!(amount > 0, E_NO_TOKENS_TO_REDEEM);

        // Calculate fee
        let fee_bps = market_types::fee_bps(market);
        let fee_amount = (amount * (fee_bps as u64)) / 10000;
        let payout = amount - fee_amount;

        // Update vault supply
        token_types::decrease_yes_supply(vault, amount);

        // Remove collateral from vault (full amount)
        let mut collateral_balance = token_types::remove_collateral(vault, amount);

        // Split fee and send to treasury
        if (fee_amount > 0) {
            let fee_balance = balance::split(&mut collateral_balance, fee_amount);
            let fee_coin = coin::from_balance(fee_balance, ctx);
            let treasury = market_types::registry_treasury(registry);
            transfer::public_transfer(fee_coin, treasury);
        };

        // Emit event
        token_events::emit_tokens_redeemed(
            market_id,
            ctx.sender(),
            market_types::outcome_yes(),
            amount,
            payout,
            fee_amount,
            clock.timestamp_ms(),
        );

        // Return payout to user
        coin::from_balance(collateral_balance, ctx)
    }

    /// Redeem winning NO tokens after market resolves to NO
    /// Burns NO tokens, returns proportional collateral minus fee
    public fun redeem_no_tokens(
        market: &Market,
        registry: &mut MarketRegistry,
        vault: &mut TokenVault,
        no_token: NoToken,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        // Validate market is resolved
        assert!(market_types::is_resolved(market), E_MARKET_NOT_RESOLVED);

        // Validate NO is the winning outcome
        assert!(
            market_types::winning_outcome(market) == market_types::outcome_no(),
            E_NOT_WINNING_OUTCOME
        );

        let market_id = market_types::market_id(market);

        // Validate token belongs to this market
        let (token_market_id, amount) = token_types::destroy_no_token(no_token);
        assert!(token_market_id == market_id, E_MARKET_ID_MISMATCH);
        assert!(amount > 0, E_NO_TOKENS_TO_REDEEM);

        // Calculate fee
        let fee_bps = market_types::fee_bps(market);
        let fee_amount = (amount * (fee_bps as u64)) / 10000;
        let payout = amount - fee_amount;

        // Update vault supply
        token_types::decrease_no_supply(vault, amount);

        // Remove collateral from vault (full amount)
        let mut collateral_balance = token_types::remove_collateral(vault, amount);

        // Split fee and send to treasury
        if (fee_amount > 0) {
            let fee_balance = balance::split(&mut collateral_balance, fee_amount);
            let fee_coin = coin::from_balance(fee_balance, ctx);
            let treasury = market_types::registry_treasury(registry);
            transfer::public_transfer(fee_coin, treasury);
        };

        // Emit event
        token_events::emit_tokens_redeemed(
            market_id,
            ctx.sender(),
            market_types::outcome_no(),
            amount,
            payout,
            fee_amount,
            clock.timestamp_ms(),
        );

        // Return payout to user
        coin::from_balance(collateral_balance, ctx)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 5: REDEEM VOIDED MARKET
    // ═══════════════════════════════════════════════════════════════════════════

    /// Redeem tokens from a voided market
    /// Returns collateral proportionally - user gets back what they put in
    /// Accepts both YES and NO tokens, returns combined value
    public fun redeem_voided(
        market: &Market,
        registry: &mut MarketRegistry,
        vault: &mut TokenVault,
        yes_token: YesToken,
        no_token: NoToken,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        // Validate market is voided
        assert!(market_types::is_voided(market), E_MARKET_NOT_VOIDED);

        let market_id = market_types::market_id(market);

        // Validate tokens belong to this market
        let (yes_market_id, yes_amount) = token_types::destroy_yes_token(yes_token);
        let (no_market_id, no_amount) = token_types::destroy_no_token(no_token);

        assert!(yes_market_id == market_id, E_MARKET_ID_MISMATCH);
        assert!(no_market_id == market_id, E_MARKET_ID_MISMATCH);

        // Must have equal amounts for full refund
        assert!(yes_amount == no_amount, E_AMOUNT_MISMATCH);

        let amount = yes_amount;
        assert!(amount > 0, E_NO_TOKENS_TO_REDEEM);

        // Update vault supply
        token_types::decrease_yes_supply(vault, amount);
        token_types::decrease_no_supply(vault, amount);

        // Remove collateral from vault (1 YES + 1 NO = 1 SUI refund)
        let collateral_balance = token_types::remove_collateral(vault, amount);

        // Update registry collateral tracking
        market_types::registry_remove_collateral(registry, amount);

        // Emit event
        token_events::emit_void_redemption(
            market_id,
            ctx.sender(),
            amount,
            amount,
            amount,
            clock.timestamp_ms(),
        );

        // Return full refund to user
        coin::from_balance(collateral_balance, ctx)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 6: TOKEN BALANCE QUERIES
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get market statistics from vault
    /// Returns (total_collateral, yes_supply, no_supply)
    public fun get_market_stats(vault: &TokenVault): (u64, u64, u64) {
        (
            token_types::vault_collateral_value(vault),
            token_types::vault_yes_supply(vault),
            token_types::vault_no_supply(vault),
        )
    }

    /// Check if a YES token belongs to a specific market
    public fun yes_token_is_for_market(token: &YesToken, market_id: u64): bool {
        token_types::yes_token_market_id(token) == market_id
    }

    /// Check if a NO token belongs to a specific market
    public fun no_token_is_for_market(token: &NoToken, market_id: u64): bool {
        token_types::no_token_market_id(token) == market_id
    }

    /// Get YES token details
    /// Returns (market_id, amount)
    public fun get_yes_token_info(token: &YesToken): (u64, u64) {
        (
            token_types::yes_token_market_id(token),
            token_types::yes_token_amount(token),
        )
    }

    /// Get NO token details
    /// Returns (market_id, amount)
    public fun get_no_token_info(token: &NoToken): (u64, u64) {
        (
            token_types::no_token_market_id(token),
            token_types::no_token_amount(token),
        )
    }

    /// Calculate potential payout for YES tokens if market resolves to YES
    /// Returns (payout_amount, fee_amount)
    public fun calculate_yes_payout(market: &Market, token: &YesToken): (u64, u64) {
        let amount = token_types::yes_token_amount(token);
        let fee_bps = market_types::fee_bps(market);
        let fee_amount = (amount * (fee_bps as u64)) / 10000;
        let payout = amount - fee_amount;
        (payout, fee_amount)
    }

    /// Calculate potential payout for NO tokens if market resolves to NO
    /// Returns (payout_amount, fee_amount)
    public fun calculate_no_payout(market: &Market, token: &NoToken): (u64, u64) {
        let amount = token_types::no_token_amount(token);
        let fee_bps = market_types::fee_bps(market);
        let fee_amount = (amount * (fee_bps as u64)) / 10000;
        let payout = amount - fee_amount;
        (payout, fee_amount)
    }
}
