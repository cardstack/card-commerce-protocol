pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

interface ILevel {
    struct Badge {
        address token;
        uint256 tokenID;
    }

    event LevelCreated(address badge, address creator);
    event LevelRemoved(address badge, address creator);
    event LevelSet(address badge, address beneficiary);
    event LevelUnset(address badge, address beneficiary);
    event LevelBadgeSupplied(address badge, address suppler);
    event CrossHonorAdded(address parentBadge, address childBadge);

    //Level
    function createLevel(address badge) external;

    function removeLevel(address badge) external;

    function setLevel(
        address badge,
        uint256 tokenID,
        address beneficiary
    ) external;

    function unsetLevel(address badge, address beneficiary) external;

    function addCrossLevel(address parentBadge, address childBadge) external;

    //View
    function hasLevel(address badge, address beneficiary)
        external
        view
        returns (bool);

    function isCrossLevel(address parentBadge, address childBadge)
        external
        view
        returns (bool);

    //TBD
    //Merkle Proof
}
