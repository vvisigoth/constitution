// an urbit star pool
// draft

pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/token/MintableToken.sol';
import 'zeppelin-solidity/contracts/token/BurnableToken.sol';

import './Constitution.sol';

// we use this.call for certain operations so that msg.sender gets set to us.
// they operations won't run correctly otherwise.

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
    // needs to be its own owner so that it can mint.
    // this pool design is completely hands-off after launching, so the contract
    // creator doesn't need special permissions anyway.
    owner = this;
  }

  // give one star to the pool.
  // either of the following requirements must be fulfilled:
  // 1. the star must be unlocked, the sender the owner of the star, and this
  //    pool configured as the transferrer for that star.
  // 2. the star must be latent, the sender the owner of its parent galaxy, and
  //    this pool configured as a launcher for that galaxy.
  function deposit(uint16 _star)
    external
    isStar(_star)
  {
    // there are two possible ways to deposit a star:
    // 1: for locked stars, grant the pool permission to transfer ownership of
    //    that star. the pool will transfer the deposited star to itself.
    if (ships.isPilot(_star, msg.sender)
             && ships.isTransferrer(_star, this))
    {
      // only accept stars that aren't alive, that are reputationless, "clean".
      require(!ships.isState(_star, Ships.State.Living));
      // attempt to transfer the star to us.
      Constitution(ships.owner()).transferShip(_star, this, true);
    }
    // 2: for latent stars, grant the pool launch permission on a galaxy.
    //    the pool will launch the deposited star directly to itself.
    else if (ships.isPilot(ships.getOriginalParent(_star), msg.sender)
        && ships.isLauncher(ships.getOriginalParent(_star), this))
    {
      // attempt to launch the star to us.
      Constitution(ships.owner()).launch(_star, this, 0);
    }
    // if neither of those are possible, error out.
    else
    {
      revert();
    }
    // we succeeded, so grant the sender their token.
    this.call.gas(50000)(bytes4(sha3("mint(address,uint256)")), msg.sender, oneStar);
  }

  // take one star from the pool.
  function withdraw(uint16 _star)
    external
    isStar(_star)
  {
    // attempt to transfer the sender their star.
    Constitution(ships.owner()).transferShip(_star, msg.sender, true);
    // we own one less star, so burn one token.
    burn(oneStar);
  }

  // test if the ship is, in fact, a star.
  modifier isStar(uint16 _star)
  {
    require(_star > 255);
    _;
  }
}
