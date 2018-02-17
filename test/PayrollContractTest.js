var Payroll = artifacts.require('./Payroll.sol');
var EURToken = artifacts.require("./EURToken.sol");
var USDToken = artifacts.require("./USDToken.sol");

contract('Payroll', function (accounts) {

    assert.equal(10, accounts.length, "Test must start with 10 accounts");

    const defaultOracleAddress = web3.eth.accounts[8];
    const defaultEURExchangeRate = 1;
    const defaultUSDExchangeRate = 1;
    const tokenSupply = 1000000;
    const ownerAddress = accounts[0];
    const employeeA = accounts[1];
    const employeeB = accounts[2];
    const yearlyEURSalaryA = 100000;
    const yearlyEURSalaryB = 120000;
    const newOracleAddress = accounts[6];

    let PayrollContract;
    let EURTokenContract;
    let USDTokenContract;
    let tokenEUR;
    let tokenUSD;

    it("should initialize the EURToken contract", async function () {
        EURTokenContract = await EURToken.new(tokenSupply);
        assert(EURTokenContract !== undefined);
    });

    it("should initialize the USDToken contract", async function () {
        USDTokenContract = await USDToken.new(tokenSupply);
        assert(USDTokenContract !== undefined);
        tokenUSD = USDTokenContract.address;
    });

    it("should initialize the Payroll contract", async function () {
        tokenEUR = EURTokenContract.address;
        PayrollContract = await Payroll.new(defaultOracleAddress, EURTokenContract.address, defaultEURExchangeRate);
        assert(PayrollContract !== undefined);
    });

    it("should not allow sending ether to payroll contract", async function () {
        try {
            await web3.eth.sendTransaction({
                from: eth.coinbase,
                to: PayrollContract.address,
                value: web3.toWei(0.05, "ether")
            });
        } catch (error) {
            return true
        }
        throw new Error("Payroll contract must not allow ether transactions");
    });

    it("should not allow sending ether to EURToken contract", async function () {
        try {
            await web3.eth.sendTransaction({
                from: eth.coinbase,
                to: EURTokenContract.address,
                value: web3.toWei(0.05, "ether")
            });
        } catch (error) {
            return true
        }
        throw new Error("EURToken contract must not allow ether transactions");
    });

    it("should not allow sending ether to USDToken contract", async function () {
        try {
            await web3.eth.sendTransaction({
                from: eth.coinbase,
                to: USDTokenContract.address,
                value: web3.toWei(0.05, "ether")
            });
        } catch (error) {
            return true
        }
        throw new Error("EURToken contract must not allow ether transactions");
    });

    it("should be initialized with zero employees", async function () {
        let count = await PayrollContract.getEmployeeCount({from: ownerAddress});
        assert.equal(0, count.toNumber(), "employees count must be zero");
    });

    it("should be initialized default oracle address", async function () {
        let expectedAddress = await PayrollContract.oracle();
        assert.equal(defaultOracleAddress, expectedAddress);
    });

    it("should send 1000000 EUR tokens to Payroll contract", async function () {
        await EURTokenContract.transfer(PayrollContract.address, 1000000);
        let payrollBalance = await EURTokenContract.balanceOf.call(PayrollContract.address);
        assert.equal(1000000, payrollBalance, "Payroll balance must have 1,000,000 EUR Tokens");
    });

    it("should send 1000000 USD tokens to Payroll contract", async function () {
        await USDTokenContract.transfer(PayrollContract.address, 1000000);
        let payrollBalance = await USDTokenContract.balanceOf.call(PayrollContract.address);
        assert.equal(1000000, payrollBalance, "Payroll balance must have 1,000,000 USD Tokens");
    });

    it("should add a new employee, allow payments in EUR token and get employee info", async function () {
        let result = await PayrollContract.addEmployee(employeeA, yearlyEURSalaryA, {from: ownerAddress});
        assert.equal("LogEmployeeAdded", result.logs[0].event, "Event must be LogEmployeeAdded");
        assert.equal(employeeA, result.logs[0].args._employeeAddress, "An invalid employee address was added");
        assert.equal(yearlyEURSalaryA, result.logs[0].args._yearlyEURSalary, "An invalid employee salary was added");

        result = await PayrollContract.getEmployeeCount({from: ownerAddress});
        assert.equal(1, result.toNumber(), "Employee count should be equals to 1");
    });

    it("should allow payments in EUR token for employee", async function () {
        let result = await PayrollContract.allowToken(employeeA, tokenEUR, 1, {from: ownerAddress});
        assert.equal("LogTokenAllowed", result.logs[0].event, "Event must be LogTokenAllowed");
        assert.equal(employeeA, result.logs[0].args._employeeAddress, "Employee must be employeeA");
        assert.equal(tokenEUR, result.logs[0].args._token, "Allowed token must be tokenEUR");
        assert.equal(1, result.logs[0].args._exchangeRate.toNumber(), "EUR exchange range must be 1");
    });

    it("should get the new employee info", async function () {
        let result = await PayrollContract.getEmployee(employeeA, {from: ownerAddress});
        assert.equal(yearlyEURSalaryA, result[0].toNumber(), "Yearly salary must be yearlyEURSalaryA");
        assert.equal(0, result[1].toNumber(), "Total received so far must be zero");
        assert.equal(tokenEUR, result[2], "First allowed token must be EURToken (tokenEUR)");
    });

    it("should update the employee salary", async function () {
        let result = await PayrollContract.setEmployeeSalary(employeeA, yearlyEURSalaryB, {from: ownerAddress});
        assert.equal("LogEmployeeSalaryUpdated", result.logs[0].event, "Event must be LogEmployeeSalaryUpdated");
        assert.equal(employeeA, result.logs[0].args._employeeAddress, "Invalid employee address");
        assert.equal(yearlyEURSalaryA, result.logs[0].args._oldYearlyEURSalary.toNumber(), "Old employee salary must be yearlyEURSalaryA");
        assert.equal(yearlyEURSalaryB, result.logs[0].args._newYearlyEURSalary.toNumber(), "New employee salary must be yearlyEURSalaryB");

        result = await PayrollContract.getEmployee(employeeA, {from: ownerAddress});
        assert.equal(yearlyEURSalaryB, result[0].toNumber(), "Yearly salary must be yearlyEURSalaryB");
        assert.equal(0, result[1].toNumber(), "Total received so far must be zero");
        assert.equal(tokenEUR, result[2], "Allowed token must be tokenEUR");
    });

    it("should calculate the payroll burnrate", async function () {
        let result = await PayrollContract.calculatePayrollBurnrate({from: ownerAddress});
        var expectedBurnrate = Math.floor(yearlyEURSalaryB / 12);
        assert.closeTo(expectedBurnrate, result.toNumber(), 1, "Contract burnrate must be equal to " + expectedBurnrate);
    });

    it("should calculate the days left to run out of funds", async function () {
        let result = await PayrollContract.calculatePayrollRunway(tokenEUR, {from: ownerAddress});
        assert.equal(3048, result.toNumber(), "Days left to run out of funds must be 3048");
    });

    it("should block the payments", async function () {
        let result = await PayrollContract.blockPayments({from: ownerAddress});
        assert.equal("LogPaymentsBlocked", result.logs[0].event, "Event must be LogPaymentsBlocked");
    });

    it("should not allow updates on tokens distributions due to blocked payments", async function () {
        try {
            await PayrollContract.determineAllocation.call(tokenEUR, 10000, {from: employeeA});
        } catch (error) {
            return true
        }
        throw new Error("PayrollContract.determineAllocation function must not allow calls");
    });

    it("should not allow payments for employees due to blocked payments", async function () {
        try {
            await  await PayrollContract.payday({from: employeeA});
        } catch (error) {
            return true
        }
        throw new Error("PayrollContract.payday function must not allow calls");
    });

    it("should allow the payments", async function () {
        let result = await PayrollContract.allowPayments({from: ownerAddress});
        assert.equal("LogPaymentsAllowed", result.logs[0].event, "Event must be LogPaymentsAllowed");
    });

    it("should allow employee to update the tokens distribution", async function () {
        let result = await PayrollContract.determineAllocation(tokenEUR, 10000, {from: employeeA});
        assert.equal("LogPaymentDistributionUpdated", result.logs[0].event, "Event must be LogPaymentDistributionUpdated");
        assert.equal(employeeA, result.logs[0].args._employeeAddress, "An invalid employee address was added");
        assert.equal(10000, result.logs[0].args._totalDistributed.toNumber(), "Total distributed must be 10000");
    });

    it("should not allow distribution greater than 100%", async function () {
        try {
            await PayrollContract.determineAllocation(tokenEUR, 101, {from: employeeA});
        } catch (error) {
            return true
        }
        throw new Error("PayrollContract.determineAllocation function must not allow distribution");
    });

    it("should allow employee to receive the salary on pay day", async function () {
        let result = await PayrollContract.payday(tokenEUR, {from: employeeA});
        assert.equal("LogPaymentReceived", result.logs[0].event, "Event must be LogPaymentReceived");
        assert.equal(employeeA, result.logs[0].args._employeeAddress, "Employee must be employeeA");
        assert.equal(tokenEUR, result.logs[0].args._tokenAddress, "Payment must be sent to tokenEUR");
        assert.equal(10000, result.logs[0].args._tokenPayment.toNumber(), "Paid salary in EUR Token must be 10,000");

        result = await EURTokenContract.balanceOf(employeeA);
        assert.equal(10000, result, "Received salary in EUR Token must be 10,000")
    });

    it("should have the employee removed", async function () {
        let result = await PayrollContract.removeEmployee(employeeA);
        assert.equal("LogEmployeeRemoved", result.logs[0].event, "Event must be an LogEmployeeRemoved");
        assert.equal(employeeA, result.logs[0].args._employeeAddress, "An invalid employee address was added");
        assert.equal(0, await PayrollContract.getEmployeeCount({from: ownerAddress}), "Employee count should be equals to 0");
    });

    it("should allow employee to receive the salary distributed in USD and EUR tokens", async function() {
        let result = await PayrollContract.addEmployee(employeeB, yearlyEURSalaryB, {from: ownerAddress});
        assert.equal("LogEmployeeAdded", result.logs[0].event, "Event must be LogEmployeeAdded");

        result = await PayrollContract.allowToken(employeeB, tokenEUR, 1, {from: ownerAddress});
        assert.equal("LogTokenAllowed", result.logs[0].event, "Event must be LogTokenAllowed");

        result = await PayrollContract.addSupportedToken(tokenUSD, defaultUSDExchangeRate, {from: ownerAddress});
        assert.equal("LogSupportedTokenAdded", result.logs[0].event, "Event must be LogSupportedTokenAdded");

        result = await PayrollContract.allowToken(employeeB, tokenUSD, 1, {from: ownerAddress});
        assert.equal("LogTokenAllowed", result.logs[0].event, "Event must be LogTokenAllowed");

        result = await PayrollContract.getEmployee(employeeB, {from: ownerAddress});
        assert.equal(120000, result[0].toNumber(), "Salary must be 120,000");
        assert.equal(0, result[1].toNumber(), "Total paid must be zero");
        assert.equal(tokenEUR, result[2][0], "Token EUR must be allowed");
        assert.equal(tokenUSD, result[2][1], "Token USD must be allowed");

        result = await PayrollContract.determineAllocation(tokenUSD, 5000, {from: employeeB});
        assert.equal("LogPaymentDistributionUpdated", result.logs[0].event, "Event must be LogPaymentDistributionUpdated");

        result = await PayrollContract.determineAllocation(tokenEUR, 5000, {from: employeeB});
        assert.equal("LogPaymentDistributionUpdated", result.logs[0].event, "Event must be LogPaymentDistributionUpdated");

        result = await PayrollContract.payday(tokenEUR, {from: employeeB});
        assert.equal("LogPaymentReceived", result.logs[0].event, "Event must be LogPaymentReceived");

        result = await EURTokenContract.balanceOf.call(employeeB);
        assert.equal(5000, result.toNumber(), "Received salary in EUR Token must be 5,000");

        result = await PayrollContract.payday(tokenUSD, {from: employeeB});
        assert.equal("LogPaymentReceived", result.logs[0].event, "Event must be LogPaymentReceived");

        result = await USDTokenContract.balanceOf.call(employeeB);
        assert.equal(5000, result, "Received salary in USD Token must be 5,000");

        result = await PayrollContract.removeEmployee(employeeB);
        assert.equal("LogEmployeeRemoved", result.logs[0].event, "Event must be an LogEmployeeRemoved");
    });

    it("should have the oracle address updated", async function () {
        let result = await PayrollContract.setOracle(newOracleAddress, {from: ownerAddress});
        assert.equal("LogOracleUpdated", result.logs[0].event, "Contract must generate event LogOracleUpdated");
        assert.equal(newOracleAddress, result.logs[0].args._newOracle);
    });

});