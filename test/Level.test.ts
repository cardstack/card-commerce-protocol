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
import { randomBytes } from 'ethers/lib/utils';
import { ethers } from 'ethers';
import { LevelFactory } from '../typechain/LevelFactory';
import { Erc721Mintable } from '../typechain/Erc721Mintable';
import { Erc721MintableFactory } from '../typechain/Erc721MintableFactory';
import { MaxUint256, AddressZero } from '@ethersproject/constants';

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
  sampleRoot =
    '0x1db9340101379dc2dfc7cc11f178e9b02489d10700ea911dffa7adf45ebef56f';

  sampleProof =
    '0x00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000008AC7230489E8000066acfc5050b10b37812fc2a5902d9ba6ba8e0b057e8524b6de86e9da28b03b59b2eeddc38a59a9c5d0f5cd72d18afbb864da3e3d1b6ceb520c42d9be7206f7ab74cba4ec1e5de6222071c2237d42c316c664ec4dbd3fc8d195de6419e96ca2f5';
  sampleProofBytes = randomBytes(8);

  describe('#constructor', () => {
    it('should be able to deploy', async () => {
      await expect(deploy()).eventually.fulfilled;
    });
  });

  describe('#levels', () => {
    let levelRegistrarContract: Level;
    let erc20: BaseErc20;
    let noob, pro: Erc721Mintable;
    let noobContractMintable, proContractMintable: Erc721Mintable;
    let noobContract, proContract: BaseErc721;
    let deployerWalletAddress: string;
    let otherWalletAddress: string;
    let hasLevel: boolean;

    beforeEach(async () => {
      await deploy();
      noob = await createERC721('Noob', 'NEWB'); //an nft contract
      pro = await createERC721('Pro', 'PRO'); //an nft contract
      levelRegistrarContract = await registrarAs(deployerWallet);
      noobContractMintable = await badgeAs(noob.address, deployerWallet);
      proContractMintable = await badgeAs(pro.address, deployerWallet);
      await noobContractMintable.mint(deployerWallet.address, 1);
      await noobContractMintable.mint(deployerWallet.address, 2);
      await proContractMintable.mint(deployerWallet.address, 1);
      await proContractMintable.mint(deployerWallet.address, 2);
      noobContract = await tokenAs(noob.address, deployerWallet);
      proContract = await tokenAs(pro.address, deployerWallet);
    });

    it('Can add badge', async () => {
      await levelRegistrarContract.createLevel(noob.address);
    });

    it('Cannot set level if badge not added', async () => {
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

    it('Can set level', async () => {
      await noobContract.setApprovalForAll(
        levelRegistrarContract.address,
        true
      );
      let isApproved: boolean = await noobContract.isApprovedForAll(
        deployerWallet.address,
        levelRegistrarContract.address
      );
      await expect(isApproved, 'badge contract should be approved').to.be.true;
      let ownerOldBalance: BigNumber = await noobContract.balanceOf(
        deployerWallet.address
      );
      expect(ownerOldBalance.toNumber()).eq(2);

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
      expect(ownerNewBalance.toNumber()).eq(1);
      expect(receiverNewBalance.toNumber()).eq(1);
      expect(contractNewBalance.toNumber()).eq(0);
      let hasLevel: boolean =await levelRegistrarContract.hasLevel(noobContract.address, otherWallet.address)
      expect(hasLevel).to.be.true
    });
  });
});
