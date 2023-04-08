const { ethers, network } = require("hardhat");

async function main() {
    let [owner] = await ethers.getSigners();

    const _USDT = await ethers.getContractFactory("Test");
    const USDT = await _USDT.deploy();
    await USDT.deployed();

    const Abi = [
        "function test(tuple(address token,address tokenOut,uint256 a,uint256 b)) public view returns (uint256)",
    ];

    var arg = {
        token: owner.address,
        tokenOut: owner.address,
        a: 1,
        b: 2
    }
    console.log('原生合约:', await USDT.test(arg))
    
    let test = new ethers.Contract(USDT.address, Abi, owner);

    const inamountWeth = ethers.utils.parseEther("2")
    console.log('ABI方式：', await test.test(arg))
}

main()
    .then(() =>process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
