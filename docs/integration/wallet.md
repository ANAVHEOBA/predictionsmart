# Wallet Module Integration

## Overview

The Wallet module provides smart contract wallets with:
- Operator approvals (delegate trading)
- Session keys (limited permissions)
- Batch transactions
- Asset management

## Use Cases

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      SMART WALLET USE CASES                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. OPERATOR APPROVALS                                                  │
│     - Approve a bot to trade on your behalf                            │
│     - Set spending limits and expiration                                │
│     - Revoke anytime                                                    │
│                                                                         │
│  2. SESSION KEYS                                                        │
│     - Grant temporary access for specific actions                       │
│     - Scoped permissions (trade only, withdraw only, etc.)             │
│     - Auto-expire after time limit                                      │
│                                                                         │
│  3. BATCH TRANSACTIONS                                                  │
│     - Execute multiple actions in one transaction                       │
│     - Atomic operations (all succeed or all fail)                       │
│                                                                         │
│  4. ASSET CUSTODY                                                       │
│     - Hold SUI, YES tokens, NO tokens, LP tokens                       │
│     - Controlled withdrawals                                            │
│     - Lock/unlock for safety                                            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Object Types

### WalletFactory

```typescript
interface WalletFactory {
  id: string;
  admin: string;
  deployment_fee: number;
  total_wallets: number;
  collected_fees: number;
}
```

### SmartWallet

```typescript
interface SmartWallet {
  id: string;
  owner: string;
  sui_balance: number;
  yes_tokens: Map<string, YesToken>; // market_id -> token
  no_tokens: Map<string, NoToken>;
  lp_tokens: Map<string, LPToken>;
  approvals: Approval[];
  nonce: number;
  is_locked: boolean;
  created_at: number;
}
```

### Approval

```typescript
interface Approval {
  operator: string;
  scope: number; // 0=ALL, 1=TRADE, 2=WITHDRAW, 3=DEPOSIT
  spend_limit: number;
  spent: number;
  expires_at: number;
}
```

## Entry Functions

### 1. Initialize Wallet Factory (Admin)

```typescript
const PACKAGE_ID = "0x19469d6070113bd28ae67c52bd788ed8b6822eedbc8926aef4881a32bb11a685";

async function initializeWalletFactory(deploymentFee: number) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::wallet_entries::initialize_factory`,
    arguments: [tx.pure.u64(deploymentFee)],
  });

  return tx;
}
```

### 2. Deploy Smart Wallet

Create a new smart wallet.

```typescript
async function deployWallet(factoryId: string, deploymentFee: number) {
  const tx = new Transaction();

  const [feeCoin] = tx.splitCoins(tx.gas, [deploymentFee]);

  tx.moveCall({
    target: `${PACKAGE_ID}::wallet_entries::deploy_wallet`,
    arguments: [tx.object(factoryId), feeCoin],
  });

  return tx;
}
```

### 3. Deposit SUI

```typescript
async function depositSui(walletId: string, amount: number) {
  const tx = new Transaction();

  const [depositCoin] = tx.splitCoins(tx.gas, [amount]);

  tx.moveCall({
    target: `${PACKAGE_ID}::wallet_entries::deposit_sui`,
    arguments: [tx.object(walletId), depositCoin],
  });

  return tx;
}
```

### 4. Withdraw SUI

```typescript
async function withdrawSui(walletId: string, amount: number) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::wallet_entries::withdraw_sui`,
    arguments: [tx.object(walletId), tx.pure.u64(amount)],
  });

  return tx;
}
```

### 5. Deposit Tokens

```typescript
// Deposit YES tokens
async function depositYesToken(walletId: string, tokenId: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::wallet_entries::deposit_yes_token`,
    arguments: [tx.object(walletId), tx.object(tokenId)],
  });

  return tx;
}

// Deposit NO tokens
async function depositNoToken(walletId: string, tokenId: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::wallet_entries::deposit_no_token`,
    arguments: [tx.object(walletId), tx.object(tokenId)],
  });

  return tx;
}

// Deposit LP tokens
async function depositLpToken(walletId: string, tokenId: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::wallet_entries::deposit_lp_token`,
    arguments: [tx.object(walletId), tx.object(tokenId)],
  });

  return tx;
}
```

### 6. Withdraw Tokens

```typescript
async function withdrawYesToken(walletId: string, marketId: string, amount: number) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::wallet_entries::withdraw_yes_token`,
    arguments: [
      tx.object(walletId),
      tx.pure.address(marketId),
      tx.pure.u64(amount),
    ],
  });

  return tx;
}

async function withdrawNoToken(walletId: string, marketId: string, amount: number) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::wallet_entries::withdraw_no_token`,
    arguments: [
      tx.object(walletId),
      tx.pure.address(marketId),
      tx.pure.u64(amount),
    ],
  });

  return tx;
}
```

### 7. Grant Approval

Allow an operator to act on behalf of the wallet.

```typescript
async function grantApproval(
  walletId: string,
  operator: string,
  scope: number, // 0=ALL, 1=TRADE, 2=WITHDRAW, 3=DEPOSIT
  spendLimit: number,
  expiresAt: number // Unix timestamp in ms
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::wallet_entries::grant_approval`,
    arguments: [
      tx.object(walletId),
      tx.pure.address(operator),
      tx.pure.u8(scope),
      tx.pure.u64(spendLimit),
      tx.pure.u64(expiresAt),
    ],
  });

  return tx;
}

// Scope types
const APPROVAL_SCOPE = {
  ALL: 0, // Full control
  TRADE: 1, // Can only trade
  WITHDRAW: 2, // Can only withdraw
  DEPOSIT: 3, // Can only deposit
};
```

### 8. Revoke Approval

```typescript
async function revokeApproval(walletId: string, operator: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::wallet_entries::revoke_approval`,
    arguments: [tx.object(walletId), tx.pure.address(operator)],
  });

  return tx;
}
```

### 9. Execute as Operator

Operators can execute actions on behalf of wallet owner.

```typescript
async function executeAsOperator(
  walletId: string,
  action: number, // Action type
  params: any[] // Action-specific parameters
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::wallet_entries::execute_as_operator`,
    arguments: [
      tx.object(walletId),
      tx.pure.u8(action),
      // ... action params
      tx.object("0x6"),
    ],
  });

  return tx;
}
```

### 10. Lock/Unlock Wallet

```typescript
async function lockWallet(walletId: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::wallet_entries::lock_wallet`,
    arguments: [tx.object(walletId)],
  });

  return tx;
}

async function unlockWallet(walletId: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::wallet_entries::unlock_wallet`,
    arguments: [tx.object(walletId)],
  });

  return tx;
}
```

### 11. Transfer Ownership

```typescript
async function transferOwnership(walletId: string, newOwner: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::wallet_entries::transfer_ownership`,
    arguments: [tx.object(walletId), tx.pure.address(newOwner)],
  });

  return tx;
}
```

### 12. Execute Batch

Execute multiple actions atomically.

```typescript
async function executeBatch(
  walletId: string,
  actions: Array<{ type: number; params: any[] }>
) {
  const tx = new Transaction();

  // Build batch action vector
  const actionTypes = actions.map((a) => a.type);

  tx.moveCall({
    target: `${PACKAGE_ID}::wallet_entries::execute_batch`,
    arguments: [
      tx.object(walletId),
      tx.pure.vector("u8", actionTypes),
      // ... params
      tx.object("0x6"),
    ],
  });

  return tx;
}
```

## Query Functions

### Get Wallet Info

```typescript
async function getWalletInfo(walletId: string) {
  const wallet = await client.getObject({
    id: walletId,
    options: { showContent: true },
  });

  const fields = wallet.data?.content?.fields as any;

  return {
    id: walletId,
    owner: fields.owner,
    suiBalance: Number(fields.sui_balance),
    isLocked: fields.is_locked,
    nonce: Number(fields.nonce),
    approvals: fields.approvals || [],
    createdAt: Number(fields.created_at),
  };
}
```

### Get User's Wallets

```typescript
async function getUserWallets(address: string) {
  const wallets = await client.getOwnedObjects({
    owner: address,
    filter: {
      StructType: `${PACKAGE_ID}::wallet_types::SmartWallet`,
    },
    options: { showContent: true },
  });

  return wallets.data.map((w) => ({
    id: w.data?.objectId,
    ...w.data?.content?.fields,
  }));
}
```

### Get Wallet Balances

```typescript
async function getWalletBalances(walletId: string) {
  const wallet = await getWalletInfo(walletId);

  // Get token balances from dynamic fields
  const yesTokens = await client.getDynamicFields({
    parentId: walletId,
    // Filter for YES tokens
  });

  const noTokens = await client.getDynamicFields({
    parentId: walletId,
    // Filter for NO tokens
  });

  return {
    sui: wallet.suiBalance,
    yesTokens: yesTokens.data,
    noTokens: noTokens.data,
  };
}
```

### Check Operator Approval

```typescript
async function checkApproval(
  walletId: string,
  operator: string
): Promise<Approval | null> {
  const wallet = await getWalletInfo(walletId);

  const approval = wallet.approvals.find((a: any) => a.operator === operator);

  if (!approval) return null;

  // Check if expired
  if (approval.expires_at < Date.now()) return null;

  return {
    operator: approval.operator,
    scope: approval.scope,
    spendLimit: Number(approval.spend_limit),
    spent: Number(approval.spent),
    expiresAt: Number(approval.expires_at),
    remainingLimit: Number(approval.spend_limit) - Number(approval.spent),
  };
}
```

## Events

```typescript
// Wallet deployed
async function onWalletDeployed(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::wallet_events::WalletDeployed`,
    },
    onMessage: callback,
  });
}

// Approval granted
async function onApprovalGranted(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::wallet_events::ApprovalGranted`,
    },
    onMessage: callback,
  });
}

// Deposit/Withdrawal
async function onBalanceChanged(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::wallet_events::BalanceChanged`,
    },
    onMessage: callback,
  });
}
```

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 1 | `E_NOT_OWNER` | Caller is not wallet owner |
| 2 | `E_WALLET_LOCKED` | Wallet is locked |
| 3 | `E_NOT_APPROVED` | Operator not approved |
| 4 | `E_APPROVAL_EXPIRED` | Approval has expired |
| 5 | `E_SPEND_LIMIT_EXCEEDED` | Over spending limit |
| 6 | `E_INVALID_SCOPE` | Action not allowed for scope |
| 7 | `E_INSUFFICIENT_BALANCE` | Not enough balance |
| 8 | `E_WALLET_EXISTS` | User already has wallet |
| 9 | `E_SELF_APPROVAL` | Can't approve yourself |

## Complete Example: Wallet Service

```typescript
import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";

const PACKAGE_ID = "0x19469d6070113bd28ae67c52bd788ed8b6822eedbc8926aef4881a32bb11a685";

class WalletService {
  constructor(
    private client: SuiClient,
    private signAndExecute: (tx: Transaction) => Promise<any>,
    private factoryId: string
  ) {}

  // Deploy new wallet
  async deployWallet(deploymentFee: number = 10_000_000) {
    const tx = new Transaction();
    const [feeCoin] = tx.splitCoins(tx.gas, [deploymentFee]);

    tx.moveCall({
      target: `${PACKAGE_ID}::wallet_entries::deploy_wallet`,
      arguments: [tx.object(this.factoryId), feeCoin],
    });

    const result = await this.signAndExecute(tx);

    // Extract wallet ID from events
    const walletEvent = result.events?.find((e: any) =>
      e.type.includes("WalletDeployed")
    );

    return walletEvent?.parsedJson?.wallet_id;
  }

  // Get or create wallet for user
  async getOrCreateWallet(userAddress: string): Promise<string> {
    const wallets = await this.getUserWallets(userAddress);

    if (wallets.length > 0) {
      return wallets[0].id;
    }

    return await this.deployWallet();
  }

  async getUserWallets(address: string) {
    const wallets = await this.client.getOwnedObjects({
      owner: address,
      filter: {
        StructType: `${PACKAGE_ID}::wallet_types::SmartWallet`,
      },
      options: { showContent: true },
    });

    return wallets.data.map((w) => ({
      id: w.data?.objectId,
      ...w.data?.content?.fields,
    }));
  }

  // Deposit SUI
  async deposit(walletId: string, amount: number) {
    const tx = new Transaction();
    const [depositCoin] = tx.splitCoins(tx.gas, [amount]);

    tx.moveCall({
      target: `${PACKAGE_ID}::wallet_entries::deposit_sui`,
      arguments: [tx.object(walletId), depositCoin],
    });

    return await this.signAndExecute(tx);
  }

  // Withdraw SUI
  async withdraw(walletId: string, amount: number) {
    const tx = new Transaction();

    tx.moveCall({
      target: `${PACKAGE_ID}::wallet_entries::withdraw_sui`,
      arguments: [tx.object(walletId), tx.pure.u64(amount)],
    });

    return await this.signAndExecute(tx);
  }

  // Grant operator approval
  async approveOperator(
    walletId: string,
    operator: string,
    scope: "ALL" | "TRADE" | "WITHDRAW" | "DEPOSIT",
    spendLimitSui: number,
    durationDays: number
  ) {
    const tx = new Transaction();

    const scopeValue = { ALL: 0, TRADE: 1, WITHDRAW: 2, DEPOSIT: 3 }[scope];
    const expiresAt = Date.now() + durationDays * 24 * 60 * 60 * 1000;
    const spendLimit = spendLimitSui * 1_000_000_000;

    tx.moveCall({
      target: `${PACKAGE_ID}::wallet_entries::grant_approval`,
      arguments: [
        tx.object(walletId),
        tx.pure.address(operator),
        tx.pure.u8(scopeValue),
        tx.pure.u64(spendLimit),
        tx.pure.u64(expiresAt),
      ],
    });

    return await this.signAndExecute(tx);
  }

  // Revoke operator
  async revokeOperator(walletId: string, operator: string) {
    const tx = new Transaction();

    tx.moveCall({
      target: `${PACKAGE_ID}::wallet_entries::revoke_approval`,
      arguments: [tx.object(walletId), tx.pure.address(operator)],
    });

    return await this.signAndExecute(tx);
  }

  // Get wallet details
  async getWalletDetails(walletId: string) {
    const wallet = await this.client.getObject({
      id: walletId,
      options: { showContent: true },
    });

    const fields = wallet.data?.content?.fields as any;

    return {
      id: walletId,
      owner: fields.owner,
      suiBalance: Number(fields.sui_balance) / 1_000_000_000,
      isLocked: fields.is_locked,
      approvals: (fields.approvals || []).map((a: any) => ({
        operator: a.operator,
        scope: ["ALL", "TRADE", "WITHDRAW", "DEPOSIT"][a.scope],
        spendLimit: Number(a.spend_limit) / 1_000_000_000,
        spent: Number(a.spent) / 1_000_000_000,
        expiresAt: new Date(Number(a.expires_at)),
        isExpired: Number(a.expires_at) < Date.now(),
      })),
    };
  }
}
```

## UI Component: Wallet Dashboard

```tsx
function WalletDashboard({ walletId }: { walletId: string }) {
  const { data: wallet, refetch } = useQuery({
    queryKey: ["wallet", walletId],
    queryFn: () => walletService.getWalletDetails(walletId),
  });

  if (!wallet) return <div>Loading...</div>;

  return (
    <div className="wallet-dashboard">
      <h2>Smart Wallet</h2>
      <p className="wallet-id">{walletId.slice(0, 8)}...{walletId.slice(-6)}</p>

      <div className="balance">
        <h3>Balance</h3>
        <div className="sui-balance">{wallet.suiBalance.toFixed(4)} SUI</div>
      </div>

      <div className="status">
        Status: {wallet.isLocked ? "🔒 Locked" : "🔓 Unlocked"}
      </div>

      <div className="approvals">
        <h3>Approved Operators</h3>
        {wallet.approvals.length === 0 ? (
          <p>No operators approved</p>
        ) : (
          wallet.approvals.map((approval) => (
            <div key={approval.operator} className="approval">
              <span>{approval.operator.slice(0, 8)}...</span>
              <span>Scope: {approval.scope}</span>
              <span>Limit: {approval.spendLimit} SUI</span>
              <span>Spent: {approval.spent} SUI</span>
              <span className={approval.isExpired ? "expired" : ""}>
                {approval.isExpired ? "Expired" : `Expires: ${approval.expiresAt.toLocaleDateString()}`}
              </span>
              <button onClick={() => handleRevoke(approval.operator)}>
                Revoke
              </button>
            </div>
          ))
        )}
      </div>

      <div className="actions">
        <button onClick={() => setShowDeposit(true)}>Deposit</button>
        <button onClick={() => setShowWithdraw(true)}>Withdraw</button>
        <button onClick={() => setShowApprove(true)}>Add Operator</button>
        <button onClick={() => handleToggleLock()}>
          {wallet.isLocked ? "Unlock" : "Lock"}
        </button>
      </div>
    </div>
  );
}
```
