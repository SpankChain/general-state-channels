
pragma solidity ^0.4.23;

import "./CTFRegistry.sol";

/// @title SpankChain Meta-channel - An interpreter designed to handle multiple state-channels
/// @author Nathan Ginnever - <ginneversource@gmail.com>

contract MetaChannel {

    // sub-channel state
    struct SubChannel {
        uint isSubClose;
        uint isSubInSettlementState;
        uint subSequence;
        uint lockedNonce;
        address challenger;
        address CTFaddress;
        uint subSettlementPeriodLength;
        uint subSettlementPeriodEnd;
        uint settledAt;
        bytes subState;
    }

    mapping(uint => SubChannel) subChannels;

    // meta-channel state
    address public partyA; // Address of first channel participant
    address public partyB; // Address of second channel participant
    uint public settlementPeriodLength = 0; // How long challengers have to reply to settle engagement
    bytes32 public stateRoot; // The merkle root of all sub-channel state
    uint public isClosed;
    bytes public state;
    uint public sequence = 0;
    // settlement state
    uint public isInSettlementState = 0; // meta channel is in settling 1: Not settling 0
    uint public isInSubSettlementState = 0; // sub channel is in settling 1: Not settling 0
    CTFRegistry public registry; // Address of the CTF registry
    uint public settlementPeriodEnd; // The time when challenges are no longer accepted after

    constructor(address _registry, address _partyA, address _partyB) public {
        require(_partyA != 0x0 && _partyB != 0x0 && _registry != 0x0);
        registry = CTFRegistry(_registry);
        partyA = _partyA;
        partyB = _partyB;
    }

    // Allows for single signature of state, it can punish invalid transitions that where signed
    // or it may reward a valid state advance if the counterparty does not respond.
    // Slash the initiator if they do respond
    //
    // Must start settling the force push state with the double signed open state on the force push subchannel
    function forcePushSubchannel(bytes _forceState, uint _channelID) public payable{
        // require force pushes to have a bond
        require(msg.value == 1 ether);
        // Make sure one of the parties has signed this subchannel update
        require(_hasOneSig(msg.sender));

        require(_getSequence(_forceState) > subChannels[_channelID].subSequence);

        // this subchannel must have an agreement to allow force pushing state
        require(_allowForce(subChannels[_channelID].subState) == 1);

        // sub-channel must be open
        require(subChannels[_channelID].isSubClose == 0);
        // sub-channel must already be in a settle state, this should
        // only be called once it is confirmed that a subchannel with both
        // parties sigs with a forcepsuh flag has entered
        require(subChannels[_channelID].isSubInSettlementState == 1);

        uint _length = _forceState.length;
        require(address(subChannels[_channelID].CTFaddress).delegatecall(bytes4(keccak256("validateState(bytes)")), bytes32(32), bytes32(_length), _forceState));

        subChannels[_channelID].challenger = msg.sender;
        subChannels[_channelID].subSequence = _getSequence(_forceState);
        subChannels[_channelID].subState = _forceState;
        subChannels[_channelID].subSettlementPeriodEnd = now + _getChallengePeriod(subChannels[_channelID].subState);
    }

    function challengeForcePush(bytes _forceState, uint _channelID) public {
        // Make sure one of the parties has signed this subchannel update
        require(_hasOneSig(msg.sender));

        require(_getSequence(_forceState) > subChannels[_channelID].subSequence);

        // this subchannel must have an agreement to allow force pushing state
        require(_allowForce(subChannels[_channelID].subState) == 1);
        // sub-channel must be open
        require(subChannels[_channelID].isSubClose == 0);
        // sub-channel must already be in a settle state, this should
        // only be called once it is confirmed that a subchannel with both
        // parties sigs with a forcepsuh flag has entered
        require(subChannels[_channelID].isSubInSettlementState == 1);
        require(subChannels[_channelID].subSettlementPeriodEnd > now);
        require(subChannels[_channelID].challenger != 0x0);

        uint _length = _forceState.length;
        require(address(subChannels[_channelID].CTFaddress).delegatecall(bytes4(keccak256("validateState(bytes)")), bytes32(32), bytes32(_length), _forceState));

        subChannels[_channelID].subState = _forceState;
        subChannels[_channelID].subSequence = _getSequence(_forceState);
        // reset the challenger
        subChannels[_channelID].challenger = 0x0;
        subChannels[_channelID].subSettlementPeriodEnd = now + _getChallengePeriod(subChannels[_channelID].subState);
        // Punish the challenger for force pushing
        msg.sender.transfer(1 ether);
    }


    // entry point for settlement of byzantine sub-channel
    function startSettleStateSubchannel(bytes _proof, bytes _state, bytes _subchannel, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {
        // check that this state is signed
        address _partyA = _getSig(_state, _v[0], _r[0], _s[0]);
        address _partyB = _getSig(_state, _v[1], _r[1], _s[1]);

        uint _channelID = _getChannelID(_subchannel);

        // get roothash
        stateRoot = _getRoot(_state);

        require(_hasAllSigs(_partyA, _partyB));

        // sub-channel must be open
        require(subChannels[_channelID].isSubClose == 0);
        // sub-channel must not already be in a settle state, this should
        // only be called once to initiate settlement period
        require(subChannels[_channelID].isSubInSettlementState == 0);

        bytes32 _stateHash = keccak256(_subchannel);
        // do proof of inclusing of sub-channel state in root state
        require(_isContained(_stateHash, _proof, stateRoot));

        // consider running some logic on the state from the interpreter to validate
        // the new state obeys transition rules

        subChannels[_channelID].CTFaddress = _getInterpreterAddress(_subchannel);

        subChannels[_channelID].isSubInSettlementState = 1;
        subChannels[_channelID].subSettlementPeriodEnd = now + _getChallengePeriod(_subchannel);
        subChannels[_channelID].subState = _subchannel;
        subChannels[_channelID].subSequence = _getSequence(_subchannel);
        state = _state;
    }


    function challengeSettleStateSubchannel(bytes _proof, bytes _state, bytes _subchannel, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {
        // check sigs
        address _partyA = _getSig(_state, _v[0], _r[0], _s[0]);
        address _partyB = _getSig(_state, _v[1], _r[1], _s[1]);

        uint _channelID = _getChannelID(_subchannel);

        // get roothash
        stateRoot = _getRoot(_state);

        require(_hasAllSigs(_partyA, _partyB));

        require(subChannels[_channelID].isSubInSettlementState == 1);
        require(subChannels[_channelID].subSettlementPeriodEnd > now);

        bytes32 _stateHash = keccak256(_subchannel);
        require(_isContained(_stateHash, _proof, stateRoot));

        require(_getSequence(_subchannel) > subChannels[_channelID].subSequence);

        subChannels[_channelID].CTFaddress = _getInterpreterAddress(_subchannel);
        // extend the challenge time for the sub-channel
        subChannels[_channelID].subSettlementPeriodEnd = now + _getChallengePeriod(_subchannel);
        subChannels[_channelID].subState = _subchannel;
        subChannels[_channelID].subSequence = _getSequence(_subchannel);
        state = _state;
    }

    // in the case of HTLC sub-channels, this must be called after the subchannel interpreter
    // has had enough time to play out the locked txs and update is balances
    function closeWithTimeoutSubchannel(uint _channelID) public {
        require(subChannels[_channelID].subSettlementPeriodEnd <= now);
        require(subChannels[_channelID].isSubClose == 0);
        require(subChannels[_channelID].isSubInSettlementState == 1);

        uint _length = subChannels[_channelID].subState.length;
        bytes memory _s = subChannels[_channelID].subState;
        require(address(subChannels[_channelID].CTFaddress).delegatecall(bytes4(keccak256("finalizeState(bytes)")), bytes32(32), bytes32(_length), _s));

        subChannels[_channelID].isSubClose = 1;
        subChannels[_channelID].isSubInSettlementState = 0;
        subChannels[_channelID].settledAt = now;

        // return bond if challenge received no response
        if(subChannels[_channelID].challenger != 0x0) { subChannels[_channelID].challenger.transfer(1 ether); }
    }

    // send ether balance
    // assumptions:
    //   - Channels are single directional
    //   - party A is always paying party B
    function updateHTLCBalances(bytes _proof, uint _channelID, uint256 _lockedNonce, uint256 _amount, bytes32 _hash, uint256 _timeout, bytes32 _secret) public returns (bool) {
        require(subChannels[_channelID].isSubInSettlementState == 0);
        require(subChannels[_channelID].isSubClose == 1);
        // require that the transaction timeout has not expired
        require(now < subChannels[_channelID].settledAt + _timeout);
        // be sure the tx nonce lines up with the interpreters sequence
        // initially this will be 0
        require(_lockedNonce == subChannels[_channelID].lockedNonce);

        bytes32 _lockRoot = _getSubRoot(subChannels[_channelID].subState);

        bytes32 _txHash = keccak256(_lockedNonce, _amount, _hash, _timeout);
        require(_isContained(_txHash, _proof, _lockRoot));

        // no need to refund?, just don't update the state balance

        // redeem case
        //require(keccak256(_secret) == _hash);

        partyB.transfer(_amount);
        subChannels[_channelID].lockedNonce++;

        return true;
    }

    // TODO allow Alice to come online and reclaim locked funds
    function finalizeHTLCupdates() public pure returns (bool) {
        return true;
    }

    // /// --- Close Meta Channel Functions

    function startSettle(bytes _state, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {
        address _partyA = _getSig(_state, _v[0], _r[0], _s[0]);
        address _partyB = _getSig(_state, _v[1], _r[1], _s[1]);

        require(_hasAllSigs(_partyA, _partyB));

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

        require(isInSettlementState == 1);
        require(settlementPeriodEnd <= now);

        require(_getSequence(_state) > sequence);

        settlementPeriodEnd = now + settlementPeriodLength;
        state = _state;
        sequence++;
    }

    function closeWithTimeout() public {
        require(settlementPeriodEnd <= now);
        require(isClosed == 0);
        require(isInSettlementState == 1);

        isClosed = 1;
    }

    // Internal Functions
    function _getInterpreterAddress(bytes _s) public pure  returns (address _ctf) {
        assembly {
            _ctf := mload(add(_s, 160))
        }
    }

    function _getChannelID(bytes _s) public pure returns (uint _id) {
        assembly {
            _id := mload(add(_s, 192))
        }
    }

    function _getSequence(bytes _data) public pure returns (uint _seq) {
        assembly {
            _seq := mload(add(_data, 64))
        }
    }

    function _getChallengePeriod(bytes _data) public pure returns (uint _length) {
        assembly {
            _length := mload(add(_data, 128))
        }
    }


    function _isContained(bytes32 _hash, bytes _proof, bytes32 _root) internal pure returns (bool) {
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

        return cursor == _root;
    }

    function _allowForce(bytes _state) internal pure returns (uint _isForce) {
        assembly { _isForce := mload(add(_state, 96))}
    }

    function _hasAllSigs(address _a, address _b) internal view returns (bool) {
        require(_a == partyA && _b == partyB);
        return true;
    }

    function _hasOneSig(address _c) internal view returns (bool) {
        require(_c == partyA || _c == partyB);
        return true;
    }

    function _getRoot(bytes _state) internal pure returns (bytes32 _root){
        assembly {
            _root := mload(add(_state, 192))
        }
    }

    function _getSubRoot(bytes _state) internal pure returns (bytes32 _root){
        assembly {
            _root := mload(add(_state, 288))
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

    function getSubChannel(uint _channelID)
        external
        view
        returns
    (
        uint isSubClose,
        uint isSubInSettlementState,
        uint subSequence,
        uint lockedNonce,
        address challenger,
        address subCTFaddress,
        uint subSettlementPeriodLength,
        uint subSettlementPeriodEnd,
        uint settledAt,
        bytes subState
    ) {
        SubChannel storage g = subChannels[_channelID];
        return (
            g.isSubClose,
            g.isSubInSettlementState,
            g.subSequence,
            g.lockedNonce,
            g.challenger,
            g.CTFaddress,
            g.subSettlementPeriodLength,
            g.subSettlementPeriodEnd,
            g.settledAt,
            g.subState
        );
    }

    function() payable public {}
}
