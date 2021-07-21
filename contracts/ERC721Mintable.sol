// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/GSN/Context.sol";
import "./BaseErc721.sol";

/**
 * @title ERC721 Mintable Token
 * @dev ERC721 Token that can be minted
 */
contract ERC721Mintable is Context, BaseERC721 {
    constructor(string memory name, string memory symbol)
        public
        BaseERC721(name, symbol)
    {}

    function mint(address to, uint256 tokenId) public virtual {
        // require(
        //     _isApprovedOrOwner(_msgSender(), tokenId),
        //     "ERC721Mintable: caller is not owner nor approved"
        // );
        _mint(to, tokenId);
    }
}
