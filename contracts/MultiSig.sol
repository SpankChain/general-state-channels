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
        // only allow pre-deployed extension contracts
        require(_assertExtension(_ext));     
         // require the channel is not open yet
        require(isOpen == false, 'openAgreement already called, isOpen true');
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
        // only allow pre-deployed extension contracts        
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


    function closeSubchannel(uint _channelID) public {
        MetaChannel deployedMetaChannel = MetaChannel(registry.resolveAddress(metachannel));

        deployedMetaChannel.delegatecall(bytes4(keccak256("closeWithTimeoutSubchannel(uint)")), _channelID);
    }


    function updateHTLCSubchannel(uint _channelID, bytes _proof, uint256 _lockedNonce, uint256 _amount, bytes32 _hash, uint256 _timeout, bytes32 _secret) public {
        MetaChannel deployedMetaChannel = MetaChannel(registry.resolveAddress(metachannel));

        uint _l = _proof.length;
        deployedMetaChannel.delegatecall(bytes4(keccak256("updateHTLCBalances(bytes, uint, uint256, uint256, bytes32, uint256, bytes32)")), bytes32(32), bytes32(_l), _proof, _channelID, _lockedNonce, _amount, _hash, _timeout, _secret);
    }


    function closeAgreement(bytes _state, uint8[2] sigV, bytes32[2] sigR, bytes32[2] sigS) public {
        address _partyA = _getSig(_state, sigV[0], sigR[0], sigS[0]);
        address _partyB = _getSig(_state, sigV[1], sigR[1], sigS[1]);

        require(_isClose(_state), 'State did not have a signed close sentinel');
        require(_hasAllSigs(_partyA, _partyB));

        _finalizeAll(_state);
        isOpen = false;
    }


    function closeAgreementByzantine() public {
        MetaChannel deployedMetaChannel = MetaChannel(registry.resolveAddress(metachannel));

        require(deployedMetaChannel.isClosed() == 1);


        _finalizeAll(deployedMetaChannel.state());
        isOpen = false;
    }


    function _finalizeAll(bytes _s) internal {
        uint _length = _s.length;
        for(uint i = 0; i < extensions.length; i++) {
            ExtensionInterface deployedExtension = ExtensionInterface(extensions[i]);
            deployedExtension.delegatecall(bytes4(keccak256("finalize(bytes)")), bytes32(32), bytes32(_length), _s);
        }
    }


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
