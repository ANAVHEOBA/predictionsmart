/// Pyth Adapter - Integration with Pyth Network price feeds
///
/// This module provides functions to read Pyth price feeds and resolve
/// prediction markets based on real-time price data.
///
/// Pyth provides 1,500+ price feeds across crypto, equities, FX, and commodities.
/// Reading price feeds is FREE - no fees required.
///
/// Documentation: https://docs.pyth.network/price-feeds/use-real-time-data/sui
module predictionsmart::pyth_adapter {
    use sui::clock::Clock;
    use pyth::price_info::PriceInfoObject;
    use pyth::price;
    use pyth::i64::{Self, I64};
    use pyth::pyth;

    use predictionsmart::oracle_types;

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Default max age for price staleness check (60 seconds)
    const DEFAULT_MAX_AGE: u64 = 60;

    // ═══════════════════════════════════════════════════════════════════════════
    // ERROR CODES
    // ═══════════════════════════════════════════════════════════════════════════

    const E_NEGATIVE_PRICE: u64 = 2;

    // ═══════════════════════════════════════════════════════════════════════════
    // PRICE FEED FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get the latest price from a Pyth price feed
    /// Returns (price, exponent, timestamp)
    /// Price is returned as i64, exponent shows decimal places (e.g., -8 means divide by 10^8)
    public fun get_price(
        price_info_object: &PriceInfoObject,
        clock: &Clock,
    ): (I64, I64, u64) {
        let price_struct = pyth::get_price_no_older_than(
            price_info_object,
            clock,
            DEFAULT_MAX_AGE,
        );

        let price_value = price::get_price(&price_struct);
        let expo = price::get_expo(&price_struct);
        let timestamp = price::get_timestamp(&price_struct);

        (price_value, expo, timestamp)
    }

    /// Get price with custom max age
    public fun get_price_with_max_age(
        price_info_object: &PriceInfoObject,
        clock: &Clock,
        max_age: u64,
    ): (I64, I64, u64) {
        let price_struct = pyth::get_price_no_older_than(
            price_info_object,
            clock,
            max_age,
        );

        let price_value = price::get_price(&price_struct);
        let expo = price::get_expo(&price_struct);
        let timestamp = price::get_timestamp(&price_struct);

        (price_value, expo, timestamp)
    }

    /// Get price as u64 (for positive prices, normalized to 8 decimals)
    /// This is a convenience function for typical use cases
    public fun get_price_u64(
        price_info_object: &PriceInfoObject,
        clock: &Clock,
    ): u64 {
        let (price_i64, expo_i64, _timestamp) = get_price(price_info_object, clock);

        // Ensure price is positive
        assert!(!i64::get_is_negative(&price_i64), E_NEGATIVE_PRICE);

        let price_value = i64::get_magnitude_if_positive(&price_i64);
        let expo = i64::get_magnitude_if_negative(&expo_i64);

        // Normalize to 8 decimals
        // If expo is -8, price is already in 8 decimals
        // If expo is -6, multiply by 100
        // If expo is -10, divide by 100
        if (expo == 8) {
            price_value
        } else if (expo < 8) {
            // Need more decimals
            let multiplier = pow10(8 - expo);
            price_value * multiplier
        } else {
            // Too many decimals
            let divisor = pow10(expo - 8);
            price_value / divisor
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARKET RESOLUTION FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Determine outcome based on price comparison
    /// Returns YES (0) if condition is met, NO (1) otherwise
    public fun resolve_price_condition(
        price_info_object: &PriceInfoObject,
        clock: &Clock,
        threshold: u64,
        comparison: u8,
    ): u8 {
        let current_price = get_price_u64(price_info_object, clock);

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
        price_info_object: &PriceInfoObject,
        clock: &Clock,
        threshold: u64,
    ): bool {
        let current_price = get_price_u64(price_info_object, clock);
        current_price > threshold
    }

    /// Check if current price is below threshold
    public fun is_price_below(
        price_info_object: &PriceInfoObject,
        clock: &Clock,
        threshold: u64,
    ): bool {
        let current_price = get_price_u64(price_info_object, clock);
        current_price < threshold
    }

    /// Get price confidence interval
    /// Returns (price, confidence) - price ± confidence represents the range
    public fun get_price_with_confidence(
        price_info_object: &PriceInfoObject,
        clock: &Clock,
    ): (u64, u64) {
        let price_struct = pyth::get_price_no_older_than(
            price_info_object,
            clock,
            DEFAULT_MAX_AGE,
        );

        let price_i64 = price::get_price(&price_struct);
        let conf = price::get_conf(&price_struct);
        let expo_i64 = price::get_expo(&price_struct);

        assert!(!i64::get_is_negative(&price_i64), E_NEGATIVE_PRICE);

        let price_value = i64::get_magnitude_if_positive(&price_i64);
        let expo = i64::get_magnitude_if_negative(&expo_i64);

        // Normalize to 8 decimals
        let (norm_price, norm_conf) = if (expo == 8) {
            (price_value, conf)
        } else if (expo < 8) {
            let multiplier = pow10(8 - expo);
            (price_value * multiplier, conf * multiplier)
        } else {
            let divisor = pow10(expo - 8);
            (price_value / divisor, conf / divisor)
        };

        (norm_price, norm_conf)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Calculate 10^n for decimal normalization
    fun pow10(n: u64): u64 {
        let mut result = 1u64;
        let mut i = 0u64;
        while (i < n) {
            result = result * 10;
            i = i + 1;
        };
        result
    }
}


