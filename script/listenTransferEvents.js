const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

async function main() {
    const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545");

    provider.on("error", (err) => {
        console.error("Provider error:", err);
    });

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

    console.log("Listening for Transfer events...");

    contract.on("Transfer", (from, to, value, event) => {
        try {
            console.log("LIVE Transfer:");
            console.log("From:", from);
            console.log("To:", to);
            console.log("Value:", value.toString());
            console.log("Block:", event.log.blockNumber);
            console.log("Tx:", event.log.transactionHash);
            console.log("-------------------------");
        } catch (err) {
            console.error("Listener callback error:", err);
        }
    });
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});