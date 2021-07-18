pragma experimental ABIEncoderV2;

interface ILevel {
    struct Cycle {
        uint256 number;
        uint256 startBlock;
    }

    event RootSubmission(bytes32 beneficiary, uint256 cycle);
    event BeneficiaryClaimLevel(address indexed beneficiary);
    event CycleEnded(uint256 number, uint256 startBlock, uint256 endBlock);

    function writeRoot(bytes32 proof) external;

    // function claimLevel(address beneficiary) external;

    // function levelForProof(address beneficiary, bytes calldata proof) external;

    // function verifyProof(address beneficiary, bytes calldata proof) external;

    // function proofUsed(bytes calldata proof) external;
}
