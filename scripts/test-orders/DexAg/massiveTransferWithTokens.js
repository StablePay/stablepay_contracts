/* eslint-disable no-console */
/* eslint-disable global-require */
/* eslint-disable import/order */
/**
    Purpose:
    It gets all the available ERC20 tokens, and transfers a random amount.

    How do I execute this script?

    truffle exec ./scripts/massiveTransferWithTokens.js --network infuraRopsten
 */
// Smart contracts
const BigNumber = require('bignumber.js');
const axios = require('axios');
const assert = require('assert');
const appConfig = require('../../../src/config');

// eslint-disable-next-line no-undef
const IStablePay = artifacts.require('./interface/IStablePay.sol');
// eslint-disable-next-line no-undef
const ERC20 = artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol');

// Util classes
const { ETH_ADDRESS } = require('../../../test/util/consts');

const ProviderKeyGenerator = require('../../../src/utils/ProviderKeyGenerator');

const providerKeyGenerator = new ProviderKeyGenerator();
const ProcessArgs = require('../../../src/utils/ProcessArgs');

const processArgs = new ProcessArgs();

/**
    Script Arguments
 */
const unavailableTokens = [
  'RCN',
  'LINK',
  'STORM',
  'COFI',
  'BITX',
  'MOC',
  'MAS',
  'SPN',
  'HKN',
];
const DAI_NAME = 'DAI'; // DAI or DAI_COMPOUND
const merchantAddressIndex = 1;
const customerAddressIndex = 0;
const minAmount = 10;
const maxAmount = 25;

module.exports = async (callback) => {
  try {
    assert(minAmount < maxAmount, 'Min amount must be < than max Amount.');
    const accounts = await web3.eth.getAccounts();
    assert(accounts, 'Accounts must be defined.');
    const merchantAddress = accounts[merchantAddressIndex];
    const customerAddress = accounts[customerAddressIndex];

    const network = processArgs.network();
    console.log(`Script will be executed in network ${network}.`);
    const appConf = require('../../../config')(network);
    // NOTE: we want to emulate mainnet if not we can use appConf.network;
    const networkName = 'homestead';
    const maxGasForDeploying = appConf.maxGas;
    const stablepayConf = appConf.stablepay;
    const stablepayContracts = stablepayConf.contracts;

    const tokensUrl = `${appConfig.getStablePayApiUrl().get()}/tokens?network=${networkName}`;
    console.log('tokensUrl', tokensUrl);
    assert(tokensUrl, 'Tokens URL is undefined.');
    const ordersUrl = `${appConfig.getStablePayApiUrl().get()}/orders?network=${networkName}`;
    assert(ordersUrl, 'Orders URL is undefined.');

    const result = await axios.get(tokensUrl);
    const tokens = result.data;
    console.log(`${Object.keys(tokens).length} tokens.`);
    const daiToken = tokens[DAI_NAME];
    console.log('daiToken', daiToken);
    const balanceTest = await web3.eth.getBalance(customerAddress);
    console.log('balanceTest', balanceTest);
    const targetTokenInstance = await ERC20.at(daiToken.address);
    assert(targetTokenInstance, 'Target token instance is undefined.');
    console.log('getting token decimals');
    const tokenDecimals = await targetTokenInstance.decimals();
    console.log('tokenDecimals', tokenDecimals);
    const decimalsPow = (new BigNumber(10)).pow(tokenDecimals);


    tokens.forEach(async (token) => {
      console.log('\n', '-'.repeat(100));
      console.log(`Testing token => ${token.address} - ${token.decimals} - ${token.symbol}`);

      const targetAmount = Math.floor((Math.random() * (maxAmount - minAmount)) + minAmount);
      const targetAmountWei = BigNumber(targetAmount).times(decimalsPow).toFixed();
      let swapMessage;
      try {
        assert(!unavailableTokens.includes(token.symbol), `Pair ${token.symbol}-${DAI_NAME} is temporarily under maintenance.`);
        const createOrderResult = await axios.post(
          ordersUrl, {
            targetAmount,
            sourceTokenAddress: token.address,
            targetTokenAddress: targetTokenInstance.address,
            merchantAddress,
            customerAddress,
            verbose: true,
            safeMargin: '0.000000000',
          },
        );
        const { order, provider } = createOrderResult.data;
        console.log(`Using provider ${provider} for order`);
        console.log(`Using order ${JSON.stringify(order)}`);
        const sourceTokenRequiredBalance = BigNumber(order[0].toString()).toFixed();

        const providerKey = provider;

        console.log(`Swapping process will use ${providerKeyGenerator.fromBytes(providerKey)}`);

        swapMessage = `${sourceTokenRequiredBalance} ${token.symbol} => ${targetAmountWei} ${DAI_NAME}`;

        let sourceTokenInstance;
        let customerBalance;
        if (ETH_ADDRESS === token.address) {
          sourceTokenInstance = token.address;
          customerBalance = await web3.eth.getBalance(customerAddress);
        } else {
          sourceTokenInstance = await ERC20.at(token.address);
          customerBalance = await sourceTokenInstance.balanceOf(customerAddress);
        }

        const customerHasBalance = BigNumber(customerBalance.toString()).gte(sourceTokenRequiredBalance);
        console.log(`Enough balance of ${token.symbol}?. ${customerHasBalance} : Current: ${customerBalance.toString()}. Required: ${sourceTokenRequiredBalance.toString()}`);
        assert(customerHasBalance, `Not enough source token ${token.symbol} balance.`);

        console.log(`${swapMessage}`);
        const stablePayInstance = await IStablePay.at(stablepayContracts.StablePay);
        assert(stablePayInstance, 'StablePay instance is undefined.');

        let transferWithResult;
        if (ETH_ADDRESS !== token.address) {
          const approveResult = await sourceTokenInstance.approve(stablePayInstance.address, sourceTokenRequiredBalance, { from: customerAddress });
          assert(approveResult, 'Approve is undefined.');
          transferWithResult = await stablePayInstance.transferWithTokens(order, providerKey, { from: customerAddress, gas: maxGasForDeploying });
        } else {
          transferWithResult = await stablePayInstance.transferWithEthers(order, providerKey, { from: customerAddress, value: sourceTokenRequiredBalance, gas: maxGasForDeploying });
        }
        assert(transferWithResult, 'TransferWith result is undefined.');

        const etherscanUrlPrefix = networkName.toLowerCase() === 'ropsten' ? networkName : 'www';
        console.log(`Customer: ${customerAddress} => Merchant: ${merchantAddress}`);
        console.log(`Success ${swapMessage}: https://${etherscanUrlPrefix}.etherscan.io/tx/${transferWithResult.tx}`);
      } catch (error) {
        console.log(error);
        console.log(`Error ${swapMessage} : ${error.toString()}`);
        console.log(`Error on ${token.name}=>${DAI_NAME} stablePayStorage.getExpectedRates(${token.address} (${token.symbol}), ${targetTokenInstance.address} (${DAI_NAME}), ${targetAmountWei});`);
      }
    });

    console.log('>>>> The script finished successfully. <<<<');
    callback();
  } catch (error) {
    console.log(error);
    callback(error);
  }
};
