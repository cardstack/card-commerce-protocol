pragma solidity 0.6.8;

// @hassan had to squash them in like this because there were many compiler conflicts between dependencies...

/// @title IProxy - Helper interface to access masterCopy of the Proxy on-chain
/// @author Richard Meissner - <richard@gnosis.io>
interface IProxy {
    function masterCopy() external view returns (address);
}

/// @title GnosisSafeProxy - Generic proxy contract allows to execute all transactions applying the code of a master contract.
/// @author Stefan George - <stefan@gnosis.io>
/// @author Richard Meissner - <richard@gnosis.io>
contract GnosisSafeProxy {
    // singleton always needs to be first declared variable, to ensure that it is at the same location in the contracts to which calls are delegated.
    // To reduce deployment costs this variable is internal and needs to be retrieved via `getStorageAt`
    address internal singleton;

    /// @dev Constructor function sets address of singleton contract.
    /// @param _singleton Singleton address.
    constructor(address _singleton) public {
        require(_singleton != address(0), "Invalid singleton address provided");
        singleton = _singleton;
    }

    /// @dev Fallback function forwards all transactions and returns all received return data.
    fallback() external payable {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let _singleton := and(
                sload(0),
                0xffffffffffffffffffffffffffffffffffffffff
            )
            // 0xa619486e == keccak("masterCopy()"). The value is right padded to 32-bytes with 0s
            if eq(
                calldataload(0),
                0xa619486e00000000000000000000000000000000000000000000000000000000
            ) {
                mstore(0, _singleton)
                return(0, 0x20)
            }
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(
                gas(),
                _singleton,
                0,
                calldatasize(),
                0,
                0
            )
            returndatacopy(0, 0, returndatasize())
            if eq(success, 0) {
                revert(0, returndatasize())
            }
            return(0, returndatasize())
        }
    }
}

/// @title Proxy Factory - Allows to create new proxy contact and execute a message call to the new proxy within one transaction.
/// @author Stefan George - <stefan@gnosis.pm>
// @hassan, had to rename this to add The because it conflicts in the typechain
contract TheGnosisSafeProxyFactory {
    event ProxyCreation(GnosisSafeProxy proxy, address singleton);

    /// @dev Allows to create new proxy contact and execute a message call to the new proxy within one transaction.
    /// @param singleton Address of singleton contract.
    /// @param data Payload for message call sent to new proxy contract.
    function createProxy(address singleton, bytes memory data)
        public
        returns (GnosisSafeProxy proxy)
    {
        proxy = new GnosisSafeProxy(singleton);
        if (data.length > 0)
            // solhint-disable-next-line no-inline-assembly
            assembly {
                if eq(
                    call(gas(), proxy, 0, add(data, 0x20), mload(data), 0, 0),
                    0
                ) {
                    revert(0, 0)
                }
            }
        emit ProxyCreation(proxy, singleton);
    }
}

contract Safe {
    bytes4 internal constant SETUP = 0xb63e800d;
    address internal constant ZERO_ADDRESS = address(0);

    address public gnosisSafe;
    address public gnosisProxyFactory;

    function setup(address _gnosisSafe, address _gnosisProxyFactory) internal {
        gnosisProxyFactory = _gnosisProxyFactory;
        gnosisSafe = _gnosisSafe;
    }

    function createSafe(address[] memory safeOwners, uint256 threshold)
        internal
        returns (address)
    {
        bytes memory data =
            abi.encodeWithSelector(
                SETUP,
                safeOwners,
                threshold,
                ZERO_ADDRESS,
                "",
                ZERO_ADDRESS,
                ZERO_ADDRESS,
                0,
                ZERO_ADDRESS
            );

        address safe =
            address(
                TheGnosisSafeProxyFactory(gnosisProxyFactory).createProxy(
                    gnosisSafe,
                    data
                )
            );

        require(safe != ZERO_ADDRESS, "Create a Safe failed");

        return safe;
    }

    function createSafe(address owner) internal returns (address) {
        address[] memory ownerArr = new address[](1);
        ownerArr[0] = owner;

        return createSafe(ownerArr, 1);
    }

    uint256[50] private ____gap;
}
