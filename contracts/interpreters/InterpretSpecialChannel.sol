
pragma solidity ^0.4.18;

import "../ChannelRegistry.sol";
import "./InterpreterInterface.sol";
import "./InterpretBidirectional.sol";
import "./InterpretPaymentChannel.sol";
import "./InterpretBattleChannel.sol";

contract InterpretSpecialChannel is InterpreterInterface {
    // state
    struct SubChannel {
        uint isClose;
        uint isInSettlementState;
        uint numParties;
        uint sequence;
        uint intType;
        address[2] participants;
        bytes32 CTFaddress;
        uint settlementPeriodLength;
        uint settlementPeriodEnd;
        bytes state;
    }

    mapping(uint => SubChannel) subChannels;
    address public partyA;
    address public partyB;
    uint256 public balanceA;
    uint256 public balanceB;
    uint256 public bonded = 0;
    bytes public state;
    uint isOpen = 1;
    uint isInSettlementState = 0;
    ChannelRegistry public registry;


    function InterpretSpecialChannel(address _registry) {
        require(_registry != 0x0);
        registry = ChannelRegistry(_registry);
    }

    // entry point for settlement of byzantine sub-channel
    function startSettleStateGame(uint _channelIndex, bytes _state, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {
        _decodeState(_state, _channelIndex);

        require(subChannels[_channelIndex].isClose == 0);
        require(subChannels[_channelIndex].isInSettlementState == 0);

        InterpreterInterface deployedInterpreter = InterpreterInterface(registry.resolveAddress(subChannels[_channelIndex].CTFaddress));

        address _partyA = _getSig(_state, _v[0], _r[0], _s[0]);
        address _partyB = _getSig(_state, _v[1], _r[1], _s[1]);

        require(_hasAllSigs(_partyA, _partyB));

        // consult the now deployed special channel logic to see if sequence is higher
        // this also may not be necessary, just check sequence on challenges. what if 
        // the initial state needs to be settled?

        require(deployedInterpreter.isSequenceHigher(_state, state));

        // consider running some logic on the state from the interpreter to validate 
        // the new state obeys transition rules

        subChannels[_channelIndex].isInSettlementState = 1;
        subChannels[_channelIndex].settlementPeriodEnd = now + subChannels[_channelIndex].settlementPeriodLength;
    }

    // No need for a consensus close on the SPC since it is only instantiated in 
    // byzantine cases and just requires updating the state
    // client side (update spc bond balances, updates number of channels open, remove
    // closed channel state from total SPC state)

    // could be a case where this gets instantiated because a game went byzantine but you 
    // want to continue fast closing sub-channels against this contract. Though you
    // could just settle the sub-channels off chain until another dispute

    function challengeSettleStateGame(uint _channelIndex, bytes _state, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {
        // require the channel to be in a settling state
        require(subChannels[_channelIndex].isInSettlementState == 1);
        require(subChannels[_channelIndex].settlementPeriodEnd <= now);
        address _partyA = _getSig(_state, _v[0], _r[0], _s[0]);
        address _partyB = _getSig(_state, _v[1], _r[1], _s[1]);

        require(_hasAllSigs(_partyA, _partyB));

        // consult the now deployed special channel logic to see if sequence is higher
        // figure out how decode the CTFaddress from the state
        InterpreterInterface deployedInterpreter = InterpreterInterface(registry.resolveAddress(subChannels[_channelIndex].CTFaddress));
        require(deployedInterpreter.isSequenceHigher(_state, state));

        // consider running some logic on the state from the interpreter to validate 
        // the new state obeys transition rules. The only invalid transition is trying to 
        // create more tokens than the bond holds, since each contract is currently deployed
        // for each channel, closing on a bad state like that would just fail at the channels
        // expense.

        subChannels[_channelIndex].settlementPeriodEnd = now + subChannels[_channelIndex].settlementPeriodLength;
        state = _state;
    }

    function closeWithTimeoutGame(bytes _state, uint _channelIndex, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {
        InterpreterInterface deployedInterpreter = InterpreterInterface(registry.resolveAddress(subChannels[_channelIndex].CTFaddress));

        require(subChannels[_channelIndex].settlementPeriodEnd <= now);
        require(subChannels[_channelIndex].isClose == 0);
        require(subChannels[_channelIndex].isInSettlementState == 1);

        // Sig checking don 
        deployedInterpreter.initState(_state, _channelIndex, _v, _r, _s);

        address _partyA = _getSig(_state, _v[0], _r[0], _s[0]);
        address _partyB = _getSig(_state, _v[1], _r[1], _s[1]);

        require(_hasAllSigs(_partyA, _partyB));

        // update the spc state for balance
        balanceA += deployedInterpreter.balanceA();
        balanceB += deployedInterpreter.balanceB();
        subChannels[_channelIndex].isClose = 1;
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

    function isClose(bytes _data) public returns(bool) {
        uint isClosed;

        assembly {
            isClosed := mload(add(_data, 32))
        }

        require(isClosed == 1);
        return true;
    }

    function _hasAllSigs(address _a, address _b) internal view returns (bool) {
        require(_a == partyA && _b == partyB);

        return true;
    }

    function _decodeState(bytes _state, uint _channelIndex) internal {
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
        // num sub channels may not be needed since the channel index is provided
        uint _numSubChannels;
        address _addressA;
        address _addressB;
        uint256 _balanceA;
        uint256 _balanceB;

        //uint _sequence;
        uint _settlement;
        uint _intType;
        bytes32 _CTFaddress;
        //bytes memory _gameState;

        assembly {
            _numSubChannels := mload(add(_state, 96))
            _addressA := mload(add(_state, 128))
            _addressB := mload(add(_state, 160))
            _balanceA := mload(add(_state, 192))
            _balanceB := mload(add(_state, 224))
        }

        partyA = _addressA;
        partyB = _addressB;
        balanceA = _balanceA;
        balanceB = _balanceB;
        // sub-channel index 0 means this is an initial state where there have
        // been no sub-channels loaded, so this state can't be assembled
        if (_channelIndex != 0) {
            // push pointer past the addresses and balances
            uint pos = 256;
            uint _channelLength;

            assembly {
                _channelLength := mload(add(_state, pos))
            }

            _channelLength = _channelLength*32;

            if(_channelIndex > 1) {
                pos+=_channelLength+32+32+32;
            }

            for(uint i=1; i<_channelIndex; i++) {
                assembly {
                    _channelLength := mload(add(_state, pos))
                }
                pos+=_channelLength+32+32+32;
            }

            if(_channelIndex > 1) {
                pos-= 32+32;
            }

            assembly {
                _intType := mload(add(_state, add(pos, 32)))
                _CTFaddress := mload(add(_state, add(pos, 64)))
                //_sequence := mload(add(_state, add(pos,128)))
                _settlement := mload(add(_state, add(pos, 160)))
                //_gameState := mload(add(_state, add(pos, _posState)))
            }

            subChannels[_channelIndex].intType = _intType;
            subChannels[_channelIndex].settlementPeriodLength = _settlement;
            subChannels[_channelIndex].CTFaddress = _CTFaddress;
        }
    }

    function _getSig(bytes _d, uint8 _v, bytes32 _r, bytes32 _s) internal pure returns(address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 h = keccak256(_d);

        bytes32 prefixedHash = keccak256(prefix, h);

        address a = ecrecover(prefixedHash, _v, _r, _s);

        //address a = ECRecovery.recover(prefixedHash, _s);

        return(a);
    }


    function isAddressInState(address _queryAddress) public returns (bool){

    }

    function quickClose(bytes _state, uint _channelIndex) public returns (bool) {

    }

    function initState(bytes _state, uint _gameIndex, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public returns (bool) {
        _decodeState(_state, 0);

        require(isOpen == 1);
        require(isInSettlementState == 0);

        address _partyA = _getSig(_state, _v[0], _r[0], _s[0]);
        address _partyB = _getSig(_state, _v[1], _r[1], _s[1]);

        require(_hasAllSigs(_partyA, _partyB));

        state = _state;
    }

    function getSubChannel(uint _channelIndex)
        external
        view
        returns
    (
        uint isClose,
        uint isInSettlementState,
        uint numParties,
        uint sequence,
        uint intType,
        address[2] participants,
        bytes32 CTFaddress,
        uint settlementPeriodLength,
        uint settlementPeriodEnd,
        bytes state
    ) {
        SubChannel storage g = subChannels[_channelIndex];

        return (
            g.isClose,
            g.isInSettlementState,
            g.numParties,
            g.sequence,
            g.intType,
            g.participants,
            g.CTFaddress,
            g.settlementPeriodLength,
            g.settlementPeriodEnd,
            g.state
        );
    }
}