pragma solidity ^0.4.18;

import "./InterpreterInterface.sol";
import "../ChannelRegistry.sol";

contract InterpretHTLC is InterpreterInterface {
    // State
    // [0-31] isClose flag
    // [32-63] sequence
    // [64-95] timeout
    // [96-127] sender
    // [128-159] receiver
    // [160-191] bond 
    // [192-223] balance A
    // [224-255] balance B
    // [256-287] lockTXroot
    // [288-319] metachannelAddress

    uint256 totalBond = 0;
    bytes32 public lockroot;
    uint256 public lockedNonce = 0;
    uint256 public sequence = 0;
    uint256 public timeout; // equal to the last timeout of locked txs
    bytes public state;

    bytes32 public CTFMetaAddress;
    ChannelRegistry public registry;

    modifier onlyMeta() {
        require(msg.sender == registry.resolveAddress(CTFMetaAddress));
        _;
    }

    function InterpretHTLC(bytes32 _CTFMetaAddress, address _registry) {
        CTFMetaAddress = _CTFMetaAddress;
        registry = ChannelRegistry(_registry);
    }

    // Lock lockedTx;
    // This always returns true since the receiver should only
    // sign and close the highest balance they have
    function isClose(bytes _data) public returns(bool) {
        uint isClosed;

        assembly {
            isClosed := mload(add(_data, 32))
        }

        require(isClosed == 1);
        return true;
    }

    function isSequenceHigher(bytes _data1, bytes _data2) public pure returns (bool) {
        uint isHigher1;
        uint isHigher2;

        assembly {
            isHigher1 := mload(add(_data1, 64))
            isHigher2 := mload(add(_data2, 64))
        }

        require(isHigher1 > isHigher2);
        return true;
    }

    // TODO: This needs to reject calls in the sub-channel is being settled. This will give both 
    // parties enough time to agree on the root hash to check transactions against. This means that the
    // lockTX timeouts need to start after the final settling to allow time for the secret to be revealed
    function updateBalances(bytes _proof, uint256 _lockedNonce, uint256 _amount, bytes32 _hash, uint256 _timeout, bytes _secret) public returns (bool) {
        // require that the transaction timeout has not expired
        require(now < _timeout);
        // be sure the tx nonce lines up with the interpreters sequence
        require(_lockedNonce == lockedNonce);
        
        bytes32 _txHash = keccak256(_lockedNonce, _amount, _hash, _timeout);
        require(_isContained(_txHash, _proof));

        // no need to refund?, just don't update the state balance
        // for the receiver
        // // refund case
        // if (_secret == 0x0) {
        //     require(_timeout <= now);
        //     //refund to sender
        //     balanceA+=_amount;
        // }

        // redeem case
        require(keccak256(_secret) == _hash);
        // assume one direction payment channel
        balanceB+=_amount;
        balanceA-=_amount;

        lockedNonce++;

        return true;
    }

    // function getLock() public view returns (uint256 amount, bytes32 hash, uint256 timeout) {
    //     return (lockedTx.amount, lockedTx.hash, lockedTx.timeout);
    // }

    function getTimeout(bytes _state) returns(uint256 _timeout) {
        assembly {
            _timeout := mload(add(_state, 96))
        }
    }

    // this needs to be permissioned to allow only calls from participants or only 
    // callable from the ctf contract pointing to it
    function initState(bytes _state, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) onlyMeta returns (bool) {
        _decodeState(_state);
        state = _state;
    }

    // this needs to be permissioned to allow only calls from participants or only 
    // callable from the ctf contract pointing to it
    function finalizeState(bytes _state, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) onlyMeta returns (bool) {
        // TODO: find best way to make this throw if the longest locked tx time hasn't elapsed
        require(now >= timeout);
        _decodeState(_state);
        state = _state;
    }



    function _isContained(bytes32 _hash, bytes _proof) returns (bool) {
        bytes32 cursor = _hash;
        bytes32 proofElem;

        for (uint256 i=64; i<=_proof.length; i+=32) {
            assembly { proofElem := mload(add(_proof, i)) }

            if (cursor < proofElem) {
                cursor = keccak256(cursor, proofElem);
            } else {
                cursor = keccak256(proofElem, cursor);
            }
        }

        return cursor == lockroot;
    }

    // this needs to be permissioned to allow only calls from participants or only 
    // callable from the ctf contract pointing to it
    function _decodeState(bytes _state) {
        // State
        // [0-31] isClose flag
        // [32-63] sequence
        // [64-95] timeout
        // [96-127] sender
        // [128-159] receiver
        // [160-191] bond 
        // [192-223] balance A
        // [224-255] balance B
        // [256-287] lockTXroot

        uint256 _bond;
        uint256 _balanceB;
        bytes32 _lockroot;
        uint256 _timeout;
        //address _meta;

        assembly {
            _timeout := mload(add(_state, 96))
            _bond := mload(add(_state, 224))
            _balanceB := mload(add(_state, 256))
            _lockroot := mload(add(_state, 288))
            //_meta := mload(add(_state, 320))
        }

        balanceA = _bond;
        balanceB = _balanceB;
        lockroot = _lockroot;
        timeout = _timeout;
        //metaAddress = _meta;
    }
}