pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {
    MerkleProof
} from "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {ILevel} from "./interfaces/ILevel.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";

contract Level is ILevel {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using MerkleProof for bytes32[];
    using EnumerableSet for EnumerableSet.AddressSet;

    ILevel.Cycle public cycle;
    Counters.Counter private levelID;
    address public tally;
    EnumerableSet.AddressSet private _registeredBadges;

    mapping(address => Level) levels; //this requires loops. dont do this!
    mapping(address => address) beneficiaries; //nft address/level id <> address
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

    function createLevel(address badge) external override {
        _registeredBadges.add(badge);
        emit LevelCreated(msg.sender);
    }

    function setLevel(address badge, address beneficiary) external override {
        require(_registeredBadges.contains(badge), "Badge is not added");
        beneficiaries[badge] = beneficiary;
        emit LevelSet(badge, beneficiary);
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

    function getLevels(address beneficiary)
        external
        view
        override
        returns (Level memory)
    {
        return levels[beneficiary];
    }

    function hasLevel(address badge, address beneficiary)
        external
        view
        override
        returns (bool)
    {
        if (beneficiaries[badge] != address(0)) return true;
        else return false;
    }

    function _startNewCycle() internal onlyTally {
        require(
            block.number > cycle.startBlock,
            "Cannot start new payment cycle before currentPaymentCycleStartBlock"
        );
        emit CycleEnded(cycle.number, cycle.startBlock, block.number);
    }
}
