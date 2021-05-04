pragma solidity 0.8.0;

interface ILevelRegistrar {
    struct Level {
        // the label for the level e.g. pro
        string label;
        // the min balance required to achieve this level
        uint256 threshold;
    }

    /*
     * @dev this function allows any merchant to set a specific level for a specific token
     * @param levelsToSet - an array of level structs containing the label and required balance threshold
     * @param token - the address of the token contract
     */
    function setLevels(Level[] memory levelsToSet, address token) external;

    /*
     * @dev this function gets the levels set by a particular merchant on a particular token for a particular balance
     * @param merchant - the address of the merchant who set the level
     * @param token - the address of the token contract
     * @param balance - the balance you are checking against
     * @returns the appropriate level as set by the merchant for this balance
     */
    function getLevelByBalance(
        address merchant,
        address token,
        uint256 balance
    ) external view returns (Level memory);

    /*
     * @dev this function gets the level set by a particular merchant on a particular token for a particular user
     * @param merchant - the address of the merchant who set the level
     * @param token - the address of the token contract
     * @param user - the address of the user who will have their balance checked
     * @returns the appropriate level for the user
     */
    function getUserLevel(
        address merchant,
        address token,
        address user
    ) external view returns (Level memory);

    /*
     * @dev workaround to access a double mapping with an array
     * @param merchant - address of the merchant who set the levels
     * @param token - the contract address of the token
     * @returns the length of the levels array
     */
    function getLevelLength(address merchant, address token)
        external
        view
        returns (uint256);
}
