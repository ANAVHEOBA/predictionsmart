# Token Module Integration

## Overview

The Token module handles minting YES/NO outcome tokens and redeeming them after market resolution.

## How It Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        TOKEN LIFECYCLE                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  MINT TOKENS                                                            │
│  ┌─────────┐      ┌──────────────┐      ┌─────────────────────────┐    │
│  │ 10 SUI  │ ───> │  TokenVault  │ ───> │ 10 YES + 10 NO Tokens   │    │
│  └─────────┘      └──────────────┘      └─────────────────────────┘    │
│                                                                         │
│  MERGE TOKENS (Anytime)                                                 │
│  ┌─────────────────────────┐      ┌──────────────┐      ┌─────────┐    │
│  │ 5 YES + 5 NO Tokens     │ ───> │  TokenVault  │ ───> │  5 SUI  │    │
│  └─────────────────────────┘      └──────────────┘      └─────────┘    │
│                                                                         │
│  REDEEM WINNING (After Resolution)                                      │
│  ┌─────────────────────────┐      ┌──────────────┐      ┌─────────┐    │
│  │ 10 YES Tokens           │ ───> │  TokenVault  │ ───> │ 10 SUI  │    │
│  │ (if YES wins)           │      └──────────────┘      └─────────┘    │
│  └─────────────────────────┘                                            │
│                                                                         │
│  REDEEM VOIDED (If market voided)                                       │
│  ┌─────────────────────────┐      ┌──────────────┐      ┌─────────┐    │
│  │ 10 YES + 10 NO Tokens   │ ───> │  TokenVault  │ ───> │ 10 SUI  │    │
│  └─────────────────────────┘      └──────────────┘      └─────────┘    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Object Types

### YesToken

```typescript
interface YesToken {
  id: string;
  market_id: string;
  balance: number; // Amount of YES tokens
}
```

### NoToken

```typescript
interface NoToken {
  id: string;
  market_id: string;
  balance: number; // Amount of NO tokens
}
```

### TokenVault

```typescript
interface TokenVault {
  id: string;
  market_id: string;
  sui_balance: number; // Locked SUI
  yes_supply: number; // Total YES minted
  no_supply: number; // Total NO minted
}
```

## Entry Functions

### 1. Initialize Token Vault

Creates token vault for a market (usually done by market creator).

```typescript
const PACKAGE_ID = "0x9d006bf5d2141570cf19e4cee42ed9638db7aff56cb30ad1a4b1aa212caf9adb";

async function initializeVault(marketId: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::token_entries::initialize_vault`,
    arguments: [tx.object(marketId)],
  });

  return tx;
}
```

### 2. Mint Tokens

Deposit SUI and receive equal YES + NO tokens.

```typescript
async function mintTokens(
  marketId: string,
  vaultId: string,
  amount: number // Amount in MIST
) {
  const tx = new Transaction();

  // Split deposit amount from gas
  const [depositCoin] = tx.splitCoins(tx.gas, [amount]);

  tx.moveCall({
    target: `${PACKAGE_ID}::token_entries::mint_tokens`,
    arguments: [
      tx.object(marketId),
      tx.object(vaultId),
      depositCoin,
      tx.object("0x6"), // Clock
    ],
  });

  return tx;
}

// Usage: Mint 10 SUI worth of tokens
const tx = await mintTokens(
  "0x...", // market ID
  "0x...", // vault ID
  10_000_000_000 // 10 SUI in MIST
);
```

### 3. Merge Token Set

Convert equal YES + NO tokens back to SUI (anytime).

```typescript
async function mergeTokenSet(
  marketId: string,
  vaultId: string,
  yesTokenId: string,
  noTokenId: string,
  amount: number
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::token_entries::merge_token_set`,
    arguments: [
      tx.object(marketId),
      tx.object(vaultId),
      tx.object(yesTokenId),
      tx.object(noTokenId),
      tx.pure.u64(amount),
    ],
  });

  return tx;
}
```

### 4. Redeem Winning Tokens

Redeem winning tokens for SUI after market resolution.

```typescript
// Redeem YES tokens (if YES wins)
async function redeemYesTokens(
  marketId: string,
  vaultId: string,
  yesTokenId: string
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::token_entries::redeem_yes_tokens`,
    arguments: [
      tx.object(marketId),
      tx.object(vaultId),
      tx.object(yesTokenId),
    ],
  });

  return tx;
}

// Redeem NO tokens (if NO wins)
async function redeemNoTokens(
  marketId: string,
  vaultId: string,
  noTokenId: string
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::token_entries::redeem_no_tokens`,
    arguments: [
      tx.object(marketId),
      tx.object(vaultId),
      tx.object(noTokenId),
    ],
  });

  return tx;
}
```

### 5. Redeem Voided Market

Get full refund if market is voided.

```typescript
async function redeemVoided(
  marketId: string,
  vaultId: string,
  yesTokenId: string,
  noTokenId: string
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::token_entries::redeem_voided`,
    arguments: [
      tx.object(marketId),
      tx.object(vaultId),
      tx.object(yesTokenId),
      tx.object(noTokenId),
    ],
  });

  return tx;
}
```

### 6. Split Tokens

Split a token into two (for partial sales).

```typescript
async function splitYesToken(yesTokenId: string, amount: number) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::token_entries::split_yes_token`,
    arguments: [tx.object(yesTokenId), tx.pure.u64(amount)],
  });

  return tx;
}

async function splitNoToken(noTokenId: string, amount: number) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::token_entries::split_no_token`,
    arguments: [tx.object(noTokenId), tx.pure.u64(amount)],
  });

  return tx;
}
```

### 7. Merge Tokens

Combine multiple tokens of same type.

```typescript
async function mergeYesTokens(targetTokenId: string, sourceTokenId: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::token_entries::merge_yes_tokens`,
    arguments: [tx.object(targetTokenId), tx.object(sourceTokenId)],
  });

  return tx;
}

async function mergeNoTokens(targetTokenId: string, sourceTokenId: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::token_entries::merge_no_tokens`,
    arguments: [tx.object(targetTokenId), tx.object(sourceTokenId)],
  });

  return tx;
}
```

## Query Functions

### Get User's Tokens

```typescript
import { SuiClient } from "@mysten/sui/client";

const client = new SuiClient({ url: "https://fullnode.testnet.sui.io:443" });

async function getUserYesTokens(address: string) {
  const tokens = await client.getOwnedObjects({
    owner: address,
    filter: {
      StructType: `${PACKAGE_ID}::token_types::YesToken`,
    },
    options: { showContent: true },
  });

  return tokens.data.map((t) => ({
    id: t.data?.objectId,
    ...t.data?.content?.fields,
  }));
}

async function getUserNoTokens(address: string) {
  const tokens = await client.getOwnedObjects({
    owner: address,
    filter: {
      StructType: `${PACKAGE_ID}::token_types::NoToken`,
    },
    options: { showContent: true },
  });

  return tokens.data.map((t) => ({
    id: t.data?.objectId,
    ...t.data?.content?.fields,
  }));
}
```

### Get Tokens for Specific Market

```typescript
async function getTokensForMarket(address: string, marketId: string) {
  const [yesTokens, noTokens] = await Promise.all([
    getUserYesTokens(address),
    getUserNoTokens(address),
  ]);

  return {
    yesTokens: yesTokens.filter((t: any) => t.market_id === marketId),
    noTokens: noTokens.filter((t: any) => t.market_id === marketId),
  };
}
```

### Get Token Vault Info

```typescript
async function getVaultInfo(vaultId: string) {
  const vault = await client.getObject({
    id: vaultId,
    options: { showContent: true },
  });

  const fields = vault.data?.content?.fields as any;

  return {
    id: vaultId,
    marketId: fields.market_id,
    suiBalance: Number(fields.sui_balance),
    yesSupply: Number(fields.yes_supply),
    noSupply: Number(fields.no_supply),
  };
}
```

### Calculate Potential Payout

```typescript
function calculatePotentialPayout(
  tokenBalance: number,
  totalWinningSupply: number,
  totalVaultBalance: number
): number {
  // Winning tokens get proportional share of entire vault
  // In simple case: 1 winning token = 1 SUI
  return tokenBalance; // 1:1 redemption
}

// More complex calculation if there's a fee
function calculatePayoutWithFee(
  tokenBalance: number,
  feePercentage: number = 0
): number {
  const fee = (tokenBalance * feePercentage) / 10000;
  return tokenBalance - fee;
}
```

## Events

### Subscribe to Token Events

```typescript
// Tokens minted
async function onTokensMinted(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::token_events::TokensMinted`,
    },
    onMessage: callback,
  });
}

// Tokens redeemed
async function onTokensRedeemed(callback: (event: any) => void) {
  return client.subscribeEvent({
    filter: {
      MoveEventType: `${PACKAGE_ID}::token_events::TokensRedeemed`,
    },
    onMessage: callback,
  });
}
```

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 1 | `E_MARKET_NOT_OPEN` | Market is not open for minting |
| 2 | `E_INSUFFICIENT_AMOUNT` | Deposit amount too small |
| 3 | `E_MARKET_NOT_RESOLVED` | Can't redeem, market not resolved |
| 4 | `E_NOT_WINNING_TOKEN` | Token type didn't win |
| 5 | `E_MARKET_NOT_VOIDED` | Market not voided for refund |
| 6 | `E_INSUFFICIENT_BALANCE` | Token balance too low |
| 7 | `E_WRONG_MARKET` | Token doesn't belong to this market |
| 8 | `E_VAULT_NOT_FOUND` | Token vault doesn't exist |

## Complete Example: Token Service

```typescript
import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";

const PACKAGE_ID = "0x9d006bf5d2141570cf19e4cee42ed9638db7aff56cb30ad1a4b1aa212caf9adb";

class TokenService {
  constructor(
    private client: SuiClient,
    private signAndExecute: (tx: Transaction) => Promise<any>
  ) {}

  // Get user's token portfolio
  async getPortfolio(address: string) {
    const [yesTokens, noTokens] = await Promise.all([
      this.client.getOwnedObjects({
        owner: address,
        filter: { StructType: `${PACKAGE_ID}::token_types::YesToken` },
        options: { showContent: true },
      }),
      this.client.getOwnedObjects({
        owner: address,
        filter: { StructType: `${PACKAGE_ID}::token_types::NoToken` },
        options: { showContent: true },
      }),
    ]);

    // Group by market
    const portfolio: Record<string, { yes: number; no: number }> = {};

    yesTokens.data.forEach((t) => {
      const fields = t.data?.content?.fields as any;
      const marketId = fields.market_id;
      if (!portfolio[marketId]) portfolio[marketId] = { yes: 0, no: 0 };
      portfolio[marketId].yes += Number(fields.balance);
    });

    noTokens.data.forEach((t) => {
      const fields = t.data?.content?.fields as any;
      const marketId = fields.market_id;
      if (!portfolio[marketId]) portfolio[marketId] = { yes: 0, no: 0 };
      portfolio[marketId].no += Number(fields.balance);
    });

    return portfolio;
  }

  // Mint tokens for a market
  async mint(marketId: string, vaultId: string, suiAmount: number) {
    const tx = new Transaction();
    const [depositCoin] = tx.splitCoins(tx.gas, [suiAmount]);

    tx.moveCall({
      target: `${PACKAGE_ID}::token_entries::mint_tokens`,
      arguments: [
        tx.object(marketId),
        tx.object(vaultId),
        depositCoin,
        tx.object("0x6"),
      ],
    });

    return await this.signAndExecute(tx);
  }

  // Redeem winning tokens
  async redeemWinning(
    marketId: string,
    vaultId: string,
    tokenId: string,
    tokenType: "YES" | "NO"
  ) {
    const tx = new Transaction();

    const target =
      tokenType === "YES"
        ? `${PACKAGE_ID}::token_entries::redeem_yes_tokens`
        : `${PACKAGE_ID}::token_entries::redeem_no_tokens`;

    tx.moveCall({
      target,
      arguments: [tx.object(marketId), tx.object(vaultId), tx.object(tokenId)],
    });

    return await this.signAndExecute(tx);
  }

  // Find vault for a market (query dynamic field or events)
  async findVaultForMarket(marketId: string): Promise<string | null> {
    // Query for VaultInitialized event
    const events = await this.client.queryEvents({
      query: {
        MoveEventType: `${PACKAGE_ID}::token_events::VaultInitialized`,
      },
      limit: 100,
    });

    const vaultEvent = events.data.find((e) => {
      const parsed = e.parsedJson as any;
      return parsed.market_id === marketId;
    });

    return vaultEvent ? (vaultEvent.parsedJson as any).vault_id : null;
  }
}

// React hook example
import { useCurrentAccount, useSignAndExecuteTransaction, useSuiClient } from "@mysten/dapp-kit";
import { useQuery, useMutation } from "@tanstack/react-query";

function useTokenService() {
  const client = useSuiClient();
  const account = useCurrentAccount();
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();

  const service = new TokenService(client, async (tx) => {
    return await signAndExecute({ transaction: tx });
  });

  const portfolio = useQuery({
    queryKey: ["portfolio", account?.address],
    queryFn: () => service.getPortfolio(account!.address),
    enabled: !!account,
  });

  const mint = useMutation({
    mutationFn: ({
      marketId,
      vaultId,
      amount,
    }: {
      marketId: string;
      vaultId: string;
      amount: number;
    }) => service.mint(marketId, vaultId, amount),
  });

  return { portfolio, mint, service };
}
```

## UI Component Example

```tsx
import { useTokenService } from "./hooks/useTokenService";

function MintTokensForm({ marketId, vaultId }: { marketId: string; vaultId: string }) {
  const [amount, setAmount] = useState("");
  const { mint } = useTokenService();

  const handleMint = async () => {
    const suiAmount = parseFloat(amount) * 1_000_000_000; // Convert to MIST
    await mint.mutateAsync({ marketId, vaultId, amount: suiAmount });
  };

  return (
    <div>
      <h3>Mint Tokens</h3>
      <input
        type="number"
        value={amount}
        onChange={(e) => setAmount(e.target.value)}
        placeholder="Amount in SUI"
      />
      <button onClick={handleMint} disabled={mint.isPending}>
        {mint.isPending ? "Minting..." : "Mint YES + NO Tokens"}
      </button>
      <p>You will receive {amount} YES tokens + {amount} NO tokens</p>
    </div>
  );
}
```
