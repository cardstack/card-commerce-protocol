import fs from 'fs-extra';
import { JsonRpcProvider } from '@ethersproject/providers';
import { Wallet } from '@ethersproject/wallet';
import { InventoryFactory } from '../typechain/InventoryFactory';
import { MarketFactory } from '../typechain/MarketFactory';
import { config as dotenv } from 'dotenv';
import minimist from 'minimist';

async function start() {
  const args = minimist(process.argv.slice(2));

  if (!args.chainId) {
    throw new Error('--chainId chain ID is required');
  }
  const path = `${process.cwd()}/.env${
    args.chainId === 1 ? '.prod' : args.chainId === 4 ? '.dev' : '.local'
  }`;
  await dotenv({ path });
  const provider = new JsonRpcProvider(process.env.RPC_ENDPOINT);
  const wallet = new Wallet(`0x${process.env.PRIVATE_KEY}`, provider);
  const sharedAddressPath = `${process.cwd()}/addresses/${args.chainId}.json`;
  const addressBook = JSON.parse(await fs.readFileSync(sharedAddressPath));
  if (addressBook.market) {
    throw new Error(
      `market already exists in address book at ${sharedAddressPath}. Please move it first so it is not overwritten`
    );
  }
  if (addressBook.media) {
    throw new Error(
      `media already exists in address book at ${sharedAddressPath}. Please move it first so it is not overwritten`
    );
  }

  console.log('Deploying Market...');
  const deployTx = await new MarketFactory(wallet).deploy();
  console.log('Deploy TX: ', deployTx.deployTransaction.hash);
  await deployTx.deployed();
  console.log('Market deployed at ', deployTx.address);
  addressBook.market = deployTx.address;

  console.log('Deploying Media...');
  const mediaDeployTx = await new InventoryFactory(wallet).deploy(
    addressBook.market
  );
  console.log(`Deploy TX: ${mediaDeployTx.deployTransaction.hash}`);
  await mediaDeployTx.deployed();
  console.log(`Media deployed at ${mediaDeployTx.address}`);
  addressBook.inventory = mediaDeployTx.address;

  console.log('Configuring Market...');
  const market = MarketFactory.connect(addressBook.market, wallet);
  //TODO plug in the SPEND exchange contract address here
  const tx = await market.configure(
    addressBook.inventory,
    addressBook.inventory
  );
  console.log(`Market configuration tx: ${tx.hash}`);
  await tx.wait();
  console.log(`Market configured.`);

  await fs.writeFile(sharedAddressPath, JSON.stringify(addressBook, null, 2));
  console.log(`Contracts deployed and configured. ☼☽`);
}

start().catch((e: Error) => {
  console.error(e);
  process.exit(1);
});
