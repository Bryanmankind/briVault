### ERC4626 Tournament Vault – Betting
This smart contract implements a tournament betting vault using the ERC4626 tokenized vault standard. It allows users to deposit an ERC20 asset to bet on a team, and at the end of the tournament, winners share the pool based on the value of their deposits.

## Overview
Participants can deposit tokens into the vault before the tournament begins, selecting a team to bet on. After the tournament ends and the winning team is set by the contract owner, users who bet on the correct team can withdraw their share of the total pooled assets.

The vault is fully ERC4626-compliant, enabling integrations with DeFi protocols and front-end tools that understand tokenized vaults.

### How It Works
## Deposit Phase
Users deposit an ERC20 token (e.g., USDC) before the eventStartDate.

Users must choose a team to bet on during deposit.

## Locking Phase
After the tournament starts, no more deposits or team changes are allowed.

Vault may earn yield depending on its strategy (e.g., Yearn, Aave).

## Result Phase
Once the tournament ends (eventEndDate), the owner sets the winner.

Only users who bet on the winning team can withdraw assets.

## Withdrawal Phase
Eligible users can withdraw based on their share of the total deposited amount among the winning team.

Non-winning participants forfeit their share.

## Security Notes
Owner has the ability to set the winner – ensure trust or decentralize this later via an oracle or DAO vote.

No early withdrawals allowed after event start.

Participation fees (if any) go to a pre-configured address.

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```
