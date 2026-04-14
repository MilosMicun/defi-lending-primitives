const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

async function main() {
    const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545");

    const artifactPath = path.join(
        __dirname,
        "..",
        "out",
        "MockERC20.sol",
        "MockERC20.json"
    );

    const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
    const abi = artifact.abi;

    const contractAddress = process.env.CONTRACT_ADDRESS;

    if (!contractAddress) {
        throw new Error("CONTRACT_ADDRESS is not set in .env");
    }

    const contract = new ethers.Contract(contractAddress, abi, provider);

    const filter = contract.filters.Transfer();

    const fromBlock = 0;
    const toBlock = "latest";

    const events = await contract.queryFilter(filter, fromBlock, toBlock);

    console.log(`Found ${events.length} Transfer events`);

    for (const event of events) {
        console.log("Transfer event:");
        console.log("From:", event.args.from);
        console.log("To:", event.args.to);
        console.log("Value:", event.args.value.toString());
        console.log("Block:", event.blockNumber);
        console.log("Tx:", event.transactionHash);
        console.log("-------------------------");
    }
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});