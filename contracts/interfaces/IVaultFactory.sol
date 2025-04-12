// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IVault.sol";

interface IEVMVaultFactory {
    struct CreateNewVaultParams {
        string name;
        string symbol;
        IERC20 underlying;
        address authority; // The authority of the vault
        address protocolHelper; // The protocol helper of the vault
        uint256 initDepositAmount; // The amount of the underlying token to deposit into the vault
        uint256 minDepositAmount; // The minimum amount of the underlying token to deposit into the vault
        uint256 maxDepositAmount; // The maximum amount of the underlying token to deposit into the vault
        uint256 deadline; // The deadline of creating the vault
    }

    event VaultCreated(IEVMVault vault, address authority, uint256 shares);

    function createNewVault(
        CreateNewVaultParams memory params,
        bytes calldata signature
    ) external returns (IEVMVault vault);

    function signer() external view returns (address);

    function collectFees(IEVMVault vault, address receiver) external;
}
