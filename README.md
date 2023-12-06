# Particle Leverage AMM (LAMM) Protocol 
Invitational Audit Details

- Total Prize Pool: $20,280 USDC (Notion: Total award pool)
  - HM awards: $20,280 USDC (Notion: HM (main) pool)
  - Analysis awards: XXX XXX USDC (Notion: Analysis pool)
  - QA awards: XXX XXX USDC (Notion: QA pool)
  - Bot Race awards: XXX XXX USDC (Notion: Bot Race pool)
  - Gas awards: XXX XXX USDC (Notion: Gas pool)
  - Judge awards: $3,380 USDC (Notion: Judge Fee)
  - Lookout awards: XXX XXX USDC (Notion: Sum of Pre-sort fee + Pre-sort early bonus)
  - Scout awards: $500 USDC (Notion: Scout fee - but usually $500 USDC)
- Join [C4 Discord](https://discord.gg/code4rena) to register
- Submit findings [using the C4 form](https://code4rena.com/contests/2023-12-particle/submit)
- [Read our guidelines for more details](https://docs.code4rena.com/roles/wardens)
- Starts December 11, 2023 20:00 UTC 
- Ends December 21, 2023 20:00 UTC

## Overview

Particle LAMM protocol enables permissionless leverage trading for any ERC20 tokens. The key idea is to borrow concentrated liquidity from AMMs (Uniswap v3 as a start). For a concentrated liquidity position, its price boundaries mathematically define the amount of tokens to convert at all price points. When borrowing from a concentrated liquidity position, the protocol calculates the exact amount required to top up upfront, such that the contract always locks enough tokens in case the price moves adversely to a price boundary. This design eliminates the need for a price oracle.

Whitepaper: [Medium](https://medium.com/@ParticleLabs/introducing-particle-leverage-amm-fcf0b3db8c55)
Developer handbook (code overview): [Gitbook](https://erc20-docs.particle.trade/)
Website: [Website](https://particle.trade)
Twitter: [Twitter](https://x.com/particle_trade)
Discord: [Discord](https://discord.particle.trade)

## Scope

| Contract | SLOC | Purpose | Libraries used |  
| ----------- | ----------- | ----------- | ----------- |
| [contracts/protocol/ParticlePositionManager.sol](https://github.com/code-423n4/2023-12-particle/blob/main/contracts/protocol/ParticlePositionManager.sol) | 416 | Main contract to mint/increase/decrease/collect/reclaim liquidity, open/close/liquidate positon, add premium, and admin control | [`@openzeppelin/contracts`](https://github.com/openzeppelin/openzeppelin-contracts/tree/0a25c1940ca220686588c4af3ec526f725fe2582) [`@openzeppelin/contracts-upgradable`](https://github.com/openzeppelin/openzeppelin-contracts-upgradeable/tree/58fa0f81c4036f1a3b616fdffad2fd27e5d5ce21) [`@uniswap/v3-periphery`](https://github.com/uniswap/v3-periphery/tree/80f26c86c57b8a5e4b913f42844d4c8bd274d058) |

### Scoping Details

```
- How many contracts are in scope?:  9
- Total SLoC for these contracts?:  1309
- How many external imports are there?: 15 
- How many separate interfaces and struct definitions are there for the contracts within scope?:  1 interface, 9 structs
- Does most of your code generally use composition or inheritance?:   Inheritance
- What is the overall line coverage percentage provided by your tests?: 95%
- Is this an upgrade of an existing system?: False
- Check all that apply (e.g. timelock, NFT, AMM, ERC20, rollups, etc.): AMM, ERC-20 Token
- Is there a need to understand a separate part of the codebase / get context in order to audit this part of the protocol?:  True 
- Please describe required context:   Uniswap v3 basic math, Uniswap liquidity logic
- Does it use an oracle?:  False
- Describe any novel or unique curve logic or mathematical models your code uses: Uniswap basic math, most importantly conversion of liquidity into different token amounts under different price points
- Is this either a fork of or an alternate implementation of another project?:   False
- Does it use a side-chain?:  False
- Describe any specific areas you would like addressed: About the design: (1) is the collateral guarantee safe in all conditions, meaning, the LPs suffers no higher impermanent loss than Uniswap itself (except for Uniswap's own rounding error) (2) borrowed liquidity should earn no less fees compared to the same liquidity would have otherwise earned in the pool (3) do we use uniswap critical variables correctly, such as the feeGrowth parameters and how we handle the premiumPortion (4) are the liquidation conditions safe or exploitable. In addition, about the implementation details: access control, token edge-case handling, reentrancy risks, and proper integration with external contracts.
```

## Setup
Cloning with submodules
```
git clone --recurse-submodules
```

Updating with submodule if the repo was cloned without --recurse-submodules
```
git submodule update --init --recursive
```

Add the following to `.env`
```
PRIVATE_KEY=[WALLET_PRIVATE_KEY]
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/[ALCHEMY_API_KEY]
GOERLI_RPC_URL=https://eth-goerli.g.alchemy.com/v2/[ALCHEMY_API_KEY]
ETHERSCAN_API_KEY=[ETHERSCAN_API_KEY]
```

Run
``` 
foundryup
source .env
```

## Test
Unit tests

```bash
forge test -vv --fork-url $MAINNET_RPC_URL --fork-block-number [BLOCK_NUMBER]
```

Gas report

```bash
forge test --gas-report --fork-url $MAINNET_RPC_URL --fork-block-number [BLOCK_NUMBER]
```

Coverage

```bash
forge coverage --ir-minimum --fork-url $MAINNET_RPC_URL --fork-block-number [BLOCK_NUMBER]
```

## Uniswap libraries diff
```
diff -u ./lib/v3-core/contracts/libraries/FullMath.sol ./contracts/libraries/FullMath.sol --ignore-space-change
diff -u ./lib/v3-core/contracts/libraries/TickMath.sol ./contracts/libraries/TickMath.sol --ignore-space-change
diff -u ./lib/v3-periphery/contracts/libraries/LiquidityAmounts.sol ./contracts/libraries/LiquidityAmounts.sol --ignore-space-change
diff -u ./lib/v3-periphery/contracts/libraries/PoolAddress.sol ./contracts/libraries/PoolAddress.sol --ignore-space-change
diff -u ./lib/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol ./contracts/interfaces/INonfungiblePositionManager.sol --ignore-space-change
```

## Foundry Deployment
Deploy
```
forge script script/DeployPositionManager.s.sol:DeployParticlePositionManager --rpc-url $GOERLI_RPC_URL/$MAINNET_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify -vv
```

Verify
```
forge verify-contract [CONTRACT_ADDRESS] contracts/protocol/ParticlePositionManager.sol:ParticlePositionManager --chain goerli/mainnet --watch
```

## Hardhat Deployment
Dependencies
```
yarn install
source .env
```

Deploy
```
yarn deploy script/deployPositionManager.ts --network goerli/mainnet --show-stack-traces
```

Verfiy
```
yarn verify --network goerli/mainnet [IMPLMENTATION_ADDRESS]
yarn verify --network goerli/mainnet [PROXY_ADDRESS] [IMPLMENTATION_ADDRESS] 0x
```

## Automated Findings / Publicly Known Issues

The 4naly3er report can be found [here](https://github.com/code-423n4/2023-12-particle/blob/main/4naly3er-report.md).

Automated findings output for the audit can be found [here](https://github.com/code-423n4/2023-12-particle/blob/main/bot-report.md) within 24 hours of audit opening.

_Note for C4 wardens: Anything included in this `Automated Findings / Publicly Known Issues` section is considered a publicly known issue and is ineligible for awards._


