pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

interface ILevel {
    struct Badge {
        address token;
        uint256 tokenID;
    }

    event LevelCreated(address creator);
    event LevelSet(address badgeAddress, address beneficiary);
    event LevelBadgeMinted(address badgeAddress);
    event CrossHonorCreated(address creator);

    //Level
    function createLevel(address badge) external;

    function setLevel(
        address badge,
        uint256 tokenID,
        address beneficiary
    ) external;

    function crossHonorLevel() external;

    //View
    function hasLevel(address badge, address beneficiary)
        external
        view
        returns (bool);
}
