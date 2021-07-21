pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {ILevel} from "./interfaces/ILevel.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Level is ILevel {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    address public tally;
    address internal constant ZERO_ADDRESS = address(0);
    EnumerableSet.AddressSet private _registeredBadges;

    mapping(address => address) beneficiaries; //badge <> beneficiary address
    mapping(address => EnumerableSet.AddressSet) crossLevels; //parent badge <> set of child badges
    mapping(address => address) parentLevel; //child badge <> parent badge

    modifier onlyTally() {
        require(tally == msg.sender, "Caller is not tally");
        _;
    }

    function createLevel(address badge) external override {
        _registeredBadges.add(badge);
        emit LevelCreated(badge, msg.sender);
    }

    function removeLevel(address badge) external override {
        _registeredBadges.remove(badge);
        emit LevelRemoved(badge, msg.sender);
    }

    function setLevel(
        address badge,
        uint256 tokenID,
        address beneficiary
    ) external override {
        require(_registeredBadges.contains(badge), "Badge is not added");
        _supplyLevelBadge(badge, tokenID, msg.sender, beneficiary);
        beneficiaries[badge] = beneficiary;
        emit LevelSet(badge, beneficiary);
    }

    function unsetLevel(address badge, address beneficiary) external override {
        require(_registeredBadges.contains(badge), "Badge is not added");
        require(beneficiaries[badge] != ZERO_ADDRESS, "Level is not set");
        delete beneficiaries[badge];
        emit LevelUnset(badge, beneficiary);
    }

    function _supplyLevelBadge(
        address token,
        uint256 tokenId,
        address from,
        address beneficiary
    ) internal {
        IERC721(token).safeTransferFrom(from, beneficiary, tokenId);
        emit LevelBadgeSupplied(token, msg.sender);
    }

    function addCrossLevel(address parentBadge, address childBadge)
        external
        override
    {
        crossLevels[parentBadge].add(childBadge);
        parentLevel[childBadge] = parentBadge;
        emit CrossHonorAdded(parentBadge, childBadge);
    }

    // View
    function hasLevel(address badge, address beneficiary)
        external
        view
        override
        returns (bool)
    {
        if (beneficiaries[badge] != ZERO_ADDRESS) return true;
        if (parentLevel[badge] != ZERO_ADDRESS) {
            if (
                crossLevels[parentLevel[badge]].contains(badge) &&
                beneficiaries[parentLevel[badge]] != ZERO_ADDRESS
            ) return true;
        } else return false;
    }

    function isCrossLevel(address parentBadge, address childBadge)
        external
        view
        override
        returns (bool)
    {
        if (crossLevels[parentBadge].contains(childBadge)) return true;
        else return false;
    }
}
