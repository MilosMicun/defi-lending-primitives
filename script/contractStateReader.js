const { ethers } = require("ethers");
require("dotenv").config();

const RPC_URL = process.env.RPC_URL;

if (!RPC_URL) {
  throw new Error("Missing RPC_URL in .env");
}

const provider = new ethers.JsonRpcProvider(RPC_URL);

const ADDRESSES = {
  multicall: process.env.MULTICALL3_ADDRESS,
  token: process.env.TOKEN_ADDRESS,
  user: process.env.USER_ADDRESS,
  dataProvider: process.env.AAVE_DATA_PROVIDER_ADDRESS,
  reserveAsset: process.env.RESERVE_ASSET_ADDRESS,
};

for (const [key, value] of Object.entries(ADDRESSES)) {
  if (!value) {
    throw new Error(`Missing address for ${key}`);
  }
}

const ERC20_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function totalSupply() view returns (uint256)",
];

const MULTICALL3_ABI = [
  "function aggregate3(tuple(address target, bool allowFailure, bytes callData)[] calls) view returns (tuple(bool success, bytes returnData)[] returnData)",
];

const AAVE_DATA_PROVIDER_ABI = [
  "function getReserveData(address asset) view returns (uint256 unbacked, uint256 accruedToTreasuryScaled, uint256 totalAToken, uint256 totalStableDebt, uint256 totalVariableDebt, uint256 liquidityRate, uint256 variableBorrowRate, uint256 stableBorrowRate, uint256 averageStableBorrowRate, uint256 liquidityIndex, uint256 variableBorrowIndex, uint40 lastUpdateTimestamp)",
  "function getReserveTokensAddresses(address asset) view returns (address aTokenAddress, address stableDebtTokenAddress, address variableDebtTokenAddress)",
];

const erc20Interface = new ethers.Interface(ERC20_ABI);
const dataProviderInterface = new ethers.Interface(AAVE_DATA_PROVIDER_ABI);

const multicall = new ethers.Contract(
  ADDRESSES.multicall,
  MULTICALL3_ABI,
  provider
);

const RAY = 10n ** 27n;

function rayToPercent(rayValue) {
  return ((Number(rayValue) / Number(RAY)) * 100).toFixed(4) + "%";
}

async function main() {
  const balanceOfCallData = erc20Interface.encodeFunctionData("balanceOf", [
    ADDRESSES.user,
  ]);

  const decimalsCallData = erc20Interface.encodeFunctionData("decimals", []);

  const totalSupplyCallData = erc20Interface.encodeFunctionData(
    "totalSupply",
    []
  );

  const reserveDataCallData = dataProviderInterface.encodeFunctionData(
    "getReserveData",
    [ADDRESSES.reserveAsset]
  );

  const reserveTokensCallData = dataProviderInterface.encodeFunctionData(
    "getReserveTokensAddresses",
    [ADDRESSES.reserveAsset]
  );

  const calls = [
    {
      target: ADDRESSES.token,
      allowFailure: true,
      callData: balanceOfCallData,
    },
    {
      target: ADDRESSES.token,
      allowFailure: true,
      callData: decimalsCallData,
    },
    {
      target: ADDRESSES.token,
      allowFailure: true,
      callData: totalSupplyCallData,
    },
    {
      target: ADDRESSES.dataProvider,
      allowFailure: true,
      callData: reserveDataCallData,
    },
    {
      target: ADDRESSES.dataProvider,
      allowFailure: true,
      callData: reserveTokensCallData,
    },
  ];

  const results = await multicall.aggregate3(calls);

  const balanceResult = results[0];
  if (!balanceResult.success) {
    throw new Error("balanceOf subcall failed");
  }

  const balance = erc20Interface.decodeFunctionResult(
    "balanceOf",
    balanceResult.returnData
  )[0];

  const decimalsResult = results[1];
  if (!decimalsResult.success) {
    throw new Error("decimals subcall failed");
  }

  const decimals = erc20Interface.decodeFunctionResult(
    "decimals",
    decimalsResult.returnData
  )[0];

  const totalSupplyResult = results[2];
  if (!totalSupplyResult.success) {
    throw new Error("totalSupply subcall failed");
  }

  const totalSupply = erc20Interface.decodeFunctionResult(
    "totalSupply",
    totalSupplyResult.returnData
  )[0];

  const reserveDataResult = results[3];
  if (!reserveDataResult.success) {
    throw new Error("getReserveData subcall failed");
  }

  const [
    unbacked,
    accruedToTreasuryScaled,
    totalAToken,
    totalStableDebt,
    totalVariableDebt,
    liquidityRate,
    variableBorrowRate,
    stableBorrowRate,
    averageStableBorrowRate,
    liquidityIndex,
    variableBorrowIndex,
    lastUpdateTimestamp,
  ] = dataProviderInterface.decodeFunctionResult(
    "getReserveData",
    reserveDataResult.returnData
  );

  const reserveTokensResult = results[4];
  if (!reserveTokensResult.success) {
    throw new Error("getReserveTokensAddresses subcall failed");
  }

  const [aToken, stableDebtToken, variableDebtToken] =
    dataProviderInterface.decodeFunctionResult(
      "getReserveTokensAddresses",
      reserveTokensResult.returnData
    );

  const formattedBalance = ethers.formatUnits(balance, decimals);
  const formattedTotalSupply = ethers.formatUnits(totalSupply, decimals);
  const formattedTotalAToken = ethers.formatUnits(totalAToken, decimals);
  const formattedTotalStableDebt = ethers.formatUnits(totalStableDebt, decimals);
  const formattedTotalVariableDebt = ethers.formatUnits(
    totalVariableDebt,
    decimals
  );

  const formattedLiquidityRate = rayToPercent(liquidityRate);
  const formattedVariableBorrowRate = rayToPercent(variableBorrowRate);
  const formattedStableBorrowRate = rayToPercent(stableBorrowRate);
  const formattedAverageStableBorrowRate = rayToPercent(
    averageStableBorrowRate
  );

  console.log("=== ERC20 ===");
  console.log("balance:", formattedBalance);
  console.log("decimals:", decimals.toString());
  console.log("totalSupply:", formattedTotalSupply);

  console.log("\n=== Reserve Data ===");
  console.log("unbacked:", unbacked.toString());
  console.log("accruedToTreasuryScaled:", accruedToTreasuryScaled.toString());
  console.log("totalAToken:", formattedTotalAToken);
  console.log("totalStableDebt:", formattedTotalStableDebt);
  console.log("totalVariableDebt:", formattedTotalVariableDebt);
  console.log("liquidityRate:", formattedLiquidityRate);
  console.log("variableBorrowRate:", formattedVariableBorrowRate);
  console.log("stableBorrowRate:", formattedStableBorrowRate);
  console.log(
    "averageStableBorrowRate:",
    formattedAverageStableBorrowRate
  );
  console.log("liquidityIndex:", liquidityIndex.toString());
  console.log("variableBorrowIndex:", variableBorrowIndex.toString());
  console.log("lastUpdateTimestamp:", lastUpdateTimestamp.toString());

  console.log("\n=== Reserve Tokens ===");
  console.log("aToken:", aToken);
  console.log("stableDebtToken:", stableDebtToken);
  console.log("variableDebtToken:", variableDebtToken);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});