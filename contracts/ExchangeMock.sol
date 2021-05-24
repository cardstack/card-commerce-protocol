pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {IExchange} from "./interfaces/IExchange.sol";

contract ExchangeMock is IExchange {
    function convertToSpend(address payableTokenAddr, uint256 amount)
        public
        view
        override
        returns (uint256)
    {
        // NB: for testing tokens that have no spend value
        require(
            payableTokenAddr != address(1),
            "ExchangeMock: this address has no SPEND value"
        );
        return amount * 100;
    }
}
