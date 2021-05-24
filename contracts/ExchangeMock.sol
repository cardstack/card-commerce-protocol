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
        return amount * 100;
    }
}
