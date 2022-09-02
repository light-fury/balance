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
TODO: Add deployment instructions