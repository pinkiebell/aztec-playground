import ethers from 'ethers';
import utils from '@aztec/dev-utils';
import secp256k1 from '@aztec/secp256k1';
import bn128 from '@aztec/bn128';
import aztec from 'aztec.js';
import assert from 'assert';

import Artifacts from '../../common/Artifacts.js';

const { Playground } = Artifacts;
const { ACE, JoinSplitFluid, Swap, Dividend, JoinSplit, PrivateRange } = Artifacts;
const { FactoryBase201907, FactoryAdjustable201907 } = Artifacts;

const {
  proofs: {
    JOIN_SPLIT_PROOF,
    MINT_PROOF,
    SWAP_PROOF,
    DIVIDEND_PROOF,
    PRIVATE_RANGE_PROOF,
  },
} = utils;

async function deployArtifact (artifact, wallet, ...deployArgs) {
  const _factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, wallet);
  const contract = await _factory.deploy(...deployArgs);
  const receipt = await contract.deployTransaction.wait();

  const gasUsed = receipt.gasUsed.toLocaleString();
  console.log({ name: artifact.contractName, gasUsed });

  return contract;
}

export async function deploy (wallet) {
  const ace = await deployArtifact(ACE, wallet);
  const joinSplitFluid = await deployArtifact(JoinSplitFluid, wallet);
  const swap = await deployArtifact(Swap, wallet);
  const joinSplit = await deployArtifact(JoinSplit, wallet);
  const dividend = await deployArtifact(Dividend, wallet);
  const privateRange = await deployArtifact(PrivateRange, wallet);

  await (await ace.setCommonReferenceString(bn128.CRS)).wait();
  await (await ace.setProof(MINT_PROOF, joinSplitFluid.address)).wait();
  await (await ace.setProof(SWAP_PROOF, swap.address)).wait();
  await (await ace.setProof(DIVIDEND_PROOF, dividend.address)).wait();
  await (await ace.setProof(JOIN_SPLIT_PROOF, joinSplit.address)).wait();
  await (await ace.setProof(PRIVATE_RANGE_PROOF, privateRange.address)).wait();

  const baseFactory = await deployArtifact(FactoryBase201907, wallet, ace.address);
  await (await ace.setFactory(1 * 256 ** 2 + 1 * 256 ** 1 + 1 * 256 ** 0, baseFactory.address)).wait();

  const adjustableBaseFactory = await deployArtifact(FactoryAdjustable201907, wallet, ace.address);
  await (await ace.setFactory(1 * 256 ** 2 + 1 * 256 ** 1 + 2 * 256 ** 0, adjustableBaseFactory.address)).wait();

  const playground = await deployArtifact(Playground, wallet, ace.address);

  return {
    ace,
    joinSplitFluid,
    swap,
    joinSplit,
    dividend,
    privateRange,
    baseFactory,
    adjustableBaseFactory,
    playground,
  };
}

describe('Playground', async () => {
  let provider;
  let wallet;
  let contracts;
  let bob;
  let sally;

  before(async () => {
    provider = new ethers.providers.JsonRpcProvider(`http://localhost:${process.env.RPC_PORT}`);
    wallet = await provider.getSigner(0);
    contracts = await deploy(wallet);

    const PRIV_KEY_BOB = '0x2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501201';
    const PRIV_KEY_SALLY = '0x2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501202';

    bob = secp256k1.accountFromPrivateKey(PRIV_KEY_BOB);
    sally = secp256k1.accountFromPrivateKey(PRIV_KEY_SALLY);
  });

  it('Bob should be able to deposit 100 then pay sally 25 by splitting notes he owns', async () => {
    console.log('Bob wants to deposit 100');

    const bobMintNote = await aztec.note.create(bob.publicKey, 100);
    const newMintCounterNote = await aztec.note.create(bob.publicKey, 100);
    const zeroMintCounterNote = await aztec.note.createZeroValueNote();
    const proofSender = await wallet.getAddress();

    const mintProof = new aztec.MintProof(
      zeroMintCounterNote,
      newMintCounterNote,
      [bobMintNote],
      proofSender
    );
    const mintData = mintProof.encodeABI();

    let tx = await contracts.playground.confidentialMint(MINT_PROOF, mintData);
    let receipt = await tx.wait();

    console.log({ mintGasUsed: receipt.gasUsed.toLocaleString(), mintProofSize: (mintData.length - 2) / 2 });
    console.log('Bob successfully deposited 100');

    console.log('Bob takes a taxi, Sally is the driver. Sally wants 25');
    const sallyTaxiFee = await aztec.note.create(sally.publicKey, 25);
    // if bob pays with his note worth 100 he requires 75 change
    const bobChangeNote = await aztec.note.create(bob.publicKey, 75);
    const withdrawPublicValue = 0;
    const publicOwner = proofSender;
    const sendProof = new aztec.JoinSplitProof(
      [bobMintNote],
      [sallyTaxiFee, bobChangeNote],
      proofSender,
      withdrawPublicValue,
      publicOwner
    );
    const sendProofData = sendProof.encodeABI(contracts.playground.address);
    const sendProofSignatures = sendProof.constructSignatures(
      contracts.playground.address,
      [bob]
    );

    // that should be the keycard's owner configurable transfer limit
    // const originalNote = await aztec.note.create(bob.publicKey, 30);
    // noteHash: 0x78faf9e05cc78a378d0848d37851cecb621501b605ac5e9f6940460d852baabc
    const originalNote = await aztec.note.fromViewKey(
      '0x2ca862066a0fd9936a5d334a2d0a5a0acf41034606f8a6535e176213f0db592a0000001e02e8a317378b84ef20624f97e4c04503764fe95a3927e2e64b1c78eb51c8236df8'
    );
    const comparisonNote = sallyTaxiFee;
    // transaction limit = 30; -25 sally; = 5
    const utilityNote = await aztec.note.create(bob.publicKey, 5);
    const rangeProof = new aztec.PrivateRangeProof(originalNote, comparisonNote, utilityNote, proofSender);
    const rangeProofData = rangeProof.encodeABI();

    // confidentialTransfer
    tx = await contracts.playground.foobar(sendProofData, sendProofSignatures, rangeProofData);
    receipt = await tx.wait();

    console.log('Bob paid sally 25 for the taxi and gets 75 back');
    console.log(
      {
        transferGasUsed: receipt.gasUsed.toLocaleString(),
        proofSize: (sendProofData.length - 2) / 2,
        sigSize: (sendProofSignatures.length - 2) / 2,
        rangeProofSize: (rangeProofData.length - 2) / 2,
      }
    );
  });
});
