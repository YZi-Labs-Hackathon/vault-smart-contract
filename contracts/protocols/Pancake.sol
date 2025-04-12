// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/IProtocolHelper.sol";

contract Pancake is IProtocolHelper, OwnableUpgradeable {
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    function onDeposit(
        IEVMVault vault,
        uint256 amount
    ) external returns (address[] memory targets, bytes[] memory data) {
        return (new address[](0), new bytes[](0));
    }

    function onWithdraw(
        IEVMVault vault,
        uint256 shares
    ) external returns (address[] memory targets, bytes[] memory data) {
        return (new address[](0), new bytes[](0));
    }

    function getVaultValue(IEVMVault vault) external view returns (uint256) {
        return 0;
    }
}
