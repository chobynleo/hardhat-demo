const { ethers, network } = require("hardhat");

const XXX = require(`../../deployments/${network.name}/XXX.json`);

async function main() {
    let [owner] = await ethers.getSigners();

    const Abi = [
      "function balanceOf(address owner) external view returns (uint)",
      "function approve(address spender, uint value) external returns (bool)",
      "function allowance(address owner, address spender) external view returns (uint)"
    ];

    let xxx = await new ethers.Contract(XXX.address, Abi, owner);

}

main()
    .then(() =>process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
