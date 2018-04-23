
pragma solidity ^0.4.23;

import "./lib/interpreters/LibBidirectional.sol";
import "./lib/interpreters/LibPaymentChannel.sol";
import "./lib/interpreters/LibHTLC.sol";
import "./lib/interpreters/LibVirtualChannel.sol";
import "./lib/interpreters/LibBattleChannel.sol";
import ""

/// @title SpankChain Meta-channel - An interpreter designed to handle multiple state-channels
/// @author Nathan Ginnever - <ginneversource@gmail.com>

contract MetaChannel {
    // sub-channel state
    struct SubChannel {
        uint isSubClose;
        uint isSubInSettlementState;
        uint subSequence;
        address[2] participants;
        bytes32 CTFaddress;
        uint subSettlementPeriodLength;
        uint subSettlementPeriodEnd;
        bytes subState;
    }

    mapping(uint => SubChannel) subChannels;

    // meta-channel state
    address public partyA; // Address of first channel participant
    address public partyB; // Address of second channel participant
    uint public settlementPeriodLength; // How long challengers have to reply to settle engagement
    bytes32 public stateRoot; // The merkle root of all sub-channel state
    bytes32 public stateHash; // Hash of entire state
    uint public isClosed;
    bytes public state;
    // settlement state
    uint public isInSettlementState = 0; // meta channel is in settling 1: Not settling 0
    ChannelRegistry public registry; // Address of the CTF registry
    uint public settlementPeriodEnd; // The time when challenges are no longer accepted after

    // function InterpretMetaChannel(address _registry) {
    //     require(_registry != 0x0);
    //     registry = ChannelRegistry(_registry);
    // }

    // entry point for settlement of byzantine sub-channel
    function startSettleStateSubchannel(uint _channelID, bytes _proof, bytes _state, bytes _subchannel, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {
        // check that this state is signed
        address _partyA = _getSig(_state, _v[0], _r[0], _s[0]);
        address _partyB = _getSig(_state, _v[1], _r[1], _s[1]);

        // sub-channel state should be passed to the interpreter to decode
        // we decode the overall state to get the agreed roothash of subchannels
        // and other actionable state like timeout
        _decodeState(_state);
        require(_hasAllSigs(_partyA, _partyB));

        // sub-channel must be open
        require(subChannels[_channelID].isSubClose == 0);
        // sub-channel must not already be in a settle state, this should
        // only be called once to initiate settlement period
        require(subChannels[_channelID].isSubInSettlementState == 0);

        bytes32 _stateHash = keccak256(_subchannel);
        // do proof of inclusing in of sub-channel state in root state
        require(_isContained(_stateHash, _proof));

        //InterpreterInterface deployedInterpreter = InterpreterInterface(registry.resolveAddress(subChannels[_channelID].CTFaddress));
        // this interprets the agreed upon state and sets its storage (currently in both the meta and subchannel)
        //deployedInterpreter.initState(_subchannel);

        // consider running some logic on the state from the interpreter to validate 
        // the new state obeys transition rules

        subChannels[_channelID].isSubInSettlementState = 1;
        subChannels[_channelID].subSettlementPeriodEnd = now + subChannels[_channelID].subSettlementPeriodLength;
        stateHash = keccak256(_state);
        subChannels[_channelID].subState = _subchannel;
    }

    // No need for a consensus close on the SPC since it is only instantiated in 
    // byzantine cases and just requires updating the state
    // client side (update spc bond balances, updates number of channels open, remove
    // closed channel state from total SPC state)

    // could be a case where this gets instantiated because a game went byzantine but you 
    // want to continue fast closing sub-channels against this contract. Though you
    // could just settle the sub-channels off chain until another dispute. In order to 
    // continue off chain the parties will have to update the timeout onchian with this setup

    function challengeSettleStateSubchannel(uint _channelID, bytes _proof, bytes _state, bytes _subchannel, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {
        // check sigs
        address _partyA = _getSig(_state, _v[0], _r[0], _s[0]);
        address _partyB = _getSig(_state, _v[1], _r[1], _s[1]);

        // get roothash
        _decodeState(_state);
        require(_hasAllSigs(_partyA, _partyB));

        require(subChannels[_channelID].isSubInSettlementState == 1);
        require(subChannels[_channelID].subSettlementPeriodEnd <= now);

        bytes32 _stateHash = keccak256(_subchannel);
        require(_isContained(_stateHash, _proof));

        //InterpreterInterface deployedInterpreter = InterpreterInterface(registry.resolveAddress(subChannels[_channelID].CTFaddress));
        // since the initial bytes of the state are the same in subchannel as metachannel, we could reuse the isSequenceHigher here
        require(isSequenceHigher(_subchannel));
        
        // store the new sub-channel state in the interpreter
        deployedInterpreter.initState(_subchannel);

        // extend the challenge time for the sub-channel
        subChannels[_channelID].subSettlementPeriodEnd = now + subChannels[_channelID].subSettlementPeriodLength;
        subChannels[_channelID].subState = _subchannel;
    }

    // in the case of HTLC sub-channels, this must be called after the subchannel interpreter
    // has had enough time to play out the locked txs and update is balances
    function closeWithTimeoutSubchannel(uint _channelID) public {
        //InterpreterInterface deployedInterpreter = InterpreterInterface(registry.resolveAddress(subChannels[_channelID].CTFaddress));

        require(subChannels[_channelID].subSettlementPeriodEnd <= now);
        require(subChannels[_channelID].isSubClose == 0);
        //require(subChannels[_channelID].isInSettlementState == 1);

        // this may not be needed since initState is called for every challenge
        // for htlc channels, the client just needs to be sure that for any individual
        // tx timeout, that the individual timeout is shorter than the channel timeout.
        //deployedInterpreter.finalizeState();

        // update the meta-channel state for balance
        // TODO: generalize this to just STATE for the msig extension to read
        // just leave the state stored in the subchannel contract, and interpret it
        // via the msig
        // put the action of reconciling subchannel state and top state bytes in the interpreter
        //balanceA += deployedInterpreter.balanceA();
        //balanceB += deployedInterpreter.balanceB();
        
        // maybe do this in the metachannel
        //_reconcileState(deployedInterpreter.getExtType());

        // GET interpreter library type
        // send funds that are now stored on the metachannel

        subChannels[_channelID].isSubClose = 1;
    }

    /// --- Close Meta Channel Functions

    function startSettle(bytes _state, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {
        address _partyA = _getSig(_state, _v[0], _r[0], _s[0]);
        address _partyB = _getSig(_state, _v[1], _r[1], _s[1]);

        require(_hasAllSigs(_partyA, _partyB));

        _decodeState(_state);

        require(isClosed == 0);
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

        isSequenceHigher(_state);

        settlementPeriodEnd = now + settlementPeriodLength;
        state = _state;
    }

    function closeWithTimeout() public {
        require(settlementPeriodEnd <= now);
        require(isClosed == 0);
        require(isInSettlementState == 1);

        _decodeState(state);
        stateHash = keccak256(state);
        isClosed = 1;
    }

    // TODO: Build SPC settlement functions

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


    function isClose(bytes _data) public returns(bool) {
        uint _isClosed;

        assembly {
            _isClosed := mload(add(_data, 32))
        }

        require(_isClosed == 1);
        return true;
    }



    function _reconcileState(uint8 _ext) internal {
        if(_ext == 0) {
            // do eth resettle
        }

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
        // uint256 _balanceA;
        // uint256 _balanceB;
        uint256 _timeout;
        bytes32 _root;

        //uint _sequence;
        uint _settlement;
        //uint _intType;
        assembly {
            _timeout := mload(add(_state, 96))
            _addressA := mload(add(_state, 128))
            _addressB := mload(add(_state, 160))
            // _balanceA := mload(add(_state, 192))
            // _balanceB := mload(add(_state, 224))
            _root := mload(add(_state, 256))
        }

        partyA = _addressA;
        partyB = _addressB;
        // balanceA = _balanceA;
        // balanceB = _balanceB;
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

    function getSubChannel(uint _channelID)
        external
        view
        returns
    (
        uint isSubClose,
        uint isSubInSettlementState,
        //uint numParties,
        uint subSequence,
        // uint intType,
        address[2] participants,
        bytes32 subCTFaddress,
        uint subSettlementPeriodLength,
        uint subSettlementPeriodEnd,
        bytes subState
    ) {
        SubChannel storage g = subChannels[_channelID];

        return (
            g.isSubClose,
            g.isSubInSettlementState,
            //g.numParties,
            g.subSequence,
            // g.intType,
            g.participants,
            g.CTFaddress,
            g.subSettlementPeriodLength,
            g.subSettlementPeriodEnd,
            g.subState
        );
    }
}