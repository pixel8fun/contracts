/*
These values were obtained using: https://github.com/SKYBITDev3/SKYBIT-Keyless-Deployment
(This is using the Solady CREATE3 implementation under the hood).
*/

import { type PublicClient, type WalletClient, getContract, formatEther } from 'viem';

export const CREATE3_FACTORY_NAME = 'CREATE3Factory'

export const CREATE3_FACTORY_BYTECODE =
  '0x608060405234801561000f575f80fd5b506103868061001d5f395ff3fe608060405260043610610028575f3560e01c806350f1c4641461002c578063cdcb760a14610074575b5f80fd5b348015610037575f80fd5b5061004b61004636600461020e565b610087565b60405173ffffffffffffffffffffffffffffffffffffffff909116815260200160405180910390f35b61004b61008236600461027d565b6100ea565b6040517fffffffffffffffffffffffffffffffffffffffff000000000000000000000000606084901b166020820152603481018290525f906054016040516020818303038152906040528051906020012091506100e382610147565b9392505050565b6040517fffffffffffffffffffffffffffffffffffffffff0000000000000000000000003360601b166020820152603481018390525f906054016040516020818303038152906040528051906020012092506100e383833461019c565b5f604051305f5260ff600b53826020527f21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f6040526055600b20601452806040525061d6945f52600160345350506017601e2090565b5f6f67363d3d37363d34f03d5260086018f35f52836010805ff5806101c85763301164255f526004601cfd5b8060145261d6945f5260016034536017601e2091505f8085516020870186855af16101fa576319b991a85f526004601cfd5b50803b6100e3576319b991a85f526004601cfd5b5f806040838503121561021f575f80fd5b823573ffffffffffffffffffffffffffffffffffffffff81168114610242575f80fd5b946020939093013593505050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b5f806040838503121561028e575f80fd5b82359150602083013567ffffffffffffffff808211156102ac575f80fd5b818501915085601f8301126102bf575f80fd5b8135818111156102d1576102d1610250565b604051601f82017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0908116603f0116810190838211818310171561031757610317610250565b8160405282815288602084870101111561032f575f80fd5b826020860160208301375f602084830101528095505050505050925092905056fea2646970667358221220992118230e4c9ffed4926da567e9fee8d8a102c65d41aa5ee3579d36ca97124164736f6c63430008150033'

export const CREATE3_FACTORY_SIGNED_RAW_TX =
  '0xf903f68085174876e800830557308080b903a3608060405234801561000f575f80fd5b506103868061001d5f395ff3fe608060405260043610610028575f3560e01c806350f1c4641461002c578063cdcb760a14610074575b5f80fd5b348015610037575f80fd5b5061004b61004636600461020e565b610087565b60405173ffffffffffffffffffffffffffffffffffffffff909116815260200160405180910390f35b61004b61008236600461027d565b6100ea565b6040517fffffffffffffffffffffffffffffffffffffffff000000000000000000000000606084901b166020820152603481018290525f906054016040516020818303038152906040528051906020012091506100e382610147565b9392505050565b6040517fffffffffffffffffffffffffffffffffffffffff0000000000000000000000003360601b166020820152603481018390525f906054016040516020818303038152906040528051906020012092506100e383833461019c565b5f604051305f5260ff600b53826020527f21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f6040526055600b20601452806040525061d6945f52600160345350506017601e2090565b5f6f67363d3d37363d34f03d5260086018f35f52836010805ff5806101c85763301164255f526004601cfd5b8060145261d6945f5260016034536017601e2091505f8085516020870186855af16101fa576319b991a85f526004601cfd5b50803b6100e3576319b991a85f526004601cfd5b5f806040838503121561021f575f80fd5b823573ffffffffffffffffffffffffffffffffffffffff81168114610242575f80fd5b946020939093013593505050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b5f806040838503121561028e575f80fd5b82359150602083013567ffffffffffffffff808211156102ac575f80fd5b818501915085601f8301126102bf575f80fd5b8135818111156102d1576102d1610250565b604051601f82017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0908116603f0116810190838211818310171561031757610317610250565b8160405282815288602084870101111561032f575f80fd5b826020860160208301375f602084830101528095505050505050925092905056fea2646970667358221220992118230e4c9ffed4926da567e9fee8d8a102c65d41aa5ee3579d36ca97124164736f6c634300081500331ba03333333333333333333333333333333333333333333333333333333333333333a03333333333333333333333333333333333333333333333333333333333333333'

export const CREATE3_FACTORY_DEPLOYED_ADDRESS = '0x24fCFA23F3b22c15070480766E3fE2fad3E813EA'

export const CREATE3_FACTORY_DEPLOYER_ADDRESS = '0xc7c0A9dc9c997438eE834bb155dF2AF7fDAe6073'

export const CREATE3_FACTORY_GAS_LIMIT = 360000n; // See https://github.com/SKYBITDev3/SKYBIT-Keyless-Deployment
export const CREATE3_FACTORY_GAS_PRICE = 100000000000n; // 100 gwei

export const CREATE3_FACTORY_ABI = [
  {
    inputs: [
      {
        internalType: 'bytes32',
        name: 'salt',
        type: 'bytes32',
      },
      {
        internalType: 'bytes',
        name: 'creationCode',
        type: 'bytes',
      },
    ],
    name: 'deploy',
    outputs: [
      {
        internalType: 'address',
        name: 'deployed',
        type: 'address',
      },
    ],
    stateMutability: 'payable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'address',
        name: 'deployer',
        type: 'address',
      },
      {
        internalType: 'bytes32',
        name: 'salt',
        type: 'bytes32',
      },
    ],
    name: 'getDeployed',
    outputs: [
      {
        internalType: 'address',
        name: 'deployed',
        type: 'address',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
] as const

const log = (msg: string) => console.log(`  [create3] ${msg}`)

const throwError = (msg: string) => {
  throw new Error(`[create3] ${msg}`)
}

const waitForTx = async (publicClient: any, tx: `0x${string}`, message: string = 'Waiting for transaction to complete') => {
  log(`Waiting for tx to complete: ${tx}`)
  const receipt = await publicClient.waitForTransactionReceipt({ hash: tx })
  if (receipt.status !== 'success') throwError('Transaction failed')
  return receipt
}

export const deployCreate3Factory = async (publicClient: PublicClient, walletClient: WalletClient) => {
  const code = await publicClient.getCode({ address: CREATE3_FACTORY_DEPLOYED_ADDRESS })
  if (!code) {
    // Check deployer has enough balance
    const balance = await publicClient.getBalance({ address: CREATE3_FACTORY_DEPLOYER_ADDRESS })
    const requiredBalance = CREATE3_FACTORY_GAS_LIMIT * CREATE3_FACTORY_GAS_PRICE

    if (balance < requiredBalance) {
      log(`Sending ${requiredBalance} wei (${formatEther(requiredBalance)} ETH) to ${CREATE3_FACTORY_DEPLOYER_ADDRESS} to deploy CREATE3 factory`)

      // Send enough ETH to cover deployment
      await walletClient.sendTransaction({
        chain: walletClient.chain,
        to: CREATE3_FACTORY_DEPLOYER_ADDRESS,
        value: requiredBalance - balance,
        account: walletClient.account!,
      })
    }

    // Deploy factory using pre-signed transaction
    log(`Deploying CREATE3 factory using pre-signed transaction to ${CREATE3_FACTORY_DEPLOYED_ADDRESS}`)
    const tx = await publicClient.sendRawTransaction({
      serializedTransaction: CREATE3_FACTORY_SIGNED_RAW_TX,
    })

    await waitForTx(publicClient, tx)
  } else {
    log('CREATE3 factory already deployed')
  }

  // Return the deployed factory as a contract with ABI
  log(`Getting CREATE3 factory deployed at ${CREATE3_FACTORY_DEPLOYED_ADDRESS}`)
  return getContract({
    address: CREATE3_FACTORY_DEPLOYED_ADDRESS,
    abi: CREATE3_FACTORY_ABI,
    client: { public: publicClient, wallet: walletClient },
  })
}

export const deployUsingCreate3Factory = async ({ publicClient, walletClient, salt, creationCode, gasLimit, abi }: { publicClient: PublicClient, walletClient: WalletClient, salt: `0x${string}`, creationCode: `0x${string}`, gasLimit: bigint, abi: any }) => {
  log('Deploying using CREATE3 factory')
  const create3Factory = await deployCreate3Factory(publicClient, walletClient)
  const address = await create3Factory.read.getDeployed([walletClient.account!.address, salt])

  if (await publicClient.getCode({ address })) {
    log(`Contract already deployed at ${address}`)
  } else {
    log(`Deploying contract to ${address}`)
    const tx = await create3Factory.write.deploy([salt, creationCode], { gas: gasLimit, account: walletClient.account!, chain: walletClient.chain })
    await waitForTx(publicClient, tx)
  }

  log(`Getting contract at ${address}`)
  return getContract({
    address: address,
    abi: abi,
    client: { public: publicClient, wallet: walletClient },
  })
}
