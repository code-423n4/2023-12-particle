import { ethers } from "hardhat";
import { verifyWithRetry } from "./utils";

///@dev uniswap v3 router: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
///@dev 1inch v5 router: 0x1111111254EEB25477B68fb85Ed929f73A960582
const DEX_AGGREGATOR = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45";
const FEE_FACTOR = 500;
const LIQUIDATION_REWARD_FACTOR = 50_000;
const LOAN_TERM = 7 * 24 * 60 * 60; // 7 days in seconds
const TREASURY_RATE = 500_000;

const main = async () => {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", await deployer.getAddress());

  // Define the contract factories
  const ParticlePositionManager = await ethers.getContractFactory("ParticlePositionManager");
  const ERC1967Proxy = await ethers.getContractFactory("ERC1967Proxy");

  // Deploy ParticlePositionManager contract
  const particlePositionManagerImpl = await ParticlePositionManager.deploy();

  // Deploy ERC1967Proxy contract
  const proxy = await ERC1967Proxy.deploy(await particlePositionManagerImpl.getAddress(), "0x");

  // Initialize the ParticlePositionManager through the proxy
  const positionManager = ParticlePositionManager.attach(await proxy.getAddress());
  await positionManager.initialize(
    DEX_AGGREGATOR,
    FEE_FACTOR,
    LIQUIDATION_REWARD_FACTOR,
    LOAN_TERM,
    TREASURY_RATE
  );

  const particleImplAddr = await particlePositionManagerImpl.getAddress();
  const particleProxyAddr = await positionManager.getAddress();
  console.log("ParticlePositionManager implementation deployed to:", particleImplAddr);
  console.log("ParticlePositionManager proxy deployed to:", particleProxyAddr);

  // Verify implementation contract
  await verifyWithRetry(particleImplAddr, []);

  // Verify proxy contract
  await verifyWithRetry(particleProxyAddr, [particleImplAddr, "0x"]);
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
