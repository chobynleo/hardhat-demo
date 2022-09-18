const { ethers, network } = require("hardhat");

const FACTORY = require(`../../deployments/${network.name}/WETH9.json`);
const USDT = require(`../../deployments/${network.name}/USDT.json`);
const BUSD = require(`../../deployments/${network.name}/USDT.json`);
const WETH9 = require(`../../deployments/${network.name}/WETH9.json`);
const FACTORY = require(`../../deployments/${network.name}/UniswapV3Factory.json`);
const SwapExamples = require(`../../deployments/${network.name}/SwapExamples.json`);

async function main() {
    let [owner] = await ethers.getSigners();

    // 调用SwapExamples合约的swapExactInputSingle方法
    const amount = 1000
    const amountInMaximum = 10000

    const Abi = [
      "function balanceOf(address owner) external view returns (uint)",
      "function approve(address spender, uint value) external returns (bool)",
      "function allowance(address owner, address spender) external view returns (uint)"
    ];
    const SwapAbi = [];

    let busd_token = await new ethers.Contract(BUSD.address, Abi, owner);
    await busd_token.approve(SwapExamples.address, amount)

    let weth_token = await new ethers.Contract(WETH9.address, Abi, owner);
    await weth_token.approve(SwapExamples.address, amount);

    let swapExample = await new ethers.Contract(BSwapExamplesSD.address, SwapAbi, owner);
    const eth_output = await swapExample.swapExactInputSingle(100)
    console.log('eth_output:', eth_output)
    
}

main()
    .then(() =>process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
