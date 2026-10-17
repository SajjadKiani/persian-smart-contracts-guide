import {
  createPublicClient, createWalletClient, custom, http, parseAbi,
  type Address, type EIP1193Provider,
} from 'viem';
import { foundry } from 'viem/chains';

const abi = parseAbi([
  'function buyer() view returns (address)',
  'function price() view returns (uint256)',
  'function fund() payable',
  'error Unauthorized()',
  'error InvalidState()',
  'error WrongAmount()',
  'error DeadlinePassed()',
]);

// Browser only. Pass an EIP-1193 wallet provider and your local deployment.
export async function fundEscrow(provider: EIP1193Provider, address: Address) {
  const publicClient = createPublicClient({
    chain: foundry,
    transport: http('http://127.0.0.1:8545'),
  });
  const walletClient = createWalletClient({
    chain: foundry,
    transport: custom(provider),
  });
  const [account] = await walletClient.requestAddresses();
  if (!account) throw new Error('No wallet account');
  if (await walletClient.getChainId() !== foundry.id) {
    throw new Error('Switch wallet to local Anvil (31337)');
  }
  const bytecode = await publicClient.getCode({ address });
  if (!bytecode || bytecode === '0x') throw new Error('No contract at address');

  const buyer = await publicClient.readContract({ address, abi, functionName: 'buyer' });
  const price = await publicClient.readContract({ address, abi, functionName: 'price' });
  if (account.toLowerCase() !== buyer.toLowerCase()) {
    throw new Error('Connect the buyer account');
  }

  const { request } = await publicClient.simulateContract({
    address, abi, functionName: 'fund', account, value: price,
  });
  const hash = await walletClient.writeContract(request);
  sessionStorage.setItem('pending-escrow', JSON.stringify({
    chainId: foundry.id, address, account, hash,
  }));

  let wasReplaced = false;
  const receipt = await publicClient.waitForTransactionReceipt({
    hash,
    confirmations: 1,
    onReplaced: () => { wasReplaced = true; },
  });
  if (wasReplaced) throw new Error('Inspect replacement transaction before continuing');
  if (receipt.status !== 'success') throw new Error('Transaction reverted');
  sessionStorage.removeItem('pending-escrow');
  return receipt;
}
