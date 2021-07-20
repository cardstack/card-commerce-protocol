pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

interface ILevel {
    struct Cycle {
        uint256 number;
        uint256 startBlock;
    }

    // struct Level {
    //     string label;
    //     Badge badge;
    // }

    struct Badge {
        address token;
        uint256 tokenID;
    }

    event RootSubmission(bytes32 beneficiary, uint256 cycle);
    event BeneficiaryClaimLevel(address indexed beneficiary);
    event LevelCreated(address creator);
    event LevelSet(address badgeAddress, address beneficiary);
    event LevelBadgeMinted();
    event CrossHonorCreated(address creator);

    // event CycleEnded(uint256 number, uint256 startBlock, uint256 endBlock);

    // function writeRoot(bytes32 root) external;

    // function claimLevel(bytes calldata proof) external;

    function createLevel(address badge) external;

    function setLevel(
        address badge,
        uint256 tokenID,
        address beneficiary
    ) external;

    function crossHonorLevel() external;

    // function getLevels(address beneficiary)
    //     external
    //     view
    //     returns (Level memory);

    function hasLevel(address badge, address beneficiary)
        external
        view
        returns (bool);

    // function checkLevel(address beneficiary) external view;

    // function levelForProof(address beneficiary, bytes calldata proof) external;

    // function verifyProof(address beneficiary, bytes calldata proof) external;

    // function proofUsed(bytes calldata proof) external;
}
