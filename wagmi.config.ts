import { defineConfig } from '@wagmi/cli';
import { foundry } from '@wagmi/cli/plugins';

export default defineConfig({
  out: 'src-ts/abi.ts',
  plugins: [
    foundry({
      project: '.',
      include: [
        '**/Pixel8.sol/**/*.json',
        '**/MintSwapPool.sol/**/*.json',
        '**/Factory.sol/**/*.json'
      ],
    }),
  ],
});