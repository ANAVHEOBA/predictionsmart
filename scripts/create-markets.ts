/**
 * PredictionSmart - Automated Market Creation Script
 *
 * Creates multiple prediction markets on Sui testnet using admin privileges (no fees)
 *
 * Usage:
 *   npx ts-node --esm create-markets.ts           # Create all markets
 *   npx ts-node --esm create-markets.ts --single  # Create first market only (test)
 *   npx ts-node --esm create-markets.ts --dry-run # Show what would be created
 */

import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { fromHex } from '@mysten/sui/utils';
import * as fs from 'fs';
import * as path from 'path';

// ============================================================================
// CONFIGURATION - Update these with your deployed contract details
// ============================================================================

const CONFIG = {
  // Network
  network: 'testnet' as const,

  // Package ID (v2 after upgrade)
  packageId: '0x41e4ff9b7bbb704402b880e31b13958d932e6bbc03766f1c3e6083833148affe',

  // Shared objects
  registryId: '0xdb9b4975c219f9bfe8755031d467a274c94eacb317f7dbb144c5285a023fdc10',
  clockId: '0x6', // Sui system clock

  // Admin cap - for package 0x9d006... (original deployment)
  adminCapId: '0xf729d4b7c157cfa3e1cda4098caf2a57fe7e60ffff8be62e46bda906ec4ff462',

  // Default market settings
  defaultFeeBps: 100, // 1% trading fee
  resolutionType: 0,  // 0 = ADMIN resolution
};

// ============================================================================
// TYPES
// ============================================================================

interface MarketData {
  category: string;
  question: string;
  description: string;
  outcome_yes: string;
  outcome_no: string;
  end_days: number;
  resolution_days: number;
  image_url: string;
  tags: string[];
}

interface MarketsFile {
  markets: MarketData[];
}

// ============================================================================
// HELPERS
// ============================================================================

function loadPrivateKey(): Ed25519Keypair {
  // Try to load from environment variable first
  const privateKeyHex = process.env.SUI_PRIVATE_KEY;

  if (privateKeyHex) {
    // Remove 0x prefix if present
    const cleanKey = privateKeyHex.startsWith('0x') ? privateKeyHex.slice(2) : privateKeyHex;
    return Ed25519Keypair.fromSecretKey(fromHex(cleanKey));
  }

  // Try to load from ~/.sui/sui_config/sui.keystore
  const homeDir = process.env.HOME || process.env.USERPROFILE || '';
  const keystorePath = path.join(homeDir, '.sui', 'sui_config', 'sui.keystore');

  if (fs.existsSync(keystorePath)) {
    const keystore = JSON.parse(fs.readFileSync(keystorePath, 'utf-8'));
    if (keystore.length > 0) {
      // Keystore contains base64-encoded keys
      const base64Key = keystore[0];
      const decoded = Buffer.from(base64Key, 'base64');
      // Skip the first byte (key scheme flag)
      return Ed25519Keypair.fromSecretKey(decoded.slice(1));
    }
  }

  throw new Error('No private key found. Set SUI_PRIVATE_KEY env var or check ~/.sui/sui_config/sui.keystore');
}

function loadMarkets(): MarketData[] {
  const marketsPath = path.join(process.cwd(), 'markets-nigeria.json');
  const data = JSON.parse(fs.readFileSync(marketsPath, 'utf-8')) as MarketsFile;
  return data.markets;
}

function daysToMs(days: number): bigint {
  return BigInt(days * 24 * 60 * 60 * 1000);
}

function stringToBytes(str: string): number[] {
  return Array.from(Buffer.from(str, 'utf-8'));
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// ============================================================================
// MARKET CREATION
// ============================================================================

async function createMarket(
  client: SuiClient,
  keypair: Ed25519Keypair,
  market: MarketData,
  index: number,
  total: number
): Promise<string | null> {
  console.log(`\n[${ index + 1 }/${total}] Creating market: "${market.question.slice(0, 50)}..."`);
  console.log(`   Category: ${market.category}`);

  const now = Date.now();
  const endTime = now + Number(daysToMs(market.end_days));
  const resolutionTime = now + Number(daysToMs(market.resolution_days));

  const tx = new Transaction();

  tx.moveCall({
    target: `${CONFIG.packageId}::market_entries::create_market_admin`,
    arguments: [
      tx.object(CONFIG.registryId),
      tx.object(CONFIG.adminCapId),
      tx.pure.vector('u8', stringToBytes(market.question)),
      tx.pure.vector('u8', stringToBytes(market.description)),
      tx.pure.vector('u8', stringToBytes(market.image_url)),
      tx.pure.vector('u8', stringToBytes(market.category)),
      tx.pure.vector('vector<u8>', market.tags.map(tag => stringToBytes(tag))),
      tx.pure.vector('u8', stringToBytes(market.outcome_yes)),
      tx.pure.vector('u8', stringToBytes(market.outcome_no)),
      tx.pure.u64(endTime),
      tx.pure.u64(resolutionTime),
      tx.pure.vector('u8', stringToBytes('2026')),
      tx.pure.u8(CONFIG.resolutionType),
      tx.pure.vector('u8', stringToBytes('admin')),
      tx.pure.u16(CONFIG.defaultFeeBps),
      tx.object(CONFIG.clockId),
    ],
  });

  tx.setGasBudget(50_000_000); // 0.05 SUI

  try {
    const result = await client.signAndExecuteTransaction({
      signer: keypair,
      transaction: tx,
      options: {
        showEffects: true,
        showObjectChanges: true,
      },
    });

    if (result.effects?.status?.status === 'success') {
      // Find the created market object
      const createdMarket = result.objectChanges?.find(
        change => change.type === 'created' && change.objectType?.includes('::market_types::Market')
      );

      const marketId = createdMarket && 'objectId' in createdMarket ? createdMarket.objectId : 'unknown';
      console.log(`   ✅ Success! Market ID: ${marketId}`);
      console.log(`   TX: ${result.digest}`);
      return marketId;
    } else {
      console.log(`   ❌ Failed: ${result.effects?.status?.error || 'Unknown error'}`);
      return null;
    }
  } catch (error) {
    console.log(`   ❌ Error: ${error instanceof Error ? error.message : 'Unknown error'}`);
    return null;
  }
}

// ============================================================================
// MAIN
// ============================================================================

async function main() {
  const args = process.argv.slice(2);
  const singleMode = args.includes('--single');
  const dryRun = args.includes('--dry-run');

  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║     PredictionSmart - Automated Market Creation              ║');
  console.log('╚══════════════════════════════════════════════════════════════╝');
  console.log('');

  // Load markets
  const markets = loadMarkets();
  const marketsToCreate = singleMode ? [markets[0]] : markets;

  console.log(`📋 Loaded ${markets.length} markets from markets-2026.json`);
  console.log(`🎯 Will create ${marketsToCreate.length} market(s)`);
  console.log(`🌐 Network: ${CONFIG.network}`);
  console.log(`📦 Package: ${CONFIG.packageId}`);
  console.log('');

  if (dryRun) {
    console.log('🔍 DRY RUN MODE - No transactions will be sent\n');
    marketsToCreate.forEach((market, i) => {
      console.log(`[${i + 1}] ${market.category}: ${market.question}`);
      console.log(`    Ends in ${market.end_days} days | Resolution: ${market.resolution_days} days`);
      console.log(`    Tags: ${market.tags.join(', ')}`);
      console.log('');
    });
    return;
  }

  // Initialize client and keypair
  const client = new SuiClient({ url: getFullnodeUrl(CONFIG.network) });
  const keypair = loadPrivateKey();
  const address = keypair.getPublicKey().toSuiAddress();

  console.log(`🔑 Using address: ${address}`);

  // Check balance
  const balance = await client.getBalance({ owner: address });
  console.log(`💰 Balance: ${Number(balance.totalBalance) / 1e9} SUI`);
  console.log('');

  // Create markets
  const results: { market: MarketData; marketId: string | null }[] = [];

  for (let i = 0; i < marketsToCreate.length; i++) {
    const market = marketsToCreate[i];
    const marketId = await createMarket(client, keypair, market, i, marketsToCreate.length);
    results.push({ market, marketId });

    // Rate limiting - wait between transactions
    if (i < marketsToCreate.length - 1) {
      console.log('   ⏳ Waiting 2 seconds before next market...');
      await sleep(2000);
    }
  }

  // Summary
  console.log('\n');
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║                        SUMMARY                                ║');
  console.log('╚══════════════════════════════════════════════════════════════╝');

  const successful = results.filter(r => r.marketId !== null);
  const failed = results.filter(r => r.marketId === null);

  console.log(`✅ Successfully created: ${successful.length}`);
  console.log(`❌ Failed: ${failed.length}`);
  console.log('');

  if (successful.length > 0) {
    console.log('Created Markets:');
    successful.forEach(({ market, marketId }) => {
      console.log(`  • ${market.category}: ${market.question.slice(0, 40)}...`);
      console.log(`    ID: ${marketId}`);
    });
  }

  if (failed.length > 0) {
    console.log('\nFailed Markets:');
    failed.forEach(({ market }) => {
      console.log(`  • ${market.category}: ${market.question.slice(0, 40)}...`);
    });
  }

  // Save results
  const resultsPath = path.join(process.cwd(), 'created-markets.json');
  fs.writeFileSync(resultsPath, JSON.stringify({
    timestamp: new Date().toISOString(),
    network: CONFIG.network,
    packageId: CONFIG.packageId,
    results: results.map(r => ({
      category: r.market.category,
      question: r.market.question,
      marketId: r.marketId,
      status: r.marketId ? 'success' : 'failed',
    })),
  }, null, 2));

  console.log(`\n📁 Results saved to: ${resultsPath}`);
}

main().catch(console.error);
