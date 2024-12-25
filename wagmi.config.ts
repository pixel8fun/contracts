import path from 'node:path'
import { defineConfig } from '@wagmi/cli';
import { foundry } from '@wagmi/cli/plugins';

export default defineConfig({
  out: 'scripts/generated.ts', // Output file for generated bindings
  plugins: [
    foundry({
      project: '.',
      include: [
        '**/Pixel8.sol/**/*.json',
        '**/MintSwapPool.sol/**/*.json'
      ],
    }),
  ],
});