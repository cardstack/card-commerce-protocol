// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {IMarket} from "./IMarket.sol";

/**
 * @title Interface for CardPay Commerce Protocol's Inventory
 */
interface IInventory {
    struct EIP712Signature {
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct InventoryData {
        // A valid URI of the content represented by this token
        string listingURI;
        // A valid URI of the metadata associated with this token
        string metadataURI;
        // A SHA256 hash of the content pointed to by tokenURI
        bytes32 contentHash;
        // A SHA256 hash of the content pointed to by metadataURI
        bytes32 metadataHash;
    }

    event TokenURIUpdated(uint256 indexed _tokenId, address owner, string _uri);
    event TokenMetadataURIUpdated(
        uint256 indexed _tokenId,
        address owner,
        string _uri
    );

    /**
     * @notice Return the metadata URI for a piece of media given the token URI
     */
    function tokenMetadataURI(uint256 tokenId)
        external
        view
        returns (string memory);

    /**
     * @notice Mint new media for msg.sender.
     */
    function mint(InventoryData calldata data) external;

    /**
     * @notice EIP-712 mintWithSig method. Mints new media for a creator given a valid signature.
     */
    function mintWithSig(
        address creator,
        InventoryData calldata data,
        EIP712Signature calldata sig
    ) external;

    /**
     * @notice Transfer the token with the given ID to the burn address.
     * @dev This can only be called by the auction contract specified at deployment
     */
    function burnListing(uint256 tokenId) external;

    /**
     * @notice Set the ask on a piece of media
     */
    function setAsk(uint256 tokenId, IMarket.Ask calldata ask) external;

    /**
     * @notice Set items in listing
     */
    function setItems(uint256 tokenId, IMarket.Items calldata items) external;

    /**
     * @notice set a discount based on a particular level
     */
    function setDiscount(
        uint256 tokenId,
        IMarket.Discount calldata discount,
        address merchant
    ) external;

    /**
     * @notice set a level requirement for the buyers e.g. must own 100 FAN to buy
     */
    function setLevelRequirement(
        uint256 tokenId,
        IMarket.LevelRequirement calldata levelRequirement,
        address merchant,
        address token
    ) external;

    /**
     * @notice Remove the ask on a piece of media
     */
    function removeAsk(uint256 tokenId) external;

    /**
     * @notice Set the bid on a piece of media
     */
    function setBid(uint256 tokenId, IMarket.Bid calldata bid) external;

    /**
     * @notice Remove the bid on a piece of media
     */
    function removeBid(uint256 tokenId) external;

    function acceptBid(uint256 tokenId, IMarket.Bid calldata bid) external;

    /**
     * @notice Revoke approval for a piece of media
     */
    function revokeApproval(uint256 tokenId) external;

    /**
     * @notice Update the token URI
     */
    function updateTokenURI(uint256 tokenId, string calldata tokenURI) external;

    /**
     * @notice Update the token metadata uri
     */
    function updateTokenMetadataURI(
        uint256 tokenId,
        string calldata metadataURI
    ) external;

    /**
     * @notice EIP-712 permit method. Sets an approved spender given a valid signature.
     */
    function permit(
        address spender,
        uint256 tokenId,
        EIP712Signature calldata sig
    ) external;
}
