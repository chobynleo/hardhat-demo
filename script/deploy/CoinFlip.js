const { ethers, upgrades, network, artifacts } = require("hardhat");
const { writeAbiAddr } = require('../utils/log');


async function main() {
    let [owner]  = await ethers.getSigners();

    const _CoinFlip = await ethers.getContractFactory("CoinFlip");
    const CoinFlip = await _CoinFlip.deploy();
    await CoinFlip.deployed();

    let Artifact = await artifacts.readArtifact("CoinFlip")
    await writeAbiAddr(Artifact, CoinFlip.address, "CoinFlip", network.name);

    const _Hack = await ethers.getContractFactory("Hack");
    const Hack = await _Hack.deploy();
    await Hack.deployed();

    Artifact = await artifacts.readArtifact("Hack")
    await writeAbiAddr(Artifact, Hack.address, "Hack", network.name);

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
});