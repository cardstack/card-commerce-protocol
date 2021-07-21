pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

interface ILevel {
    struct Badge {
        address token;
        uint256 tokenID;
    }

    // mapping(address => address) beneficiaries; //badge <> beneficiary address

    event LevelCreated(address badge, address creator);
    event LevelRemoved(address badge, address creator);
    event LevelSet(address badge, address beneficiary);
    event LevelUnset(address badge, address beneficiary);
    event LevelBadgeSupplied(address badge, address suppler);
    event CrossHonorCreated(address creator);

    //Level
    function createLevel(address badge) external;

    function removeLevel(address badge) external;

    function setLevel(
        address badge,
        uint256 tokenID,
        address beneficiary
    ) external;

    function unsetLevel(address badge, address beneficiary) external;

    function crossHonorLevel() external;

    //View
    function hasLevel(address badge, address beneficiary)
        external
        view
        returns (bool);

    //TBD
    //Merkle Proo
}
