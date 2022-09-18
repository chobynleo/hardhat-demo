const { ethers, upgrades, network, artifacts } = require("hardhat");
const { writeAbiAddr } = require('../utils/log');


async function main() {
    let [owner]  = await ethers.getSigners();

    const _USDT = await ethers.getContractFactory("Mock_USDT");
    const USDT = await _USDT.deploy();
    await USDT.deployed();

    let Artifact = await artifacts.readArtifact("Mock_USDT")
    await writeAbiAddr(Artifact, USDT.address, "Mock_USDT", network.name);

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
});