pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {
    MerkleProof
} from "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {ILevel} from "./interfaces/ILevel.sol";

contract Level is ILevel {
    using SafeMath for uint256;
    using MerkleProof for bytes32[];
    using Counters for Counters.Counter;

    ILevel.Cycle public cycle;
    address public tally;
    Counters.Counter private _tokenIdTracker;

    mapping(uint256 => bytes32) roots;
    mapping(address => bytes32) usedProofs;

    modifier onlyTally() {
        require(tally == msg.sender, "Caller is not tally");
        _;
    }

    modifier onlyTokenCreated(uint256 tokenId) {
        require(
            _tokenIdTracker.current() > tokenId,
            "Inventory: token with that id does not exist"
        );
        _;
    }

    function writeRoot(bytes32 root) external override {
        roots[cycle.number] = root;
        emit RootSubmission(root, cycle.number);
    }

    function claimLevel(address beneficiary) external override {
        emit BeneficiaryClaimLevel(beneficiary);
    }

    function createLevel() external override {
        emit LevelCreated(msg.sender);
    }

    function crossHonorLevel() external override {
        emit CrossHonorCreated(msg.sender);
    }

    function _mintLevelBadge() internal {
        emit LevelBadgeMinted();
    }

    function checkLevel(address beneficiary) external view override {}

    function _startNewCycle() internal onlyTally {
        require(
            block.number > cycle.startBlock,
            "Cannot start new payment cycle before currentPaymentCycleStartBlock"
        );
        emit CycleEnded(cycle.number, cycle.startBlock, block.number);
    }
}
