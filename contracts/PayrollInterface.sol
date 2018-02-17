pragma solidity 0.4.19;

// For the sake of simplicity lets assume EUR is a ERC20 token
// Also lets assume we can 100% trust the exchange rate oracle
interface PayrollInterface {

    function tokenFallback(address _from, uint256 _value, bytes data) public; // ERC223 tokenFallback

    /* OWNER ONLY */

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

    /* EMPLOYEE ONLY */
    function determineAllocation(address _token, uint256 _distributionMontlyAmount) external; // only callable once every 6 months
    function payday(address _token) external; // only callable once a month and releases the funds according to distribution so employee can withdraw

    /* ORACLE ONLY */
    function setExchangeRate(address _token, uint256 _newEURExchangeRate) external; // uses decimals from token
}