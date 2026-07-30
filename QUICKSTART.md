# Dollar1usd Protocol — Layer Infinity (bootstrap)

Requirements:
- foundryup (Foundry)
- git, bash

Local test:
1. Install Foundry:
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
2. Run tests:
   forge test -vv

Deploy (testnet):
1. Copy env template:
   cp deploy.env.template .env
   # Fill .env with DEPLOYER_PRIVATE_KEY, RPC_URL, ETHERSCAN_API_KEY
2. Deploy:
   forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast

CI:
- The GitHub Actions workflow runs forge test automatically on pushes/PRs to main/feature/dollar1usd-bootstrap.

Security:
- Slither is configured to run in CI; adjust .github/workflows/security.yml if you want to run in parallel or on a schedule.
