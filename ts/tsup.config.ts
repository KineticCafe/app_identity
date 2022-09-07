import { defineConfig } from 'tsup'

export default defineConfig([
  {
    name: 'library',
    entry: ['src/index.ts'],
    format: ['esm', 'cjs'],
    minify: true,
    dts: { entry: 'src/index.ts', resolve: false },
    sourcemap: false,
    splitting: false,
  },
  {
    name: 'suite-cli',
    entry: ['support/cli.ts'],
    format: ['cjs'],
    minify: true,
    dts: false,
    sourcemap: false,
    splitting: false,
  },
])
