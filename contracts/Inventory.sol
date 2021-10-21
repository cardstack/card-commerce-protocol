pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ERC721Burnable} from "./ERC721Burnable.sol";
import {ERC721} from "./ERC721.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";
// import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {Decimal} from "./Decimal.sol";
import {IMarket} from "./interfaces/IMarket.sol";
import "./interfaces/IInventory.sol";

/**
 * @title A media value system, with perpetual equity to creators
 * @notice This contract provides an interface to mint media with a market
 * owned by the creator.
 */
contract Inventory is IInventory, ERC721Burnable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    /* *******
     * Globals
     * *******
     */

    // Address for the market
    address public marketContract;

    // Mapping from token to previous owner of the token
    mapping(uint256 => address) public previousTokenOwners;

    // Mapping from token id to merchant address
    mapping(uint256 => address) public merchants;

    // Mapping from creator address to their (enumerable) set of created tokens
    mapping(address => EnumerableSet.UintSet) private _listingIds;

    // Mapping from token id to sha256 hash of content
    mapping(uint256 => bytes32) public tokenContentHashes;

    // Mapping from token id to sha256 hash of metadata
    mapping(uint256 => bytes32) public tokenMetadataHashes;

    // Mapping from token id to metadataDID
    mapping(uint256 => string) private _tokenMetadataDIDs;

    // Mapping from contentHash to bool
    mapping(bytes32 => bool) private _contentHashes;

    //keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x49ecf333e5b8c95c40fdafc95c1ad136e8914a8fb55e9dc8bb01eaa83a2df9ad;

    //keccak256("MintWithSig(bytes32 contentHash,bytes32 metadataHash,uint256 nonce,uint256 deadline)");
    bytes32 public constant MINT_WITH_SIG_TYPEHASH =
        0xb8e306ed6e9440d7144689fef1dae9b858f47d62ff7c9fd9b88d1c353ab85fc9;

    // Mapping from address to token id to permit nonce
    mapping(address => mapping(uint256 => uint256)) public permitNonces;

    // Mapping from address to mint with sig nonce
    mapping(address => uint256) public mintWithSigNonces;

    /*
     *     bytes4(keccak256('name()')) == 0x06fdde03
     *     bytes4(keccak256('symbol()')) == 0x95d89b41
     *     bytes4(keccak256('tokenURI(uint256)')) == 0xc87b56dd
     *     bytes4(keccak256('tokenMetadataDID(uint256)')) == 0x157c3df9
     *
     *     => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd ^ 0x157c3df9 == 0x4e222e66
     */
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x4e222e66;

    Counters.Counter private _tokenIdTracker;

    /* *********
     * Modifiers
     * *********
     */

    /**
     * @notice Require that the token has not been burned and has been minted
     */
    modifier onlyExistingToken(uint256 tokenId) {
        require(_exists(tokenId), "Inventory: nonexistent token");
        _;
    }

    /**
     * @notice Require that the token has had a content hash set
     */
    modifier onlyTokenWithContentHash(uint256 tokenId) {
        require(
            tokenContentHashes[tokenId] != 0,
            "Inventory: token does not have hash of created content"
        );
        _;
    }

    /**
     * @notice Require that the token has had a metadata hash set
     */
    modifier onlyTokenWithMetadataHash(uint256 tokenId) {
        require(
            tokenMetadataHashes[tokenId] != 0,
            "Inventory: token does not have hash of its metadata"
        );
        _;
    }

    /**
     * @notice Ensure that the provided spender is the approved or the owner of
     * the media for the specified tokenId
     */
    modifier onlyApprovedOrOwner(address spender, uint256 tokenId) {
        require(
            _isApprovedOrOwner(spender, tokenId),
            "Inventory: Only approved or owner"
        );
        _;
    }

    /**
     * @notice Ensure the token has been created (even if it has been burned)
     */
    modifier onlyTokenCreated(uint256 tokenId) {
        require(
            _tokenIdTracker.current() > tokenId,
            "Inventory: token with that id does not exist"
        );
        _;
    }

    /**
     * @notice Ensure that the provided URI is not empty
     */
    modifier onlyValidURI(string memory uri) {
        require(
            bytes(uri).length != 0,
            "Inventory: specified URI must be non-empty"
        );
        _;
    }

    /**
     * @notice Ensure that the provided URI is not empty
     */
    modifier onlyValidDID(string memory did) {
        require(
            bytes(did).length != 0,
            "Inventory: specified DID must be non-empty"
        );
        _;
    }

    /**
     * @notice On deployment, set the market contract address and register the
     * ERC721 metadata interface
     */
    function initialize(address marketContractAddr) initializer public {
        __ERC721_init("CardPay Inventory", "CPI");
        __Ownable_init();

        marketContract = marketContractAddr;
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
    }

    /* **************
     * View Functions
     * **************
     */

    /**
     * @notice return the URI for a particular piece of media with the specified tokenId
     * @dev This function is an override of the base OZ implementation because we
     * will return the tokenURI even if the media has been burned. In addition, this
     * protocol does not support a base URI, so relevant conditionals are removed.
     * @return the URI for a token
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        onlyTokenCreated(tokenId)
        returns (string memory)
    {
        string memory _tokenURI = _tokenURIs[tokenId];

        return _tokenURI;
    }

    /**
     * @notice Return the metadata URI for a piece of media given the token URI
     * @return the metadata URI for the token
     */
    function tokenMetadataDID(uint256 tokenId)
        external
        view
        override
        onlyTokenCreated(tokenId)
        returns (string memory)
    {
        return _tokenMetadataDIDs[tokenId];
    }

    /* ****************
     * Public Functions
     * ****************
     */

    /**
     * @notice see IInventory
     */
    function mint(InventoryData memory data) public override nonReentrant {
        _mintForCreator(msg.sender, data);
    }

    /**
     * @notice see IInventory
     */
    function mintWithSig(
        address creator,
        InventoryData memory data,
        EIP712Signature memory sig
    ) public override nonReentrant {
        require(
            sig.deadline == 0 || sig.deadline >= block.timestamp,
            "Inventory: mintWithSig expired"
        );

        bytes32 domainSeparator = _calculateDomainSeparator();

        bytes32 digest =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator,
                    keccak256(
                        abi.encode(
                            MINT_WITH_SIG_TYPEHASH,
                            data.contentHash,
                            data.metadataHash,
                            mintWithSigNonces[creator]++,
                            sig.deadline
                        )
                    )
                )
            );

        address recoveredAddress = ecrecover(digest, sig.v, sig.r, sig.s);

        require(
            recoveredAddress != address(0) && creator == recoveredAddress,
            "Inventory: Signature invalid"
        );

        _mintForCreator(recoveredAddress, data);
    }

    /**
     * @notice see IInventory
     */
    function burnListing(uint256 tokenId) external override {
        require(
            msg.sender == marketContract,
            "Inventory: only market contract"
        );
        _burn(tokenId);
    }

    /**
     * @notice see IInventory
     */
    function setAsk(uint256 tokenId, IMarket.Ask memory ask)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IMarket(marketContract).setAsk(tokenId, ask);
    }

    /**
     * @notice see IInventory
     */
    function removeAsk(uint256 tokenId)
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IMarket(marketContract).removeAsk(tokenId);
    }

    /**
     * @notice see IInventory
     */
    function setBid(uint256 tokenId, IMarket.Bid memory bid)
        public
        override
        nonReentrant
        onlyExistingToken(tokenId)
    {
        require(
            msg.sender == bid.bidder,
            "Inventory: Bidder must be msg sender"
        );
        IMarket(marketContract).setBid(tokenId, bid, msg.sender);
    }

    /**
     * @notice see IInventory
     */
    function removeBid(uint256 tokenId)
        external
        override
        nonReentrant
        onlyTokenCreated(tokenId)
    {
        IMarket(marketContract).removeBid(tokenId, msg.sender);
    }

    /**
     * @notice see IInventory
     */
    function acceptBid(uint256 tokenId, IMarket.Bid memory bid)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IMarket(marketContract).acceptBid(tokenId, bid);
    }

    /**
     * @notice see IInventory
     */
    function setDiscount(uint256 tokenId, IMarket.Discount memory discount)
        public
        override
        nonReentrant
        onlyExistingToken(tokenId)
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IMarket(marketContract).setDiscount(tokenId, discount);
    }

    /**
     * @notice see IInventory
     */
    function setItems(uint256 tokenId, IMarket.Items memory items)
        public
        override
        nonReentrant
        onlyExistingToken(tokenId)
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        require(
            msg.sender == items.merchant,
            "Market: Merchant must be msg sender"
        );
        IMarket(marketContract).setItems(tokenId, items);
    }

    /**
     * @notice see IInventory
     */
    function setLevelRequirement(
        uint256 tokenId,
        IMarket.LevelRequirement memory levelRequirement,
        address merchant,
        address token
    )
        public
        override
        nonReentrant
        onlyExistingToken(tokenId)
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IMarket(marketContract).setLevelRequirement(
            tokenId,
            levelRequirement,
            merchant,
            token
        );
    }

    /**
     * @notice Burn a token.
     * @dev Only callable if the media owner is also the creator.
     */
    function burn(uint256 tokenId)
        public
        override
        nonReentrant
        onlyExistingToken(tokenId)
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        address owner = ownerOf(tokenId);

        require(
            merchants[tokenId] == owner,
            "Inventory: owner is not creator of media"
        );

        _burn(tokenId);
    }

    /**
     * @notice Revoke the approvals for a token. The provided `approve` function is not sufficient
     * for this protocol, as it does not allow an approved address to revoke it's own approval.
     * In instances where a 3rd party is interacting on a user's behalf via `permit`, they should
     * revoke their approval once their task is complete as a best practice.
     */
    function revokeApproval(uint256 tokenId) external override nonReentrant {
        require(
            msg.sender == getApproved(tokenId),
            "Inventory: caller not approved address"
        );
        _approve(address(0), tokenId);
    }

    /**
     * @notice see IInventory
     * @dev only callable by approved or owner
     */
    function updateTokenURI(uint256 tokenId, string calldata tokenURI)
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
        onlyTokenWithContentHash(tokenId)
        onlyValidURI(tokenURI)
    {
        _setTokenURI(tokenId, tokenURI);
        emit TokenURIUpdated(tokenId, msg.sender, tokenURI);
    }

    /**
     * @notice see IInventory
     * @dev only callable by approved or owner
     */
    function updateTokenMetadataDID(
        uint256 tokenId,
        string calldata metadataDID
    )
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
        onlyTokenWithMetadataHash(tokenId)
        onlyValidDID(metadataDID)
    {
        _setTokenMetadataDID(tokenId, metadataDID);
        emit TokenMetadataDIDUpdated(tokenId, msg.sender, metadataDID);
    }

    /**
     * @notice see IInventory
     * @dev This method is loosely based on the permit for ERC-20 tokens in  EIP-2612, but modified
     * for ERC-721.
     */
    function permit(
        address spender,
        uint256 tokenId,
        EIP712Signature memory sig
    ) public override nonReentrant onlyExistingToken(tokenId) {
        require(
            sig.deadline == 0 || sig.deadline >= block.timestamp,
            "Inventory: Permit expired"
        );
        require(spender != address(0), "Inventory: spender cannot be 0x0");
        bytes32 domainSeparator = _calculateDomainSeparator();

        bytes32 digest =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            spender,
                            tokenId,
                            permitNonces[ownerOf(tokenId)][tokenId]++,
                            sig.deadline
                        )
                    )
                )
            );

        address recoveredAddress = ecrecover(digest, sig.v, sig.r, sig.s);

        require(
            recoveredAddress != address(0) &&
                ownerOf(tokenId) == recoveredAddress,
            "Inventory: Signature invalid"
        );

        _approve(spender, tokenId);
    }

    /* *****************
     * Private Functions
     * *****************
     */

    /**
     * @notice Creates a new token for `creator`. Its token ID will be automatically
     * assigned (and available on the emitted {IERC721-Transfer} event), and the token
     * URI autogenerated based on the base URI passed at construction.
     *
     * See {ERC721-_safeMint}.
     *
     * On mint, also set the sha256 hashes of the content and its metadata for integrity
     * checks, along with the initial URIs to point to the content and metadata. Attribute
     * the token ID to the creator, mark the content hash as used, and set the bid shares for
     * the media's market.
     *
     * Note that although the content hash must be unique for future mints to prevent duplicate media,
     * metadata has no such requirement.
     */
    function _mintForCreator(address creator, InventoryData memory data)
        internal
        onlyValidURI(data.listingURI)
        onlyValidDID(data.metadataDID)
    {
        require(
            data.contentHash != 0,
            "Inventory: content hash must be non-zero"
        );
        require(
            _contentHashes[data.contentHash] == false,
            "Inventory: a token has already been created with this content hash"
        );
        require(
            data.metadataHash != 0,
            "Inventory: metadata hash must be non-zero"
        );

        uint256 tokenId = _tokenIdTracker.current();

        _safeMint(creator, tokenId);
        _tokenIdTracker.increment();
        _setTokenContentHash(tokenId, data.contentHash);
        _setTokenMetadataHash(tokenId, data.metadataHash);
        _setTokenMetadataDID(tokenId, data.metadataDID);
        _setTokenURI(tokenId, data.listingURI);
        _listingIds[creator].add(tokenId);
        _contentHashes[data.contentHash] = true;

        merchants[tokenId] = creator;
        previousTokenOwners[tokenId] = creator;
    }

    function _setTokenContentHash(uint256 tokenId, bytes32 contentHash)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenContentHashes[tokenId] = contentHash;
    }

    function _setTokenMetadataHash(uint256 tokenId, bytes32 metadataHash)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenMetadataHashes[tokenId] = metadataHash;
    }

    function _setTokenMetadataDID(uint256 tokenId, string memory metadataDID)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        _tokenMetadataDIDs[tokenId] = metadataDID;
    }

    /**
     * @notice Destroys `tokenId`.
     * @dev We modify the OZ _burn implementation to
     * maintain metadata and to remove the
     * previous token owner from the piece
     */
    function _burn(uint256 tokenId) internal override {
        string memory tokenURI = _tokenURIs[tokenId];

        super._burn(tokenId);

        if (bytes(tokenURI).length != 0) {
            _tokenURIs[tokenId] = tokenURI;
        }

        delete previousTokenOwners[tokenId];
    }

    /**
     * @dev Calculates EIP712 DOMAIN_SEPARATOR based on the current contract and chain ID.
     */
    function _calculateDomainSeparator() internal view returns (bytes32) {
        uint256 chainID;
        /* solium-disable-next-line */
        assembly {
            chainID := chainid()
        }

        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes("CardPay Inventory")),
                    keccak256(bytes("1")),
                    chainID,
                    address(this)
                )
            );
    }
}
