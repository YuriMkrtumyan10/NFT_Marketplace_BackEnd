const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

//-------------------------as hh input parameters
module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    log("------------------NFT Marketplace----------------------")

    //no constructor
    args = []

    const nftMarketplace = await deploy("NftMarketplace", {
        from: deployer,
        args: args,
        logs: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying... ")
        await verify(nftMarketplace.address, args)
    }
    log("+++++++++++++++++++++++++++++++++++++++++++++++++++++++")
}

module.exports.tags = ["all", "nftmarketplace"]
