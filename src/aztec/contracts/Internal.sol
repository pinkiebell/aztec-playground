pragma solidity >= 0.5.0 <0.7.0;

library NoteUtils {
  /**
   * @dev Get the number of entries in an AZTEC-ABI array (bytes proofOutputs, bytes inputNotes, bytes outputNotes)
   *      All 3 are rolled into a single function to eliminate 'wet' code - the implementations are identical
   * @param _proofOutputsOrNotes `proofOutputs`, `inputNotes` or `outputNotes`
   * @return number of entries in the pseudo dynamic array
   */
  function getLength(bytes memory _proofOutputsOrNotes) internal pure returns (
    uint len
  ) {
    assembly {
      // first word = the raw byte length
      // second word = the actual number of entries (hence the 0x20 offset)
      len := mload(add(_proofOutputsOrNotes, 0x20))
    }
  }

  /**
   * @dev Get a bytes object out of a dynamic AZTEC-ABI array
   * @param _proofOutputsOrNotes `proofOutputs`, `inputNotes` or `outputNotes`
   * @param _i the desired entry
   * @return number of entries in the pseudo dynamic array
   */
  function get(bytes memory _proofOutputsOrNotes, uint _i) internal pure returns (
    bytes memory out
  ) {
    bool valid;
    assembly {
      // check that i < the number of entries
      valid := lt(
        _i,
        mload(add(_proofOutputsOrNotes, 0x20))
      )
      // memory map of the array is as follows:
      // 0x00 - 0x20 : byte length of array
      // 0x20 - 0x40 : n, the number of entries
      // 0x40 - 0x40 + (0x20 * i) : relative memory offset to start of i'th entry (i <= n)

      // Step 1: compute location of relative memory offset: _proofOutputsOrNotes + 0x40 + (0x20 * i)
      // Step 2: loaded relative offset and add to _proofOutputsOrNotes to get absolute memory location
      out := add(
        mload(
          add(
            add(_proofOutputsOrNotes, 0x40),
            mul(_i, 0x20)
          )
        ),
        _proofOutputsOrNotes
      )
    }
    require(valid, "AZTEC array index is out of bounds");
  }

  /**
   * @dev Extract constituent elements of a `bytes _proofOutput` object
   * @param _proofOutput an AZTEC proof output
   * @return inputNotes, AZTEC-ABI dynamic array of input AZTEC notes
   * @return outputNotes, AZTEC-ABI dynamic array of output AZTEC notes
   * @return publicOwner, the Ethereum address of the owner of any public tokens involved in the proof
   * @return publicValue, the amount of public tokens involved in the proof
   *         if (publicValue > 0), this represents a transfer of tokens from ACE to publicOwner
   *         if (publicValue < 0), this represents a transfer of tokens from publicOwner to ACE
   */
  function extractProofOutput(bytes memory _proofOutput) internal pure returns (
    bytes memory inputNotes,
    bytes memory outputNotes,
    address publicOwner,
    int256 publicValue
  ) {
    assembly {
      // memory map of a proofOutput:
      // 0x00 - 0x20 : byte length of proofOutput
      // 0x20 - 0x40 : relative offset to inputNotes
      // 0x40 - 0x60 : relative offset to outputNotes
      // 0x60 - 0x80 : publicOwner
      // 0x80 - 0xa0 : publicValue
      // 0xa0 - 0xc0 : challenge
      inputNotes := add(_proofOutput, mload(add(_proofOutput, 0x20)))
      outputNotes := add(_proofOutput, mload(add(_proofOutput, 0x40)))
      publicOwner := and(
        mload(add(_proofOutput, 0x60)),
        0xffffffffffffffffffffffffffffffffffffffff
      )
      publicValue := mload(add(_proofOutput, 0x80))
    }
  }

  /**
   * @dev Extract the challenge from a bytes proofOutput variable
   * @param _proofOutput bytes proofOutput, outputted from a proof validation smart contract
   * @return bytes32 challenge - cryptographic variable that is part of the sigma protocol
   */
  function extractChallenge(bytes memory _proofOutput) internal pure returns (
    bytes32 challenge
  ) {
    assembly {
      challenge := mload(add(_proofOutput, 0xa0))
    }
  }

  /**
   * @dev Extract constituent elements of an AZTEC note
   * @param _note an AZTEC note
   * @return owner, Ethereum address of note owner
   * @return noteHash, the hash of the note's public key
   * @return metadata, note-specific metadata (contains public key and any extra data needed by note owner)
   */
  function extractNote (bytes memory _note) internal pure returns (
    address owner,
    bytes32 noteHash
    //bytes memory metadata
  ) {
    assembly {
      // memory map of a note:
      // 0x00 - 0x20 : byte length of note
      // 0x20 - 0x40 : note type
      // 0x40 - 0x60 : owner
      // 0x60 - 0x80 : noteHash
      // 0x80 - 0xa0 : start of metadata byte array
      owner := and(
        mload(add(_note, 0x40)),
        0xffffffffffffffffffffffffffffffffffffffff
      )
      noteHash := mload(add(_note, 0x60))
      //metadata := add(_note, 0x80)
    }
  }

  /**
   * @dev Get the note type
   * @param _note an AZTEC note
   * @return noteType
   */
  function getNoteType(bytes memory _note) internal pure returns (
    uint256 noteType
  ) {
    assembly {
      noteType := mload(add(_note, 0x20))
    }
  }
}

interface CallWrapper {
  function __validateProof(uint24 _proof, address _sender, bytes calldata) external returns (bytes memory);
}

contract Internal {
  // proofEpoch = 1 | proofCategory = 1 | proofId = 1
  // 1 * 256**(2) + 1 * 256**(1) ++ 1 * 256**(0)
  uint24 public constant JOIN_SPLIT_PROOF = 65793;

  // proofEpoch = 1 | proofCategory = 2 | proofId = 1
  // (1 * 256**(2)) + (2 * 256**(1)) + (1 * 256**(0))
  uint24 public constant MINT_PROOF = 66049;

  // proofEpoch = 1 | proofCategory = 3 | proofId = 1
  // (1 * 256**(2)) + (3 * 256**(1)) + (1 * 256**(0))
  uint24 public constant BURN_PROOF = 66305;

  // proofEpoch = 1 | proofCategory = 4 | proofId = 2
  // (1 * 256**(2)) + (4 * 256**(1)) + (2 * 256**(0))
  uint24 public constant PRIVATE_RANGE_PROOF = 66562;

  // proofEpoch = 1 | proofCategory = 4 | proofId = 3
  // (1 * 256**(2)) + (4 * 256**(1)) + (2 * 256**(0))
  uint24 public constant PUBLIC_RANGE_PROOF = 66563;

  // proofEpoch = 1 | proofCategory = 4 | proofId = 1
  // (1 * 256**(2)) + (4 * 256**(1)) + (2 * 256**(0))
  uint24 public constant DIVIDEND_PROOF = 66561;

  using NoteUtils for bytes;

  event CreateNote(address indexed owner, bytes32 indexed noteHash);
  event DestroyNote(address indexed owner, bytes32 indexed noteHash);

  string constant internal EIP712_DOMAIN_VERSION = "1";
  string constant internal EIP712_DOMAIN_NAME = 'ZK_ASSET';
  // Hash of the EIP712 Domain Separator Schema
  bytes32 constant internal EIP712_DOMAIN_SEPARATOR_SCHEMA_HASH = keccak256(abi.encodePacked(
    "EIP712Domain(",
    "string name,",
    "string version,",
    "address verifyingContract",
    ")"
  ));
  bytes32 constant internal JOIN_SPLIT_SIGNATURE_TYPE_HASH = keccak256(abi.encodePacked(
    'JoinSplitSignature(',
    'uint24 proof,',
    'bytes32 noteHash,',
    'uint256 challenge,',
    'address sender',
    ')'
  ));

  bytes32 public EIP712_DOMAIN_HASH;
  mapping (bytes32 => address) _notes;

  constructor () public {
    EIP712_DOMAIN_HASH = keccak256(abi.encodePacked(
      EIP712_DOMAIN_SEPARATOR_SCHEMA_HASH,
      keccak256(bytes(EIP712_DOMAIN_NAME)),
      keccak256(bytes(EIP712_DOMAIN_VERSION)),
      bytes32(uint256(address(this)))
    ));
  }

  /**
   * @dev Perform ECDSA signature validation for a signature over an input note
   *
   * @param _hashStruct - the data to sign in an EIP712 signature
   * @param _noteHash - keccak256 hash of the note coordinates (gamma and sigma)
   * @param _signature - ECDSA signature for a particular input note
   */
  function _validateSignature (bytes32 _hashStruct, bytes32 _noteHash, bytes memory _signature) internal view returns (address) {
    address signer;
    if (_signature.length != 0) {
      // validate EIP712 signature
      bytes32 msgHash = _hashEIP712Message(_hashStruct);
      signer = _recoverSignature(
        msgHash,
        _signature
      );
    } else {
      signer = msg.sender;
    }

    address noteOwner = _getNoteOwner(_noteHash);
    require(signer == noteOwner, 'the note owner did not sign this message');

    return noteOwner;
  }

  /// @dev Extract the appropriate ECDSA signature from an array of signatures,
  /// @param _signatures - array of ECDSA signatures over all inputNotes
  /// @param _i - index used to determine which signature element is desired
  function _extractSignature (bytes memory _signatures, uint _i) internal pure returns (bytes memory _signature) {
    bytes32 r;
    bytes32 s;
    uint8 v;

    assembly {
      // memory map of signatures
      // 0x00 - 0x20 : length of signature array
      // 0x20 - 0x40 : first sig, r
      // 0x40 - 0x60 : first sig, s
      // 0x61 - 0x62 : first sig, v
      // 0x62 - 0x82 : second sig, r
      // and so on...
      // Length of a signature = 0x41

      let sigLength := 0x41

      r := mload(add(add(_signatures, 0x20), mul(_i, sigLength)))
      s := mload(add(add(_signatures, 0x40), mul(_i, sigLength)))
      v := mload(add(add(_signatures, 0x41), mul(_i, sigLength)))
    }

    _signature = abi.encodePacked(r, s, v);
  }

  function _getNoteHash (bytes memory note) internal pure returns (bytes32) {
    (, bytes32 noteHash) = note.extractNote();

    return noteHash;
  }

  function _getNoteOwner (bytes32 _noteHash) internal view returns (address) {
    address owner = _notes[_noteHash];
    require(owner != address(0));

    return owner;
  }

  function _deleteNote (bytes32 _noteHash) internal {
    emit DestroyNote(_notes[_noteHash], _noteHash);
    _notes[_noteHash] = address(0);
  }

  function _createNote (bytes32 _noteHash, address _noteOwner) internal {
    require(_noteOwner != address(0x0), 'output note owner cannot be address(0x0)');
    _notes[_noteHash] = _noteOwner;
    emit CreateNote(_noteOwner, _noteHash);
  }

  function _validateProof (uint24 _proof, address _sender, bytes memory proofData) internal returns (bytes memory ret) {
    return CallWrapper(address(this)).__validateProof(_proof, _sender, proofData);
  }

  /**
   * @dev Validate an AZTEC zero-knowledge proof. ACE will issue a validation transaction to the smart contract
   *      linked to `_proof`. The validator smart contract will have the following interface:
   *
   *      function validate(
   *          bytes _proofData,
   *          address _sender,
   *          bytes32[6] _commonReferenceString
   *      ) public returns (bytes)
   *
   * @param _proof the AZTEC proof object
   * @param _sender the Ethereum address of the original transaction sender. It is explicitly assumed that
   *        an asset using ACE supplies this field correctly - if they don't their asset is vulnerable to front-running
   * Unnamed param is the AZTEC zero-knowledge proof data
   * @return a `bytes proofOutputs` variable formatted according to the Cryptography Engine standard
   */
  function __validateProof (uint24 _proof, address _sender, bytes calldata) external returns (bytes memory) {
    require(_proof != 0, "expected the proof to be valid");
    address validatorAddress;

    if (_proof == MINT_PROOF) {
      validatorAddress = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    } else if (_proof == JOIN_SPLIT_PROOF) {
      validatorAddress = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;
    } else if (_proof == PRIVATE_RANGE_PROOF) {
      validatorAddress = 0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa;
    } else {
      revert();
    }

    bytes memory proofOutputs;
    assembly {
      // the first evm word of the 3rd function param is the abi encoded location of proof data
      let proofDataLocation := add(0x04, calldataload(68))

      // manually construct validator calldata map
      let memPtr := mload(0x40)
      mstore(add(memPtr, 0x04), 0x100) // location in calldata of the start of `bytes _proofData` (0x100)
      mstore(add(memPtr, 0x24), _sender)
      // The commonReferenceString contains one G1 group element and one G2 group element,
      // that are created via the AZTEC protocol's trusted setup. All zero-knowledge proofs supported
      // by ACE use the same common reference string.
      mstore(add(memPtr, 0x44), 0x00164b60d0fa1eab5d56d9653aed9dc7f7473acbe61df67134c705638441c4b9)
      mstore(add(memPtr, 0x64), 0x2bb1b9b55ffdcf2d7254dfb9be2cb4e908611b4adeb4b838f0442fce79416cf0)
      mstore(add(memPtr, 0x84), 0x0118c4d5b837bcc2bc89b5b398b5974e9f5944073b32078b7e231fec938883b0)
      mstore(add(memPtr, 0xa4), 0x260e01b251f6f1c7e7ff4e580791dee8ea51d87a358e038b4efe30fac09383c1)
      mstore(add(memPtr, 0xc4), 0x22febda3c0c0632a56475b4214e5615e11e6dd3f96e6cea2854a87d4dacc5e55)
      mstore(add(memPtr, 0xe4), 0x04fc6369f7110fe3d25156c1bb9a72859cf2a04641f99ba4ee413c80da6a5fe4)

      // 0x104 because there's an address, the length 6 and the static array items
      let destination := add(memPtr, 0x104)
      // note that we offset by 0x20 because the first word is the length of the dynamic bytes array
      let proofDataSize := add(calldataload(proofDataLocation), 0x20)
      // copy the calldata into memory so we can call the validator contract
      calldatacopy(destination, proofDataLocation, proofDataSize)
      // call our validator smart contract, and validate the call succeeded
      let callSize := add(proofDataSize, 0x104)
      switch staticcall(gas, validatorAddress, memPtr, callSize, 0x00, 0x00)
      case 0 {
        mstore(0x00, 400) revert(0x00, 0x20) // call failed because proof is invalid
      }

      // copy returndata to memory
      returndatacopy(memPtr, 0x00, returndatasize)
      // store the proof outputs in memory
      mstore(0x40, add(memPtr, returndatasize))
      // the first evm word in the memory pointer is the abi encoded location of the actual returned data
      proofOutputs := add(memPtr, mload(memPtr))
    }

    return proofOutputs;
  }

  /// @dev Extracts the address of the signer with ECDSA.
  /// @param _message The EIP712 message.
  /// @param _signature The ECDSA values, v, r and s.
  /// @return The address of the message signer.
  function _recoverSignature (
    bytes32 _message,
    bytes memory _signature
  ) internal view returns (address _signer) {
    bool result;
    assembly {
      // Here's a little trick we can pull. We expect `_signature` to be a byte array, of length 0x60, with
      // 'v', 'r' and 's' located linearly in memory. Preceeding this is the length parameter of `_signature`.
      // We *replace* the length param with the signature msg to get a memory block formatted for the precompile
      // load length as a temporary variable

      let byteLength := mload(_signature)

      // store the signature message
      mstore(_signature, _message)

      // load 'v' - we need it for a condition check
      // add 0x60 to jump over 3 words - length of bytes array, r and s
      let v := mload(add(_signature, 0x60))
      let s := mload(add(_signature, 0x40))
      v := shr(248, v) // bitshifting, to resemble padLeft

      /**
       * Original memory map for input to precompile
       *
       * _signature : _signature + 0x20            message
       * _signature + 0x20 : _signature + 0x40     r
       * _signature + 0x40 : _signature + 0x60     s
       * _signature + 0x60 : _signature + 0x80     v

       * Desired memory map for input to precompile
       *
       * _signature : _signature + 0x20            message
       * _signature + 0x20 : _signature + 0x40     v
       * _signature + 0x40 : _signature + 0x60     r
       * _signature + 0x60 : _signature + 0x80     s
       */

      // move s to v position
      mstore(add(_signature, 0x60), mload(add(_signature, 0x40)))
      // move r to s position
      mstore(add(_signature, 0x40), mload(add(_signature, 0x20)))
      // move v to r position
      mstore(add(_signature, 0x20), v)
      result := and(
        and(
          // validate s is in lower half order
          lt(s, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0),
          and(
            // validate signature length == 0x41
            eq(byteLength, 0x41),
            // validate v == 27 or v == 28
            or(eq(v, 27), eq(v, 28))
          )
        ),
        // validate call to precompile succeeds
        staticcall(gas, 0x01, _signature, 0x80, _signature, 0x20)
      )
      // save the _signer only if the first word in _signature is not `_message` anymore
      switch eq(_message, mload(_signature))
      case 0 {
        _signer := mload(_signature)
      }
      mstore(_signature, byteLength) // and put the byte length back where it belongs
    }
    // wrap Failure States in a single if test, so that happy path only has 1 conditional jump
    if (!(result && (_signer != address(0x0)))) {
      require(_signer != address(0x0), "signer address cannot be 0");
      require(result, "signature recovery failed");
    }
  }

  /// @dev Calculates EIP712 encoding for a hash struct in this EIP712 Domain.
  /// @param _hashStruct The EIP712 hash struct.
  /// @return EIP712 hash applied to this EIP712 Domain.
  function _hashEIP712Message (bytes32 _hashStruct) internal view returns (bytes32 _result) {
    bytes32 eip712DomainHash = EIP712_DOMAIN_HASH;

    // Assembly for more efficient computing:
    // keccak256(abi.encodePacked(
    //     EIP191_HEADER,
    //     EIP712_DOMAIN_HASH,
    //     hashStruct
    // ));

    assembly {
      // Load free memory pointer. We're not going to use it - we're going to overwrite it!
      // We need 0x60 bytes of memory for this hash,
      // cheaper to overwrite the free memory pointer at 0x40, and then replace it, than allocating free memory
      let memPtr := mload(0x40)
      mstore(0x00, 0x1901)               // EIP191 header
      mstore(0x20, eip712DomainHash)     // EIP712 domain hash
      mstore(0x40, _hashStruct)          // Hash of struct
      _result := keccak256(0x1e, 0x42)   // compute hash
      // replace memory pointer
      mstore(0x40, memPtr)
    }
  }
}
