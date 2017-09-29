pragma solidity 0.4.15;

import 'zeppelin-solidity/contracts/token/MintableToken.sol';
import 'zeppelin-solidity/contracts/token/BurnableToken.sol';

contract Spark is MintableToken, BurnableToken {
	string public name = "Spark";
  string public symbol = "USP";
  uint public decimals = 18;
}
