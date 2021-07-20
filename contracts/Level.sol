pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {
    MerkleProof
} from "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {ILevel} from "./interfaces/ILevel.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Level is ILevel {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    // using MerkleProof for bytes32[];
    using EnumerableSet for EnumerableSet.AddressSet;

    // ILevel.Cycle public cycle;
    // Counters.Counter private levelID;
    address public tally;
    EnumerableSet.AddressSet private _registeredBadges;

    mapping(address => address) beneficiaries; //badge <> beneficiary address

    // mapping(uint256 => bytes32) roots;
    // mapping(address => bytes32) usedProofs;

    modifier onlyTally() {
        require(tally == msg.sender, "Caller is not tally");
        _;
    }

    // function writeRoot(bytes32 root) external override {
    //     roots[cycle.number] = root;
    //     _startNewCycle();
    //     emit RootSubmission(root, cycle.number);
    // }

    // claim level may be in reward contract
    // function claimLevel(bytes calldata proof) external override {
    //     // verify proof here
    //     emit BeneficiaryClaimLevel(msg.sender);
    // }

    // holder of nft has to tell contract
    function createLevel(address badge) external override {
        _registeredBadges.add(badge);
        emit LevelCreated(msg.sender);
    }

    function crossHonorLevel() external override {
        emit CrossHonorCreated(msg.sender);
    }

    function setLevel(
        address badge,
        uint256 tokenID,
        address beneficiary
    ) external override {
        require(_registeredBadges.contains(badge), "Badge is not added");
        _mintLevelBadge(badge, tokenID, msg.sender, beneficiary);
        beneficiaries[badge] = beneficiary;
        emit LevelSet(badge, beneficiary);
    }

    function _mintLevelBadge(
        address token,
        uint256 tokenId,
        address from,
        address beneficiary
    ) internal {
        IERC721(token).safeTransferFrom(from, beneficiary, tokenId);
        emit LevelBadgeMinted();
    }

    // function getLevels(address beneficiary)
    //     external
    //     view
    //     override
    //     returns (Level memory)
    // {
    //     return levels[beneficiary];
    // }

    function hasLevel(address badge, address beneficiary)
        external
        view
        override
        returns (bool)
    {
        if (beneficiaries[badge] != address(0)) return true;
        else return false;
    }

    // function _startNewCycle() internal onlyTally {
    //     require(
    //         block.number > cycle.startBlock,
    //         "Cannot start new payment cycle before currentPaymentCycleStartBlock"
    //     );
    //     emit CycleEnded(cycle.number, cycle.startBlock, block.number);
    // }
}
