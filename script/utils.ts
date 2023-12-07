import { run } from "hardhat";

const MAX_RETRIES = 4;
const RETRY_DELAYS = [5000, 10000, 30000, 60000]; // 5s, 10s, 30s, 60s

export const verifyWithRetry = async (address: string, constructorArguments: any[]) => {
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      await run("verify:verify", {
        address: address,
        constructorArguments: constructorArguments,
      });
      console.log("Verified", address);
      break;
    } catch (error) {
      console.log(`Verification attempt ${attempt}`);
      if (attempt < MAX_RETRIES) {
        console.log(`Waiting for ${RETRY_DELAYS[attempt - 1] / 1000} seconds before retrying...`);
        await delay(RETRY_DELAYS[attempt - 1]);
      } else {
        console.error("Verification error", error);
      }
    }
  }
};

const delay = (ms: number) => {
  return new Promise((resolve) => setTimeout(resolve, ms));
};
