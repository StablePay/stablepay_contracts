require('dotenv').config();
const KeyValue = require('./KeyValue');

const DEFAULT_GAS_WEI = "4600000";
const DEFAULT_ADDRESS_COUNT = "10";
const DEFAULT_ADDRESS_INDEX = "0";
const DEFAULT_GAS_GWEI_PRICE = '20';

const PLATFORM_FEE_KEY = 'PLATFORM_FEE';
const ADDRESS_COUNT_KEY = 'ADDRESS_COUNT_KEY';
const DEFAULT_ADDRESS_INDEX_KEY = 'DEFAULT_ADDRESS_INDEX_KEY';
const MNEMONIC_KEY = 'MNEMONIC_KEY';
const INFURA_KEY = 'INFURA_KEY';
const GAS_WEI_KEY = 'GAS_WEI_KEY';
const GAS_PRICE_GWEI_KEY = 'GAS_PRICE_GWEI_KEY';
const ETHERSCAN_API_KEY_KEY = 'ETHERSCAN_API_KEY';
const KYBER_ADDRESS_FEE_KEY = 'KYBER_ADDRESS_FEE';
const STABLEPAY_API_URL_KEY = 'STABLEPAY_API_URL';

class AppConfig {
    constructor() {
        this.conf = new Map();
        this.initializeConf();
    }
}

AppConfig.prototype.initializeConf = function() {
    this.createItem(STABLEPAY_API_URL_KEY, undefined, 'It is used to call StablePay API Rest endpoints.');
    this.createItem(PLATFORM_FEE_KEY, undefined, 'This is the platform fee.');
    this.createItem(DEFAULT_ADDRESS_INDEX_KEY, DEFAULT_ADDRESS_INDEX, 'This is the address index to be used as default.');
    this.createItem(ADDRESS_COUNT_KEY, DEFAULT_ADDRESS_COUNT, 'Addresses needed to deploy smart contracts.');
    this.createItem(MNEMONIC_KEY, undefined, 'Mnemonic to generate addresses.');
    this.createItem(INFURA_KEY, undefined, 'Infura provider key used to deploy smart contracts.');
    this.createItem(GAS_WEI_KEY, DEFAULT_GAS_WEI, 'Default gas value in wei.');
    this.createItem(GAS_PRICE_GWEI_KEY, DEFAULT_GAS_GWEI_PRICE, 'Default gas price value in gwei.');
    this.createItem(ETHERSCAN_API_KEY_KEY, undefined, 'API key to verify smart contracts in Etherscan using truffle-plugin-verify plugin.');
    this.createItem(KYBER_ADDRESS_FEE_KEY, undefined, 'This address is used by Kyber Swapping Provider to get fees for each trading.');
}

AppConfig.prototype.createItem = function(name, defaultValue = undefined, description = undefined) {
    const value = process.env[name];
    this.conf.set(name, new KeyValue(name, value, defaultValue, description));
}

AppConfig.prototype.getMnemonic = function() {
    return this.conf.get(MNEMONIC_KEY);
}

AppConfig.prototype.getInfuraKey = function() {
    return this.conf.get(INFURA_KEY);
}

AppConfig.prototype.getAddressCount = function() {
    return this.conf.get(ADDRESS_COUNT_KEY);
}

AppConfig.prototype.getGasWei = function() {
    return this.conf.get(GAS_WEI_KEY);
}

AppConfig.prototype.getGasPriceGwei = function() {
    return this.conf.get(GAS_PRICE_GWEI_KEY);
}

AppConfig.prototype.getDefaultAddressIndex = function() {
    return this.conf.get(DEFAULT_ADDRESS_INDEX_KEY);
}

AppConfig.prototype.getPlatformFee = function() {
    return this.conf.get(PLATFORM_FEE_KEY);
}

AppConfig.prototype.getEtherscanApiKey = function() {
    return this.conf.get(ETHERSCAN_API_KEY_KEY);
}

AppConfig.prototype.getKyberAddressFee = function() {
    return this.conf.get(KYBER_ADDRESS_FEE_KEY);
}

AppConfig.prototype.getStablePayApiUrl = function() {
    return this.conf.get(STABLEPAY_API_URL_KEY);
}

AppConfig.prototype.validate = function() {
    
    if (!this.getInfuraKey().hasValue()) {
        throw new Error('The infura key (INFURA_KEY) is empty. It must be defined in .env file.');
    }
    if (!this.getMnemonic().hasValue()) {
        throw new Error('The mnemonic key (MNEMONIC_KEY) is empty. It must be defined in .env file.');
    }
    if(!this.getPlatformFee().hasValue()) {
        throw new Error(`The platform fee key (PLATFORM_FEE) is empty. It must be defined in .env file.`);
    }
    if(!this.getKyberAddressFee().hasValue()) {
        throw new Error(`The Kyber Address Fee (KYBER_ADDRESS_FEE) is empty. It must be defined in .env file.`);
    }
}

module.exports = AppConfig;