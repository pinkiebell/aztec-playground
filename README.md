```
bash-5.0# yarn test
yarn run v1.22.4
warning package.json: No license field
$ yarn _test "src/*/**/*.test.js"
warning package.json: No license field
$ yarn compile && yarn geth && RPC_PORT=$(printenv RPC_PORT || echo -n 8222) mocha --color --bail --exit --timeout=900000 $@ 'src/*/**/*.test.js'
warning package.json: No license field
$ scripts/compile.js src/*/**/*.sol
> Compiling src/aztec/contracts/Playground.sol
> Compiling src/aztec/contracts/imports.sol
No changes. Not compiling
warning package.json: No license field
$ RPC_PORT=8222 ACCOUNTS=1 scripts/geth.js
{
  jsonrpc: '2.0',
  id: 42,
  result: 'Geth/v1.9.9-stable/linux-amd64/go1.13.10'
}
RPC port reachable, doing nothing


  Playground
{ name: 'ACE', gasUsed: '4049369' }
{ name: 'JoinSplitFluid', gasUsed: '518213' }
{ name: 'Swap', gasUsed: '482156' }
{ name: 'JoinSplit', gasUsed: '482744' }
{ name: 'Dividend', gasUsed: '449881' }
{ name: 'PrivateRange', gasUsed: '441235' }
{ name: 'FactoryBase201907', gasUsed: '1446759' }
{ name: 'FactoryAdjustable201907', gasUsed: '1586287' }
{ name: 'Playground', gasUsed: '4840562' }
Bob wants to deposit 100
{ mintGasUsed: '335217', mintProofSize: 1186 }
Bob successfully deposited 100
Bob takes a taxi, Sally is the driver. Sally wants 25
Bob paid sally 25 for the taxi and gets 75 back
{
  transferGasUsed: '639439',
  proofSize: 1250,
  sigSize: 65,
  rangeProofSize: 1089
}
    ✓ Bob should be able to deposit 100 then pay sally 25 by splitting notes he owns (2465ms)


  1 passing (3s)

Done in 6.21s.
```
