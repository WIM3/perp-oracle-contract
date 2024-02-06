import { MockContract, smock } from "@defi-wonderland/smock"
import { expect } from "chai"
import { BigNumber } from "ethers"
import { parseEther } from "ethers/lib/utils"
import { ethers, waffle } from "hardhat"
import { PythPriceFeedV3, MockAggregatorV3, MockAggregatorV3__factory } from "../typechain"

interface PythPriceFeedFixture {
    pythPriceFeed: PythPriceFeedV3
    aggregator: MockContract<MockAggregatorV3>
    pythPriceFeed2: PythPriceFeedV3
    aggregator2: MockContract<MockAggregatorV3>
}

async function pythPriceFeedFixture(): Promise<PythPriceFeedFixture> {
    const [admin] = await ethers.getSigners()
    const aggregatorFactory = await smock.mock<MockAggregatorV3__factory>("MockAggregatorV3", admin)
    const aggregator = await aggregatorFactory.deploy()
    aggregator.decimals.returns(() => 18)

    const pythPriceFeedFactory = await ethers.getContractFactory("PythPriceFeedV3")
    const pythPriceFeed = (await pythPriceFeedFactory.deploy(aggregator.address, 60*40, 900)) as PythPriceFeedV3

    const aggregatorFactory2 = await smock.mock<MockAggregatorV3__factory>("MockAggregatorV3", admin)
    const aggregator2 = await aggregatorFactory2.deploy()
    aggregator2.decimals.returns(() => 8)

    const pythPriceFeedFactory2 = await ethers.getContractFactory("PythPriceFeedV3")
    const pythPriceFeed2 = (await pythPriceFeedFactory2.deploy(
        aggregator2.address,
        900,
        900
    )) as PythPriceFeedV3

    return { pythPriceFeed, aggregator, pythPriceFeed2, aggregator2 }
}

describe("PythPriceFeedV3 Spec", () => {
    const [admin] = waffle.provider.getWallets()
    const loadFixture: ReturnType<typeof waffle.createFixtureLoader> = waffle.createFixtureLoader([admin])
    let pythPriceFeed: PythPriceFeedV3
    let aggregator: MockContract<MockAggregatorV3>
    let priceFeedDecimals: number
    let pythPriceFeed2: PythPriceFeedV3
    let aggregator2: MockContract<MockAggregatorV3>
    let priceFeedDecimals2: number

    beforeEach(async () => {
        const _fixture = await loadFixture(pythPriceFeedFixture)
        pythPriceFeed = _fixture.pythPriceFeed
        aggregator = _fixture.aggregator
        priceFeedDecimals = await pythPriceFeed.decimals()
        pythPriceFeed2 = _fixture.pythPriceFeed2
        aggregator2 = _fixture.aggregator2
        priceFeedDecimals2 = await pythPriceFeed2.decimals()
    })

    describe("edge cases, have the same timestamp for several rounds", () => {
        let currentTime: number
        let roundData: any[]

        async function updatePrice(index: number, price: number, forward: boolean = true): Promise<void> {
            roundData.push([index, parseEther(price.toString()), currentTime, currentTime, index])
            aggregator.latestRoundData.returns(() => {
                return roundData[roundData.length - 1]
            })
            await pythPriceFeed.update()
            if (forward) {
                currentTime += 15
                await ethers.provider.send("evm_setNextBlockTimestamp", [currentTime])
                await ethers.provider.send("evm_mine", [])
            }
        }

        it("force error, can't update if timestamp is the same", async () => {
            currentTime = (await waffle.provider.getBlock("latest")).timestamp
            roundData = [
                // [roundId, answer, startedAt, updatedAt, answeredInRound]
            ]
            // set first round data
            roundData.push([0, parseEther("399"), currentTime, currentTime, 0])
            aggregator.latestRoundData.returns(() => {
                return roundData[roundData.length - 1]
            })

            // update without forward timestamp
            await updatePrice(1, 400, false)
            await expect(pythPriceFeed.update()).to.be.revertedWith("CPF_NU")
        })
    })

    it("getAggregator", async () => {
        expect(await pythPriceFeed2.getAggregator()).to.be.eq(aggregator2.address)
    })
})