/// Token Entries - Public entry functions (transaction endpoints)
///
/// These are the functions users call directly via transactions.
module predictionsmart::token_entries {
    use sui::clock::Clock;
    use sui::coin::Coin;
    use sui::sui::SUI;

    use predictionsmart::market_types::{Market, MarketRegistry};
    use predictionsmart::token_types::{Self, TokenVault, YesToken, NoToken};
    use predictionsmart::token_operations;

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 1: CREATE VAULT (internal - called when market created)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create a vault for a market
    /// Typically called right after market creation
    entry fun create_vault(
        market_id: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let vault = token_operations::create_vault(market_id, clock, ctx);
        token_types::share_vault(vault);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 2: MINT TOKEN SETS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Mint YES and NO tokens by depositing SUI
    /// 1 SUI = 1 YES + 1 NO
    entry fun mint_tokens(
        market: &mut Market,
        registry: &mut MarketRegistry,
        vault: &mut TokenVault,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let (yes_token, no_token) = token_operations::mint_token_set(
            market,
            registry,
            vault,
            payment,
            clock,
            ctx,
        );

        let sender = ctx.sender();
        token_types::transfer_yes_token(yes_token, sender);
        token_types::transfer_no_token(no_token, sender);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TOKEN UTILITIES
    // ═══════════════════════════════════════════════════════════════════════════

    /// Split YES token and transfer part to another address
    entry fun split_and_transfer_yes(
        token: &mut YesToken,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let split_token = token_operations::split_yes_token(token, amount, ctx);
        token_types::transfer_yes_token(split_token, recipient);
    }

    /// Split NO token and transfer part to another address
    entry fun split_and_transfer_no(
        token: &mut NoToken,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let split_token = token_operations::split_no_token(token, amount, ctx);
        token_types::transfer_no_token(split_token, recipient);
    }

    /// Merge YES tokens (combine two into one)
    entry fun merge_yes(
        token: &mut YesToken,
        token_to_merge: YesToken,
    ) {
        token_operations::merge_yes_tokens(token, token_to_merge);
    }

    /// Merge NO tokens (combine two into one)
    entry fun merge_no(
        token: &mut NoToken,
        token_to_merge: NoToken,
    ) {
        token_operations::merge_no_tokens(token, token_to_merge);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 3: MERGE TOKEN SETS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Merge YES + NO tokens back into SUI collateral
    /// Burns equal amounts of YES and NO tokens, returns SUI to sender
    entry fun merge_token_set(
        market: &mut Market,
        registry: &mut MarketRegistry,
        vault: &mut TokenVault,
        yes_token: YesToken,
        no_token: NoToken,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let refund = token_operations::merge_token_set(
            market,
            registry,
            vault,
            yes_token,
            no_token,
            clock,
            ctx,
        );

        transfer::public_transfer(refund, ctx.sender());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 4: REDEEM WINNING TOKENS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Redeem winning YES tokens after market resolves to YES
    entry fun redeem_yes(
        market: &Market,
        registry: &mut MarketRegistry,
        vault: &mut TokenVault,
        yes_token: YesToken,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let payout = token_operations::redeem_yes_tokens(
            market,
            registry,
            vault,
            yes_token,
            clock,
            ctx,
        );

        transfer::public_transfer(payout, ctx.sender());
    }

    /// Redeem winning NO tokens after market resolves to NO
    entry fun redeem_no(
        market: &Market,
        registry: &mut MarketRegistry,
        vault: &mut TokenVault,
        no_token: NoToken,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let payout = token_operations::redeem_no_tokens(
            market,
            registry,
            vault,
            no_token,
            clock,
            ctx,
        );

        transfer::public_transfer(payout, ctx.sender());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE 5: REDEEM VOIDED MARKET
    // ═══════════════════════════════════════════════════════════════════════════

    /// Redeem tokens from a voided market
    /// Returns full collateral (1 YES + 1 NO = 1 SUI)
    entry fun redeem_voided(
        market: &Market,
        registry: &mut MarketRegistry,
        vault: &mut TokenVault,
        yes_token: YesToken,
        no_token: NoToken,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let refund = token_operations::redeem_voided(
            market,
            registry,
            vault,
            yes_token,
            no_token,
            clock,
            ctx,
        );

        transfer::public_transfer(refund, ctx.sender());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test_only]
    public fun create_vault_for_testing(
        market_id: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): TokenVault {
        token_operations::create_vault(market_id, clock, ctx)
    }
}


