import chai, {expect} from 'chai';
import asPromised from 'chai-as-promised';
import {JsonRpcProvider} from '@ethersproject/providers';
import {Blockchain} from '../utils/Blockchain';
import {generatedWallets} from '../utils/generatedWallets';
import {MarketFactory} from '../typechain/MarketFactory';
import {BigNumber, BigNumberish, Wallet} from 'ethers';
import {formatUnits} from '@ethersproject/units';
import {AddressZero, MaxUint256} from '@ethersproject/constants';
import {BaseErc20Factory} from '../typechain/BaseErc20Factory';
import {Market} from '../typechain/Market';
import {ExchangeMockFactory} from '../typechain/ExchangeMockFactory';
import {LevelRegistrarFactory} from "../typechain";
import Decimal from "../utils/Decimal";

chai.use(asPromised);

const provider = new JsonRpcProvider();
const blockchain = new Blockchain(provider);

type Ask = {
  amount: BigNumberish;
};

type Bid = {
  currency: string;
  amount: BigNumberish;
  bidder: string;
  recipient: string;
};

type Items = {
  merchant: string;
  tokenAddresses: string[];
  amounts: number[];
  quantity: number;
}

type Discount = {
  levelRequired: LevelRequirement;
  discount: { value: BigNumberish };
}

type LevelRequirement = {
  setter: string;
  registrar: string;
  token: string;
  levelLabel: string;
}

describe('Market', () => {
  const [
    deployerWallet,
    bidderWallet,
    mockTokenWallet,
    otherWallet,
  ] = generatedWallets(provider);

  const defaultTokenId = 1;
  const defaultAsk = {
    amount: 100
  };

  const defaultLevelRequirement: LevelRequirement = {
    setter: deployerWallet.address,
    registrar: mockTokenWallet.address,
    token: mockTokenWallet.address,
    levelLabel: "noob"
  }

  const defaultDiscount: Discount = {
    levelRequired: null,
    discount: Decimal.new(10)
  }

  let auctionAddress: string;
  let exchangeAddress: string;
  let levelRegistrarAddress: string;

  function toNumWei(val: BigNumber) {
    return parseFloat(formatUnits(val, 'wei'));
  }

  function toNumEther(val: BigNumber) {
    return parseFloat(formatUnits(val, 'ether'));
  }

  async function auctionAs(wallet: Wallet) {
    return MarketFactory.connect(auctionAddress, wallet);
  }

  async function levelRegistrarAs(wallet: Wallet) {
    return LevelRegistrarFactory.connect(levelRegistrarAddress, wallet);
  }

  async function deploy() {
    const auction = await (
      await new MarketFactory(deployerWallet).deploy()
    ).deployed();
    const exchange = await (
        await new ExchangeMockFactory(deployerWallet).deploy()
    ).deployed();
    const levelRegistrar = await (
        await new LevelRegistrarFactory(deployerWallet).deploy()
    );
    levelRegistrarAddress = levelRegistrar.address;
    exchangeAddress = exchange.address;
    auctionAddress = auction.address;
  }

  async function configure() {
    return MarketFactory.connect(auctionAddress, deployerWallet).configure(
        mockTokenWallet.address,
        exchangeAddress
    );
  }

  async function configureItems(currency, merchant = otherWallet) {
    await mintCurrency(currency, merchant.address, 10000);
    await approveCurrency(currency, auctionAddress, merchant);
    const auction = await auctionAs(mockTokenWallet);
    await auction.setItems(defaultTokenId, {
      merchant: merchant.address,
      tokenAddresses: [currency],
      amounts: [1000],
      quantity: 10
    });
  }

  async function readInventoryContract() {
    return MarketFactory.connect(
      auctionAddress,
      deployerWallet
    ).inventoryContract();
  }

  async function setAsk(auction: Market, tokenId: number, ask?: Ask) {
    return auction.setAsk(tokenId, ask);
  }

  async function deployCurrency() {
    const currency = await new BaseErc20Factory(deployerWallet).deploy(
      'test',
      'TEST',
      18
    );
    return currency.address;
  }

  async function mintCurrency(currency: string, to: string, value: number) {
    await BaseErc20Factory.connect(currency, deployerWallet).mint(to, value);
  }

  async function approveCurrency(
    currency: string,
    spender: string,
    owner: Wallet
  ) {
    await BaseErc20Factory.connect(currency, owner).approve(
      spender,
      MaxUint256
    );
  }
  async function getBalance(currency: string, owner: string) {
    return BaseErc20Factory.connect(currency, deployerWallet).balanceOf(owner);
  }
  async function setBid(
    auction: Market,
    bid: Bid,
    tokenId: number,
    spender?: string
  ) {
    await auction.setBid(tokenId, bid, spender || bid.bidder);
  }

  beforeEach(async () => {
    await blockchain.resetAsync();
  });

  describe('#constructor', () => {
    it('should be able to deploy', async () => {
      await expect(deploy()).eventually.fulfilled;
    });
  });

  describe('#configure', () => {
    beforeEach(async () => {
      await deploy();
    });

    it('should revert if not called by the owner', async () => {
      await expect(
        MarketFactory.connect(auctionAddress, otherWallet).configure(
          mockTokenWallet.address,
          mockTokenWallet.address
        )
      ).eventually.rejectedWith('Market: Only owner');
    });

    it('should be callable by the owner', async () => {
      await expect(configure()).eventually.fulfilled;
      const tokenContractAddress = await readInventoryContract();

      expect(tokenContractAddress).eq(mockTokenWallet.address);
    });

    it('should reject if called twice', async () => {
      await configure();

      await expect(configure()).eventually.rejectedWith(
        'Market: Already configured'
      );
    });
  });

  describe('#setItems', () => {

    const defaultItems: Items = {
      merchant: deployerWallet.address,
      tokenAddresses: [],
      amounts: [1000],
      quantity: 10
    }

    let currency;

    beforeEach(async () => {
      await deploy();
      await configure();
      currency = await deployCurrency();
      defaultItems.tokenAddresses = [currency];
    });

    it('should not set the items if the Merchant has not approved the Market contract', async () => {
      await mintCurrency(currency, otherWallet.address, 10000);
      const auction = await auctionAs(mockTokenWallet);
      await expect(auction.setItems(defaultTokenId, {
        merchant: otherWallet.address,
        tokenAddresses: [currency],
        amounts: [1000],
        quantity: 10
      })).rejected;
    });

    it('should set the items by the merchant', async () => {
      expect(await configureItems(currency), "properly formed item setting transaction should pass");
      const auction = await auctionAs(mockTokenWallet);
      const block = await provider.getBlockNumber();
      const events = await auction.queryFilter(
          auction.filters.ItemsSet(defaultTokenId, null),
          block
      );
      expect(events.length).eq(1);
    });

    it("should refund the merchant when items are updated", async() => {
      const contractPreBalance = await getBalance(currency, auctionAddress);
      expect(contractPreBalance.toNumber()).eq(0, "contract should have no funds from the items");
      // set the items twice to trigger a refund and resetting of the items
      await configureItems(currency);
      // mint 10k & deposit 10k = balance of 0
      const beforeBalance = await getBalance(currency, otherWallet.address);
      const contractBalance = await getBalance(currency, auctionAddress);
      expect(contractBalance.toNumber()).eq(10000, "contract should have the merchants item deposit");
      expect(beforeBalance.toNumber()).eq(0, "Merchant should have nothing left over from the item deposit");
      // mint 10k & deposit 10k but get back original 10k = balance of 10k
      await configureItems(currency);
      const afterBalance = await getBalance(currency, otherWallet.address);
      expect(afterBalance.toNumber()).eq(10000, "should have 10k left over after refund of original deposit + 10k mint")
    });

    it("should emit an event when items are updated", async () => {
      // set items twice, emitting two events
      await configureItems(currency);
      await configureItems(currency);
      const auction = await auctionAs(mockTokenWallet);
      const block = await provider.getBlockNumber();
      const eventsFromBlockZero = await auction.queryFilter(
          auction.filters.ItemsSet(defaultTokenId, null),
          0,
          block
      );
      expect(eventsFromBlockZero.length).eq(2, "Should emit two events: one for the original set & another for the updated items setting");
      const eventsFromLatestBlock = await auction.queryFilter(
          auction.filters.ItemsSet(defaultTokenId, null),
          block
      );
      expect(eventsFromLatestBlock.length).eq(1, "update should trigger one ItemsSet event");
    });


  });

  describe("#setLevelRequirements", () => {

    let currency;
    let levelReq;

    beforeEach(async () => {
      await deploy();
      await configure();
      currency = await deployCurrency();
      levelReq = {...defaultLevelRequirement, token: currency, registrar: levelRegistrarAddress, setter: otherWallet.address};
    });

    it("should not be able to set a level requirement if the level does not exist", async() => {
      const auction = await auctionAs(mockTokenWallet);
      await expect(auction.setLevelRequirement(defaultTokenId, levelReq, otherWallet.address, currency)).rejectedWith("Market: level does not exist");
    });

    it("should be able to set a level requirement", async() => {
      const auction = await auctionAs(mockTokenWallet);
      const registrar = await levelRegistrarAs(otherWallet);
      await registrar.setLevels([{label: "noob", threshold: 0}], currency);
      await expect(auction.setLevelRequirement(defaultTokenId, levelReq, otherWallet.address, currency));
    });

    it("should prevent a bid if the level requirement is not met", async() => {
      const auction = await auctionAs(mockTokenWallet);
      const registrar = await levelRegistrarAs(otherWallet);
      await registrar.setLevels([{label: "noob", threshold: 1000000}], currency);
      await auction.setLevelRequirement(defaultTokenId, levelReq, otherWallet.address, currency);
      await configureItems(currency, deployerWallet);
      await mintCurrency(currency, bidderWallet.address, 500);
      await approveCurrency(currency, auction.address, bidderWallet);
      await expect(auction.setBid(defaultTokenId, {
          amount: 10,
          currency: currency,
          bidder: bidderWallet.address,
          recipient: otherWallet.address
        }, bidderWallet.address)).rejectedWith("Market: bidder does not meet the level requirement");
    });

  });

  describe("#setDiscount", () => {

    let currency;
    let discount;
    let levelReq;
    let levelRequiredPro;
    let proDiscount;

    beforeEach(async () => {
      await deploy();
      await configure();
      currency = await deployCurrency();
      levelReq = {...defaultLevelRequirement, token: currency, registrar: levelRegistrarAddress};
      discount = {...defaultDiscount, levelRequired: levelReq };
      levelRequiredPro = {...levelReq, levelLabel: "pro", discount: 10};
      proDiscount = {...discount, levelRequired: levelRequiredPro};
    });

    it('should not be able to set a discount due to the level being absent', async () => {
      const auction = await auctionAs(mockTokenWallet);
      await expect(auction.setDiscount(0, discount)).rejectedWith("Market: level does not exist");
    });

    it('should set a discount by the Merchant', async () => {
      const auction = await auctionAs(mockTokenWallet);
      const levelRegistrar = await levelRegistrarAs(deployerWallet);
      await levelRegistrar.setLevels([{ label: "noob", threshold: 100 }], currency);
      await expect(auction.setDiscount(0, discount)).fulfilled;
      const block = await provider.getBlockNumber();
      const events = await auction.queryFilter(
          auction.filters.DiscountSet(0, null),
          block
      );
      expect(events.length).to.eq(1);
    });

    it("should apply the correct discount on a bid", async() => {
      const auction = await auctionAs(mockTokenWallet);
      const levelRegistrar = await levelRegistrarAs(deployerWallet);
      await levelRegistrar.setLevels([{ label: "noob", threshold: 100 }], currency);
      await auction.setDiscount(1, discount);
      await configureItems(currency, otherWallet);
      await mintCurrency(currency, bidderWallet.address, 1000);
      await approveCurrency(currency, auction.address, bidderWallet);
      const beforeBalance = await getBalance(currency, bidderWallet.address);
      await auction.setBid(1, { amount: 100, currency: currency, bidder: bidderWallet.address, recipient: mockTokenWallet.address}, bidderWallet.address);
      const afterBalance = await getBalance(currency, bidderWallet.address);
      const bidMinusDiscount = 90;
      expect(afterBalance.toNumber()).eq((beforeBalance.toNumber() - bidMinusDiscount), "discount of 10% should be applied");
    });

    it("should apply the correct discount on a successful bid", async() => {
      const auction = await auctionAs(mockTokenWallet);
      const levelRegistrar = await levelRegistrarAs(deployerWallet);
      await levelRegistrar.setLevels([{ label: "noob", threshold: 100 }], currency);
      await auction.setDiscount(1, discount);
      await configureItems(currency, otherWallet);
      await auction.setAsk(1, { amount: 100 });
      await mintCurrency(currency, bidderWallet.address, 1000);
      await approveCurrency(currency, auction.address, bidderWallet);
      const beforeBalance = await getBalance(currency, bidderWallet.address);
      await auction.setBid(1, { amount: 100, currency: currency, bidder: bidderWallet.address, recipient: mockTokenWallet.address}, bidderWallet.address);
      const afterBalance = await getBalance(currency, bidderWallet.address);
      const bidMinusDiscount = 90;
      expect(afterBalance.toNumber()).eq((beforeBalance.toNumber() - bidMinusDiscount) + 1000, "discount of 10% should be applied with 1k tokens from merchant");
    });

    it("should not apply a discount if the buyer is not eligible on a successful bid", async() => {
      const auction = await auctionAs(mockTokenWallet);
      const levelRegistrar = await levelRegistrarAs(deployerWallet);
      await levelRegistrar.setLevels([{ label: "pro", threshold: 100000000 }], currency);
      await auction.setDiscount(1, proDiscount);
      await configureItems(currency, otherWallet);
      await auction.setAsk(1, { amount: 100 });
      await mintCurrency(currency, bidderWallet.address, 1000);
      await approveCurrency(currency, auction.address, bidderWallet);
      await auction.setBid(1, { amount: 100, currency: currency, bidder: bidderWallet.address, recipient: otherWallet.address}, bidderWallet.address);
      const afterBalance = await getBalance(currency, bidderWallet.address);
      // 100 bid - no discount + 1k from merchant item
      expect(afterBalance.toNumber()).eq(1900, "no discount should be applied");
    });

    it("should not apply a discount if the buyer is not eligible", async() => {
      const auction = await auctionAs(mockTokenWallet);
      const levelRegistrar = await levelRegistrarAs(deployerWallet);
      await levelRegistrar.setLevels([{ label: "pro", threshold: 100000000 }], currency);
      await auction.setDiscount(1, proDiscount);
      await configureItems(currency, otherWallet);
      await mintCurrency(currency, bidderWallet.address, 1000);
      await approveCurrency(currency, auction.address, bidderWallet);
      await auction.setBid(1, { amount: 100, currency: currency, bidder: bidderWallet.address, recipient: otherWallet.address}, bidderWallet.address);
      const afterBalance = await getBalance(currency, bidderWallet.address);
      // 100 bid - no discount
      expect(afterBalance.toNumber()).eq(900, "no discount should be applied");
    });

  });

  describe('#setAsk', () => {
    beforeEach(async () => {
      await deploy();
      await configure();
    });

    it('should reject if not called by the inventory address', async () => {
      const auction = await auctionAs(otherWallet);

      await expect(setAsk(auction, defaultTokenId, defaultAsk)).rejectedWith(
        'Market: Only inventory contract'
      );
    });

    it('should set the ask if called by the inventory address', async () => {
      const auction = await auctionAs(mockTokenWallet);
      await expect(setAsk(auction, defaultTokenId, defaultAsk)).fulfilled;
    });

    it('should emit an event if the ask is updated', async () => {
      const auction = await auctionAs(mockTokenWallet);

      const block = await provider.getBlockNumber();
      await setAsk(auction, defaultTokenId, defaultAsk);
      const events = await auction.queryFilter(
        auction.filters.AskCreated(null, null),
        block
      );

      expect(events.length).eq(1);
      const logDescription = auction.interface.parseLog(events[0]);
      expect(toNumWei(logDescription.args.tokenId)).to.eq(defaultTokenId);
      expect(toNumWei(logDescription.args.ask.amount)).to.eq(defaultAsk.amount);
    });

  });

  describe('#setBid', () => {
    let currency: string;
    const defaultBid = {
      amount: 100,
      currency: currency,
      bidder: bidderWallet.address,
      recipient: otherWallet.address,
      spender: bidderWallet.address
    };

    beforeEach(async () => {
      await deploy();
      await configure();
      currency = await deployCurrency();
      defaultBid.currency = currency;
    });

    it("should revert if no items are available", async() => {
      const auction = await auctionAs(mockTokenWallet);
      await expect(setBid(auction, defaultBid, defaultTokenId)).rejectedWith(
          'Market: No items left for sale'
      );
    });

    it('should revert if not called by the inventory contract', async () => {
      await configureItems(currency);
      const auction = await auctionAs(otherWallet);
      await expect(setBid(auction, defaultBid, defaultTokenId)).rejectedWith(
        'Market: Only inventory contract'
      );
    });

    it('should revert if the bidder does not have a high enough allowance for their bidding currency', async () => {
      await configureItems(currency);
      const auction = await auctionAs(mockTokenWallet);
      await expect(setBid(auction, defaultBid, defaultTokenId)).rejectedWith(
        'SafeERC20: ERC20 operation did not succeed'
      );
    });

    it('should revert if the bidder does not have enough tokens to bid with', async () => {
      await configureItems(currency);
      const auction = await auctionAs(mockTokenWallet);
      await mintCurrency(currency, defaultBid.bidder, defaultBid.amount - 1);
      await approveCurrency(currency, auction.address, bidderWallet);

      await expect(setBid(auction, defaultBid, defaultTokenId)).rejectedWith(
        'SafeERC20: ERC20 operation did not succeed'
      );
    });

    it("should revert if the bid currency has no SPEND value", async() => {
      await configureItems(currency);
      const auction = await auctionAs(mockTokenWallet);
      await mintCurrency(currency, defaultBid.bidder, defaultBid.amount);
      await approveCurrency(currency, auction.address, bidderWallet);
      await expect(
          setBid(
              auction,
              { ...defaultBid, currency: "0x0000000000000000000000000000000000000001" },
              defaultTokenId
          )
      ).rejectedWith('ExchangeMock: this address has no SPEND value');
    });

    it('should revert if the bid recipient is 0 address', async () => {
      await configureItems(currency);
      const auction = await auctionAs(mockTokenWallet);
      await mintCurrency(currency, defaultBid.bidder, defaultBid.amount);
      await approveCurrency(currency, auction.address, bidderWallet);

      await expect(
        setBid(
          auction,
          { ...defaultBid, recipient: AddressZero },
          defaultTokenId
        )
      ).rejectedWith('Market: bid recipient cannot be 0 address');
    });

    it('should accept a valid bid but not fulfill it automatically', async () => {
      await configureItems(currency);
      const auction = await auctionAs(mockTokenWallet);
      await mintCurrency(currency, defaultBid.bidder, defaultBid.amount);
      await approveCurrency(currency, auction.address, bidderWallet);

      const beforeBalance = toNumWei(
        await getBalance(currency, defaultBid.bidder)
      );

      await expect(setBid(auction, defaultBid, defaultTokenId)).fulfilled;

      const afterBalance = toNumWei(
        await getBalance(currency, defaultBid.bidder)
      );
      const bid = await auction.bidForTokenBidder(1, bidderWallet.address);
      expect(bid.currency).eq(currency);
      expect(toNumWei(bid.amount)).eq(defaultBid.amount);
      expect(bid.bidder).eq(defaultBid.bidder);
      expect(beforeBalance).eq(afterBalance + defaultBid.amount);
    });

    it('should fulfil a valid bid larger than the ask', async () => {
      await configureItems(currency);
      const auction = await auctionAs(mockTokenWallet);
      // ask is below the bid
      await auction.setAsk(1, { amount: 1000000 });

      const largerValidBid = {
        amount: 130000000,
        currency: currency,
        bidder: bidderWallet.address,
        recipient: otherWallet.address,
        spender: bidderWallet.address,
      };

      await mintCurrency(
        currency,
        largerValidBid.bidder,
        largerValidBid.amount
      );

      await approveCurrency(currency, auction.address, bidderWallet);

      const beforeBalance = toNumWei(
        await getBalance(currency, defaultBid.bidder)
      );

      await expect(setBid(auction, largerValidBid, defaultTokenId)).fulfilled;

      const afterBalance = toNumWei(
        await getBalance(currency, largerValidBid.bidder)
      );
      // Bid is removed as it is automatically fulfilled
      const bid = await auction.bidForTokenBidder(1, bidderWallet.address);
      expect(bid.currency).eq(AddressZero);
      expect(toNumWei(bid.amount)).eq(0);
      expect(bid.bidder).eq(AddressZero);
      // NB: since the bid is fulfilled automatically, the bidders gets the 1k tokens set as an item by the merchant and hands over the 130000000 from the bid
      expect(beforeBalance).eq(largerValidBid.amount);
      expect(afterBalance).eq(1000);
    });

    it('should refund the original bid if the bidder bids again', async () => {
      await configureItems(currency);
      const auction = await auctionAs(mockTokenWallet);
      await mintCurrency(currency, defaultBid.bidder, 5000);
      await approveCurrency(currency, auction.address, bidderWallet);

      const bidderBalance = toNumWei(
        await BaseErc20Factory.connect(currency, bidderWallet).balanceOf(
          bidderWallet.address
        )
      );

      await setBid(auction, defaultBid, defaultTokenId);
      await expect(
        setBid(
          auction,
          { ...defaultBid, amount: defaultBid.amount * 2 },
          defaultTokenId
        )
      ).fulfilled;

      const afterBalance = toNumWei(
        await BaseErc20Factory.connect(currency, bidderWallet).balanceOf(
          bidderWallet.address
        )
      );
      await expect(afterBalance).eq(bidderBalance - defaultBid.amount * 2);
    });

    it('should emit a bid event', async () => {
      await configureItems(currency);
      const auction = await auctionAs(mockTokenWallet);
      await mintCurrency(currency, defaultBid.bidder, 5000);
      await approveCurrency(currency, auction.address, bidderWallet);

      const block = await provider.getBlockNumber();
      await setBid(auction, defaultBid, defaultTokenId);
      const events = await auction.queryFilter(
        auction.filters.BidCreated(null, null),
        block
      );

      expect(events.length).eq(1);
      const logDescription = auction.interface.parseLog(events[0]);
      expect(toNumWei(logDescription.args.tokenId)).to.eq(defaultTokenId);
      expect(toNumWei(logDescription.args.bid.amount)).to.eq(defaultBid.amount);
      expect(logDescription.args.bid.currency).to.eq(defaultBid.currency);
    });
  });
});
