pragma solidity 0.5.17;

// this is used only for getting the SPEND value, see: https://github.com/cardstack/card-protocol-xdai/blob/main/contracts/core/Exchange.sol#L62
interface IExchange {
    function convertToSpend(address payableTokenAddr, uint256 amount)
        external
        view
        returns (uint256);
}
