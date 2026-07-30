#!/usr/bin/env bash
# Usage: ./scripts/verify.sh <contract-address> <contract-name>
# Requires ETHERSCAN_API_KEY and CHAIN in env
CONTRACT=$1
NAME=$2
echo "Verify $NAME at $CONTRACT (placeholder - implement with hardhat/forge verify as needed)"
# Example (hardhat): npx hardhat verify --network $CHAIN $CONTRACT
# Example (forge): forge verify-contract --chain-id <id> $CONTRACT <FullyQualifiedName> $ETHERSCAN_API_KEY
