const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deployer } = await getNamedAccounts()
    const { deploy, log } = deployments
    log("---------------------Basic NFT-------------------------")

    args = []

    const basicNft = await deploy("BasicNft", {
        from: deployer,
        logs: true,
        args: args,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying... ")
        await verify(basicNft.address, args)
    }
    log("+++++++++++++++++++++++++++++++++++++++++++++++++++++++")
}

module.exports.tags = ["all", "basicNft"]
