// an urbit star pool
// untested draft

pragma solidity 0.4.15;

import 'zeppelin-solidity/contracts/token/MintableToken.sol';
import 'zeppelin-solidity/contracts/token/BurnableToken.sol';

import './Constitution.sol';

contract Pool is MintableToken, BurnableToken
{
  // token details
  string constant public name = "StarToken";
  string constant public symbol = "STA";
  uint constant public decimals = 18;
  uint256 constant public oneStar = 1e18;

  // store reference to the ship contract, because it is constant.
  // the current constitution is always ships.owner.
  Ships public ships;

  // could keep track of assets for public viewing.
  // this isn't a necessity for logic because the constitution already performs
  // all ownership checks for us.
  //uint16[] public assets;

  function Pool(Ships _ships)
  {
    ships = _ships;
  }

  // give one latent star to the pool.
  // this contract's address must be set as a launcher for the star's parent.
  function deposit(uint16 _star)
    external
    isStar(_star)
  {
    // only a star's parent may deposit it.
    require(ships.isPilot(ships.getOriginalParent(_star), msg.sender));
    // attempt to grant the star to us.
    Constitution(ships.owner()).launch(_star, this, 0);
    // we succeeded, so grant the sender their token.
    mint(msg.sender, oneStar);
  }

  // take one star from the pool.
  // this contract's address must have a StarToken allowance of at least oneStar
  function withdraw(uint16 _star)
    external
    isStar(_star)
  {
    // attempt to take one token from them.
    // we use this.call for token operations so that msg.sender gets set
    // to us. token operations won't complete correctly otherwise.
    this.call.gas(50000)(bytes4(sha3("transferFrom(address,address,uint256)")), msg.sender, this, oneStar);
    // attempt to transfer the sender their star.
    Constitution(ships.owner()).transferShip(_star, msg.sender, true);
    // we own one less star, so burn one token.
    this.call.gas(50000)(bytes4(sha3("burn(uint256)")), oneStar);
  }

  // test if the ship is, in fact, a star.
  modifier isStar(uint16 _star)
  {
    require(_star > 255);
    _;
  }
}
