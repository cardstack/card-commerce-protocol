import chai, { expect } from 'chai';
import asPromised from 'chai-as-promised';
import { JsonRpcProvider } from '@ethersproject/providers';
import { Blockchain } from '../utils/Blockchain';
import { generatedWallets } from '../utils/generatedWallets';
import { BaseErc721Factory } from '../typechain/BaseErc721Factory';
import { BaseErc20Factory } from '../typechain/BaseErc20Factory';
import { Level } from '../typechain/Level';
import {BaseErc20, LevelFactory} from "../typechain";
import {Wallet} from "ethers";
import {BigNumber, BigNumberish, Wallet} from 'ethers';

chai.use(asPromised);

let provider = new JsonRpcProvider();
let blockchain = new Blockchain(provider);

describe('Level Registrar', () => {
    let [
        deployerWallet,
        otherWallet,
    ] = generatedWallets(provider);

    const defaultLevel: Level = {
        label: "noob",
        tokenID: 1,
        tokenAddress: "0x" // different badge, different token address
    }

    const proLevel: Level = {
        label: "pro",
        tokenID: 2,
        tokenAddress: "0x" // different badge, different token address
    }

    async function deploy() {
        const levelRegistrar = await (
            await new LevelFactory(deployerWallet).deploy()
        ).deployed();
        levelAddress = levelRegistrar.address;
    }

    function createERC20() {
        return new BaseErc20Factory(deployerWallet).deploy("Test Token", "TEST", 18);
    }

    function createERC721() {
        return new BaseErc721Factory(deployerWallet).deploy("Test Token", "TEST", 18);
    }

    async function registrarAs(wallet: Wallet) {
        return LevelFactory.connect(levelAddress, wallet)
    }

    describe('#constructor', () => {
        it('should be able to deploy', async () => {
            await expect(deploy()).eventually.fulfilled;
        });
    });

    describe("#levels", () => {

        let levelRegistrarContract: Level;
        let erc20: BaseErc20;

        beforeEach(async () => {
            await deploy();
            levelRegistrarContract = await registrarAs(deployerWallet);
            erc20 = await createERC20();
        });

        it("Claim level from proof", async () => {
        })

        it("Cannot claim level from proof for the second time", async () => {
        })

        it("Check level from proof", async () => {
        })

    });

    describe("#crossLevels", () => {
        let levelRegistrarContract: Level;
        let erc20: BaseErc20;

        beforeEach(async () => {
            await deploy();
            levelRegistrarContract = await registrarAs(deployerWallet);
            erc20 = await createERC20();
        });

        it("Should be able to get a level", async () => {
        })

    });

});
