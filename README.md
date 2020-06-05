# 🎰DeFi777🎰

Use DeFi protocols using simple token transfers.

Visit https://defi777.com for instructions

## Developers

DeFi777 can be a great tool for smart contract & dapp developers to easily use DeFi protocols.

More documentation coming soon.

## Contracts

* `protocols`
    + `aave`
        - `Aave777.sol`: Root contract, can create AToken777s and will forward received tokens
        - `AToken777.sol`: ERC777 wrapper for aTokens. Calculates balances using the Aave lending pool
        - `ERC777WithoutBalance.sol`: Clone of the OpenZeppelin ERC777 contract, but does not store any token balances
        - `WadRawMath.sol`: Math library copied from Aave repo
    + `balancer`
        - `Balancer777`: Receives ERC777 tokens and swaps into destination token using Balancer
        - `BalancerHub`: Root contract, stores a mapping of tokens to pools, constructs Balancer777s
    + `uniswap`
        - `UniswapWrapper.sol`: Receives 777 tokens and swaps into destination token using Uniswap V2
        - `UniswapWrapperFactory.sol`: Factory for UniswapWrappers
* `test`: Contracts used by unit tests
* `tokens`: ERC777 wrapper contracts
    - `ERC777WithGranularity`: Clone of the OpenZeppelin ERC777 contract, but uses Granularity.sol
    - `Granularity.sol`: Helper contract to convert between ERC20 decimals and ERC777 granularity
    - `IWrapped777.sol`: Interface for a ERC777 wrapper
    - `Unwrapper.sol`: Simple contract that unwraps 777 tokens and returns the wrapped ERC20. Deployed at defi777.eth
    - `Wrapped777.sol`: ERC777 token that is minted when locking a ERC20 token. Also adds permit() and flashloans
    - `WrapperFactory.sol`: Factory to generate a Wrapped777 for any ERC20
* `Receiver.sol`: Helper contract for simplifying ERC777Recipient
