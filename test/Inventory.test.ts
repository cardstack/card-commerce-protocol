import chai, { expect } from 'chai';
import asPromised from 'chai-as-promised';
import { JsonRpcProvider } from '@ethersproject/providers';
import { Blockchain } from '../utils/Blockchain';
import { generatedWallets } from '../utils/generatedWallets';
import { MarketFactory } from '../typechain/MarketFactory';
import { ethers, Wallet } from 'ethers';
import { AddressZero } from '@ethersproject/constants';
import Decimal from '../utils/Decimal';
import { BigNumber, BigNumberish, Bytes } from 'ethers';
import { InventoryFactory } from '../typechain/InventoryFactory';
import { Inventory } from '../typechain/Inventory';
import {
  approveCurrency,
  deployCurrency,
  EIP712Sig,
  getBalance,
  mintCurrency,
  signMintWithSig,
  signPermit,
  toNumWei,
} from './utils';
import {
  arrayify,
  formatBytes32String,
  formatUnits,
  sha256,
} from 'ethers/lib/utils';
import exp from 'constants';
import {BytesLike} from "@ethersproject/bytes";
import {ExchangeMock, ExchangeMockFactory, LevelRegistrarFactory} from "../typechain";

chai.use(asPromised);

const provider = new JsonRpcProvider();
const blockchain = new Blockchain(provider);

let contentHex: string;
let contentHash: string;
let contentHashBytes: Bytes;
let otherContentHex: string;
let otherContentHash: string;
let otherContentHashBytes: Bytes;
let zeroContentHashBytes: Bytes;
let metadataHex: string;
let metadataHash: string;
let metadataHashBytes: Bytes;

const tokenURI = 'www.example.com';
const metadataURI = 'www.example2.com';

type InventoryData = {
  listingURI: string;
  metadataURI: string;
  contentHash: Bytes;
  metadataHash: Bytes;
};

type Ask = {
  amount: BigNumberish;
};

type Bid = {
  currency: string;
  amount: BigNumberish;
  bidder: string;
  recipient: string;
};

describe('Inventory', () => {
  const [
    deployerWallet,
    bidderWallet,
    merchantWallet,
    ownerWallet,
    prevOwnerWallet,
    otherWallet,
    nonBidderWallet,
  ] = generatedWallets(provider);

  const defaultTokenId = 1;
  const defaultAsk = {
    amount: 100
  };
  const defaultBid = (
    currency: string,
    bidder: string,
    recipient?: string
  ) => ({
    amount: 100,
    currency,
    bidder,
    recipient: recipient || bidder
  });

  let auctionAddress: string;
  let tokenAddress: string;
  let registarAddress: string;

  async function tokenAs(wallet: Wallet) {
    return InventoryFactory.connect(tokenAddress, wallet);
  }
  async function deploy() {
    const auction = await (
      await new MarketFactory(deployerWallet).deploy()
    ).deployed();
    auctionAddress = auction.address;
    const token = await (
      await new InventoryFactory(deployerWallet).deploy(auction.address)
    ).deployed();
    tokenAddress = token.address;

    const registrar = await (
        await new LevelRegistrarFactory(deployerWallet).deploy()
    ).deployed();
    registarAddress = registrar.address;

    const exchangeMock = await (
        await new ExchangeMockFactory(deployerWallet).deploy()
    );

    await auction.configure(tokenAddress, exchangeMock.address);
  }

  async function setDefaultLevel(wallet: Wallet) {
    const defaultLevel = {
      label: "noob",
      threshold: 0
    }
    await LevelRegistrarFactory.connect(registarAddress, wallet).setLevels([defaultLevel], tokenAddress);
  }

  async function mint(
    token: Inventory,
    metadataURI: string,
    listingURI: string,
    contentHash: Bytes,
    metadataHash: Bytes
  ) {
    const data: InventoryData = {
      listingURI,
      metadataURI,
      contentHash,
      metadataHash,
    };
    return token.mint(data);
  }

  async function mintWithSig(
    token: Inventory,
    creator: string,
    listingURI: string,
    metadataURI: string,
    contentHash: Bytes,
    metadataHash: Bytes,
    sig: EIP712Sig
  ) {
    const data: InventoryData = {
      listingURI,
      metadataURI,
      contentHash,
      metadataHash,
    };

    return token.mintWithSig(creator, data, sig);
  }

  async function setAsk(token: Inventory, tokenId: number, ask: Ask) {
    return token.setAsk(tokenId, ask);
  }

  async function removeAsk(token: Inventory, tokenId: number) {
    return token.removeAsk(tokenId);
  }

  async function setBid(token: Inventory, bid: Bid, tokenId: number) {
    return token.setBid(tokenId, bid);
  }

  async function removeBid(token: Inventory, tokenId: number) {
    return token.removeBid(tokenId);
  }

  async function acceptBid(token: Inventory, tokenId: number, bid: Bid) {
    return token.acceptBid(tokenId, bid);
  }

  async function setItems(currencyAddr: string, tokenId = 0, wallet = merchantWallet) {
    await mintCurrency(currencyAddr, wallet.address, 10000);
    await approveCurrency(currencyAddr, auctionAddress, wallet);
    const inventory = await tokenAs(wallet);
    await inventory.setItems(tokenId, {
      merchant: wallet.address,
      tokenAddresses: [currencyAddr],
      amounts: [1000],
      quantity: 10
    });
  }

  // Trade a token a few times and create some open bids
  async function setupAuction(currencyAddr: string, tokenId = 0, merchant = merchantWallet) {
    const asMerchant = await tokenAs(merchant);
    const asPrevOwner = await tokenAs(prevOwnerWallet);
    const asOwner = await tokenAs(ownerWallet);
    const asBidder = await tokenAs(bidderWallet);
    const asOther = await tokenAs(otherWallet);

    await mintCurrency(currencyAddr, merchant.address, 10000);
    await mintCurrency(currencyAddr, prevOwnerWallet.address, 10000);
    await mintCurrency(currencyAddr, ownerWallet.address, 10000);
    await mintCurrency(currencyAddr, bidderWallet.address, 10000);
    await mintCurrency(currencyAddr, otherWallet.address, 10000);
    await approveCurrency(currencyAddr, auctionAddress, merchant);
    await approveCurrency(currencyAddr, auctionAddress, prevOwnerWallet);
    await approveCurrency(currencyAddr, auctionAddress, ownerWallet);
    await approveCurrency(currencyAddr, auctionAddress, bidderWallet);
    await approveCurrency(currencyAddr, auctionAddress, otherWallet);

    await mint(
      asMerchant,
      metadataURI,
      tokenURI,
      contentHashBytes,
      metadataHashBytes
    );

    await setItems(currencyAddr, tokenId, merchant);

    await setBid(
      asPrevOwner,
      defaultBid(currencyAddr, prevOwnerWallet.address),
      tokenId
    );

    await setBid(
      asOwner,
      defaultBid(currencyAddr, ownerWallet.address),
      tokenId
    );
    await setBid(
      asBidder,
      defaultBid(currencyAddr, bidderWallet.address),
      tokenId
    );
    await setBid(
      asOther,
      defaultBid(currencyAddr, otherWallet.address),
      tokenId
    );
  }

  beforeEach(async () => {
    await blockchain.resetAsync();

    metadataHex = ethers.utils.formatBytes32String('{}');
    metadataHash = await sha256(metadataHex);
    metadataHashBytes = ethers.utils.arrayify(metadataHash);

    contentHex = ethers.utils.formatBytes32String('invert');
    contentHash = await sha256(contentHex);
    contentHashBytes = ethers.utils.arrayify(contentHash);

    otherContentHex = ethers.utils.formatBytes32String('otherthing');
    otherContentHash = await sha256(otherContentHex);
    otherContentHashBytes = ethers.utils.arrayify(otherContentHash);

    zeroContentHashBytes = ethers.utils.arrayify(ethers.constants.HashZero);
  });

  describe('#constructor', () => {
    it('should be able to deploy', async () => {
      await expect(deploy()).eventually.fulfilled;
    });
  });

  describe('#mint', () => {
    beforeEach(async () => {
      await deploy();
    });

    it('should mint a token', async () => {
      const token = await tokenAs(merchantWallet);

      await expect(
        mint(
          token,
          metadataURI,
          tokenURI,
          contentHashBytes,
          metadataHashBytes
        )
      ).fulfilled;

      const t = await token.tokenByIndex(0);
      const ownerT = await token.tokenOfOwnerByIndex(merchantWallet.address, 0);
      const ownerOf = await token.ownerOf(0);
      const prevOwner = await token.previousTokenOwners(0);
      const tokenContentHash = await token.tokenContentHashes(0);
      const metadataContentHash = await token.tokenMetadataHashes(0);
      const savedTokenURI = await token.tokenURI(0);
      const savedMetadataURI = await token.tokenMetadataURI(0);

      expect(toNumWei(t)).eq(toNumWei(ownerT));
      expect(ownerOf).eq(merchantWallet.address);
      expect(prevOwner).eq(merchantWallet.address);
      expect(tokenContentHash).eq(contentHash);
      expect(metadataContentHash).eq(metadataHash);
      expect(savedTokenURI).eq(tokenURI);
      expect(savedMetadataURI).eq(metadataURI);
    });

    it('should revert if an empty content hash is specified', async () => {
      const token = await tokenAs(merchantWallet);

      await expect(
        mint(
          token,
          metadataURI,
          tokenURI,
          zeroContentHashBytes,
          metadataHashBytes
        )
      ).rejectedWith('Inventory: content hash must be non-zero');
    });

    it('should revert if the content hash already exists for a created token', async () => {
      const token = await tokenAs(merchantWallet);

      await expect(
        mint(
          token,
          metadataURI,
          tokenURI,
          contentHashBytes,
          metadataHashBytes
        )
      ).fulfilled;

      await expect(
        mint(
          token,
          metadataURI,
          tokenURI,
          contentHashBytes,
          metadataHashBytes
        )
      ).rejectedWith(
        'Inventory: a token has already been created with this content hash'
      );
    });

    it('should revert if the metadataHash is empty', async () => {
      const token = await tokenAs(merchantWallet);

      await expect(
        mint(
          token,
          metadataURI,
          tokenURI,
          contentHashBytes,
          zeroContentHashBytes
        )
      ).rejectedWith('Inventory: metadata hash must be non-zero');
    });

    it('should revert if the tokenURI is empty', async () => {
      const token = await tokenAs(merchantWallet);

      await expect(
        mint(token, metadataURI, '', zeroContentHashBytes, metadataHashBytes)
      ).rejectedWith('Inventory: specified uri must be non-empty');
    });

    it('should revert if the metadataURI is empty', async () => {
      const token = await tokenAs(merchantWallet);

      await expect(
        mint(token, '', tokenURI, zeroContentHashBytes, metadataHashBytes)
      ).rejectedWith('Inventory: specified uri must be non-empty');
    });
  });

  describe('#mintWithSig', () => {
    beforeEach(async () => {
      await deploy();
    });

    it('should mint a token for a given merchant with a valid signature', async () => {
      const token = await tokenAs(otherWallet);
      const sig = await signMintWithSig(
          merchantWallet,
          token.address,
          merchantWallet.address,
          contentHash,
          metadataHash,
          1
      );

      const beforeNonce = await token.mintWithSigNonces(merchantWallet.address);
      await expect(
        mintWithSig(
          token,
          merchantWallet.address,
          tokenURI,
          metadataURI,
          contentHashBytes,
          metadataHashBytes,
          sig
        )
      ).fulfilled;

      const recovered = await token.merchants(0);
      const recoveredTokenURI = await token.tokenURI(0);
      const recoveredMetadataURI = await token.tokenMetadataURI(0);
      const recoveredContentHash = await token.tokenContentHashes(0);
      const recoveredMetadataHash = await token.tokenMetadataHashes(0);

      const afterNonce = await token.mintWithSigNonces(merchantWallet.address);

      expect(recovered).to.eq(merchantWallet.address);
      expect(recoveredTokenURI).to.eq(tokenURI);
      expect(recoveredMetadataURI).to.eq(metadataURI);
      expect(recoveredContentHash).to.eq(contentHash);
      expect(recoveredMetadataHash).to.eq(metadataHash);
      expect(toNumWei(afterNonce)).to.eq(toNumWei(beforeNonce) + 1);
    });

    it('should not mint a token for a different merchant', async () => {
      const token = await tokenAs(otherWallet);
      const sig = await signMintWithSig(
        bidderWallet,
        token.address,
        merchantWallet.address,
        tokenURI,
        metadataURI,
        1
      );

      await expect(
        mintWithSig(
          token,
          merchantWallet.address,
          tokenURI,
          metadataURI,
          contentHashBytes,
          metadataHashBytes,
          sig
        )
      ).rejectedWith('Inventory: Signature invalid');
    });

    it('should not mint a token for a different contentHash', async () => {
      const badContent = 'bad bad bad';
      const badContentHex = formatBytes32String(badContent);
      const badContentHash = sha256(badContentHex);
      const badContentHashBytes = arrayify(badContentHash);

      const token = await tokenAs(otherWallet);
      const sig = await signMintWithSig(
        merchantWallet,
        token.address,
        merchantWallet.address,
        contentHash,
        metadataHash,
        1
      );

      await expect(
        mintWithSig(
          token,
          merchantWallet.address,
          tokenURI,
          metadataURI,
          badContentHashBytes,
          metadataHashBytes,
          sig
        )
      ).rejectedWith('Inventory: Signature invalid');
    });

    it('should not mint a token for a different metadataHash', async () => {
      const badMetadata = '{"some": "bad", "data": ":)"}';
      const badMetadataHex = formatBytes32String(badMetadata);
      const badMetadataHash = sha256(badMetadataHex);
      const badMetadataHashBytes = arrayify(badMetadataHash);
      const token = await tokenAs(otherWallet);
      const sig = await signMintWithSig(
        merchantWallet,
        token.address,
        merchantWallet.address,
        contentHash,
        metadataHash,
        1
      );

      await expect(
        mintWithSig(
          token,
          merchantWallet.address,
          tokenURI,
          metadataURI,
          contentHashBytes,
          badMetadataHashBytes,
          sig
        )
      ).rejectedWith('Inventory: Signature invalid');
    });

    it('should not mint a token with an invalid deadline', async () => {
      const token = await tokenAs(otherWallet);
      const sig = await signMintWithSig(
        merchantWallet,
        token.address,
        merchantWallet.address,
        tokenURI,
        metadataURI,
        1
      );

      await expect(
        mintWithSig(
          token,
          merchantWallet.address,
          tokenURI,
          metadataURI,
          contentHashBytes,
          metadataHashBytes,
          { ...sig, deadline: '1' }
        )
      ).rejectedWith('Inventory: mintWithSig expired');
    });
  });

  describe('#setAsk', () => {
    let currencyAddr: string;
    beforeEach(async () => {
      await deploy();
      currencyAddr = await deployCurrency();
      await setupAuction(currencyAddr, 0, ownerWallet);
    });

    it('should set the ask', async () => {
      const token = await tokenAs(ownerWallet);
      await expect(setAsk(token, 0, defaultAsk)).fulfilled;
    });
  });

  describe('#removeAsk', () => {
    it('should remove the ask', async () => {
      const token = await tokenAs(ownerWallet);
      const market = await MarketFactory.connect(
        auctionAddress,
        deployerWallet
      );
      await setAsk(token, 0, defaultAsk);

      await expect(removeAsk(token, 0)).fulfilled;
      const ask = await market.currentAskForToken(0);
      expect(toNumWei(ask.amount)).eq(0);
    });

    it('should emit an Ask Removed event', async () => {
      const token = await tokenAs(ownerWallet);
      const auction = await MarketFactory.connect(
        auctionAddress,
        deployerWallet
      );
      await setAsk(token, 0, defaultAsk);
      const block = await provider.getBlockNumber();
      const tx = await removeAsk(token, 0);

      const events = await auction.queryFilter(
        auction.filters.AskRemoved(0, null),
        block
      );
      expect(events.length).eq(1);
      const logDescription = auction.interface.parseLog(events[0]);
      expect(toNumWei(logDescription.args.tokenId)).to.eq(0);
      expect(toNumWei(logDescription.args.ask.amount)).to.eq(defaultAsk.amount);
    });

    it('should not be callable by anyone that is not owner or approved', async () => {
      const token = await tokenAs(ownerWallet);
      const asOther = await tokenAs(otherWallet);
      await setAsk(token, 0, defaultAsk);

      expect(removeAsk(asOther, 0)).rejectedWith(
        'Inventory: Only approved or owner'
      );
    });
  });

  describe('#setBid', () => {
    let currencyAddr: string;
    beforeEach(async () => {
      await deploy();
      await mint(
        await tokenAs(merchantWallet),
        metadataURI,
        '1111',
        otherContentHashBytes,
        metadataHashBytes
      );
      currencyAddr = await deployCurrency();
      await setItems(currencyAddr);
    });

    it('should revert if the token bidder does not have a high enough allowance for their bidding currency', async () => {
      const token = await tokenAs(bidderWallet);
      await expect(
        token.setBid(0, defaultBid(currencyAddr, bidderWallet.address))
      ).rejectedWith('SafeERC20: ERC20 operation did not succeed');
    });

    it('should revert if the token bidder does not have a high enough balance for their bidding currency', async () => {
      const token = await tokenAs(bidderWallet);
      await approveCurrency(currencyAddr, auctionAddress, bidderWallet);
      await expect(
        token.setBid(0, defaultBid(currencyAddr, bidderWallet.address))
      ).rejectedWith('SafeERC20: ERC20 operation did not succeed');
    });

    it('should set a bid', async () => {
      const token = await tokenAs(bidderWallet);
      await approveCurrency(currencyAddr, auctionAddress, bidderWallet);
      await mintCurrency(currencyAddr, bidderWallet.address, 100000);
      await expect(
        token.setBid(0, defaultBid(currencyAddr, bidderWallet.address))
      ).fulfilled;
      const balance = await getBalance(currencyAddr, bidderWallet.address);
      expect(toNumWei(balance)).eq(100000 - 100);
    });

    it('should refund a bid if one already exists for the bidder', async () => {
      const token = await tokenAs(bidderWallet);
      await setupAuction(currencyAddr, 1);
      // bids 100 in setupAuction
      const beforeBalance = toNumWei(
        await getBalance(currencyAddr, bidderWallet.address)
      );
      await setBid(
        token,
        {
          currency: currencyAddr,
          amount: 200,
          bidder: bidderWallet.address,
          recipient: otherWallet.address,
        },
        1
      );
      const afterBalance = toNumWei(
        await getBalance(currencyAddr, bidderWallet.address)
      );

      expect(afterBalance).eq(beforeBalance - 100);
    });
  });

  describe('#removeBid', () => {
    let currencyAddr: string;
    beforeEach(async () => {
      await deploy();
      currencyAddr = await deployCurrency();
      await setupAuction(currencyAddr);
    });

    it('should revert if the bidder has not placed a bid', async () => {
      const token = await tokenAs(nonBidderWallet);

      await expect(removeBid(token, 0)).rejectedWith(
        'Market: cannot remove bid amount of 0'
      );
    });

    it('should revert if the tokenId has not yet been created', async () => {
      const token = await tokenAs(bidderWallet);

      await expect(removeBid(token, 100)).rejectedWith(
        'Inventory: token with that id does not exist'
      );
    });

    it('should remove a bid and refund the bidder', async () => {
      const token = await tokenAs(bidderWallet);
      const beforeBalance = toNumWei(
        await getBalance(currencyAddr, bidderWallet.address)
      );
      await expect(removeBid(token, 0)).fulfilled;
      const afterBalance = toNumWei(
        await getBalance(currencyAddr, bidderWallet.address)
      );

      expect(afterBalance).eq(beforeBalance + 100);
    });

    it('should not be able to remove a bid twice', async () => {
      const token = await tokenAs(bidderWallet);
      await removeBid(token, 0);

      await expect(removeBid(token, 0)).rejectedWith(
        'Market: cannot remove bid amount of 0'
      );
    });

    it('should remove a bid, even if the token is burned', async () => {
      const asBidder = await tokenAs(bidderWallet);
      const asCreator = await tokenAs(merchantWallet);

      await asCreator.burn(0);
      const beforeBalance = toNumWei(
        await getBalance(currencyAddr, bidderWallet.address)
      );
      await expect(asBidder.removeBid(0)).fulfilled;
      const afterBalance = toNumWei(
        await getBalance(currencyAddr, bidderWallet.address)
      );
      expect(afterBalance).eq(beforeBalance + 100);
    });
  });

  describe('#acceptBid', () => {
    let currencyAddr: string;
    beforeEach(async () => {
      await deploy();
      currencyAddr = await deployCurrency();
      await setupAuction(currencyAddr, 0, ownerWallet);
    });

    it('should accept a bid', async () => {
      const token = await tokenAs(ownerWallet);
      const asBidder = await tokenAs(bidderWallet);
      const bid = {
        ...defaultBid(currencyAddr, bidderWallet.address, otherWallet.address),
      };
      await setBid(asBidder, bid, 0);

      await expect(token.acceptBid(0, bid)).fulfilled;
    });

    it('should emit a bid finalized event if the bid is accepted', async () => {
      const asBidder = await tokenAs(bidderWallet);
      const token = await tokenAs(ownerWallet);
      const auction = await MarketFactory.connect(auctionAddress, bidderWallet);
      const bid = defaultBid(currencyAddr, bidderWallet.address);
      const block = await provider.getBlockNumber();
      await setBid(asBidder, bid, 0);
      await token.acceptBid(0, bid);
      const events = await auction.queryFilter(
        auction.filters.BidFinalized(null, null),
        block
      );
      expect(events.length).eq(1);
      const logDescription = auction.interface.parseLog(events[0]);
      expect(toNumWei(logDescription.args.tokenId)).to.eq(0);
      expect(toNumWei(logDescription.args.bid.amount)).to.eq(bid.amount);
      expect(logDescription.args.bid.currency).to.eq(bid.currency);
      expect(logDescription.args.bid.bidder).to.eq(bid.bidder);
    });

    it('should revert if not called by the owner', async () => {
      const token = await tokenAs(otherWallet);

      await expect(
        token.acceptBid(0, { ...defaultBid(currencyAddr, otherWallet.address) })
      ).rejectedWith('Inventory: Only approved or owner');
    });

    it('should revert if a non-existent bid is accepted', async () => {
      const token = await tokenAs(ownerWallet);
      await expect(
        token.acceptBid(0, { ...defaultBid(currencyAddr, AddressZero) })
      ).rejectedWith('Market: cannot accept bid of 0');
    });
  });

  describe('#transfer', () => {
    let currencyAddr: string;
    beforeEach(async () => {
      await deploy();
      currencyAddr = await deployCurrency();
      await setupAuction(currencyAddr);
    });

    it('should revert on transfer for NFT listings', async () => {
      const token = await tokenAs(ownerWallet);

      await expect(
        token.transferFrom(ownerWallet.address, otherWallet.address, 0)
      ).rejectedWith("Transfer is blocked");
    });
  });

  describe('#burn', () => {
    beforeEach(async () => {
      await deploy();
      const token = await tokenAs(merchantWallet);
      await mint(
        token,
        metadataURI,
        tokenURI,
        contentHashBytes,
        metadataHashBytes
      );
    });

    it('should allow approved to burn token', async () => {
      const token = await tokenAs(merchantWallet);
      await token.approve(otherWallet.address, 0);

      const otherToken = await tokenAs(otherWallet);
      await expect(otherToken.burn(0)).fulfilled;
    });

    it('should revert when the caller is not the owner or a creator', async () => {
      const token = await tokenAs(otherWallet);

      await expect(token.burn(0)).rejectedWith('Inventory: Only approved or owner');
    });

    it('should revert if the token id does not exist', async () => {
      const token = await tokenAs(merchantWallet);

      await expect(token.burn(100)).rejectedWith('Inventory: nonexistent token');
    });

    it('should clear approvals, set remove owner, but maintain tokenURI and contentHash when the owner is creator and caller', async () => {
      const token = await tokenAs(merchantWallet);
      await expect(token.approve(otherWallet.address, 0)).fulfilled;

      await expect(token.burn(0)).fulfilled;

      await expect(token.ownerOf(0)).rejectedWith(
        'ERC721: owner query for nonexistent token'
      );

      const totalSupply = await token.totalSupply();
      expect(toNumWei(totalSupply)).eq(0);

      await expect(token.getApproved(0)).rejectedWith(
        'ERC721: approved query for nonexistent token'
      );

      const tokenURI = await token.tokenURI(0);
      expect(tokenURI).eq('www.example.com');

      const contentHash = await token.tokenContentHashes(0);
      expect(contentHash).eq(contentHash);

      const previousOwner = await token.previousTokenOwners(0);
      expect(previousOwner).eq(AddressZero);
    });

    it('should clear approvals, set remove owner, but maintain tokenURI and contentHash when the owner is creator and caller is approved', async () => {
      const token = await tokenAs(merchantWallet);
      await expect(token.approve(otherWallet.address, 0)).fulfilled;

      const otherToken = await tokenAs(otherWallet);

      await expect(otherToken.burn(0)).fulfilled;

      await expect(token.ownerOf(0)).rejectedWith(
        'ERC721: owner query for nonexistent token'
      );

      const totalSupply = await token.totalSupply();
      expect(toNumWei(totalSupply)).eq(0);

      await expect(token.getApproved(0)).rejectedWith(
        'ERC721: approved query for nonexistent token'
      );

      const tokenURI = await token.tokenURI(0);
      expect(tokenURI).eq('www.example.com');

      const contentHash = await token.tokenContentHashes(0);
      expect(contentHash).eq(contentHash);

      const previousOwner = await token.previousTokenOwners(0);
      expect(previousOwner).eq(AddressZero);
    });
  });

  describe('#setDiscount', async() => {

    const defaultLevelRequirement = {
      setter: merchantWallet.address,
      registrar: undefined,
      token: undefined,
      levelLabel: "noob"
    }

    const defaultDiscount = {
      levelRequired: defaultLevelRequirement,
      discount: { value: 1 }
    }

    beforeEach(async () => {
      await deploy();
      defaultLevelRequirement.token = tokenAddress;
      defaultLevelRequirement.registrar = registarAddress;
      await setDefaultLevel(merchantWallet);
      await mint(
          await tokenAs(merchantWallet),
          metadataURI,
          '1111',
          otherContentHashBytes,
          metadataHashBytes
      );
    });

    it('should revert if the token id does not exist', async () => {
      const token = await tokenAs(merchantWallet);
      await expect(token.setDiscount(100, defaultDiscount)).rejectedWith('Inventory: nonexistent token');
    });

    it("should not be able to set a discount if not approved or merchant", async() => {
      const token = await tokenAs(otherWallet);
      await expect(token.setDiscount(0, defaultDiscount)).rejectedWith('Inventory: Only approved or owner');
    });

    it("should be able to set a discount if approved or merchant", async() => {
      const token = await tokenAs(merchantWallet);
      await expect(token.setDiscount(0, defaultDiscount)).fulfilled;
      await token.approve(otherWallet.address, 0);
      const tokenAsOtherWallet = await tokenAs(otherWallet);
      await expect(tokenAsOtherWallet.setDiscount(0, defaultDiscount)).fulfilled;
    });

  });

  describe('#setItems', async() => {

    let currency;

    beforeEach(async () => {
      await deploy();
      await mint(
          await tokenAs(merchantWallet),
          metadataURI,
          '1111',
          otherContentHashBytes,
          metadataHashBytes
      );
      currency = await deployCurrency();
    });

    it('should revert if the token id does not exist', async () => {
      await expect(setItems(currency, 100)).rejectedWith('Inventory: nonexistent token');
    });

    it("should not be able to set items if not approved or merchant", async() => {
      await expect(setItems(currency, 0, otherWallet)).rejectedWith('Inventory: Only approved or owner');
    });

    it("should be able to set items if approved or merchant", async() => {
      const token = await tokenAs(merchantWallet);
      await token.approve(otherWallet.address, 0);
      await expect(setItems(currency, 0, otherWallet)).fulfilled;
      await expect(setItems(currency, 0, merchantWallet)).fulfilled;
    });
  });

  describe("#setLevelRequirements", () => {

    const defaultLevelRequirement = {
      setter: deployerWallet.address,
      registrar: undefined,
      token: undefined,
      levelLabel: "noob"
    }

    beforeEach(async () => {
      await deploy();
      await mint(
          await tokenAs(merchantWallet),
          metadataURI,
          '1111',
          otherContentHashBytes,
          metadataHashBytes
      );
      defaultLevelRequirement.token = tokenAddress;
      defaultLevelRequirement.registrar = registarAddress;
    });

    it('should revert if the token id does not exist', async () => {
      const token = await tokenAs(merchantWallet);
      await expect(token.setLevelRequirement(100, defaultLevelRequirement, merchantWallet.address, token.address)).rejectedWith('Inventory: nonexistent token');
    });

    it("should not be able to set a level requirement if not approved or owner", async() => {
        const token = await tokenAs(otherWallet);
        await expect(token.setLevelRequirement(0, defaultLevelRequirement, merchantWallet.address, token.address)).rejectedWith('Inventory: Only approved or owner');
    });

    it("should be able to set a level requirement if approved or owner", async() => {
      const token = await tokenAs(merchantWallet);
      await token.approve(otherWallet.address, 0);
      const tokenAsApproved = await tokenAs(otherWallet);
      await setDefaultLevel(merchantWallet);
      await expect(token.setLevelRequirement(0, defaultLevelRequirement, merchantWallet.address, token.address)).fulfilled;
      await expect(tokenAsApproved.setLevelRequirement(0, defaultLevelRequirement, merchantWallet.address, token.address)).fulfilled;
    });
  });

  describe('#updateTokenURI', async () => {
    let currencyAddr: string;

    beforeEach(async () => {
      await deploy();
      currencyAddr = await deployCurrency();
      await setupAuction(currencyAddr);
    });

    it('should revert if the token does not exist', async () => {
      const token = await tokenAs(merchantWallet);

      await expect(token.updateTokenURI(1, 'blah blah')).rejectedWith(
        'ERC721: operator query for nonexistent token'
      );
    });

    it('should revert if the caller is not the owner of the token and does not have approval', async () => {
      const token = await tokenAs(otherWallet);

      await expect(token.updateTokenURI(0, 'blah blah')).rejectedWith(
        'Inventory: Only approved or owner'
      );
    });

    it('should revert if the uri is empty string', async () => {
      const token = await tokenAs(merchantWallet);
      await expect(token.updateTokenURI(0, '')).rejectedWith(
        'Inventory: specified uri must be non-empty'
      );
    });

    it('should revert if the token has been burned', async () => {
      const token = await tokenAs(merchantWallet);

      await mint(
        token,
        metadataURI,
        tokenURI,
        otherContentHashBytes,
        metadataHashBytes
      );

      await expect(token.burn(1)).fulfilled;

      await expect(token.updateTokenURI(1, 'blah')).rejectedWith(
        'ERC721: operator query for nonexistent token'
      );
    });

    it('should set the tokenURI to the URI passed if the msg.sender is the merchant', async () => {
      const token = await tokenAs(merchantWallet);
      await expect(token.updateTokenURI(0, 'blah blah')).fulfilled;

      const tokenURI = await token.tokenURI(0);
      expect(tokenURI).eq('blah blah');
    });

    it('should set the tokenURI to the URI passed if the msg.sender is approved', async () => {
      const token = await tokenAs(merchantWallet);
      await token.approve(otherWallet.address, 0);

      const otherToken = await tokenAs(otherWallet);
      await expect(otherToken.updateTokenURI(0, 'blah blah')).fulfilled;

      const tokenURI = await token.tokenURI(0);
      expect(tokenURI).eq('blah blah');
    });
  });

  describe('#updateMetadataURI', async () => {
    let currencyAddr: string;

    beforeEach(async () => {
      await deploy();
      currencyAddr = await deployCurrency();
      await setupAuction(currencyAddr);
    });

    it('should revert if the token does not exist', async () => {
      const token = await tokenAs(merchantWallet);

      await expect(token.updateTokenMetadataURI(1, 'blah blah')).rejectedWith(
        'ERC721: operator query for nonexistent token'
      );
    });

    it('should revert if the caller is not the merchant or approved', async () => {
      const token = await tokenAs(otherWallet);

      await expect(token.updateTokenMetadataURI(0, 'blah blah')).rejectedWith(
        'Inventory: Only approved or owner'
      );
    });

    it('should revert if the uri is empty string', async () => {
      const token = await tokenAs(merchantWallet);
      await expect(token.updateTokenMetadataURI(0, '')).rejectedWith(
        'Inventory: specified uri must be non-empty'
      );
    });

    it('should revert if the token has been burned', async () => {
      const token = await tokenAs(merchantWallet);

      await mint(
        token,
        metadataURI,
        tokenURI,
        otherContentHashBytes,
        metadataHashBytes
      );

      await expect(token.burn(1)).fulfilled;

      await expect(token.updateTokenMetadataURI(1, 'blah')).rejectedWith(
        'ERC721: operator query for nonexistent token'
      );
    });

    it('should set the tokenMetadataURI to the URI passed if msg.sender is the merchant', async () => {
      const token = await tokenAs(merchantWallet);
      await expect(token.updateTokenMetadataURI(0, 'blah blah')).fulfilled;

      const tokenURI = await token.tokenMetadataURI(0);
      expect(tokenURI).eq('blah blah');
    });

    it('should set the tokenMetadataURI to the URI passed if the msg.sender is approved', async () => {
      const token = await tokenAs(merchantWallet);
      await token.approve(otherWallet.address, 0);

      const otherToken = await tokenAs(otherWallet);
      await expect(otherToken.updateTokenMetadataURI(0, 'blah blah')).fulfilled;

      const tokenURI = await token.tokenMetadataURI(0);
      expect(tokenURI).eq('blah blah');
    });
  });

  describe('#permit', () => {
    let currency: string;

    beforeEach(async () => {
      await deploy();
      currency = await deployCurrency();
      await setupAuction(currency);
    });

    it('should allow a wallet to set themselves to approved with a valid signature', async () => {
      const token = await tokenAs(otherWallet);
      const sig = await signPermit(
        merchantWallet,
        otherWallet.address,
        token.address,
        0,
        // NOTE: We set the chain ID to 1 because of an error with ganache-core: https://github.com/trufflesuite/ganache-core/issues/515
        1
      );
      await expect(token.permit(otherWallet.address, 0, sig)).fulfilled;
      await expect(token.getApproved(0)).eventually.eq(otherWallet.address);
    });

    it('should not allow a wallet to set themselves to approved with an invalid signature', async () => {
      const token = await tokenAs(otherWallet);
      const sig = await signPermit(
        ownerWallet,
        bidderWallet.address,
        token.address,
        0,
        1
      );
      await expect(token.permit(otherWallet.address, 0, sig)).rejectedWith(
        'Inventory: Signature invalid'
      );
      await expect(token.getApproved(0)).eventually.eq(AddressZero);
    });
  });

  describe('#supportsInterface', async () => {
    beforeEach(async () => {
      await deploy();
    });

    it('should return true to supporting new metadata interface', async () => {
      const token = await tokenAs(otherWallet);
      const interfaceId = ethers.utils.arrayify('0x4e222e66');
      const supportsId = await token.supportsInterface(interfaceId);
      expect(supportsId).eq(true);
    });

    it('should return false to supporting the old metadata interface', async () => {
      const token = await tokenAs(otherWallet);
      const interfaceId = ethers.utils.arrayify('0x5b5e139f');
      const supportsId = await token.supportsInterface(interfaceId);
      expect(supportsId).eq(false);
    });
  });

  describe('#revokeApproval', async () => {
    let currency: string;

    beforeEach(async () => {
      await deploy();
      currency = await deployCurrency();
      await setupAuction(currency);
    });

    it('should revert if the caller is the owner', async () => {
      const token = await tokenAs(ownerWallet);
      await expect(token.revokeApproval(0)).rejectedWith(
        'Inventory: caller not approved address'
      );
    });

    it('should revert if the caller is the creator', async () => {
      const token = await tokenAs(merchantWallet);
      await expect(token.revokeApproval(0)).rejectedWith(
        'Inventory: caller not approved address'
      );
    });

    it('should revert if the caller is neither owner, creator, or approver', async () => {
      const token = await tokenAs(otherWallet);
      await expect(token.revokeApproval(0)).rejectedWith(
        'Inventory: caller not approved address'
      );
    });

    it('should revoke the approval for token id if caller is approved address', async () => {
      const token = await tokenAs(merchantWallet);
      await token.approve(otherWallet.address, 0);
      const otherToken = await tokenAs(otherWallet);
      await expect(otherToken.revokeApproval(0)).fulfilled;
      const approved = await token.getApproved(0);
      expect(approved).eq(ethers.constants.AddressZero);
    });
  });
});
