pragma experimental ABIEncoderV2;

interface ILevel {
    struct CycleInfo {
        uint256 currentCycle;
        uint256 currentCycleStartBlock;
    }

    event RootSubmission(bytes32 beneficiary, uint256 cycle);
    event BeneficiaryClaimLevel(address indexed beneficiary);

    function writeRoot(bytes32 proof) external;

    // function claimLevel(address beneficiary) external;

    // function levelForProof(address beneficiary, bytes calldata proof) external;

    // function verifyProof(address beneficiary, bytes calldata proof) external;

    // function proofUsed(bytes calldata proof) external;
}
