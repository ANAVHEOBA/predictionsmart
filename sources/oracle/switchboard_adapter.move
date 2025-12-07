/// Switchboard Adapter - Integration with Switchboard Oracle
///
/// This module provides functions to read Switchboard price feeds and resolve
/// prediction markets based on real-time price data.
///
/// Switchboard On-Demand provides customizable, permissionless oracle aggregation.
/// It aggregates data from multiple sources (Chainlink, Pyth, Switchboard) into unified feeds.
/// Reading price feeds is FREE - no fees required.
///
/// Documentation: https://docs.switchboard.xyz/product-documentation/data-feeds/sui
module predictionsmart::switchboard_adapter {
    use switchboard::aggregator::Aggregator;
    use switchboard::decimal;

    use predictionsmart::oracle_types;

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Target decimal precision for normalized prices (8 decimals)
    const TARGET_DECIMALS: u8 = 8;

    /// Switchboard uses 18 decimals internally
    const SWITCHBOARD_DECIMALS: u8 = 18;

    // ═══════════════════════════════════════════════════════════════════════════
    // ERROR CODES
    // ═══════════════════════════════════════════════════════════════════════════

    const E_NEGATIVE_PRICE: u64 = 1;
    const E_STALE_DATA: u64 = 2;

    // ═══════════════════════════════════════════════════════════════════════════
    // PRICE FEED FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get the latest price from a Switchboard aggregator
    /// Returns (price, timestamp_ms)
    /// Price is normalized to 8 decimals
    public fun get_price(
        aggregator: &Aggregator,
    ): (u64, u64) {
        let current_result = aggregator.current_result();
        let result_decimal = current_result.result();

        // Get timestamp (use max_timestamp for latest)
        let timestamp = current_result.max_timestamp_ms();

        // Convert decimal reference to u64
        let price = decimal_ref_to_u64(result_decimal);

        (price, timestamp)
    }

    /// Get price with min/max range from aggregator
    /// Returns (median_price, min_price, max_price, timestamp_ms)
    public fun get_price_with_range(
        aggregator: &Aggregator,
    ): (u64, u64, u64, u64) {
        let current_result = aggregator.current_result();

        let median = decimal_ref_to_u64(current_result.result());
        let min_price = decimal_ref_to_u64(current_result.min_result());
        let max_price = decimal_ref_to_u64(current_result.max_result());
        let timestamp = current_result.max_timestamp_ms();

        (median, min_price, max_price, timestamp)
    }

    /// Get price with statistical data
    /// Returns (median, mean, stdev, range, timestamp_ms)
    public fun get_price_with_stats(
        aggregator: &Aggregator,
    ): (u64, u64, u64, u64, u64) {
        let current_result = aggregator.current_result();

        let median = decimal_ref_to_u64(current_result.result());
        let mean = decimal_ref_to_u64(current_result.mean());
        let stdev = decimal_ref_to_u64(current_result.stdev());
        let range = decimal_ref_to_u64(current_result.range());
        let timestamp = current_result.max_timestamp_ms();

        (median, mean, stdev, range, timestamp)
    }

    /// Check if data is fresh (within max_age_ms)
    public fun is_data_fresh(
        aggregator: &Aggregator,
        current_time_ms: u64,
        max_age_ms: u64,
    ): bool {
        let current_result = aggregator.current_result();
        let data_timestamp = current_result.max_timestamp_ms();

        current_time_ms - data_timestamp <= max_age_ms
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARKET RESOLUTION FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Determine outcome based on price comparison
    /// Returns YES (0) if condition is met, NO (1) otherwise
    public fun resolve_price_condition(
        aggregator: &Aggregator,
        threshold: u64,
        comparison: u8,
    ): u8 {
        let (current_price, _timestamp) = get_price(aggregator);

        let condition_met = if (comparison == oracle_types::compare_greater()) {
            current_price > threshold
        } else if (comparison == oracle_types::compare_less()) {
            current_price < threshold
        } else if (comparison == oracle_types::compare_equal()) {
            current_price == threshold
        } else if (comparison == oracle_types::compare_greater_or_equal()) {
            current_price >= threshold
        } else {
            // compare_less_or_equal
            current_price <= threshold
        };

        if (condition_met) {
            oracle_types::outcome_yes()
        } else {
            oracle_types::outcome_no()
        }
    }

    /// Check if current price is above threshold
    public fun is_price_above(
        aggregator: &Aggregator,
        threshold: u64,
    ): bool {
        let (current_price, _) = get_price(aggregator);
        current_price > threshold
    }

    /// Check if current price is below threshold
    public fun is_price_below(
        aggregator: &Aggregator,
        threshold: u64,
    ): bool {
        let (current_price, _) = get_price(aggregator);
        current_price < threshold
    }

    /// Resolve with freshness check
    /// Aborts if data is stale
    public fun resolve_price_condition_fresh(
        aggregator: &Aggregator,
        threshold: u64,
        comparison: u8,
        current_time_ms: u64,
        max_age_ms: u64,
    ): u8 {
        assert!(is_data_fresh(aggregator, current_time_ms, max_age_ms), E_STALE_DATA);
        resolve_price_condition(aggregator, threshold, comparison)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Convert Switchboard Decimal reference to u64 (normalized to 8 decimals)
    /// Switchboard uses 18 decimals internally, we normalize to 8 decimals
    fun decimal_ref_to_u64(dec: &switchboard::decimal::Decimal): u64 {
        // Get value (u128) and check if negative
        let value = decimal::value(dec);
        let is_neg = decimal::neg(dec);

        // For prices, we don't expect negative values
        assert!(!is_neg, E_NEGATIVE_PRICE);

        // Switchboard uses 18 decimals, we want 8 decimals
        // So we divide by 10^(18-8) = 10^10
        let divisor = pow10_u128((SWITCHBOARD_DECIMALS - TARGET_DECIMALS) as u64);
        ((value / divisor) as u64)
    }

    /// Calculate 10^n for decimal normalization (u128 version)
    fun pow10_u128(n: u64): u128 {
        let mut result = 1u128;
        let mut i = 0u64;
        while (i < n) {
            result = result * 10;
            i = i + 1;
        };
        result
    }
}
