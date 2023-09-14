import { AbiCoder, Contract, formatEther, formatUnits, parseUnits } from "ethers";
import { ethers } from "hardhat";
import source from "./source.json";

const MAX_GAS_PRICE = parseUnits("0.7", "gwei"); // Set your maximum value here
const BLOCK_TIME = 12; // Average block generation time in Ethereum, in seconds
const PORTAL_ADDRESS = "0xb3c0e57d560f36697f5d727c2c6db4e0c8f87bd8";
const BATCH_LENGTH = 100;

interface AttestationPayload {
  schemaId?: string;
  expirationDate?: number;
  subject: string;
  attestationData: string;
}

async function callMassImport(batches: AttestationPayload[][], attestationRegistry: Contract) {
  if (batches.length === 0) {
    return;
  }

  // TODO: check batches length is decreasing regularly

  const batch = batches.pop();

  if (!batch) {
    return;
  }

  // Retrieve information about the last block
  const lastBlock = await ethers.provider.getBlock("latest");

  try {
    if (!lastBlock) {
      batches.unshift(batch); // Put the batch back in the list
      setTimeout(callMassImport, BLOCK_TIME * 1000, batches, attestationRegistry); // Wait for a block generation time before retrying
      return;
    }

    // Retrieve the current gas price
    const gasPrice = (await ethers.provider.getFeeData()).gasPrice;

    // Check if the gas price is defined
    if (!gasPrice) {
      console.log(`Gas price is unknown. Aborting transaction.`);
      batches.unshift(batch); // Put the batch back in the list
      setTimeout(callMassImport, BLOCK_TIME * 1000, batches, attestationRegistry); // Wait for a block generation time before retrying
      return;
    }

    // Check if the gas price is acceptable
    if (gasPrice > MAX_GAS_PRICE) {
      console.log(`Gas price of ${formatUnits(gasPrice, "gwei")} gwei is too high. Aborting transaction.`);
      batches.unshift(batch); // Put the batch back in the list
      setTimeout(callMassImport, BLOCK_TIME * 1000, batches, attestationRegistry); // Wait for a block generation time before retrying
      return;
    }

    const gasEstimated = await attestationRegistry.massImport.estimateGas(batch, PORTAL_ADDRESS);

    console.log(
      `Sending a transaction with a gas price of ${formatUnits(
        gasPrice.toString(),
        "gwei",
      )} gwei and an estimated gas of ${formatUnits(gasEstimated, "gwei")} for an estimated total of ${formatEther(
        gasEstimated * gasPrice,
      )} ETH`,
    );

    // Call the contract method
    const txResponse = await attestationRegistry.massImport(batch, PORTAL_ADDRESS, {
      gasPrice: gasPrice,
    });

    console.log(`Transaction sent with hash: ${txResponse.hash}`);

    // Wait for the transaction receipt
    const receipt = await txResponse.wait();

    console.log(`Transaction successfully confirmed in block ${receipt.blockNumber}`);
    console.log(`There are ${batches.length} batches left`);

    // Recursively call the function for the next transaction
    callMassImport(batches, attestationRegistry);
  } catch (error: unknown) {
    assertIsError(error);
    console.log(`Transaction failed with error: ${error.message}. Retrying...`);
    batches.unshift(batch); // Put the batch back in the list
    setTimeout(callMassImport, BLOCK_TIME * 1000, batches, attestationRegistry); // Wait for a block generation time before retrying
  }
}

async function main() {
  const proxyAddress = process.env.ATTESTATION_REGISTRY_ADDRESS ?? "";
  const attestationRegistry = await ethers.getContractAt("AttestationRegistry", proxyAddress);

  const abiCoder = new AbiCoder();

  const rawPayloads: AttestationPayload[] = source.map((item) => ({
    ...item,
    subject: abiCoder.encode(["address"], [item.subject]),
    attestationData: abiCoder.encode(["uint8"], [item.attestationData]),
  }));

  const attestationPayloads: AttestationPayload[] = [];

  for (let i = 0; i < 1000; i++) {
    attestationPayloads.push(...rawPayloads);
  }

  console.log(`${attestationPayloads.length} total payloads to attest`);

  const batches: AttestationPayload[][] = Array.from(
    { length: Math.ceil(attestationPayloads.length / BATCH_LENGTH) },
    (v, i) => attestationPayloads.slice(i * BATCH_LENGTH, i * BATCH_LENGTH + BATCH_LENGTH),
  ).reverse();

  console.log(`${batches.length} batches of payloads to attest`);

  await callMassImport(batches, attestationRegistry);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

function assertIsError(error: unknown): asserts error is Error {
  if (!(error instanceof Error)) {
    throw error;
  }
}
