### 🎰🎲 LeveredVault || 🏗 Scaffold-Eth 2

## Overview

An ERC4626 vault that deposits on aave with leveradge and float.

You can deposit either Matic directly, or wMatic.

Once deposited, you are givin a share of the vault in LVT tokens, that represent your ownership. When you want to withdraw, Leveredvault gives you back your principal amount and any earnings

## Deployment

Create an .env file using the .env.example file as a template.

Then run:

```bash
  yarn install
```

App is setup to deploy on polygon. To deploy and start the app

```bash
  yarn deploy
  yarn start
```

## Tests

We used Foundry for testing, and a Makefile.
To run tests forking from polygon fork, run the following command

```bash
  cd packages/hardhat
  make test-polygon
```

# Acknowledgements

- [ScaffoldETH v2](https://github.com/scaffold-eth/se-2)
