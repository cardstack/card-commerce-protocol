pragma solidity 0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // TODO update the dependency or downgrade the compiler version
import "./interfaces/ILevelRegistrar.sol";

contract LevelRegistrar is ILevelRegistrar {
    mapping(address => mapping(address => Level[])) public levels; // merchant => token address => Level[]

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
     * @param merchant - address of the merchant who set the levels
     * @param token - the contract address of the token
     * @returns the length of the levels array
     */
    function _clearLevels(
        address merchant,
        address token,
        uint256 levelLength
    ) internal {
        for (uint256 i = 0; i < levelLength; i++) {
            delete levels[msg.sender][token][i];
        }
    }

    /*
     * @dev see ILevelRegistrar.sol
     */
    function getLevelByBalance(
        address merchant,
        address token,
        uint256 balance
    ) public view override returns (Level memory) {
        uint256 levelLength = getLevelLength(merchant, token);
        Level memory levelByBalance;
        for (uint256 i = 0; i < levelLength; i++) {
            Level memory level = levels[msg.sender][token][i];
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
    function getUserLevel(
        address merchant,
        address token,
        address user
    ) public view override returns (Level memory) {
        IERC20 erc20 = IERC20(token);
        uint256 balance = erc20.balanceOf(user);

        return getLevelByBalance(merchant, token, balance);
    }

    /*
     * @dev see ILevelRegistrar.sol
     */
    function getLevelLength(address merchant, address token)
        public
        view
        override
        returns (uint256)
    {
        return levels[merchant][token].length;
    }
}
