#!/usr/bin/env bash
set -euo pipefail

BRANCH="add/dollar1usd-protocol-sync"
ORIGIN="origin"

# Ensure we're in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: run this script from the root of the git repository."
  exit 1
fi

# Create and switch to branch
git fetch "$ORIGIN"
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "Branch $BRANCH already exists locally. Checking it out."
  git checkout "$BRANCH"
else
  echo "Creating branch $BRANCH from current HEAD."
  git checkout -b "$BRANCH"
fi

# Create directories
mkdir -p adapters/dollar1usd/scripts
mkdir -p adapters/dollar1usd/data
mkdir -p .github/workflows

# Write protocol.json
cat > adapters/dollar1usd/protocol.json <<'EOF'
{
  "$schema": "https://defillama.com/schemas/protocol-import-v1.json",
  "name": "Layer ∞ (Layer Infinite - Dollar1USD)",
  "id": "dollar1usd-protocol",
  "slug": "dollar1usd-protocol-for-building-layer-infinity-protocol-6507tl",
  "symbol": "$1USD",
  "category": "Cross-Chain Intents / MEV Infrastructure",
  "description": "Layer Infinite ($1USD Protocol) is a cross-chain intent execution infrastructure and liquidity network built for sovereign, MEV-resilient decentralized finance. Fully compliant with EIP-7702 dynamic delegation and ERC-7579 modular smart accounts, featuring Gas Optimized Bundling (GOB) reducing overhead by up to 40.8% and SovereignRelayer latency < 120ms.",
  "url": "https://dollar1usd.com",
  "defillamaProUrl": "https://defillama.com/pro/dollar1usd-protocol-for-building-layer-infinity-protocol-6507tl",
  "github": "https://github.com/Emadalshamery/layer-infinite-dollar1usd",
  "gecko_id": "dollar1usd",
  "twitter": "dollar1usd",
  "chains": [
    "ethereum",
    "arbitrum",
    "optimism",
    "polygon",
    "bsc",
    "base",
    "solana"
  ],
  "standards": [
    "EIP-7702",
    "ERC-7579",
    "ERC-4337"
  ],
  "mevProtection": {
    "engine": "Layer Infinite Delegation Engine (IDE)",
    "coreInvariant": "require(tx.gasprice <= auth.maxGasPrice, \"IDE: Gas price exceeds MEV limit\")",
    "gasOptimizationRatio": 40.8,
    "sovereignRelayLatencyMs": 118,
    "attacksBlocked": 14892
  },
  "tvlSummary": {
    "totalTvlUsd": 9178422.74,
    "evmTvlUsd": 6439166.64,
    "solanaTvlUsd": 2739256.1,
    "totalWalletsCount": 23,
    "evmWalletsCount": 21,
    "solanaWalletsCount": 2,
    "lastUpdatedIso": "2026-08-17T13:20:27.683Z",
    "timestampUnix": 1787059227
  },
  "methodology": "Sums native gas tokens (ETH, SOL, BNB, POL) and contract assets ($1USD, USDC, USDT) across 21 EVM executive authority clusters and 2 Solana sovereign settlement endpoints with MEV-resilience and EIP-7702 delegation tracking.",
  "chainOwners": {
    "ethereum": [
      "0xf3e726642f6384cb3d0ca14f426403bae888bf96",
      "0x773b20285d03b13190a31790dc4911c7188d24dc",
      "0x2426b9ce7906231f8f3fe8fdab74dd914d72f1e7",
      "0xdd5039bb6c28da062f351c5025873d6bbeeb0415",
      "0x0d8612a8929e7308d4d6f31e44d4e8c2f2d6fb52",
      "0xb4c50b3e6f7cdf918b3bd0e63a6c62e960ee9b62",
      "0x6784e004126d91a3b034787d662ce3e97dd34025",
      "0xd97303b627563aef52adf26878c57534f4079a47",
      "0x3e42d550ac249d2077f888838e15a5bf185054fd"
    ],
    "solana": [
      "Eq9MkY3jhFsjGQ4RjUjrFjGUD34qyN2iBhqFLzZEDydQ",
      "EZqGfTKusnWaZoFqfKqZbwwcM9oZFE5tuc2EpuseFKkk"
    ],
    "arbitrum": [
      "0x2e8601bfb4bd0f31a60e1b93945cfb7d6c2f17c5",
      "0xc26e08ec5f2289759fc9ec10ae9e035f29d929a7",
      "0x4cef0487ccd6f5fe52070cb57bf5c1eb6b3bd5b6"
    ],
    "optimism": [
      "0x086a2fff5f6e1c9eff375d1819eef314da84cbe4",
      "0xf30a791b0e7e122d89ea30bb7ea7f35941ea952d",
      "0xb8509f5259d6fEd87C13d31ABA4D638b8dc97F35"
    ],
    "polygon": [
      "0x9ecb641434f1eef3382bf573a1ef5065f31c69dd",
      "0x611c0972f77acbfb57236db016e4ed63a5122b4a"
    ],
    "bsc": [
      "0x53208f405281cae9ce059b2e9669d23412c0e2b3",
      "0x8e8a432e3877a9d553a759081daecf9367e8f3eb"
    ],
    "base": [
      "0x3C9718a88C31D397c494A51Dbec614afB77ddBB2",
      "0x8d791192d28b113ac347950f0a4badb0a7e5bd0f"
    ]
  },
  "clusters": [
    {
      "id": "evm-1",
      "address": "0xf3e726642f6384cb3d0ca14f426403bae888bf96",
      "chain": "ethereum",
      "primaryChain": "Ethereum",
      "role": "Primary Block Builder & Executive Hub #1",
      "roleAr": "المحور التنفيذي وباني الكتل الرئيسي #1",
      "nativeBalance": 42.85,
      "nativeSymbol": "ETH",
      "nativePriceUsd": 1895.08,
      "totalValueUsd": 926204.18,
      "tokens": [
        {
          "symbol": "$1USD",
          "name": "Dollar1USD Stable Asset",
          "balance": 520000,
          "valueUsd": 520000
        },
        {
          "symbol": "USDC",
          "name": "USD Coin",
          "balance": 185000,
          "valueUsd": 185000
        },
        {
          "symbol": "USDT",
          "name": "Tether USD",
          "balance": 140000,
          "valueUsd": 140000
        }
      ],
      "mevProtected": true,
      "eip7702Enabled": true,
      "txCount": 4129
    },
    {
      "id": "evm-2",
      "address": "0x2e8601bfb4bd0f31a60e1b93945cfb7d6c2f17c5",
      "chain": "arbitrum",
      "primaryChain": "Arbitrum",
      "role": "SovereignRelayer Cluster <120ms Latency",
      "roleAr": "عنقود الترحيل السيادي (زمن استجابة < 120ms)",
      "nativeBalance": 28.4,
      "nativeSymbol": "ETH",
      "nativePriceUsd": 1895.08,
      "totalValueUsd": 455020.27,
      "tokens": [
        {
          "symbol": "$1USD",
          "name": "Dollar1USD Stable Asset",
          "balance": 340000,
          "valueUsd": 340000
        },
        {
          "symbol": "ARB",
          "name": "Arbitrum Token",
          "balance": 85000,
          "valueUsd": 61200
        }
      ],
      "mevProtected": true,
      "eip7702Enabled": true,
      "txCount": 8940
    },
    {
      "id": "evm-3",
      "address": "0x773b20285d03b13190a31790dc4911c7188d24dc",
      "chain": "ethereum",
      "primaryChain": "Ethereum",
      "role": "InfiniteDelegationEngine (EIP-7702 Root)",
      "roleAr": "محرك التفويض اللانهائي (معيار EIP-7702)",
      "nativeBalance": 19.5,
      "nativeSymbol": "ETH",
      "nativePriceUsd": 1895.08,
      "totalValueUsd": 596705.81,
      "tokens": [
        {
          "symbol": "$1USD",
          "name": "Dollar1USD Stable Asset",
          "balance": 290000,
          "valueUsd": 290000
        },
        {
          "symbol": "WBTC",
          "name": "Wrapped Bitcoin",
          "balance": 4.25,
          "valueUsd": 269751.75
        }
      ],
      "mevProtected": true,
      "eip7702Enabled": true,
      "txCount": 3240
    },
    {
      "id": "evm-4",
      "address": "0x086a2fff5f6e1c9eff375d1819eef314da84cbe4",
      "chain": "optimism",
      "primaryChain": "Optimism",
      "role": "Gas Optimized Bundling (GOB -40.8%) Hub",
      "roleAr": "محور تجميع الغاز المحسن (توفير 40.8%)",
      "nativeBalance": 14.8,
      "nativeSymbol": "ETH",
      "nativePriceUsd": 1895.08,
      "totalValueUsd": 307797.18,
      "tokens": [
        {
          "symbol": "$1USD",
          "name": "Dollar1USD Stable Asset",
          "balance": 215000,
          "valueUsd": 215000
        },
        {
          "symbol": "OP",
          "name": "Optimism Token",
          "balance": 35000,
          "valueUsd": 64750
        }
      ],
      "mevProtected": true,
      "eip7702Enabled": true,
      "txCount": 6512
    },
    {
      "id": "evm-5",
      "address": "0x2426b9ce7906231f8f3fe8fdab74dd914d72f1e7",
      "chain": "ethereum",
      "primaryChain": "Ethereum",
      "role": "MEV Gas-Cap Enforcer Authority",
      "roleAr": "سلطة فرض سقف الغاز ومكافحة MEV",
      "nativeBalance": 22.1,
      "nativeSymbol": "ETH",
      "nativePriceUsd": 1895.08,
      "totalValueUsd": 451881.27,
      "tokens": [
        {
          "symbol": "$1USD",
          "name": "Dollar1USD Stable Asset",
          "balance": 410000,
          "valueUsd": 410000
        }
      ],
      "mevProtected": true,
      "eip7702Enabled": true,
      "txCount": 5210
    },
    {
      "id": "evm-6",
      "address": "0x9ecb641434f1eef3382bf573a1ef5065f31c69dd",
      "chain": "polygon",
      "primaryChain": "Polygon",
      "role": "Dollar1USD Protocol Core Treasury",
      "roleAr": "خزينة بروتوكول Dollar1USD المركزية",
      "nativeBalance": 45000,
      "nativeSymbol": "POL",
      "nativePriceUsd": 0.126156,
      "totalValueUsd": 875677.02,
      "tokens": [
        {
          "symbol": "$1USD",
          "name": "Dollar1USD Stable Asset",
          "balance": 750000,
          "valueUsd": 750000
        },
        {
          "symbol": "DAI",
          "name": "Dai Stablecoin",
          "balance": 120000,
          "valueUsd": 120000
        }
      ],
      "mevProtected": true,
      "eip7702Enabled": true,
      "txCount": 1980
    },
    {
      "id": "evm-7",
      "address": "0x3C9718a88C31D397c494A51Dbec614afB77ddBB2",
      "chain": "base",
      "primaryChain": "Base",
      "role": "Cross-Chain Intent Propagator",
      "roleAr": "ممرر النوايا عبر السلاسل (Base Engine)",
      "nativeBalance": 12.6,
      "nativeSymbol": "ETH",
      "nativePriceUsd": 1895.08,
      "totalValueUsd": 298878.01,
      "tokens": [
        {
          "symbol": "$1USD",
          "name": "Dollar1USD Stable Asset",
          "balance": 180000,
          "valueUsd": 180000
        },
        {
          "symbol": "USDC",
          "name": "USD Coin",
          "balance": 95000,
          "valueUsd": 95000
        }
      ],
      "mevProtected": true,
      "eip7702Enabled": true,
      "txCount": 4890
    },
    {
      "id": "evm-8",
      "address": "0x53208f405281cae9ce059b2e9669d23412c0e2b3",
      "chain": "bsc",
      "primaryChain": "BSC",
      "role": "ERC-7579 Modular Smart Account Controller",
      "roleAr": "متحكم الحسابات الذكية المعيارية ERC-7579",
      "nativeBalance": 85.2,
      "nativeSymbol": "BNB",
      "nativePriceUsd": 603.33,
      "totalValueUsd": 391403.72,
      "tokens": [
        {
          "symbol": "$1USD",
          "name": "Dollar1USD Stable Asset",
          "balance": 260000,
          "valueUsd": 260000
        },
        {
          "symbol": "USDT",
          "name": "Tether USD",
          "balance": 80000,
          "valueUsd": 80000
        }
      ],
      "mevProtected": true,
      "eip7702Enabled": true,
      "txCount": 3100
    },
    {
      "id": "evm-9",
      "address": "0xdd5039bb6c28da062f351c5025873d6bbeeb0415",
      "chain": "ethereum",
      "primaryChain": "Ethereum",
      "role": "Multi-Chain Liquidity Sink Node #9",
      "roleAr": "عقدة مجمع السيولة متعددة السلاسل #9",
      "nativeBalance": 16.4,
      "nativeSymbol": "ETH",
      "nativePriceUsd": 1895.08,
      "totalValueUsd": 226079.31,
      "tokens": [
        {
          "symbol": "$1USD",
          "name": "Dollar1USD Stable Asset",
          "balance": 195000,
          "valueUsd": 195000
        }
      ],
      "mevProtected": true,
      "eip7702Enabled": true,
      "txCount": 2450
    },
    {
      "id": "evm-10",
      "address": "0x0d8612a8929e7308d4d6f31e44d4e8c2f2d6fb52",
      "chain": "ethereum",
      "primaryChain": "Ethereum",
      "role": "Layer ∞ Sovereign Validator Authority #10",
      "roleAr": "سلطة التحقق السيادية Layer ∞ #10",
      "nativeBalance": 15.1,
      "nativeSymbol": "ETH",
      "nativePriceUsd": 1895.08,
      "totalValueUsd": 203615.71,
      "tokens": [
        {
          "symbol": "$1USD",
          "name": "Dollar1USD Stable Asset",
          "balance": 175000,
          "valueUsd": 175000
        }
      ],
      "mevProtected": true,
      "eip7702Enabled": true,
      "txCount": 1870
    },
    {
      "id": "evm-11",
      "address": "0xc26e08ec5f2289759fc9ec10ae9e035f29d929a7",
      "chain": "arbitrum",
      "primaryChain": "Arbitrum",
      "role": "Executive Cluster Node #11",
      "roleAr": "عقدة العنقود التنفيذي #11",
      "nativeBalance": 8.5,
      "nativeSymbol": "ETH",
      "nativePriceUsd": 1895.08,
