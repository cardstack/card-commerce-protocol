// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {Decimal} from "../Decimal.sol";

/**
 * @title Interface for Zora Protocol's Market
 */
interface IMarket {

    struct Bid {
        // Amount of the SPEND being bid
        uint256 amount;
        // Address of the bidder
        address bidder;
        // Address of the recipient
        address recipient;
    }

    struct Ask {
        // Amount of the SPEND being asked
        uint256 amount;
    }

    struct Bonus {
        // address of the merchant who has set and locked up these bonuses
        address merchant;
        // addresses of each token contract corresponding to the bonus
        address[] tokenAddresses;
        // items to send out on completion of the listing (amount or tokenId), matching the tokenAddresses index
        uint[] rewards;
    }

    struct Discount {
        // address of the merchant who has set and locked up these bonuses
        address merchant;
        // address of the token contract that holds the balance that the merchant wants to give a discount to
        address tokenContract;
        // the balance requirements for each discount threshold e.g. 100 or more is a 10% discount. Index matches discounts array
        uint[] levelThresholds;
        // the discount to apply as a decimal e.g. total cost * 0.9 for a 10% discount
        Decimal.D256[] discounts;
    }

    struct LevelRequirement {
        // the address of the token contract for which the user must have a balance in
        address tokenContract;
        // an amount of fungible tokens or a specific tokenId for an NFT
        uint requiredBalance;
    }

    event BidCreated(uint256 indexed tokenId, Bid bid);
    event BidRemoved(uint256 indexed tokenId, Bid bid);
    event BidFinalized(uint256 indexed tokenId, Bid bid);
    event AskCreated(uint256 indexed tokenId, Ask ask);
    event AskRemoved(uint256 indexed tokenId, Ask ask);

    function bidForTokenBidder(uint256 tokenId, address bidder)
        external
        view
        returns (Bid memory);

    function currentAskForToken(uint256 tokenId)
        external
        view
        returns (Ask memory);

    function isValidBid(uint256 tokenId, uint256 bidAmount)
        external
        view
        returns (bool);

    function configure(address mediaContractAddress) external;

    function setAsk(uint256 tokenId, Ask calldata ask) external;

    function setBonus(uint256 tokenId, Bonus calldata bonus) external;

    function setDiscount(uint256 tokenId, Discount calldata discount) external;

    function setLevelRequirement(uint256 tokenId, LevelRequirement calldata levelRequirement) external;

    function removeAsk(uint256 tokenId) external;

    function setBid(
        uint256 tokenId,
        Bid calldata bid,
        address spender
    ) external;

    function removeBid(uint256 tokenId, address bidder) external;

    function acceptBid(uint256 tokenId, Bid calldata expectedBid) external;
}
