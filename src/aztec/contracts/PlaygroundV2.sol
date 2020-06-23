pragma solidity >= 0.5.0 <0.7.0;

import './Internal.sol';

contract PlaygroundV2 is Internal {
  constructor () public Internal() {
  }

  function confidentialMint (bytes memory _mintProof, address receiver) public {
    require(_mintProof.length != 0, 'proof invalid');

    bytes memory _proofOutputs = _validateProof(MINT_PROOF, msg.sender, _mintProof);
    require(_proofOutputs.getLength() > 0, 'call to validateProof failed');

    // TODO verify mints
    /*
    (bytes memory oldTotal, // input notes
      bytes memory newTotal, // output notes
      ,
    ) = _proofOutputs.get(0).extractProofOutput();
    (, bytes32 oldTotalNoteHash, ) = oldTotal.get(0).extractNote();
    require(oldTotalNoteHash == totalMinted, 'provided total minted note does not match');
    (, bytes32 newTotalNoteHash, ) = newTotal.get(0).extractNote();
    setTotalMinted(newTotalNoteHash);
    */

    (, bytes memory mintedNotes, ,) = _proofOutputs.get(1).extractProofOutput();

    for (uint i = 0; i < mintedNotes.getLength(); i += 1) {
      (address noteOwner, bytes32 noteHash) = mintedNotes.get(i).extractNote();
      _createNote(noteHash, receiver);
    }
  }

  /// @dev Foo to the bar
  function foobar (bytes memory _transferProofData, bytes memory _signatures, bytes memory _rangeProofData, address receiver) public {
    bytes memory transferOutputs = _validateProof(JOIN_SPLIT_PROOF, msg.sender, _transferProofData);
    bytes memory rangeOutputs = _validateProof(PRIVATE_RANGE_PROOF, msg.sender, _rangeProofData);

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
    _confidentialTransferInternal(JOIN_SPLIT_PROOF, transferOutputs, _signatures, _transferProofData, receiver);
  }

  /// @dev Fixed joinSplit of 1 input and 2 outputs
  function _confidentialTransferInternal (
    uint24 _proofId,
    bytes memory proofOutputs,
    bytes memory _signatures,
    bytes memory _proofData,
    address receiver
  ) internal {
    bytes32 _challenge;
    assembly {
      _challenge := mload(add(_proofData, 0x40))
    }
    require(proofOutputs.getLength() == 1);

    bytes memory proofOutput = proofOutputs.get(0);
    // TODO
    // is it required to keep track of already used proofs?

    (bytes memory inputNotes,
      bytes memory outputNotes,
      address publicOwner,
      int256 publicValue) = proofOutput.extractProofOutput();

    require(inputNotes.getLength() == 1);
    require(outputNotes.getLength() == 2);

    bytes memory _signature = _extractSignature(_signatures, 0);
    (, bytes32 noteHash) = inputNotes.get(0).extractNote();

    bytes32 hashStruct = keccak256(abi.encode(
      JOIN_SPLIT_SIGNATURE_TYPE_HASH,
      _proofId,
      noteHash,
      _challenge,
      msg.sender
    ));
    address sender = _validateSignature(hashStruct, noteHash, _signature);
    _deleteNote(noteHash);

    _createNote(_getNoteHash(outputNotes.get(0)), receiver);
    _createNote(_getNoteHash(outputNotes.get(1)), sender);
  }
}
