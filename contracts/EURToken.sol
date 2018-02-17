pragma solidity 0.4.19;

import "../node_modules/zeppelin-solidity/contracts/token/ERC20/BasicToken.sol";

contract EURToken is BasicToken {
    uint8 public decimals = 18;
    uint256 public totalSupply;
    string public name    = "Euro Token";
    string public symbol  = "EURT";

    function EURToken(uint256 _initialSupply) public {
        totalSupply = _initialSupply * 10 ** uint256(decimals);
        balances[msg.sender] = totalSupply;
    }

    /* @dev default fallback function to prevent from sending ether to the contract
     */
    function() external payable {revert();}
}