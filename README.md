![Slide 1](https://github.com/KintoXYZ/kinto-id/assets/541599/c9345010-21c6-411c-bbf8-31a6727d8c48)

# Kinto ID
Kinto ID gives developers all the functionality to verify on-chain whether a given address has the appropriate KYC, accreditation requirements. Kinto ID also provides functionality to check AML sanctions.

## Docs

Check to our gitbook to see all the documentation.

[Docs](https://docs.kinto.xyz/developers)

## Relevant Public Methods

You can check all the public methods in the interface [here](https://github.com/KintoXYZ/kinto-id/blob/main/src/interfaces/IKintoID.sol)

```
    function isKYC(address _account) external view returns (bool);

    function isSanctionsMonitored(uint32 _days) external view returns (bool);

    function isSanctionsSafe(address _account) external view returns (bool);

    function isSanctionsSafeIn(address _account, uint8 _countryId) external view returns (bool);

    function isCompany(address _account) external view returns (bool);

    function isIndividual(address _account) external view returns (bool);

    function mintedAt(address _account) external view returns (uint256);

    function hasTrait(address _account, uint8 index) external view returns (bool);

    function traits(address _account) external view returns (bool[] memory);
```

## Requirements

- Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Copy .env.sample to .env and fill the values. After you deploy the proxy make sure to fill its address as well.

## Testing

In order to run the tests, execute the following command:

```
forge test
```

## Deploy a new proxy and 1st version

```
source .env && forge script script/deploy.sol:KintoInitialDeployScript --rpc-url $KINTO_RPC_URL --broadcast -vvvv
```

## Upgrade to a new version

```
source .env && forge script script/deploy.sol:KintoUpgradeScript --rpc-url $KINTO_RPC_URL --broadcast -vvvv
```

## Calling the smart contract

Check that the contract is deployed:

cast call $ID_PROXY_ADDRESS "name()(string)" --rpc-url $KINTO_RPC_URL

Call KYC on an address

```
cast call $ID_PROXY_ADDRESS "isKYC(address)(bool)" 0xa8beb41cf4721121ea58837ebdbd36169a7f246e  --rpc-url $KINTO_RPC_URL
```

## Deploying other contracts

In order to deploy non upgradeable contracts, use the following command:

```
forge create --rpc-url $KINTO_RPC_URL --private-key <your_private_key> src/<CONTRACT_NAME>
```

## Verifying smart contracts on blockscout

On Testnet:

```
forge verify-contract --watch --verifier blockscout --chain-id 42888 --verifier-url http://test-explorer.kinto.xyz/api --num-of-optimizations 100000 0xE40C427226D78060062670E341b0d8D8e66d725A ETHPriceIsRight
```

# Account Abstraction & Smart Contract Wallet

## Prerequisites

### Enable CREATE2 in our chain

Fund the signer `0x3fab184622dc19b6109349b94811493bf2a45362` to deploy the arachnid proxy:

```
cast send 0x3fab184622dc19b6109349b94811493bf2a45362 --value 0.03ether --private-key <your_private_key> --rpc-url $KINTO_RPC_URL
```

Send the following transaction using foundry. Make sure you disable EIP-155:

```
cast publish f8a58085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf31ba02222222222222222222222222222222222222222222222222222222222222222a02222222222222222222222222222222222222222222222222222222222222222  --rpc-url <NODE_OPEN_EIP155>
```
Now we should have the proxy live at `0x4e59b44847b379578588920ca78fbf26c0b4956c`.

### Deploy Account Abstraction Entry Point

Reference implementation: [https://github.com/eth-infinitism/account-abstraction/blob/develop/deploy/1_deploy_entrypoint.ts](ETH-Infinitism)

We want to deploy the entry point at `0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789`.

Add the kinto network to `hardhat-config` file. Run yarn run deploy in their repo as follows:

```
yarn deploy --network kintotest
```

## Deploy Kinto Wallet Factory

Here is the code to deploy our wallet factory and an initial wallet owned by the PUBLIC_KEY/PRIVATE_KEY signer:

```
source .env && forge script script/deployaa.sol:KintoAAInitialDeployScript --rpc-url $KINTO_RPC_URL --broadcast -vvvv
```

## Funding a smart contract wallet for testing

```
cast send <WALLET_ADDRESS> "addDeposit()" --value 0.1ether
```