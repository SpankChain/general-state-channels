pragma solidity ^0.4.18;

import "./InterpreterInterface.sol";
import "../ChannelRegistry.sol";

contract InterpretPaymentChannel is InterpreterInterface {
    // State
    // [0-31] isClose flag
    // [32-63] address sender
    // [64-95] address receiver
    // [96-127] bond 
    // [128-159] balance of receiver

    // function interpret(bytes _data) public returns (bool) {

    //   return true;
    // }

    uint256 public totalBond = 0;

    
    bytes32 public CTFMetaAddress;
    ChannelRegistry public registry;

    modifier onlyMeta() {
        require(msg.sender == registry.resolveAddress(CTFMetaAddress));
        _;
    }

    function InterpretPaymentChannel(bytes32 _CTFMetaAddress, address _registry) {
        CTFMetaAddress = _CTFMetaAddress;
        registry = ChannelRegistry(_registry);
    }

    
    // This always returns true since the receiver should only
    // sign and close the highest balance they have
    function isClose(bytes _data) public returns(bool) {
        return true;
    }

    function isSequenceHigher(bytes _data) public returns (bool) {
        uint isHigher1;
        uint isHigher2;

        bytes memory _s = state;

        assembly {
            isHigher1 := mload(add(_s, 64))
            isHigher2 := mload(add(_data, 64))
        }

        require(isHigher1 < isHigher2);
        return true;
    }

    // TODO: MODIFY
    function initState(bytes _state) onlyMeta returns (bool) {
        _decodeState(_state);
        state = _state;
        totalBond = balanceA + balanceB;
    }

    function _decodeState(bytes _state) {
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


        uint256 _balanceA;
        uint256 _balanceB;

        assembly {
            _balanceA := mload(add(_state, 256))
            _balanceB := mload(add(_state, 288))
        }
        balanceA = _balanceA;
        balanceB = _balanceB;
    }
}