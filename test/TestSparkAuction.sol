pragma solidity ^0.4.15;

import "truffle/Assert.sol";

import '../contracts/Spark.sol';
import '../contracts/SparkAuction.sol';

contract TestSparkAuction
{
  uint public initialBalance = 1 ether;

  Spark spark;
  SparkAuction auction;
  uint256 saleEnd;

  function beforeAll()
  {
    spark = new Spark();
    saleEnd = block.timestamp + 1 days;
    auction = new SparkAuction(spark, 100, saleEnd);
  }

  function testBeforeSale()
  {
    auction.deposit.value(60)();
    Assert.equal(auction.depositCount(), uint256(1),
      "should have added deposit");
    Assert.equal(auction.deposits(this), 60,
      "should have added deposit value");
  }

  function testIncomplete()
  {
    Assert.isTrue(false, "tests are very incomplete");
  }
}
