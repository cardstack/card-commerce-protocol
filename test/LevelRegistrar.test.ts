import chai, { expect } from 'chai';
import asPromised from 'chai-as-promised';
import { BaseErc20Factory } from '../typechain/BaseErc20Factory';
import { LevelRegistrar } from '../typechain/LevelRegistrar';
import { BaseErc20, LevelRegistrarFactory } from '../typechain';
import { Wallet } from 'ethers';
import { ethers } from 'hardhat';

chai.use(asPromised);

type Level = {
  label: string;
  threshold: number;
};

type CrossLevel = {
  globalLevelLabel: string;
  recognisedLevelsByLabel: string[];
  setters: string[];
  tokens: string[];
};

describe('Level Registrar', () => {
  let deployerWallet, otherWallet;

  const defaultLevel: Level = {
    label: 'noob',
    threshold: 0,
  };

  const proLevel: Level = {
    label: 'pro',
    threshold: 100,
  };

  let defaultCrossLevel: CrossLevel;

  let levelRegistrarAddress: string;

  beforeEach(async function () {
    [deployerWallet, otherWallet] = await ethers.getSigners();
    defaultCrossLevel = {
      globalLevelLabel: 'Star alliance gold',
      recognisedLevelsByLabel: ['Air NZ premium', 'United Gold'],
      setters: [deployerWallet.address, otherWallet.address],
      tokens: [deployerWallet.address, otherWallet.address],
    };
  });

  async function deploy() {
    const levelRegistrar = await (
      await new LevelRegistrarFactory(deployerWallet).deploy()
    ).deployed();
    levelRegistrarAddress = levelRegistrar.address;
  }

  function createERC20() {
    return new BaseErc20Factory(deployerWallet).deploy(
      'Test Token',
      'TEST',
      18
    );
  }

  async function registrarAs(wallet: Wallet) {
    return LevelRegistrarFactory.connect(levelRegistrarAddress, wallet);
  }

  describe('#constructor', () => {
    it('should be able to deploy', async () => {
      await expect(deploy()).eventually.fulfilled;
    });
  });

  describe('#levels', () => {
    let levelRegistrarContract: LevelRegistrar;
    let erc20: BaseErc20;

    beforeEach(async () => {
      await deploy();
      levelRegistrarContract = await registrarAs(deployerWallet);
      erc20 = await createERC20();
    });

    it('should be able to set one level', async () => {
      await levelRegistrarContract.setLevels([defaultLevel], erc20.address);
    });

    it('should be able to set more than one level', async () => {
      await levelRegistrarContract.setLevels(
        [defaultLevel, proLevel],
        erc20.address
      );
    });

    it('should be able to get a set level', async () => {
      await levelRegistrarContract.setLevels([defaultLevel], erc20.address);
      const levelLength = await levelRegistrarContract.getLevelLength(
        deployerWallet.address,
        erc20.address
      );
      expect(levelLength.toNumber()).eq(
        1,
        'should be able to get the set level'
      );
    });

    it('should be able to get the level based on a balance', async () => {
      await levelRegistrarContract.setLevels([defaultLevel], erc20.address);
      const levelByBalance = await levelRegistrarContract.getLevelByBalance(
        deployerWallet.address,
        erc20.address,
        0
      );
      expect(levelByBalance.label).eq(
        'noob',
        '0 balance should be set to noob'
      );
    });

    it('should be able to get the required balance by label', async () => {
      await levelRegistrarContract.setLevels([defaultLevel], erc20.address);
      const balanceRequired = await levelRegistrarContract.getRequiredBalanceByLabel(
        deployerWallet.address,
        erc20.address,
        'noob'
      );
      expect(balanceRequired.toNumber()).eq(
        0,
        'required balance for noob should be 0'
      );
    });

    it('should be able to get the required balance by label', async () => {
      await levelRegistrarContract.setLevels([defaultLevel], erc20.address);
      const hasLabel = await levelRegistrarContract.getHasLevelByLabel(
        deployerWallet.address,
        erc20.address,
        'noob'
      );
      expect(hasLabel).eq(true, 'noob level should exist');
    });

    it('should have the level noob', async () => {
      await levelRegistrarContract.setLevels([defaultLevel], erc20.address);
      const hasLevel = await levelRegistrarContract.getHasLevel(
        deployerWallet.address,
        erc20.address,
        defaultLevel
      );
      expect(hasLevel).eq(true, 'should have the level noob');
    });

    it('should not have the level pro', async () => {
      const hasLevel = await levelRegistrarContract.getHasLevel(
        deployerWallet.address,
        erc20.address,
        proLevel
      );
      expect(hasLevel).eq(false, 'should not have the level pro');
    });

    it('should be able to get a users level', async () => {
      await levelRegistrarContract.setLevels([defaultLevel], erc20.address);
      const userLevel = await levelRegistrarContract.getUserLevel(
        deployerWallet.address,
        erc20.address,
        otherWallet.address
      );
      expect(userLevel.label).eq(
        'noob',
        'user with no balance should be a noob'
      );
    });

    it('users level should be pro and not noob', async () => {
      await levelRegistrarContract.setLevels(
        [defaultLevel, proLevel],
        erc20.address
      );
      await erc20.mint(otherWallet.address, 100);
      const userLevel = await levelRegistrarContract.getUserLevel(
        deployerWallet.address,
        erc20.address,
        otherWallet.address
      );
      expect(userLevel.label).to.not.eq('noob', 'user is not a noob');
      expect(userLevel.label).eq('pro', 'user should be a pro');
    });

    it('users level should be pro even though they exceed the threshold', async () => {
      await levelRegistrarContract.setLevels(
        [defaultLevel, proLevel],
        erc20.address
      );
      await erc20.mint(otherWallet.address, 1000);
      const userLevel = await levelRegistrarContract.getUserLevel(
        deployerWallet.address,
        erc20.address,
        otherWallet.address
      );
      expect(userLevel.label).eq(
        'pro',
        'user should be a pro, even with a higher than required balance'
      );
    });

    it('should not be able to find the noob level after the levels have been reset', async () => {
      await levelRegistrarContract.setLevels(
        [defaultLevel, proLevel],
        erc20.address
      );
      await levelRegistrarContract.setLevels([proLevel], erc20.address);
      const hasLevel = await levelRegistrarContract.getHasLevel(
        deployerWallet.address,
        erc20.address,
        defaultLevel
      );
      expect(hasLevel).eq(false, 'noob level should be erased');
    });
  });

  describe('#crossLevels', () => {
    let levelRegistrarContract: LevelRegistrar;

    beforeEach(async () => {
      await deploy();
      levelRegistrarContract = await registrarAs(deployerWallet);
      await createERC20();
    });

    it('Should be able set and get a cross level', async () => {
      await levelRegistrarContract.setCrossLevel([defaultCrossLevel]);
      const crossLevelLength = await levelRegistrarContract.getCrossLevelLength(
        deployerWallet.address
      );
      expect(crossLevelLength.toNumber()).eq(1);
    });
  });
});
