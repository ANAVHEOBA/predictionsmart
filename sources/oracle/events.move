/// Oracle Events - All events emitted by the oracle module
///
/// This module defines events for oracle operations.
module predictionsmart::oracle_events {
    use std::string::String;
    use sui::event;

    // ═══════════════════════════════════════════════════════════════════════════
    // REGISTRY EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emitted when oracle registry is initialized
    public struct RegistryInitialized has copy, drop {
        admin: address,
        default_bond: u64,
        default_dispute_window: u64,
    }

    /// Emitted when a provider is registered
    public struct ProviderRegistered has copy, drop {
        name: String,
        provider_type: u8,
        min_bond: u64,
        dispute_window: u64,
    }

    /// Emitted when a provider is updated
    public struct ProviderUpdated has copy, drop {
        name: String,
        min_bond: u64,
        dispute_window: u64,
        is_active: bool,
    }

    /// Emitted when a provider is deactivated
    public struct ProviderDeactivated has copy, drop {
        name: String,
    }

    /// Emitted when default bond is changed
    public struct DefaultBondChanged has copy, drop {
        old_bond: u64,
        new_bond: u64,
    }

    /// Emitted when default dispute window is changed
    public struct DefaultDisputeWindowChanged has copy, drop {
        old_window: u64,
        new_window: u64,
    }

    /// Emitted when registry admin is changed
    public struct RegistryAdminChanged has copy, drop {
        old_admin: address,
        new_admin: address,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // RESOLUTION REQUEST EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emitted when a resolution is requested
    public struct ResolutionRequested has copy, drop {
        request_id: u64,
        market_id: u64,
        oracle_source: String,
        requester: address,
        bond_amount: u64,
        request_time: u64,
    }

    /// Emitted when an outcome is proposed
    public struct OutcomeProposed has copy, drop {
        request_id: u64,
        market_id: u64,
        proposer: address,
        proposed_outcome: u8,
        bond_amount: u64,
        proposal_time: u64,
        dispute_deadline: u64,
    }

    /// Emitted when an outcome is disputed
    public struct OutcomeDisputed has copy, drop {
        request_id: u64,
        market_id: u64,
        disputer: address,
        bond_amount: u64,
    }

    /// Emitted when a resolution is finalized
    public struct ResolutionFinalized has copy, drop {
        request_id: u64,
        market_id: u64,
        final_outcome: u8,
        resolver: address,
        resolved_time: u64,
    }

    /// Emitted when a request is cancelled
    public struct ResolutionCancelled has copy, drop {
        request_id: u64,
        market_id: u64,
        reason: String,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BOND EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emitted when a bond is distributed
    public struct BondDistributed has copy, drop {
        request_id: u64,
        recipient: address,
        amount: u64,
        reason: String,
    }

    /// Emitted when a bond is slashed (lost by wrong party)
    public struct BondSlashed has copy, drop {
        request_id: u64,
        loser: address,
        winner: address,
        amount: u64,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EMERGENCY EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Emitted when admin uses emergency override
    public struct EmergencyOverride has copy, drop {
        request_id: u64,
        market_id: u64,
        outcome: u8,
        admin: address,
        reason: String,
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENT EMITTERS (package-only)
    // ═══════════════════════════════════════════════════════════════════════════

    // --- Registry Events ---

    public(package) fun emit_registry_initialized(
        admin: address,
        default_bond: u64,
        default_dispute_window: u64,
    ) {
        event::emit(RegistryInitialized {
            admin,
            default_bond,
            default_dispute_window,
        });
    }

    public(package) fun emit_provider_registered(
        name: String,
        provider_type: u8,
        min_bond: u64,
        dispute_window: u64,
    ) {
        event::emit(ProviderRegistered {
            name,
            provider_type,
            min_bond,
            dispute_window,
        });
    }

    public(package) fun emit_provider_updated(
        name: String,
        min_bond: u64,
        dispute_window: u64,
        is_active: bool,
    ) {
        event::emit(ProviderUpdated {
            name,
            min_bond,
            dispute_window,
            is_active,
        });
    }

    public(package) fun emit_provider_deactivated(name: String) {
        event::emit(ProviderDeactivated { name });
    }

    public(package) fun emit_default_bond_changed(old_bond: u64, new_bond: u64) {
        event::emit(DefaultBondChanged { old_bond, new_bond });
    }

    public(package) fun emit_default_dispute_window_changed(old_window: u64, new_window: u64) {
        event::emit(DefaultDisputeWindowChanged { old_window, new_window });
    }

    public(package) fun emit_registry_admin_changed(old_admin: address, new_admin: address) {
        event::emit(RegistryAdminChanged { old_admin, new_admin });
    }

    // --- Resolution Request Events ---

    public(package) fun emit_resolution_requested(
        request_id: u64,
        market_id: u64,
        oracle_source: String,
        requester: address,
        bond_amount: u64,
        request_time: u64,
    ) {
        event::emit(ResolutionRequested {
            request_id,
            market_id,
            oracle_source,
            requester,
            bond_amount,
            request_time,
        });
    }

    public(package) fun emit_outcome_proposed(
        request_id: u64,
        market_id: u64,
        proposer: address,
        proposed_outcome: u8,
        bond_amount: u64,
        proposal_time: u64,
        dispute_deadline: u64,
    ) {
        event::emit(OutcomeProposed {
            request_id,
            market_id,
            proposer,
            proposed_outcome,
            bond_amount,
            proposal_time,
            dispute_deadline,
        });
    }

    public(package) fun emit_outcome_disputed(
        request_id: u64,
        market_id: u64,
        disputer: address,
        bond_amount: u64,
    ) {
        event::emit(OutcomeDisputed {
            request_id,
            market_id,
            disputer,
            bond_amount,
        });
    }

    public(package) fun emit_resolution_finalized(
        request_id: u64,
        market_id: u64,
        final_outcome: u8,
        resolver: address,
        resolved_time: u64,
    ) {
        event::emit(ResolutionFinalized {
            request_id,
            market_id,
            final_outcome,
            resolver,
            resolved_time,
        });
    }

    public(package) fun emit_resolution_cancelled(
        request_id: u64,
        market_id: u64,
        reason: String,
    ) {
        event::emit(ResolutionCancelled {
            request_id,
            market_id,
            reason,
        });
    }

    // --- Bond Events ---

    public(package) fun emit_bond_distributed(
        request_id: u64,
        recipient: address,
        amount: u64,
        reason: String,
    ) {
        event::emit(BondDistributed {
            request_id,
            recipient,
            amount,
            reason,
        });
    }

    public(package) fun emit_bond_slashed(
        request_id: u64,
        loser: address,
        winner: address,
        amount: u64,
    ) {
        event::emit(BondSlashed {
            request_id,
            loser,
            winner,
            amount,
        });
    }

    // --- Emergency Events ---

    public(package) fun emit_emergency_override(
        request_id: u64,
        market_id: u64,
        outcome: u8,
        admin: address,
        reason: String,
    ) {
        event::emit(EmergencyOverride {
            request_id,
            market_id,
            outcome,
            admin,
            reason,
        });
    }
}
