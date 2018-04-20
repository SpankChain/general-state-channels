pragma solidity ^0.4.18;

import "./ChannelRegistry.sol";
import "./interpreters/InterpreterInterface.sol";
import "./lib/extensions/EtherExtension.sol";

/// @title SpankChain General-State-Channel - A multisignature "wallet" for general state
/// @author Nathan Ginnever - <ginneversource@gmail.com>

// TODO: Timeout on init deposit return

contract MultiSig {
    //using EtherExtension for EtherExtension;

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

    // Extension modules act on final state agreements from the sub-channel outcomes

    address public partyA;
    address public partyB;
    uint256 sequence;
    bytes32 interpreter; // Counterfactual address of metachannel interpreter

    // [Ether, ERC20, ERC721, CKBA]
    address[] public extensions;

    bytes public state;

    uint256 bonded;

    bool isOpen = false; // true when both parties have joined

    event ChannelCreated(bytes32 channelId, address indexed initiator);
    event ChannelJoined(bytes32 channelId, address indexed joiningParty);

    function MultiSig(bytes32 _interpreter, address _registry, address[] _exts) {
        require(_interpreter != 0x0);
        require(_registry != 0x0);
        interpreter = _interpreter;
        registry = ChannelRegistry(_registry);
        for (uint8 i=0; i<_exts.length; i++) {
            //require(_exts[i] !=0x0);
            extensions[i] = _exts[i];
        }
    }

    // Consider one function with both sigs, still implies multiple transactions for funding
    function openAgreement(bytes _state, uint8 _ext, uint8 _v, bytes32 _r, bytes32 _s) public payable {
         // require the channel is not open yet
        require(isOpen == false);

        // check the account opening a channel signed the initial state
        address _initiator = _getSig(_state, _v, _r, _s);
        state = _state;

        if(_ext == 0) {
            //EtherExtension _eth = EtherExtension(extensions[0]);

            require(EtherExtension.getBalanceA(state) == msg.value);
            require(EtherExtension.getPartyA(state) == _initiator);

            bonded += msg.value;
        }

        if(_ext == 1) {}

        partyA = _initiator;
    }

    function joinAgreement(uint8 _ext, uint8 _v, bytes32 _r, bytes32 _s) public payable {
        // require the channel is not open yet
        require(isOpen == false);

        // check that the state is signed by the sender and sender is in the state
        address _joiningParty = _getSig(state, _v, _r, _s);
        
        if(_ext == 0) { 
             //EtherExtension _eth = EtherExtension(extensions[0]);
             require(EtherExtension.getPartyB(state) == _joiningParty);
             require(EtherExtension.getBalanceB(state) == msg.value);
             bonded += msg.value;
             require(EtherExtension.getTotal(state) == bonded);
        }

        if(_ext == 1) {}

        partyB = _joiningParty;
        // no longer allow joining functions to be called
        isOpen = true;
    }

    // TODO this is currently limited to monetary state
    function updateAgreement(bytes _state, uint8 _ext, uint8[2] sigV, bytes32[2] sigR, bytes32[2] sigS) payable {
        address _partyA = _getSig(_state, sigV[0], sigR[0], sigS[0]);
        address _partyB = _getSig(_state, sigV[1], sigR[1], sigS[1]);

        require(_hasAllSigs(_partyA, _partyB));

        state = _state;

        if(_ext == 0) {
            //EtherExtension _eth = EtherExtension(extensions[0]);

            uint256 _balA = EtherExtension.getBalanceA(state);
            uint256 _balB = EtherExtension.getBalanceB(state);
            uint256 _total = EtherExtension.getTotal(state);

            address _a = EtherExtension.getPartyA(state);
            address _b = EtherExtension.getPartyB(state);
            require(_a == partyA && _b == partyB);

            bonded += msg.value;
            require(_total == bonded);
        }

        if(_ext == 1) {}

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
    function closeAgreementWithTimeout(bytes _state, uint8 _ext) public {
        InterpreterInterface deployedInterpreter = InterpreterInterface(registry.resolveAddress(interpreter));

        require(deployedInterpreter.isClosed() == 1);

        require(keccak256(_state) == deployedInterpreter.statehash());
        state = _state;

        _finalize(_ext);
        isOpen = false;
    }


    function closeAgreement(bytes _state, uint8 _ext, uint8[2] sigV, bytes32[2] sigR, bytes32[2] sigS) public {

        address _partyA = _getSig(_state, sigV[0], sigR[0], sigS[0]);
        address _partyB = _getSig(_state, sigV[1], sigR[1], sigS[1]);

        require(_isClose(_state));
        require(_hasAllSigs(_partyA, _partyB));
        state = _state;

        _finalize(_ext);
        isOpen = false;
    }


    // this should delegate call to an extension to read the state 
    // that was agreed upon either 
    //  1. Coop case: State has both parties sigs with an agreement to close
    //  2. Non-coop case: State has one sig
    // no force pushing of state here due to state transitions resulting in value transfer
    // it is conceivable that you could force an advantageous final state and ddos your counterparty
    // this currently works with ether only. It should take a list of extenstions that need to be called
    function _finalize(uint8 _ext) internal {

        if(_ext == 0) {
            //EtherExtension _eth = EtherExtension(extensions[0]);
            require(EtherExtension.getTotal(state) == bonded);
            partyA.transfer(EtherExtension.getBalanceA(state));
            partyB.transfer(EtherExtension.getBalanceB(state));
        }
        
        if(_ext == 1) {}
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

    // function _getExtensionInst(uint8 _ext) internal pure returns(EtherExtension) {
    //     return EtherExtension(extensions[_ext]);
    // }

    function _getSig(bytes _d, uint8 _v, bytes32 _r, bytes32 _s) internal pure returns(address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 h = keccak256(_d);

        bytes32 prefixedHash = keccak256(prefix, h);

        address a = ecrecover(prefixedHash, _v, _r, _s);

        //address a = ECRecovery.recover(prefixedHash, _s);

        return(a);
    }
}
