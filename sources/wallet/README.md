# Proxy Wallet Module

Smart contract wallets for users enabling gasless transactions, atomic multi-step operations, and improved UX.

---

## Overview

When a user first interacts with the platform, a proxy wallet (smart contract wallet) is deployed that is controlled by the user's EOA (Externally Owned Account). This wallet holds all user assets and positions, enabling:

- **Gasless transactions** via relayers
- **Atomic multi-step operations** (batch transactions)
- **Improved UX** without requiring users to hold native tokens for gas

---

## Features

### Feature 1: Proxy Wallet Factory
- Deploy new proxy wallets for users
- Deterministic address generation (CREATE2)
- One wallet per user address
- Track all deployed wallets
- Factory admin controls

### Feature 2: Wallet Ownership
- 1-of-1 ownership model (single owner)
- Owner can execute any transaction
- Owner can transfer ownership
- Owner can upgrade wallet (if upgradeable)
- Recovery mechanism (optional)

### Feature 3: Asset Custody
- Hold SUI (native token)
- Hold YES/NO tokens (outcome tokens)
- Hold LP tokens (liquidity positions)
- Support any Coin<T> type
- Query balances

### Feature 4: Transaction Execution
- Execute single transactions
- Execute batch transactions atomically
- Delegate execution to operators
- Nonce-based replay protection
- Transaction validation

### Feature 5: Gasless Transactions (Sponsored)
- Relayer can submit transactions on behalf of user
- User signs transaction off-chain
- Relayer pays gas fees
- Protocol reimburses relayer (or absorbs cost)
- Rate limiting to prevent abuse

### Feature 6: Approvals & Allowances
- Approve operators to execute specific actions
- Set spending limits per operator
- Time-bound approvals
- Revoke approvals
- Query approval status

### Feature 7: Signature Verification
- EIP-712 style typed data signing (adapted for Sui)
- Verify user signatures on-chain
- Support for multiple signature schemes
- Prevent signature replay attacks
- Domain separation

---

## Data Structures

### ProxyWallet
```
- id: UID
- owner: address              // EOA that controls this wallet
- nonce: u64                  // For replay protection
- created_at: u64             // Deployment timestamp
- is_locked: bool             // Emergency lock
```

### WalletFactory
```
- id: UID
- admin: address              // Factory admin
- wallet_count: u64           // Total wallets deployed
- wallets: Table<address, address>  // owner -> wallet mapping
- deployment_fee: u64         // Fee to deploy wallet (can be 0)
```

### Approval
```
- operator: address           // Approved operator
- scope: u8                   // What actions are approved
- limit: u64                  // Spending/action limit
- expiry: u64                 // Expiration timestamp
- used: u64                   // Amount already used
```

### RelayedTransaction
```
- wallet: address             // Target wallet
- action: vector<u8>          // Encoded action
- nonce: u64                  // Wallet nonce
- deadline: u64               // Transaction expiry
- signature: vector<u8>       // User signature
```

---

## Approval Scopes

| Scope | Value | Description |
|-------|-------|-------------|
| NONE | 0 | No permissions |
| TRADE | 1 | Place/cancel orders |
| TRANSFER | 2 | Transfer assets out |
| LIQUIDITY | 3 | Add/remove liquidity |
| ALL | 255 | Full access |

---

## Transaction Flow

### Direct Execution (User pays gas)
```
1. User calls wallet.execute(action)
2. Wallet verifies msg.sender == owner
3. Wallet executes action
4. Emit ExecutionEvent
```

### Relayed Execution (Gasless)
```
1. User signs transaction off-chain
2. User sends signed tx to relayer (off-chain)
3. Relayer calls wallet.execute_relayed(signed_tx)
4. Wallet verifies signature matches owner
5. Wallet verifies nonce (replay protection)
6. Wallet executes action
7. Increment nonce
8. Emit RelayedExecutionEvent
```

### Batch Execution
```
1. User prepares multiple actions
2. User calls wallet.execute_batch([action1, action2, ...])
3. Wallet executes all actions atomically
4. If any fails, all revert
5. Emit BatchExecutionEvent
```

---

## Security Considerations

### Replay Protection
- Each wallet has a nonce
- Each relayed transaction must use current nonce
- Nonce increments after each relayed execution
- Prevents re-submitting old transactions

### Signature Security
- Domain separation (chain ID, contract address)
- Typed data hashing
- Deadline/expiry for time-bound validity
- No signature malleability

### Access Control
- Only owner can execute transactions
- Only owner can set approvals
- Operators limited by approval scope/limits
- Emergency lock by owner

---

## Events

- `WalletCreated` - New proxy wallet deployed
- `TransactionExecuted` - Direct transaction executed
- `RelayedTransactionExecuted` - Gasless transaction executed
- `BatchExecuted` - Batch transaction executed
- `ApprovalSet` - Operator approval granted
- `ApprovalRevoked` - Operator approval revoked
- `OwnershipTransferred` - Wallet ownership changed
- `WalletLocked` - Emergency lock activated
- `WalletUnlocked` - Emergency lock deactivated

---

## Access Control

| Action | Who Can Call |
|--------|--------------|
| Create wallet | Anyone (via factory) |
| Execute transaction | Wallet owner only |
| Execute relayed | Relayer (with valid signature) |
| Set approval | Wallet owner only |
| Transfer ownership | Wallet owner only |
| Lock wallet | Wallet owner only |
| Factory admin | Factory admin only |

---

## Dependencies

- `sui::object` - Object creation
- `sui::transfer` - Asset transfers
- `sui::tx_context` - Transaction context
- `sui::table` - Wallet registry
- `sui::ed25519` - Signature verification (or sui::ecdsa_k1)

---

## Implementation Priority

1. **Phase 1: Basic Wallet**
   - Wallet factory
   - Single owner execution
   - Asset custody

2. **Phase 2: Batch & Approvals**
   - Batch transactions
   - Operator approvals
   - Spending limits

3. **Phase 3: Gasless (Sponsored)**
   - Signature verification
   - Relayed execution
   - Nonce management

---

## Sui-Specific Considerations

### Object Model
- Wallet is a shared object (accessible by relayers)
- Assets stored as dynamic fields or owned objects
- Use `sui::dynamic_field` for flexible storage

### Sponsored Transactions
- Sui has native sponsored transactions
- Consider using `sui::gas_coin` sponsor pattern
- Alternative: custom relayer with signature verification

### Signature Schemes
- Sui supports Ed25519, Secp256k1, Secp256r1
- Use `sui::ed25519::ed25519_verify` for verification
- Or `sui::ecdsa_k1::secp256k1_verify`

---

## References

- [Polymarket Proxy Wallet Docs](https://docs.polymarket.com/developers/proxy-wallet)
- [Polymarket Proxy Wallet Factory (Polygon)](https://polygonscan.com/address/0xaB45c5A4B0c941a2F231C04C3f49182e1A254052)
- [ChainSecurity Proxy Wallet Audit](https://old.chainsecurity.com/wp-content/uploads/2024/04/ChainSecurity_Polymarket_Proxy_Wallet_Factories_audit.pdf)
- [Gnosis Safe](https://safe.global/)
