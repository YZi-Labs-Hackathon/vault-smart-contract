import { ethers, upgrades } from "hardhat";
import { EVMVaultFactory } from "../types/evm";
import { ERC20, TestERC20Factory, EVMVault } from "../types/evm";
import { EventLog, TypedDataDomain, TypedDataField } from "ethers";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import assert from "assert";

describe("VaultFactory EVM", () => {
  let vaultFactory: EVMVaultFactory;
  let deployer: SignerWithAddress;
  let vaultCreator: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  v;
  let signer: SignerWithAddress;

  let vault: EVMVault;

  let token: TestERC20Factory;

  before(async () => {
    const signers = await ethers.getSigners();
    deployer = signers[0];
    signer = signers[1];
    vaultCreator = signers[2];
    user1 = signers[3];
    user2 = signers[4];

    const VaultFactory = await ethers.getContractFactory("EVMVaultFactory");
    vaultFactory = await VaultFactory.deploy(signer.address);

    const TestERC20Factory = await ethers.getContractFactory(
      "TestERC20Factory"
    );
    token = await TestERC20Factory.deploy("Test Token", "TT", 18);

    await token.mint(
      vaultCreator.address,
      ethers.parseUnits("1000000", await token.decimals())
    );
    await token.mint(
      user1.address,
      ethers.parseUnits("1000000", await token.decimals())
    );
    await token.mint(
      user2.address,
      ethers.parseUnits("1000000", await token.decimals())
    );
  });

  it("should create a new vault", async () => {
    //Approve the vault factory to spend the token
    await token
      .connect(vaultCreator)
      .approve(
        await vaultFactory.getAddress(),
        ethers.parseUnits("1000", await token.decimals())
      );

    const deadline = Math.floor(Date.now() / 1000) + 1000;

    const vaultFactorydomain: TypedDataDomain = {
      name: "Partnr Vault Factory",
      version: "1.0",
      chainId: (await ethers.provider.getNetwork()).chainId,
      verifyingContract: await vaultFactory.getAddress(),
    };
    const vaultFactoryTypes: Record<string, TypedDataField[]> = {
      CreateVault: [
        { name: "name", type: "string" },
        { name: "symbol", type: "string" },
        { name: "underlying", type: "address" },
        { name: "authority", type: "address" },
        { name: "protocolHelper", type: "address" },
        { name: "initDepositAmount", type: "uint256" },
        { name: "minDepositAmount", type: "uint256" },
        { name: "maxDepositAmount", type: "uint256" },
        { name: "deadline", type: "uint256" },
      ],
    };
    const vaultFactoryValue = {
      authority: vaultCreator.address,
      deadline: deadline,
      protocolHelper: ethers.ZeroAddress, // TODO: Add protocol helper
      name: "Test Vault",
      symbol: "TV",
      underlying: await token.getAddress(),
      initDepositAmount: ethers.parseUnits("1000", await token.decimals()),
      minDepositAmount: ethers.parseUnits("100", await token.decimals()),
      maxDepositAmount: ethers.parseUnits("1000", await token.decimals()),
    };

    const vaultFactorySignature = await signer.signTypedData(
      vaultFactorydomain,
      vaultFactoryTypes,
      vaultFactoryValue
    );

    const createNewVaultTx = await vaultFactory
      .connect(vaultCreator)
      .createNewVault(
        {
          authority: vaultFactoryValue.authority,
          name: vaultFactoryValue.name,
          symbol: vaultFactoryValue.symbol,
          underlying: vaultFactoryValue.underlying,
          initDepositAmount: vaultFactoryValue.initDepositAmount,
          minDepositAmount: vaultFactoryValue.minDepositAmount,
          maxDepositAmount: vaultFactoryValue.maxDepositAmount,
          deadline: vaultFactoryValue.deadline,
        },
        vaultFactorySignature
      );

    const createNewVaultTxReceipt = await createNewVaultTx.wait();
    let vaultAddress: string;
    createNewVaultTxReceipt.logs.map((log) => {
      if (log instanceof EventLog) {
        const event = vaultFactory.interface.parseLog(log);
        if (event.name === "VaultCreated") {
          vaultAddress = event.args.vault;
        }
      }
    });

    vault = await ethers.getContractAt("EVMVault", vaultAddress);
    const vaultCreatorShares = await vault.balanceOf(vaultCreator.address);

    assert(
      vaultCreatorShares > 0,
      "Vault creator shares should be greater than 0"
    );

    const vaultDomain: TypedDataDomain = {
      name: "Partnr Vault",
      version: "1.0",
      chainId: (await ethers.provider.getNetwork()).chainId,
      verifyingContract: await vault.getAddress(),
    };
    // Withdraw(bytes16 withdrawId,address user,uint256 amountOut,uint256 vaultTvl,uint256 vaultFee,uint256 creatorFee,uint256 deadline)
    const vaultWithdrawTypes: Record<string, TypedDataField[]> = {
      Withdraw: [
        { name: "withdrawId", type: "bytes16" },
        { name: "user", type: "address" },
        { name: "amountOut", type: "uint256" },
        { name: "vaultTvl", type: "uint256" },
        { name: "vaultFee", type: "uint256" },
        { name: "creatorFee", type: "uint256" },
        { name: "deadline", type: "uint256" },
      ],
    };

    // Deposit(bytes16 depositId,uint256 amount,address user,uint256 vaultTvl,uint256 deadline)
    const vaultDepositTypes: Record<string, TypedDataField[]> = {
      Deposit: [
        { name: "depositId", type: "bytes16" },
        { name: "amount", type: "uint256" },
        { name: "user", type: "address" },
        { name: "vaultTvl", type: "uint256" },
        { name: "deadline", type: "uint256" },
      ],
    };

    //Deposit 1000 tokens into the vault
    await token
      .connect(user1)
      .approve(vaultAddress, ethers.parseUnits("1000", await token.decimals()));
    await token
      .connect(user2)
      .approve(vaultAddress, ethers.parseUnits("1000", await token.decimals()));

    // Deposit 100 tokens into the vault
    const depositId1 = ethers.randomBytes(16);
    const depositValue1 = {
      depositId: depositId1,
      amount: ethers.parseUnits("100", await token.decimals()),
      user: user1.address,
      vaultTvl: await vault.getVaultValue(),
      deadline: deadline,
    };
    const vaultSignature1 = await signer.signTypedData(
      vaultDomain,
      vaultDepositTypes,
      depositValue1
    );
    await vault
      .connect(user1)
      .deposit(
        depositValue1.depositId,
        depositValue1.amount,
        depositValue1.user,
        depositValue1.vaultTvl,
        depositValue1.deadline,
        vaultSignature1
      );

    // Deposit 20 tokens into the vault
    try {
      const depositId2 = ethers.randomBytes(16);
      const depositValue2 = {
        depositId: depositId2,
        amount: ethers.parseUnits("20", await token.decimals()),
        user: user2.address,
        vaultTvl: await vault.getVaultValue(),
        deadline: deadline,
      };
      const vaultSignature2 = await signer.signTypedData(
        vaultDomain,
        vaultDepositTypes,
        depositValue2
      );
      await vault
        .connect(user2)
        .deposit(
          depositValue2.depositId,
          depositValue2.amount,
          depositValue2.user,
          depositValue2.vaultTvl,
          depositValue2.deadline,
          vaultSignature2
        );
    } catch (error) {
      assert(error instanceof Error, "Error should be an instance of Error");
      assert(
        error.message.includes("Invalid deposit amount"),
        "Error message should include 'Invalid deposit amount'"
      );
    }

    const user1Shares = await vault.balanceOf(user1.address);
    assert(user1Shares > 0, "User 1 shares should be greater than 0");

    // Deposit 200 tokens into the vault
    const depositId3 = ethers.randomBytes(16);
    const depositValue3 = {
      depositId: depositId3,
      amount: ethers.parseUnits("200", await token.decimals()),
      user: user2.address,
      vaultTvl: await vault.getVaultValue(),
      deadline: deadline,
    };
    const vaultSignature3 = await signer.signTypedData(
      vaultDomain,
      vaultDepositTypes,
      depositValue3
    );
    await vault
      .connect(user2)
      .deposit(
        depositValue3.depositId,
        depositValue3.amount,
        depositValue3.user,
        depositValue3.vaultTvl,
        depositValue3.deadline,
        vaultSignature3
      );

    const user2Shares = await vault.balanceOf(user2.address);

    assert(user2Shares > 0, "User 2 shares should be greater than 0");

    //Make benefit for vault
    await token.mint(
      await vault.getAddress(),
      ethers.parseUnits("1000", await token.decimals())
    );

    //Withdraw
    const withdrawValue = {
      withdrawId: ethers.randomBytes(16),
      user: user1.address,
      amountOut: user1Shares,
      vaultTvl: await vault.getVaultValue(),
      vaultFee: ethers.parseUnits("1", await token.decimals()),
      creatorFee: ethers.parseUnits("1", await token.decimals()),
      deadline: deadline,
    };

    const vaultSignature = await signer.signTypedData(
      vaultDomain,
      vaultWithdrawTypes,
      withdrawValue
    );

    const withdrawTx = await vault
      .connect(user1)
      .withdraw(
        withdrawValue.withdrawId,
        withdrawValue.user,
        withdrawValue.amountOut,
        withdrawValue.vaultTvl,
        withdrawValue.vaultFee,
        withdrawValue.creatorFee,
        withdrawValue.deadline,
        vaultSignature
      );
    const withdrawTxReceipt = await withdrawTx.wait();

    withdrawTxReceipt.logs.map((log) => {
      if (log instanceof EventLog) {
        const event = vault.interface.parseLog(log);
        if (event.name === "Withdrawn") {
          console.log(event.args);
        }
      }
    });
  });

  it("should execute burn operation to zero address", async () => {
    const vaultDomain: TypedDataDomain = {
      name: "Partnr Vault",
      version: "1.0",
      chainId: (await ethers.provider.getNetwork()).chainId,
      verifyingContract: await vault.getAddress(),
    };

    // Deposit(bytes16 depositId,uint256 amount,address user,uint256 vaultTvl,uint256 deadline)
    const vaultDepositTypes: Record<string, TypedDataField[]> = {
      Deposit: [
        { name: "depositId", type: "bytes16" },
        { name: "amount", type: "uint256" },
        { name: "user", type: "address" },
        { name: "vaultTvl", type: "uint256" },
        { name: "deadline", type: "uint256" },
      ],
    };
    // First deposit some tokens to have balance to burn
    const depositId = ethers.randomBytes(16);
    const depositValue = {
      depositId: depositId,
      amount: ethers.parseUnits("100", await token.decimals()),
      user: user1.address,
      vaultTvl: await vault.getVaultValue(),
      deadline: Math.floor(Date.now() / 1000) + 1000,
    };
    const vaultSignature = await signer.signTypedData(
      vaultDomain,
      vaultDepositTypes,
      depositValue
    );
    await vault
      .connect(user1)
      .deposit(
        depositValue.depositId,
        depositValue.amount,
        depositValue.user,
        depositValue.vaultTvl,
        depositValue.deadline,
        vaultSignature
      );

    // Get initial balance
    const initialBalance = await vault.balanceOf(user1.address);
    assert(initialBalance > 0, "Initial balance should be greater than 0");

    // Prepare execute parameters for burning tokens
    const executeId = ethers.randomBytes(16);
    const targets = [await vault.getAddress()];
    const burnAmount = ethers.parseUnits("50", await token.decimals());
    const data = [
      vault.interface.encodeFunctionData("transfer", [
        ethers.ZeroAddress,
        burnAmount,
      ]),
    ];
    const deadline = Math.floor(Date.now() / 1000) + 1000;

    // Create and sign the execute message
    const executeValue = {
      excuteId: executeId,
      targets: targets,
      data: data,
      deadline: deadline,
    };

    const executeTypes: Record<string, TypedDataField[]> = {
      Execute: [
        { name: "excuteId", type: "bytes16" },
        { name: "targets", type: "address[]" },
        { name: "data", type: "bytes[]" },
        { name: "deadline", type: "uint256" },
      ],
    };

    const executeSignature = await signer.signTypedData(
      vaultDomain,
      executeTypes,
      executeValue
    );

    // Execute the burn operation
    await vault
      .connect(user1)
      .execute(executeId, targets, data, deadline, executeSignature);

    // Verify the balance was reduced
    const finalBalance = await vault.balanceOf(user1.address);
    assert(
      finalBalance === initialBalance - burnAmount,
      "Balance should be reduced by burn amount"
    );

    // Verify the tokens were burned (sent to zero address)
    const zeroAddressBalance = await vault.balanceOf(ethers.ZeroAddress);
    assert(
      zeroAddressBalance === burnAmount,
      "Zero address should have received the burned tokens"
    );
  });
});
