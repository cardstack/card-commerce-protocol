// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {Decimal} from "./Decimal.sol";
import {Inventory} from "./Inventory.sol";
import {IMarket} from "./interfaces/IMarket.sol";
import {ILevelRegistrar} from "./interfaces/ILevelRegistrar.sol";
import {IExchange} from "./interfaces/IExchange.sol";

/**
 * @title A Market for pieces of media
 * @notice This contract contains all of the market logic for Media
 */
contract Market is IMarket {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* *******
     * Globals
     * *******
     */
    // Address of the inventory contract that can call this market
    address public inventoryContract;

    // Address for the SPEND conversion contract
    address public exchangeSPENDContract;

    // Deployment Address
    address private _owner;

    // Mapping from token to mapping from bidder to bid
    mapping(uint256 => mapping(address => Bid)) private _tokenBidders;

    // Mapping from token to the current ask for the token
    mapping(uint256 => Ask) private _tokenAsks;

    // Mapping from token to the items set
    mapping(uint256 => Items) private _items;

    // Mapping from token to the level required to purchase
    mapping(uint256 => IMarket.LevelRequirement) private _levelRequirements;

    // Mapping from token to the discounts set for the listing
    mapping(uint256 => IMarket.Discount[]) private _discounts;

    /* *********
     * Modifiers
     * *********
     */

    /**
     * @notice require that the msg.sender is the configured media contract
     */
    modifier onlyMediaCaller() {
        require(inventoryContract == msg.sender, "Market: Only media contract");
        _;
    }

    /* ****************
     * View Functions
     * ****************
     */
    function bidForTokenBidder(uint256 tokenId, address bidder)
        external
        view
        override
        returns (Bid memory)
    {
        return _tokenBidders[tokenId][bidder];
    }

    function currentAskForToken(uint256 tokenId)
        external
        view
        override
        returns (Ask memory)
    {
        return _tokenAsks[tokenId];
    }

    /* ****************
     * Public Functions
     * ****************
     */

    constructor() public {
        _owner = msg.sender;
    }

    /**
     * @notice Sets the media contract address. This address is the only permitted address that
     * can call the mutable functions. This method can only be called once.
     */
    function configure(address mediaContractAddress, address exchangeSPENDAddr)
        external
        override
    {
        require(msg.sender == _owner, "Market: Only owner");
        require(inventoryContract == address(0), "Market: Already configured");
        require(
            mediaContractAddress != address(0),
            "Market: cannot set media contract as zero address"
        );
        exchangeSPENDContract = exchangeSPENDAddr;

        inventoryContract = mediaContractAddress;
    }

    /**
     * @notice Sets the ask on a particular listing in SPEND.
     */
    function setAsk(uint256 tokenId, Ask memory ask)
        public
        override
        onlyMediaCaller
    {
        _tokenAsks[tokenId] = ask;
        emit AskCreated(tokenId, ask);
    }

    /**
     * @notice removes an ask for a token and emits an AskRemoved event
     */
    function removeAsk(uint256 tokenId) external override onlyMediaCaller {
        emit AskRemoved(tokenId, _tokenAsks[tokenId]);
        delete _tokenAsks[tokenId];
    }

    function _checkUserMatchesLevelRequirement(uint256 tokenId, address spender)
        internal
    {
        LevelRequirement memory levelRequired = _levelRequirements[tokenId];
        if (levelRequired.token == address(0)) return; // no level set

        uint256 requiredBalance =
            ILevelRegistrar(levelRequired.registrar).getRequiredBalanceByLabel(
                levelRequired.merchant,
                levelRequired.token,
                levelRequired.levelLabel
            );
        require(
            IERC20(levelRequired.token).balanceOf(spender) >= requiredBalance,
            "bidder does not meet the level requirement"
        );
    }

    /**
     * @notice Sets the bid on a particular listing for a bidder. The token being used to bid
     * is transferred from the spender to this contract to be held until removed or accepted.
     * If another bid already exists for the bidder, it is refunded.
     */
    function setBid(
        uint256 tokenId,
        Bid memory bid,
        address spender
    ) public override onlyMediaCaller {
        require(bid.bidder != address(0), "Market: bidder cannot be 0 address");
        require(_items[tokenId].quantity > 0, "Market: No items left for sale");
        //TODO be aware of the edge case whereby SPEND fluctuates between the time the tx is made and confirmed
        uint256 bidSPENDValue =
            IExchange(address(exchangeSPENDContract)).convertToSpend(
                bid.currency,
                bid.amount
            );
        require(bidSPENDValue != 0, "Market: bid must have a SPEND value");
        require(
            bid.recipient != address(0),
            "Market: bid recipient cannot be 0 address"
        );

        _checkUserMatchesLevelRequirement(tokenId, spender);

        Bid storage existingBid = _tokenBidders[tokenId][bid.bidder];

        // If there is an existing bid, refund it before continuing
        if (existingBid.amount > 0) {
            removeBid(tokenId, bid.bidder);
        }

        IERC20 token = IERC20(bid.currency);

        // We must check the balance that was actually transferred to the market,
        // as some tokens impose a transfer fee and would not actually transfer the
        // full amount to the market, resulting in locked funds for refunds & bid acceptance
        uint256 beforeBalance = token.balanceOf(address(this));
        token.safeTransferFrom(spender, address(this), bid.amount);
        uint256 afterBalance = token.balanceOf(address(this));
        _tokenBidders[tokenId][bid.bidder] = Bid(
            afterBalance.sub(beforeBalance),
            bid.currency,
            bid.bidder,
            bid.recipient
        );
        emit BidCreated(tokenId, bid);
        //check if eligible for any discounts
        for (uint256 i = 0; i < _discounts[tokenId].length; i++) {
            Discount memory currentDiscount = _discounts[tokenId][i];
            string memory label = currentDiscount.levelRequired.levelLabel;
            address token = currentDiscount.levelRequired.token;
            address registrar = currentDiscount.levelRequired.registrar;
            address merchant = currentDiscount.levelRequired.merchant;
            ILevelRegistrar.Level memory userLevel =
                ILevelRegistrar(registrar).getLevelByBalance(
                    merchant,
                    token,
                    0
                );
            if (keccak256(bytes(userLevel.label)) == keccak256(bytes(label))) {
                //TODO what if you are eligible for multiple discounts? go for the top tier
                //TODO double check that this calculation can achieve the discount by price e.g. price * 0.1 for a 10% discount
                bid.amount *= currentDiscount.discount.value;
                emit DiscountApplied(tokenId, bid.bidder, currentDiscount);
                break;
            }
        }
        // If a bid meets the criteria for an ask, automatically accept the bid.
        // If no ask is set or the bid does not meet the requirements, ignore.
        if (bidSPENDValue >= _tokenAsks[tokenId].amount) {
            // Finalize exchange
            _finalizeTransfer(tokenId, bid.bidder);
        }
    }

    /**
     * @notice Removes the bid on a particular media for a bidder. The bid amount
     * is transferred from this contract to the bidder, if they have a bid placed.
     */
    function removeBid(uint256 tokenId, address bidder)
        public
        override
        onlyMediaCaller
    {
        Bid storage bid = _tokenBidders[tokenId][bidder];
        uint256 bidAmount = bid.amount;
        address bidCurrency = bid.currency;

        require(bid.amount > 0, "Market: cannot remove bid amount of 0");

        IERC20 token = IERC20(bidCurrency);

        emit BidRemoved(tokenId, bid);
        delete _tokenBidders[tokenId][bidder];
        token.safeTransfer(bidder, bidAmount);
    }

    //TODO atm only one set of items can be purchased at once, this may or may not be ok
    /**
     * @notice Accepts a bid from a particular bidder. Can only be called by the media contract.
     * See {_finalizeNFTTransfer}
     * Provided bid must match a bid in storage. This is to prevent a race condition
     * where a bid may change while the acceptBid call is in transit.
     * A bid cannot be accepted if it cannot be split equally into its shareholders.
     * This should only revert in rare instances (example, a low bid with a zero-decimal token),
     * but is necessary to ensure fairness to all shareholders.
     */
    function acceptBid(uint256 tokenId, Bid calldata expectedBid)
        external
        override
        onlyMediaCaller
    {
        Bid memory bid = _tokenBidders[tokenId][expectedBid.bidder];
        require(bid.amount > 0, "Market: cannot accept bid of 0");
        require(
            bid.amount == expectedBid.amount &&
                bid.currency == expectedBid.currency &&
                bid.recipient == expectedBid.recipient,
            "Market: Unexpected bid found."
        );

        _finalizeTransfer(tokenId, bid.bidder);
    }

    function setDiscount(
        uint256 tokenId,
        Discount memory discount,
        address merchant,
        address token
    ) public override onlyMediaCaller {
        require(
            ILevelRegistrar(discount.levelRequired.registrar)
                .getHasLevelByLabel(
                discount.levelRequired.merchant,
                discount.levelRequired.token,
                discount.levelRequired.levelLabel
            ),
            "Market: level does not exist, failed to set discount"
        );
        _discounts[tokenId].push(discount);
        emit DiscountSet(tokenId, discount);
    }

    /*
     * @dev see IMarket.sol
     */
    function setItems(uint256 tokenId, Items memory items)
        public
        override
        onlyMediaCaller
    {
        //check if there is an existing items set, if so refund
        Items memory existingItems = _items[tokenId];
        if (existingItems.tokenAddresses.length > 0) {
            // refund from the contract
            _transferItems(
                existingItems,
                address(this),
                existingItems.merchant,
                existingItems.quantity
            );
        }
        for (uint256 i = 0; i < items.tokenAddresses.length; i++) {
            // transfer to the contract
            _transferItems(
                items,
                items.merchant,
                address(this),
                items.quantity
            );
        }
        _items[tokenId] = items;
        emit ItemsSet(tokenId, items);
    }

    /*
     * @dev transfers items
     * @param items - the items to transfer
     * @param from - the address sending the tokens
     * @param to - the address receiving the items
     * @param quantity - multiple the items by this number, if merchant refund it would be all else if buyer it would just be one
     */
    function _transferItems(
        Items memory items,
        address from,
        address to,
        uint256 quantity
    ) private {
        for (uint256 i = 0; i < items.tokenAddresses.length; i++) {
            require(
                IERC20(items.tokenAddresses[i]).transferFrom(
                    from,
                    to,
                    items.amounts[i] * quantity
                )
            );
        }
    }

    /*
     * @dev see IMarket.sol
     */
    function setLevelRequirement(
        uint256 tokenId,
        LevelRequirement memory levelRequirement,
        address merchant,
        address token
    ) public override onlyMediaCaller {
        require(
            ILevelRegistrar(levelRequirement.registrar).getHasLevelByLabel(
                merchant,
                token,
                levelRequirement.levelLabel
            ),
            "Market: level does not exist"
        );
        _levelRequirements[tokenId] = levelRequirement;
        emit LevelRequirementSet(tokenId, levelRequirement);
    }

    /**
     * @notice Given a token ID and a bidder, this method transfers the value of
     * the bid to the merchant. It also transfers the ownership of the items
     * to the bid recipient. Finally, it removes the accepted bid and the current ask.
     */
    function _finalizeTransfer(uint256 tokenId, address bidder) private {
        Bid memory bid = _tokenBidders[tokenId][bidder];

        IERC20 token = IERC20(bid.currency);
        // transfer the bid amount to the merchant
        token.transferFrom(address(this), bid.recipient, bid.amount);

        Items memory items = _items[tokenId];
        for (uint256 i = 0; i < items.tokenAddresses.length; i++) {
            address token = items.tokenAddresses[i];
            uint256 amount = items.amounts[i];
            IERC20 erc20TokenToTransfer = IERC20(token);
            erc20TokenToTransfer.transferFrom(
                address(this),
                bid.bidder,
                amount
            );
        }

        // reduce the quantity by one as the buyer just purchased one item only
        _items[tokenId].quantity -= 1;

        // burn the listing if all the items are sold
        if (_items[tokenId].quantity == 0) {
            Inventory(inventoryContract).burnListing(tokenId);
        }

        // Remove the accepted bid
        delete _tokenBidders[tokenId][bidder];

        emit BidFinalized(tokenId, bid);
    }
}
