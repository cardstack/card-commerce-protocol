pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

interface ILevelRegistrar {
    struct Level {
        // the label for the level e.g. pro
        string label;
        // the min balance required to achieve this level
        uint256 threshold;
    }

    struct CrossLevel {
        // the globally set level e.g. star alliance gold
        string globalLevelLabel;
        // the levels that fall under this globally set level e.g. united ruby, air NZ gold etc.
        string[] recognisedLevelsByLabel;
        // the addresses of the users who set the recognised levels
        address[] setters;
        // the addresses of the tokens that the merchants set a level to
        address[] tokens;
    }

    /*
     * @dev this function allows anyone to set a cross level
     * @param crossLevelsToSet - an array of CrossLevel structs
     */
    function setCrossLevel(CrossLevel[] calldata crossLevelsToSet) external;

    /*
     * @dev this function allows any merchant to set a specific level for a specific token
     * @param levelsToSet - an array of level structs containing the label and required balance threshold
     * @param token - the address of the token contract
     */
    function setLevels(Level[] calldata levelsToSet, address token) external;

    /*
     * @dev this function gets the levels set by a particular merchant on a particular token for a particular balance
     * @param setter - the address of the user who set the level
     * @param token - the address of the token contract
     * @param balance - the balance you are checking against
     * @returns the appropriate level as set by the merchant for this balance
     */
    function getLevelByBalance(
        address setter,
        address token,
        uint256 balance
    ) external view returns (Level memory);

    /*
     * @dev get the required balance for a particular level by its label
     * @param setter - the address of the user who set the level
     * @param token - the address of the token contract
     * @param label - the string label e.g. "pro"
     * @returns the required balance for this level
     */
    function getRequiredBalanceByLabel(
        address setter,
        address token,
        string calldata label
    ) external view returns (uint256);

    /*
     * @dev this function gets the level set by a particular merchant on a particular token for a particular user
     * @param setter - the address of the user who set the level
     * @param token - the address of the token contract
     * @param user - the address of the user who will have their balance checked
     * @returns the appropriate level for the user
     */
    function getUserLevel(
        address setter,
        address token,
        address user
    ) external view returns (Level memory);

    /*
     * @dev get the length of the array for levels
     * @param setter - address of the user who set the levels
     * @param token - the contract address of the token
     * @returns the length of the levels array
     */
    function getLevelLength(address setter, address token)
        external
        view
        returns (uint256);

    /*
     * @dev get the length of the array for cross levels
     * @param setter - address of the user who set the levels
     * @param token - the contract address of the token
     * @returns the length of the levels array
     */
    function getCrossLevelLength(address setter)
        external
        view
        returns (uint256);

    /*
     * @dev check if a particular level exists in the registrar
     * @param setter - address of the user who set the levels
     * @param token - the contract address of the token
     * @param level - the level to check for existence
     * @returns true if found else false
     */
    function getHasLevel(
        address setter,
        address token,
        Level calldata level
    ) external view returns (bool);

    /*
     * @dev check if a particular level by label exists in the registrar
     * @param setter - address of the user who set the levels
     * @param token - the contract address of the token
     * @param levelLabel - the level label to check for existence
     * @returns true if found else false
     */
    function getHasLevelByLabel(
        address setter,
        address token,
        string calldata levelLabel
    ) external view returns (bool);
}
