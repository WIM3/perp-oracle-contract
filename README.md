# perp-oracle

[![@perp/perp-oracle-contract on npm](https://img.shields.io/npm/v/@perp/perp-oracle-contract?style=flat-square)](https://www.npmjs.com/package/@perp/perp-oracle-contract)

This repository contains the oracle smart contracts for [Perpetual Protocol Curie (v2)](https://perp.com/). For core contracts, see [perp-curie](https://github.com/perpetual-protocol/perp-curie).

Contract source code is also published as npm package:

- [@perp/perp-oracle-contract](https://www.npmjs.com/package/@perp/perp-oracle-contract) (source code)

## Local Development

You need Node.js 16+ to build. Use [nvm](https://github.com/nvm-sh/nvm) to install it.

Clone this repository, install Node.js dependencies, and build the source code:

```bash
git clone git@github.com:perpetual-protocol/perp-oracle.git
npm i
npm run build
```

Run all the test cases:

```bash
npm run test
```
