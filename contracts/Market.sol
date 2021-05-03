// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {Decimal} from "./Decimal.sol";
import {Media} from "./Media.sol";
import {IMarket} from "./interfaces/IMarket.sol";

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
    // Address of the media contract that can call this market
    address public mediaContract;

    // Deployment Address
    address private _owner;

    // Mapping from token to mapping from bidder to bid
    mapping(uint256 => mapping(address => Bid)) private _tokenBidders;

    // Mapping from token to the current ask for the token
    mapping(uint256 => Ask) private _tokenAsks;

    /* *********
     * Modifiers
     * *********
     */

    /**
     * @notice require that the msg.sender is the configured media contract
     */
    modifier onlyMediaCaller() {
        require(mediaContract == msg.sender, "Market: Only media contract");
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

    /**
     * @notice Validates that the bid is valid by ensuring that the bid amount can be split perfectly into all the bid shares.
     *  We do this by comparing the sum of the individual share values with the amount and ensuring they are equal. Because
     *  the splitShare function uses integer division, any inconsistencies with the original and split sums would be due to
     *  a bid splitting that does not perfectly divide the bid amount.
     */
    function isValidBid(uint256 tokenId, uint256 bidAmount)
        public
        view
        override
        returns (bool)
    {
        return bidAmount != 0;
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
    function configure(address mediaContractAddress) external override {
        require(msg.sender == _owner, "Market: Only owner");
        require(mediaContract == address(0), "Market: Already configured");
        require(
            mediaContractAddress != address(0),
            "Market: cannot set media contract as zero address"
        );

        mediaContract = mediaContractAddress;
    }

    /**
     * @notice Sets the ask on a particular media. If the ask cannot be evenly split into the media's
     * bid shares, this reverts.
     */
    function setAsk(uint256 tokenId, Ask memory ask)
        public
        override
        onlyMediaCaller
    {
        require(
            isValidBid(tokenId, ask.amount),
            "Market: Ask invalid for share splitting"
        );

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

    /**
     * @notice Sets the bid on a particular media for a bidder. The token being used to bid
     * is transferred from the spender to this contract to be held until removed or accepted.
     * If another bid already exists for the bidder, it is refunded.
     */
    function setBid(
        uint256 tokenId,
        Bid memory bid,
        address spender
    ) public override onlyMediaCaller {
        require(bid.bidder != address(0), "Market: bidder cannot be 0 address");
        require(bid.amount != 0, "Market: cannot bid amount of 0");
        require(
            bid.currency != address(0),
            "Market: bid currency cannot be 0 address"
        );
        require(
            bid.recipient != address(0),
            "Market: bid recipient cannot be 0 address"
        );

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

        // If a bid meets the criteria for an ask, automatically accept the bid.
        // If no ask is set or the bid does not meet the requirements, ignore.
        if (
            _tokenAsks[tokenId].currency != address(0) &&
            bid.currency == _tokenAsks[tokenId].currency &&
            bid.amount >= _tokenAsks[tokenId].amount
        ) {
            // Finalize exchange
            _finalizeNFTTransfer(tokenId, bid.bidder);
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
        require(
            isValidBid(tokenId, bid.amount),
            "Market: Bid invalid for share splitting"
        );

        _finalizeNFTTransfer(tokenId, bid.bidder);
    }

    function setDiscountBasedOnLevel(
        uint256 tokenId,
        Discount calldata discount
    ) external override onlyMediaCaller {
        /*
            TODO implement:
            - check that the caller is authorised to set a discount
            - check the token for the levels corresponding to the discount set e.g. "noob" = 100 balance
            - if already set, replace
            - apply to the bid lockup and also the ask requirement so that the bidder can meet the original ask minus the discount
        */
    }

    function setItems(uint256 tokenId, Items calldata items)
        external
        override
        onlyMediaCaller
    {
        /*
            TODO implement:
            - check that the caller has the correct funds
            - check that the caller is authorised to add items
            - attach to the listing token id
        */
    }

    function setLevelRequirement(
        uint256 tokenId,
        LevelRequirement calldata levelRequirement
    ) external override onlyMediaCaller {
        /*
             TODO implement:
             - check caller is authorised to set a level requirement
             - tie the level requirement to the listing
             - ensure that bids that don't meet the requirement are reverted
         */
    }

    /**
     * @notice Given a token ID and a bidder, this method transfers the value of
     * the bid to the shareholders. It also transfers the ownership of the media
     * to the bid recipient. Finally, it removes the accepted bid and the current ask.
     */
    function _finalizeNFTTransfer(uint256 tokenId, address bidder) private {
        /*
             TODO:
             - change to burn the token on finalisation rather than transfer it to the buyer (since the listing NFT has no value)
             - send buyers tokens to the merchant (including any discounts the buyer is eligible for)
             - release items to the buyer
         */

        Bid memory bid = _tokenBidders[tokenId][bidder];

        IERC20 token = IERC20(bid.currency);

        // Transfer media to bid recipient
        Media(mediaContract).auctionTransfer(tokenId, bid.recipient);

        // Remove the accepted bid
        delete _tokenBidders[tokenId][bidder];

        emit BidFinalized(tokenId, bid);
    }
}
