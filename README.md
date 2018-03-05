[![Build Status](https://travis-ci.com/fforbeck/Payroll-SmartContract.svg?token=QwGVaghZwghs8qEgGeyu&branch=master)](https://travis-ci.com/fforbeck/Payroll-SmartContract)

# Payroll Smart Contract
This is a solidity smart contract to manage an employee payroll based on ERC20 tokens. The contract owner may
add new supported tokens into the contract and whitelist different types of tokens for each employee, so they can withdraw their payments in tokens according to a distribution that is set by the employee.

The default token supported is the EURT, which is a token that represents the EUR currency. I also added the USD Token, USDT. Any transaction that attempts to send ether to the Payroll contract will be reverted. Ether is not allowed.

Employees are allowed to withdraw their payment only once a month and, each six months they can define a new token distribution, but for the whitelisted tokens.

Besides that, the contract owner is able to block/allow payments in case of an emergency. Additional information about each employee, payments, distributions and supported tokens is available.



### Constructor
```solidity
function Payroll(address _defaultOracle, address _tokenEURAddress, uint256 _EURExchangeRate) //default constructor with oracle address and default EUR token details
```

### Owner Functions
```solidity
function allowToken(address _employeeAddress, address _token, uint256 _EURExchangeRate) external;
function addSupportedToken(address _token, uint256 _EURExchangeRate) public;
function claimTokenFunds(address tokenAddress) external;
function calculatePayrollBurnrate() public constant returns (uint256); // Monthly EUR amount spent in salaries
function calculatePayrollRunway(address _token) external constant returns (uint256); // Days until the contract can run out of funds based on each token
function blockPayments() external;
function allowPayments() external;
function setOracle(address _newOracleAddress) external;
function destroy() external;

function addEmployee(address _employeeAddress, uint256 _initialYearlyEURSalary) external;
function getEmployee(address _employeeAddress) external constant returns (
    uint256 _yearlyEURSalary,
    uint256 _totalReceivedEUR,
    address[] _allowedTokens);
function removeEmployee(address _employeeAddress) external;
function setEmployeeSalary(address _employeeAddress, uint256 _yearlyEURSalary) external;
function getEmployeeCount() external constant returns (uint256);
function getEmployeePayment(address _employeeAddress, address _token) external constant returns (
    uint256 _EURExchangeRate,
    uint _lastAllocationTime,
    uint _lastPaymentTime,
    uint256 _distributionMontlyAmount);
```

### Employee Functions
```solidity
function determineAllocation(address _token, uint256 _distributionMontlyAmount) external; // only callable once every 6 months
function payday(address _token) external; // only callable once a month and releases the funds according to distribution so employee can withdraw
```

### Oracle Functions
```solidity
function setExchangeRate(address _token, uint256 _newEURExchangeRate) external; // uses decimals from token
```

### Considerations
 - Instead of passing a list of tokens with an arbitrary size to calculate 
 the distribution or receive payments, it prevents problems with maximum block size with an array of arbitraty length;
 - The destroy function terminates the contract and returns the funds to the contract owner;
 - Implemented a very basic ERC20 EURT and USDT tokens without allowance in order to transfer token funds using
 a token contract. The EURT is the default token. More tokens can be easily added;
 - Assumed we can trust 100% in the oracle exchange rates; It can be improved later;
 - The contract relies on a default oracle address and default EURT address provided via constructor args;
 - Added fallback functions for token and ether;
 - The test accounts are available on `script/ganache-cli.sh` script which uses custom balances to 
 execute the truffle test `test/PayrollContractTest.js`.
