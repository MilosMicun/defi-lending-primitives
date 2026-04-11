require("dotenv").config();
const { ethers } = require("ethers");

const poolAbi = [
  "event Borrow(address indexed reserve, address user, address indexed onBehalfOf, uint256 amount, uint8 interestRateMode, uint256 borrowRate, uint16 indexed referralCode)",
];

const iface = new ethers.Interface(poolAbi);

async function inspectRevert(provider, txHash) {
  const tx = await provider.getTransaction(txHash);

  if (!tx) {
    throw new Error("Transaction not found");
  }

  const receipt = await provider.getTransactionReceipt(txHash);

  if (!receipt) {
    throw new Error("Transaction receipt not found for revert inspection");
  }

  try {
    await provider.call(
      {
        to: tx.to,
        data: tx.data,
        value: tx.value,
        from: tx.from,
      },
      receipt.blockNumber
    );
  } catch (error) {
    console.log("Revert detected");
    console.log(
      "Revert reason:",
      error.reason || error.shortMessage || error.message
    );
  }
}

async function main() {
  const rpcUrl = process.env.RPC_URL;
  const txHash = process.env.TX_HASH;
  const expectedPool = process.env.POOL_ADDRESS;

  if (!rpcUrl) throw new Error("RPC_URL is not set");
  if (!txHash) throw new Error("TX_HASH is not set");
  if (!expectedPool) throw new Error("POOL_ADDRESS is not set");

  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const receipt = await provider.getTransactionReceipt(txHash);

  if (!receipt) {
    throw new Error("Transaction receipt not found");
  }

  console.log("--- Receipt Summary ---");
  console.log("Status:    ", receipt.status === 1 ? "success" : "reverted");
  console.log("Block:     ", receipt.blockNumber);
  console.log("Gas used:  ", receipt.gasUsed.toString());
  console.log("Logs count:", receipt.logs.length);
  console.log("-----------------------");

  if (receipt.status === 0) {
    await inspectRevert(provider, txHash);
    return;
  }

  let borrowFound = false;

  for (const log of receipt.logs) {
    if (log.address.toLowerCase() !== expectedPool.toLowerCase()) {
      continue;
    }

    try {
      const parsedLog = iface.parseLog(log);

      if (!parsedLog || parsedLog.name !== "Borrow") {
        continue;
      }

      borrowFound = true;

      console.log("--- Borrow Event ---");
      console.log("Emitter:      ", log.address);
      console.log("Reserve:      ", parsedLog.args.reserve);
      console.log("User:         ", parsedLog.args.user);
      console.log("On behalf of: ", parsedLog.args.onBehalfOf);
      console.log("Amount:       ", parsedLog.args.amount.toString());
      console.log("Rate mode:    ", parsedLog.args.interestRateMode.toString(), "(1=stable, 2=variable)");
      console.log("Borrow rate:  ", parsedLog.args.borrowRate.toString(), "(ray, 1e27)");
      console.log("Referral code:", parsedLog.args.referralCode.toString());
      console.log("--------------------");
    } catch (_) {
      continue;
    }
  }

  if (!borrowFound) {
    console.log("No Borrow event found in receipt logs");
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});