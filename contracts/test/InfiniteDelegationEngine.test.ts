mkdir -p test
cat > test/InfiniteDelegationEngine.test.ts <<'EOF'
import { expect } from "chai";
import { ethers } from "hardhat";
import { BytesLike } from "ethers";

describe("InfiniteDelegationEngine - basic flow", function () {
  it("should allow delegatee to execute target when signed by owner", async function () {
    const [owner, delegatee, other] = await ethers.getSigners();

    const Engine = await ethers.getContractFactory("InfiniteDelegationEngine");
    const engine = await Engine.deploy();
    await engine.deployed();

    const Target = await ethers.getContractFactory("TestTarget");
    const target = await Target.deploy();
    await target.deployed();

    const chainId = (await ethers.provider.getNetwork()).chainId;
    const maxGasPrice = ethers.utils.parseUnits("100", "gwei");

    // create delegation
    await expect(engine.connect(owner).createDelegation(delegatee.address, chainId, maxGasPrice))
      .to.emit(engine, "DelegationCreated");

    // prepare payload
    const payload = target.interface.encodeFunctionData("setValue", [42]);
    const payloadHash = ethers.utils.keccak256(payload);

    // read nonce
    const delegationId = await engine.getDelegationId(owner.address, chainId);
    const deleg = await engine.delegations(delegationId);
    const nonce = deleg.nonce;

    // build message hash as in contract: keccak256(abi.encodePacked("IDE_EXECUTE", owner, chainId, target, payloadHash, nonce))
    const messageHash = ethers.utils.solidityKeccak256(
      ["bytes", "address", "uint256", "address", "bytes32", "uint256"],
      [ethers.utils.toUtf8Bytes("IDE_EXECUTE"), owner.address, chainId, target.address, payloadHash, nonce]
    );

    const signature = await owner.signMessage(ethers.utils.arrayify(messageHash));

    // delegatee executes
    await expect(engine.connect(delegatee).verifyAndExecute(owner.address, chainId, target.address, payload, signature))
      .to.emit(engine, "ExecutionTriggered");

    expect(await target.value()).to.equal(42);
  });

  it("should revert when signature is invalid", async function () {
    const [owner, delegatee, other] = await ethers.getSigners();

    const Engine = await ethers.getContractFactory("InfiniteDelegationEngine");
    const engine = await Engine.deploy();
    await engine.deployed();

    const Target = await ethers.getContractFactory("TestTarget");
    const target = await Target.deploy();
    await target.deployed();

    const chainId = (await ethers.provider.getNetwork()).chainId;
    const maxGasPrice = ethers.utils.parseUnits("100", "gwei");

    await engine.connect(owner).createDelegation(delegatee.address, chainId, maxGasPrice);

    const payload = target.interface.encodeFunctionData("setValue", [7]);
    const payloadHash = ethers.utils.keccak256(payload);

    const delegationId = await engine.getDelegationId(owner.address, chainId);
    const deleg = await engine.delegations(delegationId);
    const nonce = deleg.nonce;

    const messageHash = ethers.utils.solidityKeccak256(
      ["bytes", "address", "uint256", "address", "bytes32", "uint256"],
      [ethers.utils.toUtf8Bytes("IDE_EXECUTE"), owner.address, chainId, target.address, payloadHash, nonce]
    );

    // other signs instead of owner
    const signature = await other.signMessage(ethers.utils.arrayify(messageHash));

    await expect(
      engine.connect(delegatee).verifyAndExecute(owner.address, chainId, target.address, payload, signature)
    ).to.be.revertedWith("IDE: Invalid cryptographic signature");
  });

  it("should enforce gas price limit", async function () {
    const [owner, delegatee] = await ethers.getSigners();

    const Engine = await ethers.getContractFactory("InfiniteDelegationEngine");
    const engine = await Engine.deploy();
    await engine.deployed();

    const Target = await ethers.getContractFactory("TestTarget");
    const target = await Target.deploy();
    await target.deployed();

    const chainId = (await ethers.provider.getNetwork()).chainId;
    // set very low maxGasPrice
    const maxGasPrice = ethers.BigNumber.from(1);

    await engine.connect(owner).createDelegation(delegatee.address, chainId, maxGasPrice);

    const payload = target.interface.encodeFunctionData("setValue", [11]);
    const payloadHash = ethers.utils.keccak256(payload);

    const delegationId = await engine.getDelegationId(owner.address, chainId);
    const deleg = await engine.delegations(delegationId);
    const nonce = deleg.nonce;

    const messageHash = ethers.utils.solidityKeccak256(
      ["bytes", "address", "uint256", "address", "bytes32", "uint256"],
      [ethers.utils.toUtf8Bytes("IDE_EXECUTE"), owner.address, chainId, target.address, payloadHash, nonce]
    );

    const signature = await owner.signMessage(ethers.utils.arrayify(messageHash));

    // send transaction with high gasPrice override
    await expect(
      engine.connect(delegatee).verifyAndExecute(owner.address, chainId, target.address, payload, signature, { gasPrice: ethers.utils.parseUnits("1000", "gwei") })
    ).to.be.revertedWith("IDE: Gas price exceeds MEV limit");
  });

  it("should revoke and prevent execution", async function () {
    const [owner, delegatee] = await ethers.getSigners();

    const Engine = await ethers.getContractFactory("InfiniteDelegationEngine");
    const engine = await Engine.deploy();
    await engine.deployed();

    const Target = await ethers.getContractFactory("TestTarget");
    const target = await Target.deploy();
    await target.deployed();

    const chainId = (await ethers.provider.getNetwork()).chainId;
    const maxGasPrice = ethers.utils.parseUnits("100", "gwei");

    await engine.connect(owner).createDelegation(delegatee.address, chainId, maxGasPrice);

    // revoke
    await engine.connect(owner).revokeDelegation(chainId);

    const payload = target.interface.encodeFunctionData("setValue", [99]);
    const payloadHash = ethers.utils.keccak256(payload);

    const delegationId = await engine.getDelegationId(owner.address, chainId);
    const deleg = await engine.delegations(delegationId);
    const nonce = deleg.nonce;

    const messageHash = ethers.utils.solidityKeccak256(
      ["bytes", "address", "uint256", "address", "bytes32", "uint256"],
      [ethers.utils.toUtf8Bytes("IDE_EXECUTE"), owner.address, chainId, target.address, payloadHash, nonce]
    );

    const signature = await owner.signMessage(ethers.utils.arrayify(messageHash));

    await expect(
      engine.connect(delegatee).verifyAndExecute(owner.address, chainId, target.address, payload, signature)
    ).to.be.revertedWith("IDE: Request unauthorized or delegation inactive");
  });
});
EOF
