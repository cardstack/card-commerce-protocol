import { BaseErc20Factory, InventoryFactory } from '../typechain';
import { BigNumber, BigNumberish, Wallet } from 'ethers';
import { MaxUint256 } from '@ethersproject/constants';
import { generatedWallets } from '../utils/generatedWallets';
import { JsonRpcProvider } from '@ethersproject/providers';
import { formatUnits } from '@ethersproject/units';
import { signTypedData } from 'eth-sig-util';
import { fromRpcSig } from 'ethereumjs-util';

const provider = new JsonRpcProvider();
const [deployerWallet] = generatedWallets(provider);

export async function deployCurrency(): Promise<string> {
  const currency = await new BaseErc20Factory(deployerWallet).deploy(
    'test',
    'TEST',
    18
  );
  return currency.address;
}

export async function mintCurrency(
  currency: string,
  to: string,
  value: number
): Promise<void> {
  await BaseErc20Factory.connect(currency, deployerWallet).mint(to, value);
}

export async function approveCurrency(
  currency: string,
  spender: string,
  owner: Wallet
): Promise<void> {
  await BaseErc20Factory.connect(currency, owner).approve(spender, MaxUint256);
}
export async function getBalance(
  currency: string,
  owner: string
): Promise<BigNumberish> {
  return BaseErc20Factory.connect(currency, deployerWallet).balanceOf(owner);
}

export function toNumWei(val: BigNumberish): number {
  return parseFloat(formatUnits(val, 'wei'));
}

export type EIP712Sig = {
  deadline: BigNumberish;
  v: any; // eslint-disable-line @typescript-eslint/no-explicit-any
  r: any; // eslint-disable-line @typescript-eslint/no-explicit-any
  s: any; // eslint-disable-line @typescript-eslint/no-explicit-any
};

export async function signPermit(
  owner: Wallet,
  toAddress: string,
  tokenAddress: string,
  tokenId: number,
  chainId: number
): Promise<EIP712Sig> {
  let nonce;
  const inventoryContract = InventoryFactory.connect(tokenAddress, owner);

  try {
    nonce = (
      await inventoryContract.permitNonces(owner.address, tokenId)
    ).toNumber();
  } catch (e) {
    console.error('NONCE', e);
    throw e;
  }

  const deadline = Math.floor(new Date().getTime() / 1000) + 60 * 60 * 24; // 24 hours
  const name = await inventoryContract.name();

  try {
    const sig = signTypedData(Buffer.from(owner.privateKey.slice(2), 'hex'), {
      data: {
        types: {
          EIP712Domain: [
            { name: 'name', type: 'string' },
            { name: 'version', type: 'string' },
            { name: 'chainId', type: 'uint256' },
            { name: 'verifyingContract', type: 'address' },
          ],
          Permit: [
            { name: 'spender', type: 'address' },
            { name: 'tokenId', type: 'uint256' },
            { name: 'nonce', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
          ],
        },
        primaryType: 'Permit',
        domain: {
          name,
          version: '1',
          chainId,
          verifyingContract: inventoryContract.address,
        },
        message: {
          spender: toAddress,
          tokenId,
          nonce,
          deadline,
        },
      },
    });
    const response = fromRpcSig(sig);
    return {
      r: response.r,
      s: response.s,
      v: response.v,
      deadline: deadline.toString(),
    };
  } catch (e) {
    console.error(e);
    throw e;
  }
}

export async function signMintWithSig(
  owner: Wallet,
  tokenAddress: string,
  creator: string,
  contentHash: string,
  metadataHash: string,
  chainId: number
): Promise<EIP712Sig> {
  let nonce;
  const inventoryContract = InventoryFactory.connect(tokenAddress, owner);

  try {
    nonce = (await inventoryContract.mintWithSigNonces(creator)).toNumber();
  } catch (e) {
    console.error('NONCE', e);
    throw e;
    return;
  }

  const deadline = Math.floor(new Date().getTime() / 1000) + 60 * 60 * 24; // 24 hours
  const name = await inventoryContract.name();

  try {
    const sig = signTypedData(Buffer.from(owner.privateKey.slice(2), 'hex'), {
      data: {
        types: {
          EIP712Domain: [
            { name: 'name', type: 'string' },
            { name: 'version', type: 'string' },
            { name: 'chainId', type: 'uint256' },
            { name: 'verifyingContract', type: 'address' },
          ],
          MintWithSig: [
            { name: 'contentHash', type: 'bytes32' },
            { name: 'metadataHash', type: 'bytes32' },
            { name: 'nonce', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
          ],
        },
        primaryType: 'MintWithSig',
        domain: {
          name,
          version: '1',
          chainId,
          verifyingContract: inventoryContract.address,
        },
        message: {
          contentHash,
          metadataHash,
          nonce,
          deadline,
        },
      },
    });
    const response = fromRpcSig(sig);
    return {
      r: response.r,
      s: response.s,
      v: response.v,
      deadline: deadline.toString(),
    };
  } catch (e) {
    console.error(e);
    throw e;
  }
}
