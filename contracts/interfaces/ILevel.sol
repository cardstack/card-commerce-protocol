pragma solidity ^0.4.22;

contract ILevel {
    struct CycleInfo {
        uint256 currentCycle;
        uint256 currentCycleStartBlock;
    }

    function claimLevel(address beneficiary) external;

    function levelForProof(address beneficiary, bytes calldata proof) external;

    function proofUsed(bytes calldata proof) external;
}
