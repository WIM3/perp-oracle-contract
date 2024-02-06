import { expect } from "chai"
import { BigNumber } from "ethers"
import { parseEther } from "ethers/lib/utils"
import { ethers, waffle } from "hardhat"
import { UniswapV3Pool, UniswapV3PriceFeed } from "../typechain"
import { MockContract } from "ethereum-waffle"
const { deployMockContract, provider } = waffle;

interface UniswapV3PriceFeedFixture {
    uniswapV3PriceFeed: UniswapV3PriceFeed
    uniswapV3Pool: MockContract
}

async function uniswapV3PriceFeedFixture(): Promise<UniswapV3PriceFeedFixture> {
    const [admin] = await ethers.getSigners()

    const UniV3 = require('../artifacts/contracts/test/uniswapmock/UniswapV3Pool.sol/UniswapV3Pool.json');
    const uniswapV3Pool = await deployMockContract(admin, UniV3.abi);

    const uniswapV3PriceFeedFactory = await ethers.getContractFactory("UniswapV3PriceFeed")
    const uniswapV3PriceFeed = (await uniswapV3PriceFeedFactory.deploy(uniswapV3Pool.address)) as UniswapV3PriceFeed

    return { uniswapV3PriceFeed, uniswapV3Pool }
}

describe("UniswapV3PriceFeed Spec", () => {
    const [admin] = waffle.provider.getWallets()
    const loadFixture: ReturnType<typeof waffle.createFixtureLoader> = waffle.createFixtureLoader([admin])
    let uniswapV3PriceFeed: UniswapV3PriceFeed
    let uniswapV3Pool: MockContract

    it("force error, pool address has to be a contract", async () => {
        const uniswapV3PriceFeedFactory = await ethers.getContractFactory("UniswapV3PriceFeed")
        await expect(uniswapV3PriceFeedFactory.deploy(admin.address)).to.be.revertedWith("UPF_PANC")
    })

    describe("pool address is contract", () => {
        beforeEach(async () => {
            const _fixture = await loadFixture(uniswapV3PriceFeedFixture)
            uniswapV3PriceFeed = _fixture.uniswapV3PriceFeed
            uniswapV3Pool = _fixture.uniswapV3Pool
        })

        describe("decimals()", () => {
            it("decimals should be 18", async () => {
                expect(await uniswapV3PriceFeed.decimals()).to.be.eq(18)
            })
        })

        describe("getPrice()", () => {
            it("twap", async () => {
                await uniswapV3Pool.mock.observe.returns([BigNumber.from(0), BigNumber.from(82800000)], [])
                // twapTick = (82800000-0) / 1800 = 46000
                // twap = 1.0001^46000 = 99.4614384055
                const indexPrice = await uniswapV3PriceFeed.getPrice()
                
                expect(indexPrice).to.be.eq(parseEther("99.461438405455592365"))
            })
        })
    })
})