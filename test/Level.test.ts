import chai, { expect } from 'chai';
import asPromised from 'chai-as-promised';
import { JsonRpcProvider } from '@ethersproject/providers';
import { Blockchain } from '../utils/Blockchain';
import { generatedWallets } from '../utils/generatedWallets';
import { BaseErc20Factory } from '../typechain/BaseErc20Factory';
import { BaseErc721Factory } from '../typechain/BaseErc721Factory';
import { Level } from '../typechain/Level';
import { BaseErc20, BaseErc721 } from '../typechain';
import { BytesLike, BigNumber, Wallet } from 'ethers';
import { ethers } from 'ethers';
import { LevelFactory } from '../typechain/LevelFactory';
import { Erc721Mintable } from '../typechain/Erc721Mintable';
import { Erc721MintableFactory } from '../typechain/Erc721MintableFactory';
import { MaxUint256, AddressZero } from '@ethersproject/constants';
import { beforeEach } from 'mocha';

chai.use(asPromised);
let provider = new JsonRpcProvider();
let blockchain = new Blockchain(provider);

describe('Level Registrar 2', () => {
  let [deployerWallet, otherWallet] = generatedWallets(provider);
  let levelAddress: string;
  let sampleRoot: string;
  let sampleProof: string;
  let sampleProofBytes: BytesLike;

  async function deploy() {
    const levelRegistrar = await (
      await new LevelFactory(deployerWallet).deploy()
    ).deployed();
    levelAddress = levelRegistrar.address;
  }
  function createERC20() {
    return new BaseErc20Factory(deployerWallet).deploy(
      'Test Token',
      'TEST',
      18
    );
  }

  function createERC721(label: string, symbol: string) {
    return new Erc721MintableFactory(deployerWallet).deploy(label, symbol);
  }

  async function registrarAs(wallet: Wallet) {
    return LevelFactory.connect(levelAddress, wallet);
  }

  async function badgeAs(token: string, wallet: Wallet) {
    return Erc721MintableFactory.connect(token, wallet);
  }

  async function tokenAs(token: string, wallet: Wallet) {
    return BaseErc721Factory.connect(token, wallet);
  }

  describe('#constructor', () => {
    it('Should be able to deploy', async () => {
      await expect(deploy()).eventually.fulfilled;
    });
  });

  describe('#levels', () => {
    let levelRegistrarContract: Level;
    let erc20: BaseErc20;
    let noob, pro, proAlliance: Erc721Mintable;
    let noobContractMintable,
      proContractMintable,
      proAllianceContractMintable: Erc721Mintable;
    let noobContract, proContract, proAllianceContract: BaseErc721;
    let deployerWalletAddress: string;
    let otherWalletAddress: string;
    let hasLevel: boolean;

    beforeEach(async () => {
      await deploy();
      noob = await createERC721('Noob', 'NEWB'); //an nft contract
      pro = await createERC721('Pro', 'PRO'); //an nft contract
      proAlliance = await createERC721('Only Pros', 'GOPRO');
      levelRegistrarContract = await registrarAs(deployerWallet);
      noobContractMintable = await badgeAs(noob.address, deployerWallet);
      proContractMintable = await badgeAs(pro.address, deployerWallet);
      proAllianceContractMintable = await badgeAs(proAlliance.address, deployerWallet);
      await noobContractMintable.mint(deployerWallet.address, 1);
      await noobContractMintable.mint(deployerWallet.address, 2);
      await proContractMintable.mint(deployerWallet.address, 1);
      await proContractMintable.mint(deployerWallet.address, 2);
      await proAllianceContractMintable.mint(deployerWallet.address, 1);
      noobContract = await tokenAs(noob.address, deployerWallet);
      proContract = await tokenAs(pro.address, deployerWallet);
      proAllianceContract = await tokenAs(proAlliance.address, deployerWallet);
    });

    it('Can add badge', async () => {
      await levelRegistrarContract.createLevel(noob.address);
    });
    it('Can remove badge', async () => {
      await levelRegistrarContract.removeLevel(noob.address);
    });

    it('Cannot set level if badge not added / has been removed', async () => {
      await expect(
        levelRegistrarContract.setLevel(
          noobContract.address,
          1,
          otherWallet.address
        )
      ).rejectedWith('Badge is not added');
    });

    it('Cannot set level if badge is not approved', async () => {
      await levelRegistrarContract.createLevel(noobContract.address);
      await expect(
        levelRegistrarContract.setLevel(
          noobContract.address,
          1,
          otherWallet.address
        )
      ).rejectedWith('ERC721: transfer caller is not owner nor approved');
    });

    describe('#approve', () => {
      beforeEach(async () => {
        await noobContract.setApprovalForAll(
          levelRegistrarContract.address,
          true
        );
        let isApproved: boolean = await noobContract.isApprovedForAll(
          deployerWallet.address,
          levelRegistrarContract.address
        );
        await expect(isApproved, 'badge contract should be approved').to.be
          .true;
        let ownerOldBalance: BigNumber = await noobContract.balanceOf(
          deployerWallet.address
        );
        expect(ownerOldBalance.toNumber()).eq(2);
      });
      it('Can set level', async () => {
        await levelRegistrarContract.createLevel(noobContract.address);
        await levelRegistrarContract.setLevel(
          noobContract.address,
          1,
          otherWallet.address
        );
        let ownerNewBalance: BigNumber = await noobContract.balanceOf(
          deployerWallet.address
        );
        let receiverNewBalance: BigNumber = await noobContract.balanceOf(
          otherWallet.address
        );
        let contractNewBalance: BigNumber = await noobContract.balanceOf(
          levelRegistrarContract.address
        );
        let hasLevel: boolean = await levelRegistrarContract.hasLevel(
          noobContract.address,
          otherWallet.address
        );
        expect(ownerNewBalance.toNumber()).eq(1);
        expect(receiverNewBalance.toNumber()).eq(1);
        expect(contractNewBalance.toNumber()).eq(0);
        expect(hasLevel).to.be.true;
      });
      it('Can unset level', async () => {
        await levelRegistrarContract.createLevel(noobContract.address);
        await levelRegistrarContract.setLevel(
          noobContract.address,
          1,
          otherWallet.address
        );
        await levelRegistrarContract.unsetLevel(
          noobContract.address,
          otherWallet.address
        );
        let hasLevel: boolean = await levelRegistrarContract.hasLevel(
          noobContract.address,
          otherWallet.address
        );
        let receiverNewBalance: BigNumber = await noobContract.balanceOf(
          otherWallet.address
        );
        expect(receiverNewBalance.toNumber()).eq(1);
        expect(hasLevel).to.be.false;
      });

      it.only('Can add cross level', async () => {
        // parent contract
        await proAllianceContract.setApprovalForAll(
          levelRegistrarContract.address,
          true
        );
        await levelRegistrarContract.createLevel(proAllianceContract.address);
        await levelRegistrarContract.setLevel(
          proAllianceContract.address,
          1,
          otherWallet.address
        );
        //cross honor
        await levelRegistrarContract.addCrossLevel(
          proAllianceContract.address,
          proContract.address
        );
        let isCrossLevel: boolean = await levelRegistrarContract.isCrossLevel(
          proAllianceContract.address,
          proContract.address,
        )
        expect(isCrossLevel).to.be.true
        let ownerNewBalance: BigNumber = await proAllianceContract.balanceOf(
          deployerWallet.address
        );
        let receiverNewBalance: BigNumber = await proAllianceContract.balanceOf(
          otherWallet.address
        );
        let contractNewBalance: BigNumber = await proAllianceContract.balanceOf(
          levelRegistrarContract.address
        );
        let hasLevel: boolean = await levelRegistrarContract.hasLevel(
          proContract.address,
          otherWallet.address
        );
        expect(ownerNewBalance.toNumber()).eq(0);
        expect(receiverNewBalance.toNumber()).eq(1);
        expect(contractNewBalance.toNumber()).eq(0);
        expect(hasLevel).to.be.true
      });

    });
  });
});
