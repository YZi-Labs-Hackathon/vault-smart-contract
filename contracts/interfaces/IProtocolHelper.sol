// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IEVMVault} from "./IVault.sol";

interface IProtocolHelper {
    function getVaultValue(IEVMVault vault) external view returns (uint256);

    function onDeposit(
        IEVMVault vault,
        uint256 amount
    ) external returns (address[] memory targets, bytes[] memory data);

    function onWithdraw(
        IEVMVault vault,
        uint256 amount
    ) external returns (address[] memory targets, bytes[] memory data);
}
