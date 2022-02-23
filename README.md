# Shrines

A **shrine** is a smart contract that contains a list of addresses & shares, which is called the **ledger**. A shrine enables anyone to distribute any amount of any ERC20 token to the addresses on its ledger proportional to their share amounts. Shrines are at the core of Astrodrop’s product offering.

The admin of a shrine is called the **guardian**. Each guardian can modify their shrine’s ledger, as well as choose to charge a fee on all tokens distributed to their shrine. Each shrine only has one guardian, who can transfer their ownership of the shrine to another address if necessary.

Each address on a shrine’s ledger is called a **champion** of that shrine. Each champion can transfer their right to claim tokens from a certain shrine to another address.

## Installation

To install with [DappTools](https://github.com/dapphub/dapptools):

```
dapp install astrodrop/shrine
```

To install with [Foundry](https://github.com/gakonst/foundry):

```
forge install astrodrop/shrine
```

## Local development

This project uses [Foundry](https://github.com/gakonst/foundry) as the development framework.

### Dependencies

```
make update
```

### Compilation

```
make build
```

### Testing

```
make test
```
