import chai, { expect } from 'chai';
import asPromised from 'chai-as-promised';
import { JsonRpcProvider } from '@ethersproject/providers';
import { Blockchain } from '../utils/Blockchain';
import { generatedWallets } from '../utils/generatedWallets';
import { BaseErc20Factory } from '../typechain/BaseErc20Factory';
import { LevelRegistrar } from '../typechain/Level';
import {BaseErc20, LevelRegistrarFactory} from "../typechain";
import {Wallet} from "ethers";

chai.use(asPromised);

let provider = new JsonRpcProvider();
let blockchain = new Blockchain(provider);

type Level = {
    label: string;
    threshold: number;
}

type CrossLevel = {
    globalLevelLabel: string;
    recognisedLevelsByLabel: string[];
    setters: string[];
    tokens: string[];
}

describe('Level Registrar', () => {
    let [
        deployerWallet,
        otherWallet,
    ] = generatedWallets(provider);

    const defaultLevel: Level = {
        label: "noob",
        threshold: 0
    }

    const proLevel: Level = {
        label: "pro",
        threshold: 100
    }

    const defaultCrossLevel: CrossLevel = {
        globalLevelLabel: "Star alliance gold",
        recognisedLevelsByLabel: ["Air NZ premium", "United Gold"],
        setters: [deployerWallet.address, otherWallet.address],
        tokens: [deployerWallet.address, otherWallet.address]
    }

    let levelRegistrarAddress: string;

    async function deploy() {
        const levelRegistrar = await (
            await new LevelRegistrarFactory(deployerWallet).deploy()
        ).deployed();
        levelRegistrarAddress = levelRegistrar.address;
    }

    function createERC20() {
        return new BaseErc20Factory(deployerWallet).deploy("Test Token", "TEST", 18);
    }

    async function registrarAs(wallet: Wallet) {
        return LevelRegistrarFactory.connect(levelRegistrarAddress, wallet)
    }

    describe('#constructor', () => {
        it('should be able to deploy', async () => {
            await expect(deploy()).eventually.fulfilled;
        });
    });

    describe("#levels", () => {

        let levelRegistrarContract: LevelRegistrar;
        let erc20: BaseErc20;

        beforeEach(async () => {
            await deploy();
            levelRegistrarContract = await registrarAs(deployerWallet);
            erc20 = await createERC20();
        });

        it("Should be able to get a level from a proof", async () => {
        })

        it("A proof can be used", async () => {
        })

        it("A proof cannot be used for second time", async () => {
        })

        it("Should be able to retrieve a badge from a proof", async () => {
        })

    });

    describe("#crossLevels", () => {
        let levelRegistrarContract: LevelRegistrar;
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
