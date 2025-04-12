// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IEVMVault} from "./interfaces/IVault.sol";
import {IEVMVaultFactory} from "./interfaces/IVaultFactory.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract EVMVault is IEVMVault, ERC20, EIP712, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant DEPOSIT_TYPEHASH =
        keccak256(
            "Deposit(bytes16 depositId,uint256 amount,address user,uint256 vaultTvl,uint256 deadline)"
        );

    bytes32 public constant WITHDRAW_TYPEHASH =
        keccak256(
            "Withdraw(bytes16 withdrawId,address user,uint256 amountOut,uint256 vaultTvl,uint256 vaultFee,uint256 creatorFee,uint256 deadline)"
        );

    /**
     * @notice The factory of the vault
     */
    IEVMVaultFactory public immutable factory;

    /**
     * @notice The underlying token of the vault
     */
    IERC20 public immutable underlying;

    /**
     * @notice The creator of the vault
     */
    address public immutable authority;

    /**
     * @notice The minimum deposit amount of the vault
     */
    uint256 public minDepositAmount;

    /**
     * @notice The maximum deposit amount of the vault
     */
    uint256 public maxDepositAmount;

    /**
     * @notice The user deposited amount of the vault
     */
    mapping(address => uint256) public userDeposited;

    /**
     * @notice The Execute id of the vault
     */
    mapping(bytes16 => bool) public excuteIds;

    /**
     * @notice The fees of the vault
     */
    uint256 public vaultFees;

    /**
     * @notice The fees of the creator
     */
    uint256 public creatorFees;

    constructor(
        IEVMVaultFactory.CreateNewVaultParams memory params
    ) ERC20(params.name, params.symbol) EIP712("Partnr Vault", "1.0") {
        underlying = IERC20(params.underlying);
        authority = params.authority;
        minDepositAmount = params.minDepositAmount;
        maxDepositAmount = params.maxDepositAmount;

        factory = IEVMVaultFactory(msg.sender);
    }

    /**
     * @notice Get the value of the vault
     * @return The value of the vault
     */
    function getVaultValue() public view returns (uint256) {
        return
            underlying.balanceOf(address(this)) -
            (vaultFees + creatorFees);
    }

    /**
     * @notice Get the share rate of the vault
     * @return The share rate of the vault
     */
    function shareRate() public view returns (uint256) {
        uint256 totalShares = totalSupply();
        return
            (totalShares == 0) ? 1e18 : (getVaultValue() * 1e18) / totalShares;
    }

    /**
     * @notice Deposit into the vault
     * @param depositId The deposit id
     * @param vaultTvl The total value locked in the vault
     * @param deadline The deadline of the deposit
     * @param signature The signature of the deposit
     * @param amount The amount to deposit
     * @param user The user to deposit for
     * @return The number of shares minted
     */
    function deposit(
        bytes16 depositId,
        uint256 amount,
        address user,
        uint256 vaultTvl,
        uint256 deadline,
        bytes calldata signature
    ) external override nonReentrant returns (uint256) {
        require(
            amount > 0 &&
                amount >= minDepositAmount &&
                (maxDepositAmount > 0 ? amount <= maxDepositAmount : true),
            "Invalid deposit amount"
        );
        require(excuteIds[depositId] == false, "Deposit already exists");

        uint256 vaultValue = 0;
        if (vaultTvl > 0) {
            require(block.timestamp < deadline, "Deadline exceeded");
            vaultValue = vaultTvl;

            //Verify signature
            require(
                ECDSA.recover(
                    _hashTypedDataV4(
                        keccak256(
                            abi.encode(
                                DEPOSIT_TYPEHASH,
                                depositId,
                                amount,
                                user,
                                vaultTvl,
                                deadline
                            )
                        )
                    ),
                    signature
                ) == factory.signer(),
                "Invalid signature"
            );
        } else {
            vaultValue = getVaultValue();
        }

        underlying.safeTransferFrom(msg.sender, address(this), amount);
        userDeposited[user] += amount;

        uint256 totalShares = totalSupply();
        uint256 shares = (totalShares == 0)
            ? amount
            : (amount * totalShares) / vaultValue;

        _mint(user, shares);

        excuteIds[depositId] = true;

        emit Deposited(depositId, user, amount);

        return shares;
    }

    /**
     * @notice Withdraw from the vault
     * @param withdrawId The withdraw id
     * @param user The user to withdraw for
     * @param amountOut The amount to withdraw
     * @param vaultFee The fee to withdraw
     * @param creatorFee The creator fee to withdraw
     * @param deadline The deadline of the withdraw
     * @param signature The signature of the withdraw
     */
    function withdraw(
        bytes16 withdrawId,
        address user,
        uint256 amountOut,
        uint256 vaultTvl,
        uint256 vaultFee,
        uint256 creatorFee,
        uint256 deadline,
        bytes calldata signature
    ) external override nonReentrant {
        require(block.timestamp < deadline, "Deadline exceeded");

        require(amountOut > 0, "Invalid withdraw amount");
        require(excuteIds[withdrawId] == false, "Withdraw already exists");

        uint256 vaultValue = 0;
        if (vaultTvl > 0) {
            vaultValue = vaultTvl;
        } else {
            vaultValue = getVaultValue();
        }

        require(totalSupply() > 0 && vaultValue > 0, "Vault not initialized");

        //Verify signature
        require(
            ECDSA.recover(
                _hashTypedDataV4(
                    keccak256(
                        abi.encode(
                            WITHDRAW_TYPEHASH,
                            withdrawId,
                            user,
                            amountOut,
                            vaultTvl,
                            vaultFee,
                            creatorFee,
                            deadline
                        )
                    )
                ),
                signature
            ) == factory.signer(),
            "Invalid signature"
        );

        uint256 userTvl = (balanceOf(user) * vaultValue) / totalSupply();

        uint256 principalAmount = 0;
        if (userDeposited[user] > userTvl) {
            principalAmount = amountOut;
        } else {
            principalAmount =
                (amountOut * userDeposited[user]) /
                (userDeposited[user] + (userTvl - userDeposited[user])) +
                (vaultFee + creatorFee);
        }

        if (amountOut > userTvl) {
            userDeposited[user] = 0;
            _burn(user, balanceOf(user));
            amountOut = userTvl;
        } else {
            userDeposited[user] -= principalAmount;
            _burn(user, (balanceOf(user) * amountOut) / userTvl);
        }

        underlying.safeTransfer(user, amountOut - (vaultFee + creatorFee));
        vaultFees += vaultFee;
        creatorFees += creatorFee;

        excuteIds[withdrawId] = true;

        emit Withdrawn(withdrawId, user, amountOut);
    }
    
    fallback() external payable {}

    receive() external payable {}
}
