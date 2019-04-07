const BigNumber = require('bignumber.js');
const t = require('../util/TestUtil').title;
const withData = require('leche').withData;

// Mock Smart Contracts
const StandardTokenMock = artifacts.require("./mock/StandardTokenMock.sol");
const StablePayBaseMock = artifacts.require("./mock/StablePayBaseMock.sol");

// Smart Contracts
const Storage = artifacts.require("./base/Storage.sol");

contract('StablePayBaseTransferFromTest', accounts => {
    const owner = accounts[0];
    const account1 = accounts[1];
    const account2 = accounts[2];
    const account3 = accounts[3];

    let stablePay;

    beforeEach('Setup', async () => {
        const storageInstance = await Storage.deployed();
        assert(storageInstance);
        assert(storageInstance.address);

        stablePay = await StablePayBaseMock.new(storageInstance.address);
        assert(stablePay);
        assert(stablePay.address);
    });

    withData({
        _1_approve1000_amount1000: [account1, account2, account3, "1000", "1000", false],
        _2_approve10_amount100: [account1, account2, account3, "10", "100", true]
    }, function(tokenOwner, from, to, approveAmount, amount, mustFail) {
        it(t('anUser', 'transferFrom', 'Should be able (or not) to transfer from token.', mustFail), async function() {
            //Setup
            const supply = web3.utils.toWei('100000000000', 'ether');
            const approveAmountWei = web3.utils.toWei(approveAmount, 'ether');
            const amountWei = web3.utils.toWei(amount, 'ether');
            
            const token = await StandardTokenMock.new(tokenOwner, supply);
            await token.transfer(from, approveAmountWei, { from: tokenOwner});
            await token.approve(stablePay.address, approveAmountWei, { from: from});

            try {
                //Invocation
                const result = await stablePay._transferFrom(token.address, from, to, amountWei);
                
                // Assertions
                assert(!mustFail, 'It should have failed because data is invalid.');
                assert(result);

                const toBalance = await token.balanceOf(to);
                assert.equal(toBalance.toString(), amountWei.toString());
            } catch (error) {
                // Assertions
                assert(mustFail);
                assert(error);
                assert.equal(error.reason, "Value <= balance[from]");
            }
        });
    });
});