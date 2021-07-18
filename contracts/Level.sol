pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import {ILevel} from "./interfaces/ILevel.sol";

contract Level is ILevel {
    using SafeMath for uint256;
    using MerkleProof for bytes32[];

    ILevel.Cycle public cycle;
    address public tally;

    mapping(uint256 => bytes32) roots;
    mapping(address => bytes32) usedProofs;

    modifier onlyTally() {
        require(tally == msg.sender, "Caller is not tally");
        _;
    }

    function writeRoot(bytes32 root) external override {
        roots[cycle.number] = root;
        emit RootSubmission(root, cycle.number);
    }

    function _startNewCycle() internal onlyTally {
        require(
            block.number > cycle.startBlock,
            "Cannot start new payment cycle before currentPaymentCycleStartBlock"
        );
        emit CycleEnded(cycle.number, cycle.startBlock, block.number);
    }
}
