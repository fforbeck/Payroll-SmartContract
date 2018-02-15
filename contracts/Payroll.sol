pragma solidity 0.4.19;

import "./PayrollInterface.sol";
import "./EURToken.sol";

contract Payroll is PayrollInterface {

    struct Token {
        address id;
        uint256 exchangeRate;
        uint lastAllocationTime;
        uint lastPaymentTime;
        uint256 distributionPercent;
    }

    struct Employee {
        address id;
        uint256 yearlyEURSalary;
        uint256 totalReceivedEUR;
        address[] allowedTokens;
        mapping(address => uint256) allowedTokensMap;
        mapping(address => uint256) pendingWithdraws;
        mapping(address => Token) selectedTokens;
    }

    /* PAYROLL STATE */
    enum State {
        Allowed, Blocked
    }

    /* STATE VARIABLES */
    State public paymentsState;
    address public owner;
    address public oracle;
    uint256 public employeeCount;

    Token private tokenEUR;
    mapping(address => Token) private tokensMap;
    mapping(address => Employee) private employeesMap;
    uint256 private totalYearlyEURSalary;

    /* CONSTRUCTOR */
    function Payroll(address _defaultOracle, address _tokenEURAddress, uint256 _EURExchangeRate)
    public
    {
        owner = msg.sender;
        paymentsState = State.Allowed;
        oracle = _defaultOracle;
        tokenEUR = Token(_tokenEURAddress, _EURExchangeRate, 0, 0, 0);
        addSupportedToken(_tokenEURAddress, _EURExchangeRate);
    }

    /* EVENTS */
    event LogSupportedTokenAdded(uint _time, address _newToken, uint256 _exchangeRate);
    event LogEmployeeRemoved(address _employeeAddress);
    event LogEmployeeAdded(address _employeeAddress, uint256 _yearlyEURSalary, uint256 _totalYearlyEURSalary);
    event LogEmployeeSalaryUpdated(address indexed _employeeAddress, uint256 _oldYearlyEURSalary, uint256 _newYearlyEURSalary, uint256 _totalYearlyEURSalary);
    event LogTokenAllowed(uint _time, address _employeeAddress, address _token, uint256 _exchangeRate);
    event LogPaymentsAllowed(uint _time);
    event LogPaymentsBlocked(uint _time);
    event LogPaymentReceived(uint _time, address indexed _employeeAddress, address _tokenAddress, uint256 _tokenPayment);
    event LogExchangeRateUpdated(uint _time, address indexed _token, uint256 _oldRate, uint256 _newRate);
    event LogOracleUpdated(uint _time, address _oldOracle, address _newOracle);
    event LogTokenFundsAdded(uint _time, address _token, uint256 _value);
    event LogPaymentDistributionUpdated(uint _time, address indexed _employeeAddress, address _token, uint256 _totalDistributed);
    event LogDebug(uint _time, string data);


    /* ACCESS RULES */
    modifier onlyByOwner() {
        require(msg.sender == owner);
        _;
    }
    modifier onlyByEmployee() {
        require(exists(msg.sender));
        _;
    }
    modifier onlyByOracle() {
        require(msg.sender == oracle);
        _;
    }
    modifier onlyIfSupported(address _token) {
        require(supports(_token));
        _;
    }
    modifier onlyIfAllowed(address _token) {
        require(employeesMap[msg.sender].allowedTokensMap[_token] > 0);
        _;
    }
    modifier onlyPositive(uint256 _value) {
        require(_value > 0);
        _;
    }
    modifier onlyRegistered(address _employeeAddress) {
        require(exists(_employeeAddress));
        _;
    }
    modifier onlyNotRegistered(address _employeeAddress) {
        require(!exists(_employeeAddress));
        _;
    }
    modifier onlyIfPayments(State _state) {
        require(paymentsState == _state);
        _;
    }

    /** FALLBACK ONLY **/

    /* @dev default fallback function to prevent from sending ether to the contract
     * @dev the contract works only with allowed tokens
     */
    function() external payable {revert();}

    /* @dev ERC223 token fallback function, rejects if token not supported */
    function tokenFallback(address _from, uint256 _value, bytes _data)
    public
    onlyIfSupported(_from)
    {
        LogTokenFundsAdded(getTime(), _from, _value);
    }


    /* OWNER ONLY */

    /* @dev Adds a supported token and exchange rates into the payroll */
    function addSupportedToken(address _token, uint256 _exchangeRate)
    public
    onlyByOwner
    {
        require(tokenNotExists(_token) && _exchangeRate > 0);
        tokensMap[_token] = Token(_token, _exchangeRate, 0, 0, 0);
        LogSupportedTokenAdded(getTime(), tokensMap[_token].id, tokensMap[_token].exchangeRate);
    }

    /* @dev returns ERC20 tokens to contract owner */
    function claimTokenFunds(address tokenAddress)
    external
    onlyByOwner {
        ERC20Basic token = ERC20Basic(tokenAddress);
        require(token.transfer(owner, token.balanceOf(this)));
    }

    /* @dev Calculates the monthly EUR amount spent in salaries */
    function calculatePayrollBurnrate()
    public
    constant
    onlyByOwner
    returns (uint256)
    {
        return totalYearlyEURSalary / 12;
    }

    /* @dev Calculates the days until the contract can run out of funds for the provided token */
    function calculatePayrollRunway(address _token)
    external
    constant
    onlyByOwner
    onlyIfSupported(_token)
    returns (uint256)
    {
        return (ERC20Basic(_token).balanceOf(this) / tokensMap[_token].exchangeRate) / calculatePayrollBurnrate();
    }

    /* @dev Changes the contract state to Blocked, so employees won't able to receive payments */
    function blockPayments()
    external
    onlyByOwner
    {
        paymentsState = State.Blocked;
        LogPaymentsBlocked(getTime());
    }

    /* @dev Changes the contract state to Allowed, so employees are able to receive payments */
    function allowPayments()
    external
    onlyByOwner
    {
        paymentsState = State.Allowed;
        LogPaymentsAllowed(getTime());
    }

    function setOracle(address _newOracleAddress)
    external
    onlyByOwner
    {
        require(oracle != _newOracleAddress);
        address oldOracle = oracle;
        oracle = _newOracleAddress;
        LogOracleUpdated(getTime(), oldOracle, oracle);
    }

    /* @dev Destroys the current contract with selfdestruct call and
     * @dev sends remaining funds to the contract owner */
    function destroy()
    external
    onlyByOwner
    {
        selfdestruct(owner);
        //sends remaining funds back to owner of the contract
    }

    /* @dev Adds an employee into the payroll if it is not already registered and has valid tokens and salary */
    function addEmployee(address _employeeAddress, uint256 _initialYearlyEURSalary)
    external
    onlyByOwner
    onlyNotRegistered(_employeeAddress)
    onlyPositive(_initialYearlyEURSalary)
    {
        employeeCount++;
        totalYearlyEURSalary = totalYearlyEURSalary + _initialYearlyEURSalary;
        employeesMap[_employeeAddress] = Employee(_employeeAddress, _initialYearlyEURSalary, 0, new address[](0));
        LogEmployeeAdded(_employeeAddress, _initialYearlyEURSalary, totalYearlyEURSalary);
    }

    /* @dev Gets the employee data if the employee is registered in the payroll */
    function getEmployee(address _employeeAddress)
    external constant
    onlyByOwner
    onlyRegistered(_employeeAddress)
    returns (
        uint256 _yearlyEURSalary,
        uint256 _totalReceivedEUR,
        address[] _allowedTokens)
    {
        Employee memory employee = employeesMap[_employeeAddress];
        return (employee.yearlyEURSalary,
        employee.totalReceivedEUR,
        employee.allowedTokens);
    }

    /* @dev Removes the employee from the payroll if it is registered in the payroll */
    function removeEmployee(address _employeeAddress)
    external
    onlyByOwner
    onlyRegistered(_employeeAddress)
    {
        employeeCount = employeeCount - 1;
        totalYearlyEURSalary = totalYearlyEURSalary - employeesMap[_employeeAddress].yearlyEURSalary;
        delete employeesMap[_employeeAddress];
        LogEmployeeRemoved(_employeeAddress);
    }

    /* @dev Updated the employee annual salary if it is registered in the payroll */
    function setEmployeeSalary(address _employeeAddress, uint256 _newYearlyEURSalary)
    external
    onlyByOwner
    onlyRegistered(_employeeAddress)
    onlyPositive(_newYearlyEURSalary)
    {
        uint256 oldSalary = employeesMap[_employeeAddress].yearlyEURSalary;
        totalYearlyEURSalary = totalYearlyEURSalary - oldSalary + _newYearlyEURSalary;
        employeesMap[_employeeAddress].yearlyEURSalary = _newYearlyEURSalary;
        LogEmployeeSalaryUpdated(_employeeAddress, oldSalary, _newYearlyEURSalary, totalYearlyEURSalary);
    }

    /* @dev Gets the total number of employees registered in the payroll */
    function getEmployeeCount()
    external constant
    onlyByOwner
    returns (uint256)
    {
        return employeeCount;
    }

    /* @dev Gets the employee payment details based on token */
    function getEmployeePayment(address _employeeAddress, address _token)
    external
    constant
    onlyByOwner
    onlyRegistered(_employeeAddress)
    onlyIfSupported(_token)
    returns (
        uint256 _exchangeRate,
        uint _lastAllocationTime,
        uint _lastPaymentTime,
        uint256 _distributionPercent)
    {
        Token memory token = employeesMap[_employeeAddress].selectedTokens[_token];
        require(token.id != address(0x0));

        return (token.exchangeRate,
        token.lastAllocationTime,
        token.lastPaymentTime,
        token.distributionPercent);
    }

    /* @dev Allows a given token for a given employee */
    function allowToken(address _employeeAddress, address _token, uint256 _exchangeRate)
    external
    onlyByOwner
    onlyRegistered(_employeeAddress)
    onlyIfSupported(_token)
    onlyPositive(_exchangeRate)
    {
         Employee storage employee = employeesMap[_employeeAddress];
         tokensMap[_token] = Token(_token, _exchangeRate, 0, 0, 0);
         employee.selectedTokens[_token] = tokensMap[_token];

        if (employee.allowedTokens.length == 0) {
            employee.allowedTokens = new address[](0);
        }

        employee.allowedTokens.push(_token);
        employee.allowedTokensMap[_token] = 1;

        LogTokenAllowed(getTime(), _employeeAddress, _token, _exchangeRate);
    }

    /* EMPLOYEE ONLY */

    /* @dev Allows employees to set their tokens distribution for payments */
    function determineAllocation(address _token, uint256 _distributionPercent)
    external
    onlyByEmployee
    onlyIfPayments(State.Allowed)
    onlyIfAllowed(_token)
    {
        require(_distributionPercent >= 0 && _distributionPercent <= 100);

        Employee storage employee = employeesMap[msg.sender];
        Token storage token = employee.selectedTokens[_token];
        require(getTime() - 6 * 4 weeks > token.lastAllocationTime);

        token.distributionPercent = _distributionPercent;
        token.lastAllocationTime = getTime();

        assert(calculateTokenDistribution(employee.id) == 100);

        LogPaymentDistributionUpdated(getTime(), employee.id, token.id, token.distributionPercent);
    }

    /* @dev  Allows the employee to release the funds once a month*/
    function payday(address _token)
    external
    onlyByEmployee
    onlyIfPayments(State.Allowed)
    onlyIfAllowed(_token)
    {
        Employee storage employee = employeesMap[msg.sender];
        Token storage token = employee.selectedTokens[_token];
        require(getTime() - 1 * 4 weeks > token.lastPaymentTime);

        uint256 distributedEURSalary = (employee.yearlyEURSalary / 12) * (token.distributionPercent / 100);
        uint256 tokenSalary = distributedEURSalary / token.exchangeRate;
        uint256 tokenFunds = ERC20Basic(_token).balanceOf(this);
        require(tokenSalary <  tokenFunds);

        employee.pendingWithdraws[token.id] = tokenSalary;
        token.lastPaymentTime = getTime();

        employeesMap[msg.sender] = employee;

        LogPaymentReceived(getTime(), msg.sender, _token, tokenSalary);

        require(ERC20Basic(_token).transfer(msg.sender, tokenSalary));

    }

    /* ORACLE ONLY */

    /* @dev Updates the token exchange rates if supported and assumes we can trust 100% in the Oracle exchange rates */
    function setExchangeRate(address _token, uint256 _newExchangeRate)
    external
    onlyByOracle
    onlyIfSupported(_token)
    {
        //Updates the default EUR token
        if (_token == tokenEUR.id) {
            tokenEUR.exchangeRate = _newExchangeRate;
        }
        //Updates the token in the supported tokens map
        Token storage token = tokensMap[_token];
        uint256 oldRate = token.exchangeRate;
        token.exchangeRate = _newExchangeRate;
        LogExchangeRateUpdated(getTime(), _token, oldRate, token.exchangeRate);
    }

    /* HELPERS */

    /* @dev Checks if the employee is registered in the payroll */
    function exists(address _employeeAddress)
    internal
    constant
    returns (bool)
    {
        return employeesMap[_employeeAddress].id != address(0x0);
    }

    /* @dev Checks if the token is accepted according to the payroll available tokens */
    function supports(address _token)
    internal
    constant
    returns (bool)
    {
        return tokensMap[_token].id != address(0x0);
    }

    function tokenNotExists(address _token)
    internal
    constant
    returns (bool)
    {
        return tokensMap[_token].id == address(0x0);
    }

    function getTime()
    internal
    constant
    returns (uint)
    {
        return now;
    }

    function calculateTokenDistribution(address _employeeAddress)
    internal
    constant
    returns (uint256)
    {
        Employee storage employee = employeesMap[msg.sender];
        uint256 total = 0;
        address[] storage tokenList = employee.allowedTokens;
        for (uint i = 0; i < tokenList.length; i++) {
            total += employee.selectedTokens[tokenList[i]].distributionPercent;
        }
        return total;
    }
}
