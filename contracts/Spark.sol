pragma solidity 0.4.15;

import 'zeppelin-solidity/contracts/token/MintableToken.sol';

contract Spark is MintableToken {
	string public name = "Spark";
  string public symbol = "USP";
  uint public totalSupply = 65280;
  uint public decimals = 18;
}
