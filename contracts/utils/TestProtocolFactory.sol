// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ITestProtocolFactory {
    function mint(uint256 amount) external;

    function burn(uint256 amount) external;
}

contract TestProtocolFactory is ERC20 {
    using SafeERC20 for IERC20;
    IERC20 public immutable underlying;

    constructor(address _underlying) ERC20("Test Protocol", "xTEST") {
        underlying = IERC20(_underlying);
    }

    event Minted(address indexed user, uint256 amount);
    event Burned(address indexed user, uint256 amount);

    function mint(uint256 amount) public {
        underlying.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount / 2);
        emit Minted(msg.sender, amount / 2);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
        underlying.safeTransfer(msg.sender, amount * 2);
        emit Burned(msg.sender, amount);
    }
}
