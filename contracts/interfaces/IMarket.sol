// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import {Decimal} from "../Decimal.sol";
import {ILevelRegistrar} from "./ILevelRegistrar.sol";

/**
 * @title Interface for Zora Protocol's Market
 */
interface IMarket {
    struct Bid {
        // Amount of the SPEND being bid
        uint256 amount;
        // the currency used in the bid
        address currency;
        // Address of the bidder
        address bidder;
        // Address of the recipient
        address recipient;
    }

    struct Ask {
        // Amount of the SPEND being asked, convert the bid value to SPEND in real time and satisfy the condition if >= the amount specified
        uint256 amount;
    }

    struct Items {
        // address of the merchant who has set and locked up these bonuses
        address merchant;
        // addresses of each token contract corresponding to the bonus
        address[] tokenAddresses;
        // items to send out on completion of the listing (amount or tokenId), matching the tokenAddresses index
        uint256[] amounts;
        // the quantity of these items as per the listing e.g. I am selling 10 products under the same listing NFT, requires a lockup of items * quantity
        uint256 quantity;
    }

    struct Discount {
        // the level requirement to be eligible for this discount
        LevelRequirement levelRequired;
        // the discount to apply as a decimal e.g. total cost * 0.9 for a 10% discount
        Decimal.D256 discount;
    }

    // we don't put the level struct in here because this level requirement needs to dynamically change if the level label gets set to a new threshold
    struct LevelRequirement {
        // the address of the user who set this level requirement
        address setter;
        // the address of the registrar contract that records the levels
        address registrar;
        // address of the token
        address token;
        // the minimum level required to make the bid
        string levelLabel;
    }

    event BidCreated(uint256 indexed tokenId, Bid bid);
    event BidRemoved(uint256 indexed tokenId, Bid bid);
    event BidFinalized(uint256 indexed tokenId, Bid bid);
    event AskCreated(uint256 indexed tokenId, Ask ask);
    event AskRemoved(uint256 indexed tokenId, Ask ask);
    event ItemsSet(uint256 indexed tokenId, Items items);
    event DiscountApplied(
        uint256 indexed tokenId,
        address indexed bidder,
        Discount discount
    );
    event DiscountSet(uint256 indexed tokenId, Discount discount);
    event LevelRequirementSet(
        uint256 indexed tokenId,
        LevelRequirement levelRequirement
    );

    function bidForTokenBidder(uint256 tokenId, address bidder)
        external
        view
        returns (Bid memory);

    function currentAskForToken(uint256 tokenId)
        external
        view
        returns (Ask memory);

    function configure(
        address inventoryContractAddress,
        address exchangeSPENDAddr
    ) external;

    function setAsk(uint256 tokenId, Ask calldata ask) external;

    function setItems(uint256 tokenId, Items calldata items) external;

    function setDiscount(uint256 tokenId, Discount calldata discount) external;

    function setLevelRequirement(
        uint256 tokenId,
        LevelRequirement calldata levelRequirement,
        address merchant,
        address token
    ) external;

    function removeAsk(uint256 tokenId) external;

    function setBid(
        uint256 tokenId,
        Bid calldata bid,
        address spender
    ) external;

    function removeBid(uint256 tokenId, address bidder) external;

    function acceptBid(uint256 tokenId, Bid calldata expectedBid) external;
}
