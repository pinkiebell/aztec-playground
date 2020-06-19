pragma solidity >= 0.5.0 <0.7.0;

import '@aztec/protocol/contracts/ERC1724/ZkAssetMintable.sol';
import '@aztec/protocol/contracts/libs/NoteUtils.sol';

contract Playground is ZkAssetMintable {
  using NoteUtils for bytes;

  uint24 constant JOIN_SPLIT_PROOF = 65793;
  uint24 constant MINT_PRO0F = 66049;
  uint24 constant PRIVATE_RANGE_PROOF = 66562;

  constructor (address _aceAddress) public
  ZkAssetMintable(_aceAddress, address(0), 1, 0, new bytes(0))
  {
  }

  function confidentialMint (uint24 _proof, bytes memory _proofData) public {
    require(_proofData.length != 0, 'proof invalid');

    (bytes memory _proofOutputs) = ace.mint(_proof, _proofData, msg.sender);
    (, bytes memory newTotal, ,) = _proofOutputs.get(0).extractProofOutput();
    (, bytes memory mintedNotes, ,) = _proofOutputs.get(1).extractProofOutput();
    (, bytes32 noteHash, bytes memory metadata) = newTotal.get(0).extractNote();

    logOutputNotes(mintedNotes);
    emit UpdateTotalMinted(noteHash, metadata);
  }

  function foobar (bytes memory _transferProofData, bytes memory _signatures, bytes memory _rangeProofData) public {
    bytes memory transferOutputs = ace.validateProof(JOIN_SPLIT_PROOF, msg.sender, _transferProofData);
    bytes memory rangeOutputs = ace.validateProof(PRIVATE_RANGE_PROOF, msg.sender, _rangeProofData);

    (, bytes memory transferOutputNotes, ,) = transferOutputs.get(0).extractProofOutput();
    (bytes memory rangeInputNotes, , ,) = rangeOutputs.get(0).extractProofOutput();

    // the transaction limit
    require(
      _getNoteHash(rangeInputNotes.get(0)) == 0x78faf9e05cc78a378d0848d37851cecb621501b605ac5e9f6940460d852baabc
    );
    // the merchants payment
    require(
      _getNoteHash(rangeInputNotes.get(1)) == _getNoteHash(transferOutputNotes.get(0))
    );

    // transfer
    confidentialTransferInternal(JOIN_SPLIT_PROOF, transferOutputs, _signatures, _transferProofData);
  }

  function _getNoteHash (bytes memory note) internal pure returns (bytes32) {
    (, bytes32 noteHash,) = note.extractNote();

    return noteHash;
  }
}
