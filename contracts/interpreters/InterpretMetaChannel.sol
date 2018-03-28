
pragma solidity ^0.4.18;

import "../ChannelRegistry.sol";
import "./InterpreterInterface.sol";
import "./InterpretBidirectional.sol";
import "./InterpretPaymentChannel.sol";
import "./InterpretBattleChannel.sol";

contract InterpretMetaChannel is InterpreterInterface {
    // sub-channel state
    struct SubChannel {
        uint isClose;
        uint isInSettlementState;
        uint sequence;
        address[2] participants;
        bytes32 CTFaddress;
        uint settlementPeriodLength;
        uint settlementPeriodEnd;
        bytes state;
    }

    mapping(uint => SubChannel) subChannels;

    // meta-channel state
    uint public isClose = 0; // 1: Meta Channel open 0: Channel closed
    address public partyA;
    address public partyB;
    uint256 public balanceA;
    uint256 public balanceB;
    uint public settlementPeriodLength;
    bytes32 public stateRoot;
    bytes public state;

    // settlement state
    uint isInSettlementState = 0;
    ChannelRegistry public registry;
    uint public settlementPeriodEnd;

    function InterpretMetaChannel(address _registry) {
        require(_registry != 0x0);
        registry = ChannelRegistry(_registry);
    }

    // entry point for settlement of byzantine sub-channel
    function startSettleStateSubchannel(uint _channelIndex, bytes _proof, bytes _state, bytes _subchannel, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {
        // check that this state is signed
        address _partyA = _getSig(_state, _v[0], _r[0], _s[0]);
        address _partyB = _getSig(_state, _v[1], _r[1], _s[1]);
        require(_hasAllSigs(_partyA, _partyB));

        // sub-channel state should be passed to the interpreter to decode
        // we decode the overall state to get the agree roothash of subchannels
        // and other actionable state like timeout
        _decodeState(_state);
        // sub-channel must be open
        require(subChannels[_channelIndex].isClose == 0);
        // sub-channel must not already be in a settle state, this should
        // only be called once to initiate settlement period
        require(subChannels[_channelIndex].isInSettlementState == 0);

        bytes32 _stateHash = keccak256(_subchannel);
        // do proof of inclusing in of sub-channel state in root state
        require(_isContained(_stateHash, _proof));

        InterpreterInterface deployedInterpreter = InterpreterInterface(registry.resolveAddress(subChannels[_channelIndex].CTFaddress));
        deployedInterpreter.initState(_subchannel);

        // consider running some logic on the state from the interpreter to validate 
        // the new state obeys transition rules

        subChannels[_channelIndex].isInSettlementState = 1;
        subChannels[_channelIndex].settlementPeriodEnd = now + subChannels[_channelIndex].settlementPeriodLength;
        subChannels[_channelIndex].state = _subchannel;
    }

    // No need for a consensus close on the SPC since it is only instantiated in 
    // byzantine cases and just requires updating the state
    // client side (update spc bond balances, updates number of channels open, remove
    // closed channel state from total SPC state)

    // could be a case where this gets instantiated because a game went byzantine but you 
    // want to continue fast closing sub-channels against this contract. Though you
    // could just settle the sub-channels off chain until another dispute. In order to 
    // continue off chain the parties will have to update the timeout onchian with this setup

    function challengeSettleStateSubchannel(uint _channelIndex, bytes _proof, bytes _state, bytes _subchannel, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {
        // check sigs
        address _partyA = _getSig(_state, _v[0], _r[0], _s[0]);
        address _partyB = _getSig(_state, _v[1], _r[1], _s[1]);

        require(_hasAllSigs(_partyA, _partyB));

        // get roothash
        _decodeState(_state);

        require(subChannels[_channelIndex].isInSettlementState == 1);
        require(subChannels[_channelIndex].settlementPeriodEnd <= now);

        bytes32 _stateHash = keccak256(_subchannel);
        require(_isContained(_stateHash, _proof));

        // consult the now deployed special channel logic to see if sequence is higher
        // figure out how decode the CTFaddress from the state
        InterpreterInterface deployedInterpreter = InterpreterInterface(registry.resolveAddress(subChannels[_channelIndex].CTFaddress));
        require(deployedInterpreter.isSequenceHigher(subChannels[_channelIndex].state, _subchannel));
        
        deployedInterpreter.initState(_subchannel);

        subChannels[_channelIndex].settlementPeriodEnd = now + subChannels[_channelIndex].settlementPeriodLength;
        subChannels[_channelIndex].state = _subchannel;
    }

    // in the case of HTLC sub-channels, this must be called after the subchannel interpreter
    // has had enough time to play out the locked txs and update is balances
    function closeWithTimeoutSubchannel(uint _channelIndex) public {
        InterpreterInterface deployedInterpreter = InterpreterInterface(registry.resolveAddress(subChannels[_channelIndex].CTFaddress));

        require(subChannels[_channelIndex].settlementPeriodEnd <= now);
        require(subChannels[_channelIndex].isClose == 0);
        require(subChannels[_channelIndex].isInSettlementState == 1);

        deployedInterpreter.finalizeState(subChannels[_channelIndex].state);

        // update the meta-channel state for balance
        balanceA += deployedInterpreter.balanceA();
        balanceB += deployedInterpreter.balanceB();
        subChannels[_channelIndex].isClose = 1;
    }

    /// --- Close Meta Channel Functions

    function startSettle(bytes _state, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {
        address _partyA = _getSig(_state, _v[0], _r[0], _s[0]);
        address _partyB = _getSig(_state, _v[1], _r[1], _s[1]);

        require(_hasAllSigs(_partyA, _partyB));

        _decodeState(_state);

        require(isClose == 0);
        require(isInSettlementState == 0);

        state = _state;

        isInSettlementState = 1;
        settlementPeriodEnd = now + settlementPeriodLength;
    }

    function challengeSettle(bytes _state, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {
        address _partyA = _getSig(_state, _v[0], _r[0], _s[0]);
        address _partyB = _getSig(_state, _v[1], _r[1], _s[1]);

        require(_hasAllSigs(_partyA, _partyB));

        // require the channel to be in a settling state
        _decodeState(_state);
        require(isInSettlementState == 1);
        require(settlementPeriodEnd <= now);

        isSequenceHigher(_state, state);

        settlementPeriodEnd = now + settlementPeriodLength;
        state = _state;
    }

    function closeWithTimeout() public {
        require(settlementPeriodEnd <= now);
        require(isClose == 0);
        require(isInSettlementState == 1);

        _decodeState(state);
        statehash = keccak256(state);
        isClose = 1;
    }

    // TODO: Build SPC settlement functions

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

    function _isContained(bytes32 _hash, bytes _proof) internal returns (bool) {
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

        return cursor == stateRoot;
    }

    function _hasAllSigs(address _a, address _b) internal view returns (bool) {
        require(_a == partyA && _b == partyB);

        return true;
    }

    function _decodeState(bytes _state) internal {
        // SPC State
        // [
        //    32 isClose
        //    64 sequence
        //    96 timeout
        //    128 address 1
        //    160 address 2
        //    192 balance 1
        //    224 balance 2
        //    256 sub-channel root hash

        address _addressA;
        address _addressB;
        uint256 _balanceA;
        uint256 _balanceB;
        uint256 _timeout;
        bytes32 _root;

        //uint _sequence;
        uint _settlement;
        //uint _intType;
        assembly {
            _timeout := mload(add(_state, 96))
            _addressA := mload(add(_state, 128))
            _addressB := mload(add(_state, 160))
            _balanceA := mload(add(_state, 192))
            _balanceB := mload(add(_state, 224))
            _root := mload(add(_state, 256))
        }

        partyA = _addressA;
        partyB = _addressB;
        balanceA = _balanceA;
        balanceB = _balanceB;
        stateRoot = _root;
    }

    function _getSig(bytes _d, uint8 _v, bytes32 _r, bytes32 _s) internal pure returns(address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 h = keccak256(_d);

        bytes32 prefixedHash = keccak256(prefix, h);

        address a = ecrecover(prefixedHash, _v, _r, _s);

        //address a = ECRecovery.recover(prefixedHash, _s);

        return(a);
    }

    function getSubChannel(uint _channelIndex)
        external
        view
        returns
    (
        uint isClose,
        uint isInSettlementState,
        //uint numParties,
        uint sequence,
        // uint intType,
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
            //g.numParties,
            g.sequence,
            // g.intType,
            g.participants,
            g.CTFaddress,
            g.settlementPeriodLength,
            g.settlementPeriodEnd,
            g.state
        );
    }
}