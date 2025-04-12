// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEVMVaultFactory} from "./interfaces/IVaultFactory.sol";
import {EVMVault} from "./Vault.sol";
import {IEVMVault} from "./interfaces/IVault.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract EVMVaultFactory is
    EIP712Upgradeable,
    IEVMVaultFactory,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant CREATE_VAULT_TYPEHASH =
        keccak256(
            "CreateVault(string name,string symbol,address underlying,address authority,address protocolHelper,uint256 initDepositAmount,uint256 minDepositAmount,uint256 maxDepositAmount,uint256 deadline)"
        );

    address public signer;

    function initialize(address _signer) public initializer {
        __Ownable_init(msg.sender);
        __EIP712_init("Partnr Vault Factory", "1.0");
        signer = _signer;
    }

    function updateSigner(address _signer) external onlyOwner {
        signer = _signer;
    }

    function getVaultAddress(
        CreateNewVaultParams memory params,
        bytes calldata signature
    ) external view returns (address) {
        require(
            params.deadline > block.timestamp,
            "VaultFactory: deadline has passed"
        );
        require(
            params.maxDepositAmount >= params.minDepositAmount,
            "VaultFactory: maxDepositAmount must be greater than or equal to minDepositAmount"
        );

        bytes32 structHash = keccak256(
            abi.encode(
                CREATE_VAULT_TYPEHASH,
                keccak256(bytes(params.name)),
                keccak256(bytes(params.symbol)),
                params.underlying,
                params.authority,
                params.protocolHelper,
                params.initDepositAmount,
                params.minDepositAmount,
                params.maxDepositAmount,
                params.deadline
            )
        );

        bytes32 digest = _hashTypedDataV4(structHash);
        require(
            ECDSA.recover(digest, signature) == signer,
            "VaultFactory: invalid signature"
        );

        bytes32 _salt = keccak256(abi.encodePacked(structHash));

        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                _salt,
                keccak256(
                    abi.encodePacked(
                        type(EVMVault).creationCode,
                        abi.encode(params)
                    )
                )
            )
        );

        return address(uint160(uint256(hash)));
    }

    /**
     * @notice Create a new vault
     * @param params The parameters for the vault
     * @param signature The signature of the authority
     * @return vault The new vault
     */
    function createNewVault(
        CreateNewVaultParams memory params,
        bytes calldata signature
    ) external returns (IEVMVault vault) {
        require(
            params.deadline > block.timestamp,
            "VaultFactory: deadline has passed"
        );
        require(
            params.maxDepositAmount >= params.minDepositAmount,
            "VaultFactory: maxDepositAmount must be greater than or equal to minDepositAmount"
        );

        bytes32 structHash = keccak256(
            abi.encode(
                CREATE_VAULT_TYPEHASH,
                keccak256(bytes(params.name)),
                keccak256(bytes(params.symbol)),
                params.underlying,
                params.authority,
                params.protocolHelper,
                params.initDepositAmount,
                params.minDepositAmount,
                params.maxDepositAmount,
                params.deadline
            )
        );

        bytes32 digest = _hashTypedDataV4(structHash);
        require(
            ECDSA.recover(digest, signature) == signer,
            "VaultFactory: invalid signature"
        );

        bytes32 _salt = keccak256(abi.encodePacked(structHash));
        vault = new EVMVault{salt: _salt}(params);

        uint256 shares = 0;
        if (params.initDepositAmount > 0) {
            params.underlying.safeTransferFrom(
                params.authority,
                address(this),
                params.initDepositAmount
            );

            params.underlying.approve(address(vault), params.initDepositAmount);

            shares = vault.deposit(
                bytes16(0),
                params.initDepositAmount,
                params.authority,
                0,
                params.deadline,
                bytes("")
            );
        }

        emit VaultCreated(vault, params.authority, shares);
    }

    /**
     * @notice Collect fees from the vault
     * @param vault The vault to collect fees from
     */
    function collectFees(IEVMVault vault, address receiver) external onlyOwner {
        require(vault.vaultFees() > 0, "VaultFactory: no fees to collect");
        vault.collectFees(receiver);
    }
}
