import { BigVal } from 'bigval'
import { $ } from 'execa'
import { http, createPublicClient, createWalletClient, encodeAbiParameters, encodeDeployData } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { type Chain, arbitrumSepolia, localhost } from 'viem/chains';
import yargs from 'yargs';

const Pixel8Artifact = require('../out/Pixel8.sol/Pixel8.json')
const MultiSwapPoolArtifact = require('../out/MintSwapPool.sol/MintSwapPool.json')
const GameStatsArtifact = require('../out/GameStats.sol/GameStats.json')
const FactoryArtifact = require('../out/Factory.sol/Factory.json')
import { factoryAbi, gameStatsAbi, mintSwapPoolAbi, pixel8Abi } from '../dist/esm/abi';
import { deployUsingCreate3Factory } from './create3';

const ANVIL_ACCOUNT_1_PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'
const DEFAULT_PIXEL8_IMG = 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGZpbGw9Im5vbmUiIHZpZXdCb3g9IjAgMCA1MTIgNTEyIj48cGF0aCBmaWxsPSIjRDhEOEQ4IiBmaWxsLW9wYWNpdHk9Ii41IiBkPSJNMCAwaDUxMnY1MTJIMHoiLz48ZyBjbGlwLXBhdGg9InVybCgjYSkiPjxwYXRoIGZpbGw9IiMzMTMwMzAiIGQ9Ik0xOTcuNiAzNTJoMTE1LjhjNC44IDAgOC43LTMuOSA4LjctOC43VjI0NWMwLTQuOC00LTguNy04LjctOC43aC04Ljd2LTI2YTQ5LjMgNDkuMyAwIDAgMC05OC40IDB2MjZoLTguN2E4LjcgOC43IDAgMCAwLTguNyA4Ljd2OTguNGMwIDQuOCA0IDguNyA4LjcgOC43Wm02Ni42LTU1djExLjZhOC43IDguNyAwIDEgMS0xNy40IDBWMjk3YTE0LjUgMTQuNSAwIDEgMSAxNy40IDBabS00MC41LTg2LjhhMzEuOSAzMS45IDAgMCAxIDYzLjYgMHYyNmgtNjMuNnYtMjZaIi8+PC9nPjxkZWZzPjxjbGlwUGF0aCBpZD0iYSI+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTE2MCAxNjFoMTkxdjE5MUgxNjB6Ii8+PC9jbGlwUGF0aD48L2RlZnM+PC9zdmc+'
const CREATE3_SALT_PREFIX = '0xd3adbeefdeadbeefdeadbeefdeadbeefde9dbeefdeadbeefdeadbeefdeadb22' // DO NOT CHANGE THIS VALUE!

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

const toEtherBigInt = (value: number) => BigInt(new BigVal(value, 'coins').toMinScale().toString())

const getPixel8ConstructorArgs = (chainInfo: typeof chains[keyof typeof chains]) => ({
  name: "Pixel8",
  symbol: "P8",
  owner: chainInfo.owner,
  authoriser: chainInfo.authoriser,
  devRoyalty: {
    receiver: chainInfo.devRoyaltyReceiver,
    feeBips: 100n, // 1%
    amount: 0n
  },
  creatorRoyalty: {
    receiver: chainInfo.devRoyaltyReceiver,
    feeBips: 100n, // 1%
    amount: 0n
  },
  defaultImage: DEFAULT_PIXEL8_IMG,
  prizePoolFeeBips: 500n, // 5% 
  gameOverRevealThreshold: 1764n, // all tiles revealed
  forceSwapConfig: {
    cost: toEtherBigInt(0.1),
    cooldownPeriod: 1n * 60n * 60n * 1000n, // 1 hour
  },
  externalTradeThreshold: 1234n, // 70% of 1764 = 1234
})

const encodeConstructorArgs = (abi: any, args: any) => {
  return encodeAbiParameters(
    abi.find(x => x.type === 'constructor').inputs,
    args
  ).slice(2) // remove 0x prefix
}

const verifySourceCode = async (opts: {chainInfo: typeof chains[keyof typeof chains], verifierApiKey: string, name: string, address: string, abi: any, constructorArgs: any[], srcPath: string}) => {
  const { chainInfo, verifierApiKey, name, address, abi, constructorArgs, srcPath } = opts
  log(`Verifying ${name} at ${address}...`)
  const argsEncoded = encodeConstructorArgs(abi, constructorArgs)
  await $`forge verify-contract --chain-id ${chainInfo.chainId} --etherscan-api-key ${verifierApiKey} --verifier-url ${chainInfo.verifierApiUrl!} --num-of-optimizations 200 --watch --constructor-args "${argsEncoded}" ${address} ${srcPath}`
  log(`...verified ${name}`)
}

const main = async () => {
  const { argv } = yargs(process.argv.slice(2))
  const { chain: chainId } = argv as unknown as{ chain: string }
  
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

  // deploy factory
  log("Deploying Pixel8 Factory ...")
  const factoryConstructorArgs = [chainInfo.authoriser]
  const factoryCreationCode = encodeDeployData({
    abi: factoryAbi,
    bytecode: FactoryArtifact.bytecode.object,
    args: factoryConstructorArgs as any
  })
  const factory = await deployUsingCreate3Factory({ publicClient, walletClient, salt: `${CREATE3_SALT_PREFIX}a`, creationCode: factoryCreationCode, gasLimit: 6000000n, abi: factoryAbi })
  log(`...done - deployed to ${factory.address}`)

  // deploy pool
  log("Deploying MintSwapPool ...")
  const poolConstructorArgs = [chainInfo.owner, factory.address]
  const poolCreationCode = encodeDeployData({
    abi: mintSwapPoolAbi,
    bytecode: MultiSwapPoolArtifact.bytecode.object,
    args: poolConstructorArgs as any
  })
  const pool = await deployUsingCreate3Factory({ publicClient, walletClient, salt: `${CREATE3_SALT_PREFIX}b`, creationCode: poolCreationCode, gasLimit: 2000000n, abi: mintSwapPoolAbi })
  log(`...done - deployed to ${pool.address}`)

  // deploy game stats
  log("Deploying GameStats instance ...")
  const gameStatsConstructorArgs = [pool.address]
  const gameStatsCreationCode = encodeDeployData({
    abi: gameStatsAbi,
    bytecode: GameStatsArtifact.bytecode.object,
    args: gameStatsConstructorArgs as any
  })
  const gameStats = await deployUsingCreate3Factory({ publicClient, walletClient, salt: `${CREATE3_SALT_PREFIX}c`, creationCode: gameStatsCreationCode, gasLimit: 1000000n, abi: gameStatsAbi })
  log(`...done - deployed to ${gameStats.address}`)

  // deploy pixel8
  log("Deploying Pixel8 instance ...")
  const pixel8ConstructorArgs = [getPixel8ConstructorArgs(chainInfo)]
  const pixel8CreationCode = encodeDeployData({
    abi: pixel8Abi,
    bytecode: Pixel8Artifact.bytecode.object,
    args: pixel8ConstructorArgs as any
  })
  const pixel8 = await deployUsingCreate3Factory({ publicClient, walletClient, salt: `${CREATE3_SALT_PREFIX}d`, creationCode: pixel8CreationCode, gasLimit: 5000000n, abi: pixel8Abi })
  log(`...done - deployed to ${pixel8.address}`)

  // verify
  if (chainInfo.verifierApiUrl && verifierApiKey) {
    log("Verifying contracts ...")

    await verifySourceCode({ chainInfo, verifierApiKey, name: "Factory", address: factory.address, abi: factoryAbi, constructorArgs: factoryConstructorArgs, srcPath: "src/Factory.sol:Factory" })
    await verifySourceCode({ chainInfo, verifierApiKey, name: "MintSwapPool", address: pool.address, abi: mintSwapPoolAbi, constructorArgs: poolConstructorArgs, srcPath: "src/MintSwapPool.sol:MintSwapPool" })
    await verifySourceCode({ chainInfo, verifierApiKey, name: "GameStats", address: gameStats.address, abi: gameStatsAbi, constructorArgs: gameStatsConstructorArgs, srcPath: "src/GameStats.sol:GameStats" })
    await verifySourceCode({ chainInfo, verifierApiKey, name: "Pixel8", address: pixel8.address, abi: pixel8Abi, constructorArgs: pixel8ConstructorArgs, srcPath: "src/Pixel8.sol:Pixel8" })

    log("...done")
  }
}

main()


