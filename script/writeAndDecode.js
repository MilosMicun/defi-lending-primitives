const { ethers, NonceManager } = require("ethers");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

async function main() {
    const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545");

    if (!process.env.PRIVATE_KEY) {
        throw new Error("PRIVATE_KEY is not set in .env");
    }

    const privateKey = process.env.PRIVATE_KEY;
    const baseWallet = new ethers.Wallet(privateKey, provider);
    const wallet = new NonceManager(baseWallet);

    const artifactPath = path.join(
        __dirname,
        "..",
        "out",
        "MockERC20.sol",
        "MockERC20.json"
    );

    const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
    const abi = artifact.abi;
    const bytecode = artifact.bytecode;

    const factory = new ethers.ContractFactory(abi, bytecode, wallet);
    const contract = await factory.deploy("MockToken", "MTK");

    const deploymentTx = contract.deploymentTransaction();
    console.log("Deployment tx hash:", deploymentTx.hash);

    const deployReceipt = await deploymentTx.wait();
    console.log("Deploy receipt status:", deployReceipt.status);

    await contract.waitForDeployment();

    const contractAddress = await contract.getAddress();
    console.log("MockERC20 deployed at:", contractAddress);

    const user = await baseWallet.getAddress();
    const amount = ethers.parseUnits("1000", 18);

    const tx = await contract.mint(user, amount);
    console.log("Mint tx hash:", tx.hash);

    const receipt = await tx.wait();

    console.log("Receipt status:", receipt.status);
    console.log("Logs:", receipt.logs);

    for (const log of receipt.logs) {
        try {
            const parsed = contract.interface.parseLog(log);

            console.log("Decoded event:");
            console.log("Name:", parsed.name);
            console.log("Args:", parsed.args);
        } catch (err) {
            console.error(`Failed to parse log from ${log.address}:`, err.message);
        }
    }

    const balance = await contract.balanceOf(user);
    console.log("User balance:", balance.toString());
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});