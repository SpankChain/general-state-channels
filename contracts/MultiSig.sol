pragma solidity ^0.4.23;

import "./CTFRegistry.sol";
import "./MetaChannel.sol";
import "./lib/extensions/ExtensionInterface.sol";

/// @title SpankChain General-State-Channel - A multisignature "wallet" for general state
/// @author Nathan Ginnever - <ginneversource@gmail.com>

// TODO: Timeout on init deposit return

contract MultiSig {

    string public constant NAME = "General State MultiSig";
    string public constant VERSION = "0.0.1";

    CTFRegistry public registry;

    // STATE
    //    32 isClose - Cooperative close flag
    //    64 sequence
    //    96 address 1
    //    128 address 2
    //    160 Meta Channel CTF address
    //    192 Sub-Channel Root Hash
    //
    // General State Sectors - Extensions must be able to handle these format
    // Sectors represent the final state of channels.
    //
    // Ether Balances - Sector type [0]
    //    EthBalanceA
    //    EthBalanceB
    //
    // Token Balances - Sector type [1]
    //    numTokenTypes
    //    tokenAddress
    //    ERC20BalanceA
    //    ERC20BalanceB
    //    ...
    //
    // "Non-fungile" Objects - Sector type [2]
    //    num721Objects
    //    721TokenID
    //    ...
    //

    // Extension modules act on final state agreements from the sub-channel outcomes

    address public partyA;
    address public partyB;
    bytes32 public metachannel; // Counterfactual address of metachannel

    // Require curated extensions to be used.
    address[3] public extensions = [0x0, 0x0, 0x0];

    bool public isOpen = false; // true when both parties have joined
    bool public isPending = false; // true when waiting for counterparty to join agreement

    function MultiSig(bytes32 _metachannel, address _registry) {
        require(_metachannel != 0x0, 'No metachannel CTF address provided to Msig constructor');
        require(_registry != 0x0, 'No CTF Registry address provided to Msig constructor');
        metachannel = _metachannel;
        registry = CTFRegistry(_registry);
    }

    function openAgreement(bytes _state, address _ext, uint8 _v, bytes32 _r, bytes32 _s) public payable {
        require(_assertExtension(_ext));     
         // require the channel is not open yet
        require(isOpen == false, 'isOpen true, expected false in openAgreement()');
        require(isPending == false, 'openAgreement already called, isPending true');

        isPending = true;
        // check the account opening a channel signed the initial state
        address _initiator = _getSig(_state, _v, _r, _s);

        ExtensionInterface deployedExtension = ExtensionInterface(_ext);

        uint _length = _state.length;

        // the open inerface can generalize an entry point for differenct kinds of checks 
        // on opening state
        deployedExtension.delegatecall(bytes4(keccak256("open(bytes, address)")), bytes32(32), bytes32(_length), _state, _initiator);

        partyA = _initiator;
    }

    function joinAgreement(bytes _state, address _ext, uint8 _v, bytes32 _r, bytes32 _s) public payable {
        require(_assertExtension(_ext));
        // require the channel is not open yet
        require(isOpen == false);

        // no longer allow joining functions to be called
        isOpen = true;

        // check that the state is signed by the sender and sender is in the state
        address _joiningParty = _getSig(_state, _v, _r, _s);

        ExtensionInterface deployedExtension = ExtensionInterface(_ext);

        uint _length = _state.length;
        
        deployedExtension.delegatecall(bytes4(keccak256("join(bytes, address)")), bytes32(32), bytes32(_length), _state, _joiningParty);

        // Set storage for state
        partyB = _joiningParty;
    }

    // Updates must be additive
    function depositState(bytes _state, address _ext, uint8[2] sigV, bytes32[2] sigR, bytes32[2] sigS) payable {
        require(_assertExtension(_ext));
        require(isOpen == true, 'Tried adding state to a close msig wallet');
        address _partyA = _getSig(_state, sigV[0], sigR[0], sigS[0]);
        address _partyB = _getSig(_state, sigV[1], sigR[1], sigS[1]);

        // Require both signatures 
        require(_hasAllSigs(_partyA, _partyB));

        ExtensionInterface deployedExtension = ExtensionInterface(_ext);

        uint _length = _state.length;

        deployedExtension.delegatecall(bytes4(keccak256("update(bytes)")), bytes32(32), bytes32(_length), _state);
    }

    // needs to have settlement process to close the final balance
    // or just check that the meta channel has closed on a settle process
    // this allows the spc to checkpoint state

    // Send all state to the meta channel, since it has been deployed, do this
    // even if you want to close just one channel, since it is already deployed
    //  we might as well ditch the msig contract
    function closeSubchannel(uint _channelID) public {
        MetaChannel deployedMetaChannel = MetaChannel(registry.resolveAddress(metachannel));

        //var(a,b,c,d,e,f,g,h,i) = deployedMetaChannel.getSubChannel(_channelID);

        // require the subchannel is closed
        //require(a == 1);

        deployedMetaChannel.delegatecall(bytes4(keccak256("closeWithTimeoutSubchannel(uint)")), _channelID);
        
        // uint _length = _state.length;
        // ExtensionInterface deployedExtension = ExtensionInterface(_ext);
        // deployedExtension.delegatecall(bytes4(keccak256("finalize(bytes)")), bytes32(32), bytes32(_length), _state);
    }

    function updateSubchannel(uint _channelID) public {
        MetaChannel deployedMetaChannel = MetaChannel(registry.resolveAddress(metachannel));

        //var(a,b,c,d,e,f,g,h,i) = deployedMetaChannel.getSubChannel(_channelID);

        // require the subchannel is closed
        //require(a == 1);

        deployedMetaChannel.delegatecall(bytes4(keccak256("updateHTLCBalances(uint)")), _channelID);
        
        // uint _length = _state.length;
        // ExtensionInterface deployedExtension = ExtensionInterface(_ext);
        // deployedExtension.delegatecall(bytes4(keccak256("finalize(bytes)")), bytes32(32), bytes32(_length), _state);
    }



    function closeAgreement(bytes _state, uint8[2] sigV, bytes32[2] sigR, bytes32[2] sigS) public {
        address _partyA = _getSig(_state, sigV[0], sigR[0], sigS[0]);
        address _partyB = _getSig(_state, sigV[1], sigR[1], sigS[1]);

        require(_isClose(_state), 'State did not have a signed close sentinel');
        require(_hasAllSigs(_partyA, _partyB));

        _finalizeAll(_state);
        isOpen = false;
    }

    function _finalizeAll(bytes _s) internal {
        uint _length = _s.length;
        for(uint i = 0; i < extensions.length; i++) {
            ExtensionInterface deployedExtension = ExtensionInterface(extensions[i]);
            deployedExtension.delegatecall(bytes4(keccak256("finalize(bytes)")), bytes32(32), bytes32(_length), _s);
        }
    }


    // // this should delegate call to an extension to read the state 
    // // that was agreed upon either 
    // //  1. Coop case: State has both parties sigs with an agreement to close
    // //  2. Non-coop case: State has one sig
    // // no force pushing of state here due to state transitions resulting in value transfer
    // // it is conceivable that you could force an advantageous final state and ddos your counterparty
    // // this currently works with ether only. It should take a list of extenstions that need to be called
    // function _finalizeByzantine(bytes _s) internal {
    //     address _meta = registry.resolveAddress(metachannel);
    //     uint _length = _s.length;
    //     for(uint i = 0; i < extensions.length; i++) {
    //         if(extensionUsed[extensions[i]]) {
    //             ExtensionInterface deployedExtension = ExtensionInterface(extensions[i]);
    //             deployedExtension.delegatecall(bytes4(keccak256("finalizeByzantine(bytes, address)")), bytes32(32), bytes32(_length), _s, _meta);
    //         }
    //     }
    // }

    function _assertExtension(address _e) internal view returns (bool) {
        bool _contained = false;
        for(uint i=0; i<extensions.length; i++) {
            if(extensions[i] == _e) { _contained == true; }
        }
        return _contained;
    }

    function _hasAllSigs(address _a, address _b) internal view returns (bool) {
        require(_a == partyA && _b == partyB, 'Signatures do not match parties in state');

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

    function _getSig(bytes _d, uint8 _v, bytes32 _r, bytes32 _s) internal pure returns(address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 h = keccak256(_d);

        bytes32 prefixedHash = keccak256(prefix, h);

        address a = ecrecover(prefixedHash, _v, _r, _s);

        //address a = ECRecovery.recover(prefixedHash, _s);

        return(a);
    }
}
