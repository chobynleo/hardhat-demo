const { ethers, network } = require("hardhat");


async function main() {
    let [owner] = await ethers.getSigners();

    let ABI = [
        "function swapExactTokensForTokens(uint amountIn,uint amountOutMin,address[] calldata path,address to,uint deadline) external returns (uint[] memory amounts)",
        "function transferFrom(address from, address to, uint amount)",
    ]

    let iface = new ethers.utils.Interface(ABI);
    let temp = iface.getSighash("swapExactTokensForTokens")
    let txData = "0x38ed17390000000000000000000000000000000000000000000000015af1d78b58c40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000014127e127c6788badae75ba213a58ac22944c8200000000000000000000000000000000000000000000000000000000624444cf000000000000000000000000000000000000000000000000000000000000000300000000000000000000000095ee03e1e2c5c4877f9a298f1c0d6c98698fab7b0000000000000000000000000e09fabb73bd3ade0a17ecc321fd13a19e81ce82000000000000000000000000e04fe47516c4ebd56bc6291b15d46a47535e736b"
    temp = iface.decodeFunctionData("swapExactTokensForTokens", txData);
    
    const data = "0x23b872dd0000000000000000000000008ba1f109551bd432803012645ac136ddd64dba72000000000000000000000000ab7c8803962c0f2f5bbbe3fa8bf41cd82aa1923c0000000000000000000000000000000000000000000000000de0b6b3a7640000";
    const value = ethers.utils.parseUnits("1", 18);
    temp = iface.parseTransaction({ data, value });

    console.log(temp)
    
}

main()
    .then(() =>process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
