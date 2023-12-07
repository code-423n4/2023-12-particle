import { ethers } from "hardhat";
import { verifyWithRetry } from "./utils";

const PARTICLE_POSITION_MANAGER = "0x42"; // use deployed particle proxy address

const main = async () => {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", await deployer.getAddress());

  // Define the contract factories
  const ParticleInfoReader = await ethers.getContractFactory("ParticleInfoReader");
  const ERC1967Proxy = await ethers.getContractFactory("ERC1967Proxy");

  // Deploy ParticleInfoReader contract
  const particleInfoReaderImpl = await ParticleInfoReader.deploy();

  // Deploy ERC1967Proxy contract
  const proxy = await ERC1967Proxy.deploy(await particleInfoReaderImpl.getAddress(), "0x");

  // Initialize the ParticlePositionManager through the proxy
  const infoReader = ParticleInfoReader.attach(await proxy.getAddress());
  await infoReader.initialize(PARTICLE_POSITION_MANAGER);

  const particleInfoReaderImplAddr = await particleInfoReaderImpl.getAddress();
  const particleProxyAddr = await infoReader.getAddress();
  console.log("ParticleInfoReader implementation deployed to:", particleInfoReaderImplAddr);
  console.log("ParticleInfoReader proxy deployed to:", particleProxyAddr);

  // Verify implementation contract
  await verifyWithRetry(particleInfoReaderImplAddr, []);

  // Verify proxy contract
  await verifyWithRetry(particleProxyAddr, [particleInfoReaderImplAddr, "0x"]);
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
