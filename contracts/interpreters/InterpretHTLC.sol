pragma solidity ^0.4.18;

import "./InterpreterInterface.sol";

contract InterpretHTLC is InterpreterInterface {
    // State
    // [0-31] isClose flag
    // [32-63] sequence
    // [64-95] timeout
    // [96-127] bond 
    // [128-159] balance A
    // [160-191] balance B
    // [192-224] lockTXroot

    uint256 totalBond = 0;
    bytes32 public lockroot;
    uint256 lockedNonce = 0;
    bytes state;
    // struct Lock {
    //     uint256 amount;
    //     bytes32 hash;
    //     uint256 timeout;
    // }

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


    function updateBalances(bytes32 _root, bytes _proof, uint256 _lockedNonce, uint256 _amount, bytes32 _hash, uint256 _timeout, bytes _secret) public returns (bool) {
        //require(now >= getTimeout(state));
        require(_lockedNonce == lockedNonce);
        
        bytes32 _txHash = keccak256(_lockedNonce, _amount, _hash, _timeout);
        lockroot = _root;
        require(_isContained(_txHash, _proof));
        //_isContained(_txHash, _proof);

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

    function isAddressInState(address _queryAddress) public returns (bool) {
        return true;
    }


    // just look for receiver sig
    function quickClose(bytes _data, uint _gameIndex) public returns (bool) {
        require(balanceA + balanceB == totalBond);
        return true;
    }

    function startSettleStateGame(uint _gameIndex, bytes _state, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {

    }

    function closeWithTimeoutGame(uint _gameIndex, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {

    }

    // this needs to be permissioned to allow only calls from participants or only 
    // callable from the ctf contract pointing to it
    function initState(bytes _state, uint _gameIndex, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public returns (bool) {
        _decodeState(_state, _gameIndex);
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
    function _decodeState(bytes _state, uint _gameIndex) {
        // SPC State
        // [
        //    32 isClose
        //    64 sequence
        //    96 numInstalledChannels
        //    128 address 1
        //    160 address 2
        //    192 balance 1
        //    224 balance 2
        //    256 channel 1 state length
        //    288 channel 1 interpreter type
        //    320 channel 1 CTF address
        //    [
        //        isClose
        //        sequence
        //        settlement period length
        //        channel specific state
        //        ...
        //    ]
        //    channel 2 state length
        //    channel 2 interpreter type
        //    channel 2 CTF address
        //    [
        //        isClose
        //        sequence
        //        settlement period length
        //        channel specific state
        //        ...
        //    ]
        //    ...
        // ]

        uint256 _bond;
        uint256 _balanceA;
        uint256 _balanceB;
        bytes32 _lockroot;

        // game index 0 means this is an initial state where there have
        // been no games loaded, so this state can't be assembled
        if (_gameIndex != 0) {
            // push pointer past the addresses and balances
            uint pos = 256;
            uint _gameLength;

            assembly {
                _gameLength := mload(add(_state, pos))
            }

            _gameLength = _gameLength*32;

            if(_gameIndex > 1) {
                pos+=_gameLength+32+32+32;
            }

            for(uint i=1; i<_gameIndex; i++) {
                assembly {
                    _gameLength := mload(add(_state, pos))
                }
                pos+=_gameLength+32+32+32;
            }

            if(_gameIndex > 1) {
                pos-= 32+32;
            }
            assembly {
                _bond := mload(add(_state, add(pos, 256)))
                _balanceA := mload(add(_state, add(pos, 288)))
                _balanceB := mload(add(_state, add(pos, 320)))
            }
            balanceA = _balanceA;
            balanceB = _balanceB;
            lockroot = _lockroot;
        }
    }
}