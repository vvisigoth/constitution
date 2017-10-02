// default spark auction
// untested draft

pragma solidity 0.4.15;

/**
 * Based off original PoC by Nick Johnson.
 * https://gist.github.com/Arachnid/b9886ef91d5b47c31d2e3c8022eeea27
 *
 * Implements a capped token sale using a second-price auction.
 *
 * Users can deposits funds for the auction any time before endTimestamp. After
 * doing so, they send a signed message to the party running the auction with a
 * bid.
 * Bids are `(price, quantity)` tuples, where `price` is the maximum amount of
 * ether a user is willing to pay per token, and `quantity` is the number of
 * tokens the user wants to buy.
 *
 * At the end of the bidding period, the seller sets a 'strike price'. All bids
 * with a price at least as high as the strike price are filled, and all bids
 * under this strike price are returned. The strike price is calculated
 * offchain by the seller. Once set, anyone - bidder, seller, or third party -
 * can submit the signed bid to the contract, which will issue tokens to winning
 * bidders.
 *
 * A hard cap on the amount of ether raised is specified at the time the
 * contract is deployed, with extra funds being returned to users.
 *
 * A week after the end of the contract, users can unilaterally withdraw any
 * remaining funds.
 */

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/token/StandardToken.sol';

contract SparkAuction is Ownable
{
  using SafeMath for uint256;

  event Deposit(address indexed bidder, uint256 price);
  event StrikePriceSet(uint256 strikePrice);

  mapping(address => bool) public whitelist;

  mapping(address => uint256) public deposits;
  uint256 public depositCount;                 // number of yet unaccepted bids.

  StandardToken public spark;
  uint256 public salesTarget;                  // remaining wei to be raised.
  uint256 public endTimestamp;                 // sale end time.
  uint256 public strikePrice;                  // wei per token. set post-sale.
  uint256 public strikePricePct;               // % of tokens won by exact bids.

  function SparkAuction(StandardToken _spark, uint256 _salesTarget,
                        uint256 _endTimestamp)
  {
    spark = _spark; //TODO hardcode?
    salesTarget = _salesTarget;
    endTimestamp = _endTimestamp;
  }

  function deposit()
    public
    payable
    beforeSale
    whitelisted(msg.sender)
  {
    deposits[msg.sender] = deposits[msg.sender] + msg.value;
    depositCount = depositCount + 1;
    Deposit(msg.sender, msg.value);
  }

  // forward fallback function to deposit.
  function()
    payable
  {
    deposit();
  }

  function addToWhitelist(address _address)
    external
    onlyOwner
    beforeSale
  {
    whitelist[_address] = true;
  }

  function removeFromWhitelist(address _address)
    external
    onlyOwner
    beforeSale
  {
    whitelist[_address] = false;
  }

  function setStrikePrice(uint256 _price, uint256 _pct)
    external
    onlyOwner
  {
    require(endTimestamp <= block.timestamp && strikePrice == 0 && _price != 0);
    strikePrice = _price;
    strikePricePct = _pct;
    StrikePriceSet(_price);
  }

  function acceptBid(uint256 _price, uint256 _quantity, uint8 _v, bytes32 _r,
                     bytes32 _s)
    external
    afterSale
  {
    uint256 sparksLeft = spark.balanceOf(this);
    bytes32 bidHash = sha3(address(this), _price, _quantity);
    address bidder = ecrecover(bidHash, _v, _r, _s);
    uint256 total = _price.mul(_quantity);
    require(total <= deposits[bidder]);

    uint256 fillQuantity = _quantity;

    // bid under strike price: no sparks.
    if (_price < strikePrice)
    {
      fillQuantity = 0;
    }
    // bid at exactly strike price: partially fill the bid.
    else if (_price == strikePrice)
    {
      fillQuantity = fillQuantity.mul(strikePricePct).div(100);
    }

    // not enough sparks left: give remaining.
    if (sparksLeft < fillQuantity)
    {
      fillQuantity = sparksLeft;
    }

    // for the determined quanitity of tokens, calculate the eth to pay.
    uint256 fillCost = strikePrice.mul(fillQuantity);
    // not enough funds under sale cap: sell remainder.
    if (fillCost > salesTarget)
    {
      fillQuantity = salesTarget.div(strikePrice);
      fillCost = strikePrice.mul(fillQuantity);
    }

    // if bid has been filled, send sparks.
    if (fillCost > 0)
    {
      owner.transfer(fillCost);
      salesTarget = salesTarget - fillCost;
      sparksLeft = sparksLeft - fillQuantity;
    }
    // extra funds: send them back.
    if (deposits[bidder] > fillCost)
    {
      uint256 extra = deposits[bidder] - fillCost;
      deposits[bidder] = 0;
      bidder.transfer(extra);
    }

    depositCount = depositCount - 1;
    spark.transfer(bidder, fillQuantity);
  }

  function withdrawEther()
    external
    afterTimeout
  {
    uint256 total = deposits[msg.sender];
    deposits[msg.sender] = 0;
    msg.sender.transfer(total);
  }

  modifier whitelisted(address _address)
  {
    require(whitelist[_address]);
    _;
  }

  modifier beforeSale
  {
    require(block.timestamp <= endTimestamp);
    _;
  }

  modifier afterSale
  {
    require(endTimestamp <= block.timestamp && strikePrice != 0);
    _;
  }

  modifier afterTimeout
  {
    require(endTimestamp + 1 weeks <= block.timestamp);
    _;
  }
}
