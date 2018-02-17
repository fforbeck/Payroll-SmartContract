var EURToken = artifacts.require("./EURToken.sol");
var USDToken = artifacts.require("./USDToken.sol");
var Payroll = artifacts.require("./Payroll.sol");

module.exports = function(deployer) {
    const defaultOracleAddress = web3.eth.accounts[7];
    const defaultEURExchangeRate = 1;
    const tokenSupply = 100000000;
    return deployer.deploy(USDToken, tokenSupply).then(function () {
        return deployer.deploy(EURToken, tokenSupply).then(function() {
            return deployer.deploy(Payroll, defaultOracleAddress, EURToken.address, defaultEURExchangeRate);
        });
    })
};