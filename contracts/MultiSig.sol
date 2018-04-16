pragma solidity ^0.4.18;

import "./ChannelRegistry.sol";
import "./interpreters/InterpreterInterface.sol";
import "./extensions/ExtensionInterface.sol";

/// @title SpankChain General-State-Channel - A multisignature "wallet" for general state
/// @author Nathan Ginnever - <ginneversource@gmail.com>

// TODO: Timeout on init deposit return

contract MultiSig {

    string public constant NAME = "General State MultiSig";
    string public constant VERSION = "0.0.1";

    ChannelRegistry public registry;

    // STATE
    //    32 isClose - Cooperative close flag
    //    64 sequence
    //    96 address 1
    //    128 address 2
    //    160 Meta Channel CTF address
    //    192 Sub-Channel Root Hash
    //    225+ General State

    // General State - Extensions must be able to handle these format
    // Ether Balances
    //    EthBalanceA
    //    EthBalanceB
    //
    // Token Balances
    //    ERC20BalanceA
    //    ERC20BalanceB
    //
    // "Non-fungile" Objects
    //    Num721Objects
    //    721TokenID
    //    ...
    //
    // Battle Arena Fighter State
    //    Battle Arena State
    //    FighterStatsA
    //    FighterStatsB

    // Decoder modules act on final state agreements from the sub-channel outcomes

    uint256 sequence;
    address public partyA;
    address public partyB;
    uint256 public balanceA;
    uint256 public balanceB;
    bytes32 interpreter;

    bytes state;

    uint256 bonded;
    bool isOpen = false;

    event ChannelCreated(bytes32 channelId, address indexed initiator);
    event ChannelJoined(bytes32 channelId, address indexed joiningParty);

    function MultiSig(bytes32 _interpreter, address _registry) {
        require(_interpreter != 0x0);
        require(_registry != 0x0);
        interpreter = _interpreter;
        registry = ChannelRegistry(_registry);
    }

    // Consider one function with both sigs, still implies multiple transactions for funding
    function openAgreement(bytes _state, uint8 _v, bytes32 _r, bytes32 _s) public payable {
        // check the account opening a channel signed the initial state
        address s = _getSig(_state, _v, _r, _s);
        // consider if this is required, reduces ability for 3rd party to facilitate txs 
        //require(s == msg.sender || s == tx.origin);
        _decodeState(_state);
        require(partyA == s);
        require(balanceA == msg.value);
        state = _state;

        bonded += msg.value;
    }

    function joinAgreement(uint8 _v, bytes32 _r, bytes32 _s) public payable {
        // require the channel is not open yet
        require(isOpen == false);

        // check that the state is signed by the sender and sender is in the state
        address _joiningParty = _getSig(state, _v, _r, _s);

        require(_joiningParty == partyB);
        require(balanceB == msg.value);

        bonded += msg.value;

        isOpen = true;
    }

    // TODO this is currently limited to monetary state
    function updateAgreement() payable {
        require(msg.sender == partyA || msg.sender == partyB);
        if(msg.sender == partyA) { balanceA+= msg.value; }
        if(msg.sender == partyB) { balanceB+= msg.value; }
        bonded += msg.value;
    }

    // TODO allow executing subchannel state. this will allow an on-chain sub-channel close
    function executeState() {
        // this might require an executable flag on the state like the isClose sentinel.
        // this flag would represent an agreement to execute the given state
        // this state should reflect the current state of the metachannel, which in cases
        // of fault will reflect the final outcome of subchannel settlement
    }

    // needs to have settlement process to close the final balance
    // or just check that the meta channel has closed on a settle process
    // this allows the spc to checkpoint state
    function closeAgreementWithTimeout(bytes _state) public {
        InterpreterInterface deployedInterpreter = InterpreterInterface(registry.resolveAddress(interpreter));

        require(deployedInterpreter.isClosed() == 1);

        require(keccak256(_state) == deployedInterpreter.statehash());

        _finalize(_state);
        isOpen = false;
    }


    function closeAgreement(bytes _state, uint8[2] sigV, bytes32[2] sigR, bytes32[2] sigS) public {

        address _partyA = _getSig(_state, sigV[0], sigR[0], sigS[0]);
        address _partyB = _getSig(_state, sigV[1], sigR[1], sigS[1]);

        require(_isClose(_state));

        require(_hasAllSigs(_partyA, _partyB));

        _finalize(_state);
        isOpen = false;
    }


    // this should delegate call to an extension to read the state 
    // that was agreed upon either 
    //  1. Coop case: State has both parties sigs with an agreement to close
    //  2. Non-coop case: State has one sig
    // no force pushing of state here due to state transitions resulting in value transfer
    // it is conceivable that you could force an advantageous final state and ddos your counterparty
    // this currently works with ether only. It should take a list of extenstions that need to be called
    function _finalize(bytes _state) internal {
        _decodeState(_state);
        require(balanceA + balanceB == bonded);
        partyA.transfer(balanceA);
        partyB.transfer(balanceB);
    }

    function _hasAllSigs(address _a, address _b) internal view returns (bool) {
        require(_a == partyA && _b == partyB);

        return true;
    }

    function _isClose(bytes _data) internal pure returns(bool) {
        uint isClosed;

        assembly {
            isClosed := mload(add(_data, 32))
        }

        require(isClosed == 1);
        return true;
    }

    // TODO: for extensions, we can move this to the extension so that state decoding and acting
    // upon state happens in the extension.
    // In the case of CKBA the extension will be the arena contract. The arena will read
    // the final state and update the global ledger of cat stats upon exit
    function _decodeState(bytes _state) internal {
        uint256 total;
        address _addressA;
        address _addressB;
        uint256 _balanceA;
        uint256 _balanceB;

        assembly {
            _addressA := mload(add(_state, 96))
            _addressB := mload(add(_state, 128))
            _balanceA := mload(add(_state, 160))
            _balanceB := mload(add(_state, 192))
        }

        total = _balanceA + _balanceB;
        balanceA = _balanceA;
        balanceB = _balanceB;
        partyA = _addressA;
        partyB = _addressB;
    }

    function _getSig(bytes _d, uint8 _v, bytes32 _r, bytes32 _s) internal pure returns(address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 h = keccak256(_d);

        bytes32 prefixedHash = keccak256(prefix, h);

        address a = ecrecover(prefixedHash, _v, _r, _s);

        //address a = ECRecovery.recover(prefixedHash, _s);

        return(a);
    }
}
