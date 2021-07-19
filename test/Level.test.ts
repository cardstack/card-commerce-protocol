import chai, { expect } from 'chai';
import asPromised from 'chai-as-promised';
import { JsonRpcProvider } from '@ethersproject/providers';
import { Blockchain } from '../utils/Blockchain';
import { generatedWallets } from '../utils/generatedWallets';
import { Erc721Factory } from '../typechain/Erc721Factory';
import { BaseErc20Factory } from '../typechain/BaseErc20Factory';
import { Level } from '../typechain/Level';
import { BaseErc20, Erc721, LevelFactory } from '../typechain';
import { BytesLike, BigNumber, BigNumberish, Wallet } from 'ethers';
import { randomBytes } from 'ethers/lib/utils';

chai.use(asPromised);

let provider = new JsonRpcProvider();
let blockchain = new Blockchain(provider);

type Badge = {
  token: string;
  tokenID: BigNumber;
};
type LevelResult = {
  label: string;
  badge: Badge;
};
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

  function createBadge(label, symbol) {
    return new Erc721Factory(deployerWallet).deploy(label, symbol);
  }

  async function registrarAs(wallet: Wallet) {
    return LevelFactory.connect(levelAddress, wallet);
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
    let noob, pro: Erc721;
    let deployerWalletAddress: string;
    let otherWalletAddress: string;

    let userLevel: LevelResult;
    let hasLevel: boolean;

    beforeEach(async () => {
      await deploy();

      levelRegistrarContract = await registrarAs(deployerWallet);
      erc20 = await createERC20();
      noob = await createBadge('Noob', 'NEWB'); //an nft contract
      pro = await createBadge('Pro', 'PRO'); //an nft contract
    });

    it('add badge', async () => {
      await levelRegistrarContract.createLevel(noob.address)
      deployerWalletAddress = deployerWallet.address;
    });

    it('can set level set if badge added', async () => {
      await levelRegistrarContract.createLevel(noob.address)
      otherWalletAddress = otherWallet.address;
      await levelRegistrarContract.setLevel(noob.address, otherWalletAddress);
    });

    it('does not has level if level not set', async () => {
      otherWalletAddress = otherWallet.address;
      const hasLevel = await levelRegistrarContract.hasLevel(
        noob.address,
        otherWalletAddress
      );
      expect(hasLevel).eq(false, 'Address does not have a level');
    });

    it('cannot set level if badge not added', async () => {
      otherWalletAddress = otherWallet.address;
        await expect(
            levelRegistrarContract.setLevel(noob.address, otherWalletAddress)
        ).rejectedWith("Badge is not added");
    });

    it('Claim level from proof', async () => {
      await levelRegistrarContract.claimLevel(sampleProofBytes);
      deployerWalletAddress = deployerWallet.address;
      userLevel = await levelRegistrarContract.getLevels(deployerWalletAddress);
    });

    it('Cannot claim level from proof for the second time', async () => {});

    it('Check level from proof', async () => {});
  });
});
