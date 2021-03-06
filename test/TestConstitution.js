const Ships = artifacts.require('../contracts/Ships.sol');
const Votes = artifacts.require('../contracts/Votes.sol');
const Constitution = artifacts.require('../contracts/Constitution.sol');

contract('Constitution', function([owner, user1, user2]) {
  let ships, votes, constit;
  const LATENT = 0;
  const LOCKED = 1;
  const LIVING = 2;

  function assertJump(error) {
    assert.isAbove(error.message.search('revert'), -1, 'Revert must be returned, but got ' + error);
  }

  // because setTimeout doesn't work.
  function busywait(ms) {
    var start = Date.now();
    while (true) {
      if ((Date.now() - start) > ms) break;
    }
  }

  before('setting up for tests', async function() {
    ships = await Ships.new();
    votes = await Votes.new();
    constit = await Constitution.new(ships.address, votes.address);
    await ships.transferOwnership(constit.address);
    await votes.transferOwnership(constit.address);
  });

  it('creating galaxies', async function() {
    let time = Math.floor(Date.now() / 1000);
    // create, but unlocks in the future.
    //NOTE tweak time+1000 to be a bit higher if the first try in starting ships
    //     fails for you.
    await constit.createGalaxy(0, user1, time+10, time+1000);
    assert.isTrue(await ships.isState(0, LOCKED));
    assert.equal(await ships.getLocked(0), time+10);
    assert.isTrue(await ships.isPilot(0, user1));
    // can't create twice.
    try {
      await constit.createGalaxy(0, owner, 0, 0);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // non-owner can't create.
    try {
      await constit.createGalaxy(1, user1, 0, 0, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // prep for next tests.
    await constit.createGalaxy(1, user1, 0, 0);
    await constit.createGalaxy(2, user1, 0, 0);
  });

  it('starting ships', async function() {
    // can't start until unlocked.
    //NOTE if this unexpectedly fails for you, see the note above.
    try {
      await constit.start(0, 10, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // wait until we can start.
    busywait(10000);
    // can't start if not pilot.
    try {
      await constit.start(0, 10, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await constit.start(0, 10, {from:user1});
    let [key, rev] = await ships.getKey(0);
    assert.equal(key,
      '0xa000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(rev, 1);
    assert.equal(await votes.totalVoters(), 1);
  });

  it('launching ships', async function() {
    // can't start if not parent owner.
    try {
      await constit.launch(256, user1, 123, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // can't start if parent not living.
    try {
      await constit.launch(257, user1, 123, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // should be able to launch one right away.
    await constit.launch(256, user1, 123, {from:user1});
    assert.isTrue(await ships.isPilot(256, user1));
    assert.isTrue(await ships.isState(256, LOCKED));
    assert.equal(await ships.getLocked(256), 123);
    // must wait to launch more.
    try {
      await constit.launch(512, user1, 0, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // wait until we can launch again.
    while (!await constit.canSpawn(0, Math.floor(Date.now() / 1000)))
      busywait(3000);
    await constit.launch(512, user1, 0, {from:user1});
    // can't launch same ship twice.
    try {
      await constit.launch(512, user1, 0, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
  });

  it('granting and revoking launch rights', async function() {
    // should not be launcher by default.
    assert.isFalse(await ships.isLauncher(0, user2));
    // can't do if not owner.
    try {
      await constit.grantLaunchRights(0, user2, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // set up for working launch.
    await constit.grantLaunchRights(0, user2, {from:user1});
    assert.isTrue(await ships.isLauncher(0, user2));
    while (!await constit.canSpawn(0, Math.floor(Date.now() / 1000)))
      busywait(3000);
    // launch as launcher, then test revoking of rights.
    await constit.launch(768, user1, 0, {from:user2});
    await constit.revokeLaunchRights(0, user2, {from:user1});
    assert.isFalse(await ships.isLauncher(0, user2));
  });

  it('transfering ownership', async function() {
    // can't do if not owner.
    try {
      await constit.transferShip(0, user2, true, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // transfer as owner.
    await constit.transferShip(0, user2, true, {from:user1});
    assert.isTrue(await ships.isPilot(0, user2));
    let [key, rev] = await ships.getKey(0);
    assert.equal(key,
      '0x0000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(rev, 2);
  });

  it('allowing transfer of ownership', async function() {
    // can't do if not owner.
    try {
      await constit.allowTransferBy(0, user1, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // allow as owner.
    await constit.allowTransferBy(0, user1, {from:user2});
    assert.isTrue(await ships.isTransferrer(0, user1));
    // transfer as transferrer.
    await constit.transferShip(0, user1, false, {from:user1});
    assert.isTrue(await ships.isPilot(0, user1));
    assert.isFalse(await ships.isTransferrer(0, user1));
  });

  it('rekeying a ship', async function() {
    // can't do if not owner.
    try {
      await constit.rekey(0, 9, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // rekey as owner.
    await constit.rekey(0, 9, {from:user1});
    let [key, rev] = await ships.getKey(0);
    assert.equal(key,
      '0x9000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(rev, 3);
  });

  it('setting an escape', async function() {
    // can't if chosen parent not living.
    try {
      await constit.escape(256, 1, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await constit.start(1, 0, {from:user1});
    // can't if not owner of ship.
    try {
      await constit.escape(256, 1, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // set escape as owner.
    await constit.escape(256, 1, {from:user1});
    assert.isTrue(await ships.isEscape(256, 1));
    await constit.escape(512, 1, {from:user1});
  });

  it('adopting or reject an escaping ship', async function() {
    // can't if not owner of parent.
    try {
      await constit.adopt(1, 256, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    try {
      await constit.reject(1, 512, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // can't if target is not escaping to parent.
    try {
      await constit.adopt(1, 258, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    try {
      await constit.reject(1, 258, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // adopt as parent owner.
    await constit.adopt(1, 256, {from:user1});
    assert.isFalse(await ships.isEscape(256, 1));
    assert.equal(await ships.getParent(256), 1);
    // reject as parent owner.
    await constit.reject(1, 512, {from:user1});
    assert.isFalse(await ships.isEscape(512, 1));
    assert.equal(await ships.getParent(512), 0);
  });

  it('casting an abstract vote', async function() {
    // can't if not galaxy owner.
    try {
      await constit.castAbstractVote(0, 10, true, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // can't if galaxy not living.
    try {
      await constit.castAbstractVote(2, 10, true, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await constit.castAbstractVote(0, 10, true, {from:user1});
    assert.equal(await votes.abstractVoteCounts(10), 1);
    await constit.castAbstractVote(0, 10, false, {from:user1});
    assert.equal(await votes.abstractVoteCounts(10), 0);
  });

  it('casting a concrete vote', async function() {
    let consti2 = await Constitution.new(ships.address, votes.address);
    // can't if not galaxy owner.
    try {
      await constit.castConcreteVote(0, consti2.address, true, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // can't if galaxy not living.
    try {
      await constit.castConcreteVote(2, consti2.address, true, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await constit.castConcreteVote(0, consti2.address, true, {from:user1});
    assert.equal(
        await votes.concreteVoteCounts(constit.address, consti2.address),
        1);
    await constit.castConcreteVote(0, consti2.address, false, {from:user1});
    assert.equal(
        await votes.concreteVoteCounts(constit.address, consti2.address),
        0);
    await constit.castConcreteVote(0, consti2.address, true, {from:user1});
    await constit.castConcreteVote(1, consti2.address, true, {from:user1});
    assert.equal(await ships.owner(), consti2.address);
    assert.equal(await votes.owner(), consti2.address);
  });
});
