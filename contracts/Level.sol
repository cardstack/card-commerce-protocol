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
    using Counters for Counters.Counter;
    using MerkleProof for bytes32[];

    ILevel.Cycle public cycle;
    Counters.Counter private _tokenIdTracker;
    address public tally;

    mapping(address => Level) levels;
    mapping(uint256 => bytes32) roots;
    mapping(address => bytes32) usedProofs;

    modifier onlyTally() {
        require(tally == msg.sender, "Caller is not tally");
        _;
    }

    function writeRoot(bytes32 root) external override {
        roots[cycle.number] = root;
        _startNewCycle();
        emit RootSubmission(root, cycle.number);
    }

    function claimLevel(bytes calldata proof) external override {
        // verify proof here
        levels[msg.sender] = Level("hi", Badge(msg.sender, 1));
        emit BeneficiaryClaimLevel(msg.sender);
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

    // function checkLevel(address beneficiary) external view override {
    //    return levels[beneficiary].label;
    // }

    function getLevel(address beneficiary)
        external
        view
        override
        returns (Level memory)
    {
        return levels[beneficiary];
    }

    function _startNewCycle() internal onlyTally {
        require(
            block.number > cycle.startBlock,
            "Cannot start new payment cycle before currentPaymentCycleStartBlock"
        );
        emit CycleEnded(cycle.number, cycle.startBlock, block.number);
    }
}
