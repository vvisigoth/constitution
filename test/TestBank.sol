pragma solidity ^0.4.15;

import "truffle/Assert.sol";

import '../contracts/Bank.sol';

contract TestBank
{
  Ships ships;
  Constitution const;
  Bank bank;

  function beforeAll()
  {
    ships = new Ships();
    Votes v = new Votes();
    const = new Constitution(ships, v);
    ships.transferOwnership(const);
    v.transferOwnership(const);
    const.createGalaxy(0, this, 0, 0);
    const.start(0, 123);
    bank = new Bank(ships);
    const.grantLaunchRights(0, bank);
  }

  function testDeposit()
  {
    bank.deposit(256);
    Assert.isTrue(ships.isPilot(256, address(bank)),
      "should have been launched to bank");
    Assert.equal(bank.balanceOf(this), bank.oneStar(),
      "should have granted a token");
  }

  function testWithdraw()
  {
    bank.approve(address(bank), bank.oneStar());
    Assert.equal(bank.allowance(this, address(bank)), bank.oneStar(),
      "should have given allowance");
    bank.withdraw(256);
    Assert.isTrue(ships.isPilot(256, this),
      "should have transfered star");
    Assert.equal(bank.balanceOf(this), uint256(0),
      "should have taken a token");
  }
}
