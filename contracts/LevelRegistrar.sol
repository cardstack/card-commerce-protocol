pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ILevelRegistrar.sol";

contract LevelRegistrar is ILevelRegistrar {
    mapping(address => mapping(address => Level[])) public levels; // setter => token address => Level[]
    mapping(address => CrossLevel[]) public crossLevels;

    function setCrossLevel(CrossLevel[] memory crossLevelsToSet)
        public
        override
    {
        _clearCrossLevels(msg.sender);
        for (uint256 i = 0; i < crossLevelsToSet.length; i++) {
            crossLevels[msg.sender].push(crossLevelsToSet[i]);
        }
    }

    /*
     * @dev see ILevelRegistrar.sol
     */
    function setLevels(Level[] memory levelsToSet, address token)
        public
        override
    {
        uint256 levelLength = getLevelLength(msg.sender, token);
        _clearLevels(msg.sender, token, levelLength);
        for (uint256 i = 0; i < levelsToSet.length; i++) {
            levels[msg.sender][token].push(levelsToSet[i]);
        }
    }

    /*
     * @dev helper function to clear the levels for re assignment
     * @param setter - address of the user who set the levels
     * @param token - the contract address of the token
     * @param levelLength - the length of the array to delete
     */
    function _clearLevels(
        address setter,
        address token,
        uint256 levelLength
    ) internal {
        for (uint256 i = 0; i < levelLength; i++) {
            delete levels[setter][token][i];
        }
    }

    /*
     * @dev helper function to clear the cross levels for re assignment
     * @param setter - address of the user who set the levels
     */
    function _clearCrossLevels(address setter) internal {
        for (uint256 i = 0; i < crossLevels[setter].length; i++) {
            delete crossLevels[setter][i];
        }
    }

    /*
     * @dev see ILevelRegistrar.sol
     */
    function getLevelByBalance(
        address setter,
        address token,
        uint256 balance
    ) public view override returns (Level memory) {
        uint256 levelLength = getLevelLength(setter, token);
        Level memory levelByBalance;
        for (uint256 i = 0; i < levelLength; i++) {
            Level memory level = levels[setter][token][i];
            if (balance < level.threshold) {
                break;
            }
            levelByBalance = level;
        }

        return levelByBalance;
    }

    /*
     * @dev see ILevelRegistrar.sol
     */
    function getRequiredBalanceByLabel(
        address setter,
        address token,
        string memory label
    ) public view override returns (uint256) {
        uint256 levelLength = getLevelLength(setter, token);
        for (uint256 i = 0; i < levelLength; i++) {
            Level memory level = levels[setter][token][i];
            if (keccak256(bytes(level.label)) == keccak256(bytes(label))) {
                return level.threshold;
            }
        }
        // not found therefore no required balance
        return 0;
    }

    /*
     * @dev see ILevelRegistrar.sol
     */
    function getHasLevelByLabel(
        address setter,
        address token,
        string memory levelLabel
    ) public view override returns (bool) {
        uint256 length = getLevelLength(setter, token);
        for (uint256 i = 0; i < length; i++) {
            Level memory currentLevel = levels[setter][token][i];
            if (
                keccak256(bytes(currentLevel.label)) ==
                keccak256(bytes(levelLabel))
            ) {
                return true;
            }
        }

        return false;
    }

    /*
     * @dev see ILevelRegistrar.sol
     */
    function getUserLevel(
        address setter,
        address token,
        address user
    ) public view override returns (Level memory) {
        IERC20 erc20 = IERC20(token);
        uint256 balance = erc20.balanceOf(user);

        return getLevelByBalance(setter, token, balance);
    }

    /*
     * @dev see ILevelRegistrar.sol
     */
    function getLevelLength(address setter, address token)
        public
        view
        override
        returns (uint256)
    {
        return levels[setter][token].length;
    }

    /*
     * @dev see ILevelRegistrar.sol
     */
    function getCrossLevelLength(address setter)
        public
        view
        override
        returns (uint256)
    {
        return crossLevels[setter].length;
    }

    /*
     * @dev see ILevelRegistrar.sol
     */
    function getHasLevel(
        address setter,
        address token,
        Level memory level
    ) public view override returns (bool) {
        uint256 length = getLevelLength(setter, token);
        for (uint256 i = 0; i < length; i++) {
            Level memory currentLevel = levels[setter][token][i];
            if (
                keccak256(
                    abi.encodePacked(currentLevel.label, currentLevel.threshold)
                ) == keccak256(abi.encodePacked(level.label, level.threshold))
            ) {
                return true;
            }
        }

        return false;
    }
}
