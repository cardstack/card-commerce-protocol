// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

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
contract Market is IMarket, OwnableUpgradeable {
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
    modifier onlyInventoryCaller() {
        require(
            inventoryContract == msg.sender,
            "Market: Only inventory contract"
        );
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
    function initialize() initializer public {
      __Ownable_init();
    }

    /**
     * @notice Sets the media contract address. This address is the only permitted address that
     * can call the mutable functions. This method can only be called once.
     */
    function configure(
        address inventoryContractAddress,
        address exchangeSPENDAddr
    ) external override onlyOwner {
        require(inventoryContract == address(0), "Market: Already configured");
        require(
            inventoryContractAddress != address(0),
            "Market: cannot set media contract as zero address"
        );
        exchangeSPENDContract = exchangeSPENDAddr;

        inventoryContract = inventoryContractAddress;
    }

    /**
     * @notice Sets the ask on a particular listing in SPEND.
     */
    function setAsk(uint256 tokenId, Ask memory ask)
        public
        override
        onlyInventoryCaller
    {
        _tokenAsks[tokenId] = ask;
        emit AskCreated(tokenId, ask);
    }

    /**
     * @notice removes an ask for a token and emits an AskRemoved event
     */
    function removeAsk(uint256 tokenId) external override onlyInventoryCaller {
        emit AskRemoved(tokenId, _tokenAsks[tokenId]);
        delete _tokenAsks[tokenId];
    }

    function _checkUserMatchesLevelRequirement(uint256 tokenId, address spender)
        internal
        view
    {
        LevelRequirement memory levelRequired = _levelRequirements[tokenId];
        if (levelRequired.token == address(0)) return; // no level set

        uint256 requiredBalance =
            ILevelRegistrar(levelRequired.registrar).getRequiredBalanceByLabel(
                levelRequired.setter,
                levelRequired.token,
                levelRequired.levelLabel
            );
        require(
            IERC20(levelRequired.token).balanceOf(spender) >= requiredBalance,
            "Market: bidder does not meet the level requirement"
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
    ) public override onlyInventoryCaller {
        require(bid.bidder != address(0), "Market: bidder cannot be 0 address");
        require(_items[tokenId].quantity > 0, "Market: No items left for sale");
        uint256 bidSPENDValue =
            IExchange(address(exchangeSPENDContract)).convertToSpend(
                bid.currency,
                bid.amount
            );
        // Null address check & zero bid check are no longer required as it is caught by SPEND value check
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

        // Check if eligible for any discounts and apply if applicable
        Discount memory discount = _getDiscount(tokenId, bid.bidder);
        if (discount.discount.value > 0) {
            // apply discount but preserve original bidSPENDValue for comparing against the ask
            bid.amount -= Decimal.mul(bid.amount, discount.discount).div(100);
            emit DiscountApplied(tokenId, bid.bidder, discount);
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
        // If a bid meets the criteria for an ask, automatically accept the bid.
        // If no ask is set or the bid does not meet the requirements, ignore.
        if (
            bidSPENDValue >= _tokenAsks[tokenId].amount &&
            _tokenAsks[tokenId].amount != 0
        ) {
            // Finalize exchange
            _finalizeTransfer(tokenId, bid.bidder);
        }
    }

    /**
     * @notice gets the discount applicable to a listing for a given bidder
     */
    function _getDiscount(uint256 tokenId, address bidder)
        internal
        view
        returns (Discount memory)
    {
        Discount memory discount;
        for (uint256 i = 0; i < _discounts[tokenId].length; i++) {
            Discount memory currentDiscount = _discounts[tokenId][i];
            string memory label = currentDiscount.levelRequired.levelLabel;
            address token = currentDiscount.levelRequired.token;
            uint256 userBalance = IERC20(token).balanceOf(bidder);
            address registrar = currentDiscount.levelRequired.registrar;
            address merchant = currentDiscount.levelRequired.setter;
            ILevelRegistrar.Level memory userLevel =
                ILevelRegistrar(registrar).getLevelByBalance(
                    merchant,
                    token,
                    userBalance
                );
            if (keccak256(bytes(userLevel.label)) == keccak256(bytes(label))) {
                if (currentDiscount.discount.value > discount.discount.value) {
                    discount = currentDiscount;
                }
            }
        }
        return discount;
    }

    /**
     * @notice Removes the bid on a particular media for a bidder. The bid amount
     * is transferred from this contract to the bidder, if they have a bid placed.
     */
    function removeBid(uint256 tokenId, address bidder)
        public
        override
        onlyInventoryCaller
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
        onlyInventoryCaller
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

    function setDiscount(uint256 tokenId, Discount memory discount)
        public
        override
        onlyInventoryCaller
    {
        require(
            ILevelRegistrar(discount.levelRequired.registrar)
                .getHasLevelByLabel(
                discount.levelRequired.setter,
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
        onlyInventoryCaller
    {
        //check if there is an existing items set, if so refund
        Items memory existingItems = _items[tokenId];
        if (existingItems.quantity > 0) {
            // refund from the contract
            _transferItems(
                existingItems,
                address(this),
                existingItems.merchant,
                existingItems.quantity
            );
        }
        // transfer to the contract
        _transferItems(items, items.merchant, address(this), items.quantity);
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
        if (address(this) == from) {
            // Cannot use transferFrom because the contract has no allowance on itself...
            _transferItemsFromContract(items, to, quantity);
        } else {
            _transferItemsOnBehalfOfUser(items, from, to, quantity);
        }
    }

    /*
     * See _transferItems
     */
    function _transferItemsOnBehalfOfUser(
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
                    items.amounts[i].mul(quantity)
                ),
                "Market: failed to transfer items on behalf of the user"
            );
        }
    }

    /*
     * See _transferItems
     */
    function _transferItemsFromContract(
        Items memory items,
        address to,
        uint256 quantity
    ) private {
        for (uint256 i = 0; i < items.tokenAddresses.length; i++) {
            require(
                IERC20(items.tokenAddresses[i]).transfer(
                    to,
                    items.amounts[i].mul(quantity)
                ),
                "Market: failed to transfer items from the contract"
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
    ) public override onlyInventoryCaller {
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

        // transfer the items out to the bidder
        Items memory items = _items[tokenId];
        _transferItems(items, address(this), bid.bidder, 1);

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
