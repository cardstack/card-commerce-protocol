# CardPay-contracts

The repo containing the smart contracts for the CardPay protocol

## Description

CardPay is a social commerce platform that leverages EVM based blockchains to provide a marketplace for merchants and buyers to purchase digital items using cryptocurrency and fiat.

## Getting started

### install dependencies

`$ yarn`

### compile the contracts

`$ yarn build`

### run a local blockchain (required for testing)

`$ yarn chain`

### run tests

`$ yarn test`

## Contracts

- `MarketPlace.sol` - the contract that facilitates buying and selling of listings on the platform
- `Media.sol` - an ERC721 compliant contract that mints the listing NFTs and proxies calls to the market place

## Token standards used

- `ERC721` for NFTs, including listings and items
- `ERC20/ERC667` for all fungible tokens including items, SPEND & levels

## Assumptions

- These contracts will run on the xDAI chain, each asset used may or may not be pegged to a mainnet balance
- Prices are denominated in SPEND, a fungible token
- All user funds will be held in gnosis safes
- Gnosis safe infrastructure handles all the relaying RE gas fees
- the NFTs minted for listings will be contained in the CardPay NFT contract
- Each listing corresponds to a unique NFT but can represent fungibles and/or other NFT(s)
- Listings are for digital products only, no physical redemption
- Items set by the Merchant must be locked up in the contract to prevent double spending
- Items are automatically swapped on purchase
- Merchant reimburses the buyers gas fee if their bid is successful
- All NFTs are ERC721
- Listings do not expire
- “levels“ are set inside the fungible token itself so as to ensure a single source of truth set by the contract admin
- Listing prices can be changed while on the market
- Merchants can accept any bid they like, even if it is below their reserve price
- We are basing off the Zora protocol

## Architecture

This protocol extends the ERC721 standard with each listing represented by an NFT. The listing NFT itself only represents the item(s) being sold.

![overview](./diagrams/protocol.png)

The following structs are used in the marketplace to facilitate the buying and selling of items on the platform:

```solidity
struct Bid {
  // Amount of the SPEND being bid
  uint256 amount;
  // token contract for bid
  address token;
  // Address of the bidder
  address bidder;
  // Address of the recipient
  address recipient;
}

struct Ask {
  // Amount of the SPEND being asked, must be in a whitelisted currency
  uint256 amount;
}

struct Items {
  // address of the merchant who has set and locked up these items
  address merchant;
  // addresses of each token contract corresponding to the item
  address[] tokenAddresses;
  // items to send out on completion of the listing (amount or tokenId), matching the tokenAddresses index
  uint256[] amounts;
}

struct Discount {
  // address of the merchant who has set the discount based on a level
  address merchant;
  // address of the token contract that holds the balance that the merchant wants to give a discount to
  address tokenContract;
  // the level labels corresponding to a discount below. Calls the token contract to get the level string and match it accordingly
  string[] levels;
  // the discount to apply as a decimal e.g. total cost * 0.9 for a 10% discount
  Decimal.D256[] discounts;
}

struct LevelRequirement {
  // the address of the token contract for which the user must have a balance in
  address tokenContract;
  // call token contract and get the required level to make the purchase e.g. "super fan"
  string requiredLevel;
}

// Contained in the fungible token contract itself
struct Levels {
  // labels matching each threshold, e.g. 100 = power user
  string[] labels;
  // thresholds for each required level matching a label
  uint256[] thresholds;
}

```

### Mint

A merchant mints an NFT that represents the listing itself (this NFT is not the item(s) the merchant is selling, only an order id).

### Bid

Anyone can place a bid matching the listing NFT. By placing a bid, the bidder must deposit the amount denominated in SPEND. This protocol only accepts whitelisted tokens that have a corresponding rate in SPEND.

### Remove bid

A buyer can remove their bid if they change their mind, the listing is burned or another bid is successful. This will release the deposited funds back to the buyer.

### Transfer

Blocked.

### Burn

A merchant can choose to burn their listing NFT. This will refund the deposited items but the metadata and tokenId will be retained.

### Ask

A merchant can set an ask at any time. This will allow bids that match the criteria to be automatically approved. A merchant is free to modify this ask at any time.

TODO figure out how we can fulfil an ask requirement with SPEND as the yardstick e.g. merchant accepts 100 SPEND for an item which can be payable in any currency so long as it matches the SPEND denomination at the time. Note: we need to be able to get the exact rate on purchase tx.

### Accept bid

The merchant can accept any bid made by a buyer even if it doesn't meet their reserve price as set in the ask.

### Approve

The merchant can grant approval to any other address for the listing. This follows the standard ERC721 approve functionality and allows the spender to control the listing.

### Metadata for listing

A merchant can set metadata to their listing NFT. This should match a product schema defined here: https://schema.org/ProductModel

### Set item(s)

Each listing NFT on this platform is not the item(s) itself. Instead the merchant locks up these assets as items for the buyer to purchase. Each listing must have at least one item.

### Set level requirement

A merchant can set a level requirement for a listing at any time. A level corresponds to a balance of a particular token e.g. a fan token. An example of a level requirement could be that the merchant requires you hold at least 10 FAN tokens to make a bid.

### Set a discount based on a level

A merchant can set a discount based on the buyers level in a particular token. E.g. 10% off if you own at least 10 FAN tokens. This discount will be applied on the bid being accepted. TODO what if the merchant changes the discount later?

## Merchant flows

- Merchant chooses the items they wish to sell. These tokens can be either fungible or non fungible (required)
- Merchant sets a price with a reserve in SPEND (required)
- Merchant can set a discount, which is applied depending on the buyers level of fungible token holdings e.g. hold 10 RAC, get a 10% discount (optional)
- Merchant can set a required level to make a purchase, e.g. buyer must have reached VIP tier 1 (optional)
- An NFT token is minted representing the listing with a unique identifier (required)
- After listing, the Merchant can remove the listing, modify the discount based on the same levels, change the level requirement to buy or change it’s reserve price
- Merchant can accept any bid

Merchant listing flow:

![merchant listing flow](./diagrams/merchant-listing-flow.png)

Merchant modify listing flow:

![merchant modify listing flow](./diagrams/merchant-modify-listing.png)

Merchant bid flow:

![merchant bid flow](./diagrams/merchant-bid-flow.png)

## Buyer flows

- Buyer makes a bid or clicks buy now (must have the required balance)
- If buyer is eligible for a discount, this discount is applied on purchase
- If the buyer does not meet the level requirement for the purchase, the transaction will revert
- If successful, the buyer swaps their tokens for the item(s)

Buyer bid flow:

![buyer bid flow](./diagrams/buyer-bid-flow.png)

Buyer create bid flow:

![buyer create bid flow](./diagrams/buyer-create-bid-flow.png)

## Attribution

This repo is based from the [Zora protocol](https://github.com/ourzora/core)
