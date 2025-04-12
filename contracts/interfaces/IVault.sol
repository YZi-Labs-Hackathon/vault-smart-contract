// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEVMVault is IERC20 {
    event Deposited(
        bytes16 indexed depositId,
        address indexed user,
        uint256 amount
    );
    event Withdrawn(
        bytes16 indexed withdrawId,
        address indexed user,
        uint256 amount
    );

    function vaultFees() external view returns (uint256);

    function creatorFees() external view returns (uint256);

    function underlying() external view returns (IERC20);

    function userDeposited(address user) external view returns (uint256);

    function deposit(
        bytes16 depositId,
        uint256 amount,
        address user,
        uint256 vaultTvl,
        uint256 deadline,
        bytes calldata signature
    ) external returns (uint256 shares);

    function withdraw(
        bytes16 withdrawId,
        address user,
        uint256 amountOut,
        uint256 vaultTvl,
        uint256 vaultFee,
        uint256 creatorFee,
        uint256 deadline,
        bytes calldata signature
    ) external;
}
