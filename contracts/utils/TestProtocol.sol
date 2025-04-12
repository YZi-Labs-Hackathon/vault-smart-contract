// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IProtocolHelper} from "../interfaces/IProtocolHelper.sol";
import {IEVMVault} from "../interfaces/IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITestProtocolFactory} from "./TestProtocolFactory.sol";

import {console} from "hardhat/console.sol";

contract TestProtocol is IProtocolHelper, OwnableUpgradeable {
    // token address => protocol address
    mapping(address => address) public tokenToPool;

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    function addPool(address token, address pool) external onlyOwner {
        tokenToPool[token] = pool;
    }

    function removePool(address token) external onlyOwner {
        delete tokenToPool[token];
    }

    function getVaultValue(IEVMVault vault) external view returns (uint256) {
        uint256 balance = IERC20(tokenToPool[address(vault.underlying())])
            .balanceOf(address(vault));

        return balance * 2;
    }

    function onDeposit(
        IEVMVault vault,
        uint256 amount
    ) external view returns (address[] memory targets, bytes[] memory data) {
        IERC20 underlying = vault.underlying();

        require(
            tokenToPool[address(underlying)] != address(0),
            "Invalid underlying"
        );
        uint256 balance = underlying.balanceOf(address(vault));
        require(balance >= amount, "Insufficient balance");

        uint256 allowance = underlying.allowance(
            address(vault),
            tokenToPool[address(underlying)]
        );

        if (allowance < amount) {
            targets = new address[](2);
            data = new bytes[](2);

            targets[0] = address(underlying);
            data[0] = abi.encodeWithSelector(
                IERC20.approve.selector,
                tokenToPool[address(underlying)],
                amount - allowance
            );

            targets[1] = tokenToPool[address(underlying)];
            data[1] = abi.encodeWithSelector(
                ITestProtocolFactory.mint.selector,
                amount
            );
        } else {
            targets = new address[](1);
            data = new bytes[](1);

            targets[0] = tokenToPool[address(underlying)];
            data[0] = abi.encodeWithSelector(
                ITestProtocolFactory.mint.selector,
                amount
            );
        }

        return (targets, data);
    }

    function onWithdraw(
        IEVMVault vault,
        uint256 amount
    ) external view returns (address[] memory targets, bytes[] memory data) {
        IERC20 underlying = vault.underlying();

        require(
            tokenToPool[address(underlying)] != address(0),
            "Invalid underlying"
        );
        targets = new address[](1);
        data = new bytes[](1);

        targets[0] = tokenToPool[address(underlying)];
        data[0] = abi.encodeWithSelector(
            ITestProtocolFactory.burn.selector,
            amount
        );
    }
}
