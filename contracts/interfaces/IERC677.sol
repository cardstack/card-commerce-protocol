// SPDX-License-Identifier: MIT
// based from https://github.com/rsksmart/erc677/
pragma solidity 0.6.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC677 is IERC20 {
    function transferAndCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bool ok);

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value,
        bytes data
    );
}
