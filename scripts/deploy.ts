import { BigVal } from 'bigval'
import { http, createPublicClient, createWalletClient, encodeFunctionData, getContract } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { type Chain, arbitrumSepolia, localhost } from 'viem/chains';
import yargs from 'yargs/yargs'
const shell = require('shelljs')

const Pixel8Artifact = require('../out/Pixel8.sol/Pixel8.json')
const MultiSwapPoolArtifact = require('../out/MintSwapPool.sol/MintSwapPool.json')
import { mintSwapPoolAbi, pixel8Abi } from './generated';

const ANVIL_ACCOUNT_1_PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'

const DEFAULT_PIXEL8_IMG = 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGZpbGw9Im5vbmUiIHZpZXdCb3g9IjAgMCA1MTIgNTEyIj48cGF0aCBmaWxsPSIjRDhEOEQ4IiBmaWxsLW9wYWNpdHk9Ii41IiBkPSJNMCAwaDUxMnY1MTJIMHoiLz48ZyBjbGlwLXBhdGg9InVybCgjYSkiPjxwYXRoIGZpbGw9IiMzMTMwMzAiIGQ9Ik0xOTcuNiAzNTJoMTE1LjhjNC44IDAgOC43LTMuOSA4LjctOC43VjI0NWMwLTQuOC00LTguNy04LjctOC43aC04Ljd2LTI2YTQ5LjMgNDkuMyAwIDAgMC05OC40IDB2MjZoLTguN2E4LjcgOC43IDAgMCAwLTguNyA4Ljd2OTguNGMwIDQuOCA0IDguNyA4LjcgOC43Wm02Ni42LTU1djExLjZhOC43IDguNyAwIDEgMS0xNy40IDBWMjk3YTE0LjUgMTQuNSAwIDEgMSAxNy40IDBabS00MC41LTg2LjhhMzEuOSAzMS45IDAgMCAxIDYzLjYgMHYyNmgtNjMuNnYtMjZaIi8+PC9nPjxkZWZzPjxjbGlwUGF0aCBpZD0iYSI+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTE2MCAxNjFoMTkxdjE5MUgxNjB6Ii8+PC9jbGlwUGF0aD48L2RlZnM+PC9zdmc+'
const ADDRESS_ZERO: `0x${string}` = '0x0000000000000000000000000000000000000000'

const toEtherBigInt = (value: number) => BigInt(new BigVal(value, 'coins').toMinScale().toString())

const getPixel8ConstructorArgs = (chainInfo: typeof chains[keyof typeof chains]) => ({
  owner: chainInfo.owner,
  authoriser: chainInfo.authoriser,
  devRoyaltyReceiver: chainInfo.devRoyaltyReceiver,
  devRoyaltyFeeBips: 100n, // 1%
  prizePoolFeeBips: 650n, // 6.5% 
  defaultImage: DEFAULT_PIXEL8_IMG,
  gameOverRevealThreshold: 1764n, // all tiles revealed
  forceSwapCost: toEtherBigInt(0.1),
  forceSwapCooldownPeriod: 1n * 60n * 60n * 1000n, // 1 hour
  externalTradeThreshold: 1234n, // 70% of 1764 = 1234
  pool: ADDRESS_ZERO
})

const encodeConstructorArgs = (abi: any, args: any) => {
  const con = abi.find(x => x.type === 'constructor')
  if (!con) throw new Error('No constructor found in ABI')
  return encodeFunctionData({
    abi: [{ type: 'constructor', inputs: con.inputs }],
    args
  }).slice(2) // remove 0x prefix
}

const chains: Record<string, {
  chain: Chain,
  rcpUrl: string,
  chainId: number,
  owner: `0x${string}`,
  authoriser: `0x${string}`,
  devRoyaltyReceiver: `0x${string}`,
  verifierApiUrl?: string,
}> = {
  local: {
    chain: localhost,
    rcpUrl: 'http://localhost:8545',
    chainId: 1337,
    owner: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', // anvil account 1
    authoriser: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8', // anvil account 2
    devRoyaltyReceiver: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC', // anvil account 3
  },
  arbitrumSepolia: {
    chain: arbitrumSepolia,
    rcpUrl: 'https://api.zan.top/arb-sepolia',
    chainId: 421614,
    owner: '0xd50a0a15f448452710a5ce278d2dc723a368e663', // pixel8 deployment account
    authoriser: '0xd50a0a15f448452710a5ce278d2dc723a368e663', // pixel8 deployment account
    devRoyaltyReceiver: '0xd50a0a15f448452710a5ce278d2dc723a368e663', // pixel8 deployment account
    verifierApiUrl: 'https://sepolia.arbiscan.io/api',
  },
}

const log = console.log.bind(console)

const main = async () => {
  const { argv } = yargs(process.argv.slice(2))
  const { chain: chainId } = argv
  
  if (!chains[chainId]) {
    throw new Error(`Chain not configured: ${chainId}`)
  }

  const chainInfo = chains[chainId]
  log(`Deploying to chain: ${chainId}`)

  let privateKey = ''
  let verifierApiKey = ''
  
  if (chainId === 'local') {
    privateKey = ANVIL_ACCOUNT_1_PRIVATE_KEY
  } else {
    privateKey = process.env.PRIVATE_KEY as string
    if (!privateKey) {
      throw new Error('PRIVATE_KEY env var is required')
    }

    verifierApiKey = process.env.VERIFIER_API_KEY as string
    if (!verifierApiKey) {
      throw new Error('VERIFIER_API_KEY env var is required')
    }
  }

  const account = privateKeyToAccount(privateKey as `0x${string}`) 

  const walletClient = createWalletClient({
    account,
    chain: chainInfo.chain,
    transport: http(chainInfo.rcpUrl),
  })
  const publicClient = createPublicClient({
    chain: chainInfo.chain,
    transport: http(chainInfo.rcpUrl),
  })

  const sender = walletClient.account.address
  log(`Deploying from address: ${sender}`)

  // deploy pixel8
  log("Deploying Pixel8 ...")
  const pixel8ConstructorArgs = getPixel8ConstructorArgs(chainInfo)
  const hash1 = await walletClient.deployContract({   
    abi: pixel8Abi,
    account,
    bytecode: Pixel8Artifact.bytecode.object,
    args: [pixel8ConstructorArgs]
  })  
  const tx = await publicClient.waitForTransactionReceipt({ hash: hash1 })
  const pixel8 = getContract({
    address: tx.contractAddress as `0x${string}`,
    abi: pixel8Abi,
    client: { public: publicClient, wallet: walletClient }
  })  
  log(`...done - deployed to ${pixel8.address}`)

  // deploy pool
  log("Deploying MintSwapPool ...")
  const hash2 = await walletClient.deployContract({   
    abi: mintSwapPoolAbi  ,
    account,
    bytecode: MultiSwapPoolArtifact.bytecode.object,
    args: [chainInfo.owner]
  })  
  const tx2 = await publicClient.waitForTransactionReceipt({ hash: hash2 })
  const pool = getContract({
    address: tx2.contractAddress as `0x${string}`,
    abi: mintSwapPoolAbi,
    client: { public: publicClient, wallet: walletClient }
  })  
  log(`...done - deployed to ${pool.address}`)

  if (chainId === 'local') {
    // attach nft to pool
    log("Attaching NFT contract to pool ...")
    await pool.write.create([{
      nft: pixel8.address,
      curve: {
        mintStartId: 1n,
        mintEndId: 1764n,
        startPriceWei: toEtherBigInt(0.1), // 0.1 ETH
        delta: 1002500000000000000n,  // 0.25%
      }
    }])
    log("...done")

    // set pool as pixel8 minting pool
    log("Setting pool as pixel8 minting pool ...")
    await pixel8.write.setPool([pool.address])
    log("...done")
  }

  // verify
  if (chainInfo.verifierApiUrl && verifierApiKey) {
    log("Verifying contracts ...")
    
    log(`Verifying Pixel8 at ${pixel8.address}...`)
    const pixel8ConstructorArgsEncoded = encodeConstructorArgs(pixel8Abi, [pixel8ConstructorArgs])
    shell.exec(`forge verify-contract --chain-id ${chainInfo.chainId} --etherscan-api-key ${verifierApiKey} --verifier-url ${chainInfo.verifierApiUrl} --num-of-optimizations 200 --watch --constructor-args "${pixel8ConstructorArgsEncoded}" ${pixel8.address} src/Pixel8.sol:Pixel8`)
    
    log(`Verifying MintSwapPool at ${pool.address}...`)
    const poolConstructorArgsEncoded = encodeConstructorArgs(mintSwapPoolAbi, [chainInfo.owner])
    shell.exec(`forge verify-contract --chain-id ${chainInfo.chainId} --etherscan-api-key ${verifierApiKey} --verifier-url ${chainInfo.verifierApiUrl} --num-of-optimizations 200 --watch --constructor-args "${poolConstructorArgsEncoded}" ${pool.address} src/MintSwapPool.sol:MintSwapPool`)
    
    log("...done")
  }
}

main()
