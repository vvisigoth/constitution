const Ships = artifacts.require('../contracts/Ships.sol');
const Votes = artifacts.require('../contracts/Votes.sol');
const Constitution = artifacts.require('../contracts/Constitution.sol');
const Pool = artifacts.require('../contracts/Pool.sol');

contract('Pool', function([owner, user1, user2]) {
  let ships, votes, constit, pool;
  const LATENT = 0;
  const LOCKED = 1;
  const LIVING = 2;

  function assertJump(error) {
    assert.isAbove(error.message.search('revert'), -1, 'Revert must be returned, but got ' + error);
  }

  before('setting up for tests', async function() {
    ships = await Ships.new();
    votes = await Votes.new();
    constit = await Constitution.new(ships.address, votes.address);
    await ships.transferOwnership(constit.address);
    await votes.transferOwnership(constit.address);
    await constit.createGalaxy(0, user1, 0, 0);
    await constit.start(0, 10, {from:user1});
    await constit.launch(512, user2, 0, {from:user1});
    pool = await Pool.new(ships.address);
  });

  it('deposit star as galaxy owner', async function() {
    // must only accept stars.
    try {
      await pool.deposit(0, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // must fail if no launch rights.
    try {
      await pool.deposit(256, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await constit.grantLaunchRights(0, pool.address, {from:user1});
    // must fail if caller is not galaxy owner.
    try {
      await pool.deposit(256);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // deposit as galaxy owner.
    await pool.deposit(256, {from:user1});
    assert.isTrue(await ships.isPilot(256, pool.address));
    assert.equal(await pool.balanceOf(user1), 1000000000000000000);
  });

  it('deposit star as star owner', async function() {
    // can't deposit if not transferrer.
    try {
      await pool.deposit(512, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await constit.allowTransferBy(512, pool.address, {from:user2});
    // can't deposit if not owner.
    try {
      await pool.deposit(512, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // deposit as star owner.
    await pool.deposit(512, {from:user2});
    assert.isTrue(await ships.isPilot(512, pool.address));
    assert.equal(await pool.balanceOf(user2), 1000000000000000000);
  });

  it('withdraw a star', async function() {
    // can't withdraw a non-pooled star.
    try {
      await pool.withdraw(257, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // withdraw a star
    await pool.withdraw(256, {from:user1});
    assert.isTrue(await ships.isPilot(256, user1));
    assert.equal((await pool.balanceOf(user1)), 0);
    // can't withdraw without balance.
    try {
      await pool.withdraw(512, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
  });
});
