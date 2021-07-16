pragma solidity ^0.4.22;

import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/ILevel.sol";

contract Level {
    using SafeMath for uint256;
    using MerkleProof for bytes32[];

    CycleInfo public cycleInfo;
    address public tally;

    event RootSubmission(bytes32 beneficiary, uint256 cycle);
    event BeneficiaryClaimLevel(address indexed beneficiary);

    mapping(uint256 => bytes32) roots;

    modifier onlyTally() {
        require(tally == msg.sender, "Caller is not tally");
        _;
    }
}
