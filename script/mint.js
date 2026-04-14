const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

async function main() {
    const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545");

    if (!process.env.PRIVATE_KEY) {
        throw new Error("PRIVATE_KEY is not set in .env");
    }

    if (!process.env.CONTRACT_ADDRESS) {
        throw new Error("CONTRACT_ADDRESS is not set in .env");
    }

    const privateKey = process.env.PRIVATE_KEY;
    const wallet = new ethers.Wallet(privateKey, provider);

    const artifactPath = path.join(
        __dirname,
        "..",
        "out",
        "MockERC20.sol",
        "MockERC20.json"
    );

    const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
    const abi = artifact.abi;

    const contract = new ethers.Contract(
        process.env.CONTRACT_ADDRESS,
        abi,
        wallet
    );

    const user = await wallet.getAddress();
    const amount = ethers.parseUnits("1000", 18);

    const tx = await contract.mint(user, amount);
    console.log("Mint tx hash:", tx.hash);

    const receipt = await tx.wait();
    console.log("Receipt status:", receipt.status);
}

main().catch(console.error);