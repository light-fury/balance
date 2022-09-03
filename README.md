# Balance Contract


## Configuration
### Install
Yarn is recommended to install node libraries
`yarn`

### Configure
Create a /secrets.json file with the following fields
```
{
    "alchemyApiKey": "", 
    "privateKey": "", 
    "daoPrivateKey": "",
    "etherscanApiKey": "",
    "alchemyApiKeyProd": ""
}
```
A private key is required to run most functions
TODO: make private key optional unless deploying

## unit tests
`npx hardhat test`

## deploy
Rinkeby `npx hardhat run --network rinkeby scripts/balancePass.js`
Ethereum Mainnet `npx hardhat run --network mainnet scripts/balancePass.js`

## Verification
After deployment, a message will be logged to the console including the command to verify. Having an alchemy API key in the secrets.json file is required for this to run correctly.