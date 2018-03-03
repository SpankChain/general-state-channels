pragma solidity ^0.4.18;

import "./ChannelRegistry.sol";
import "./interpreters/InterpreterInterface.sol";

contract BondManager {
    // TODO: Allow token balances

    ChannelRegistry public registry;

    address public partyA;
    address public partyB;
    uint256 public balanceA;
    uint256 public balanceB;
    uint256 bond = 0; //in state
    uint256 bonded = 0;
    bytes32 interpreter;
    uint8[] booleans = [0,0,0]; // ['isChannelOpen', 'settlingPeriodStarted']
    bytes state;

    event ChannelCreated(bytes32 channelId, address indexed initiator);
    event ChannelJoined(bytes32 channelId, address indexed joiningParty);

    function BondManager(bytes32 _interpreter, address _registry) {
        require(_interpreter != 0x0);
        require(_registry != 0x0);
        interpreter = _interpreter;
        registry = ChannelRegistry(_registry);
    }

    // Consider one function with both sigs
    function openChannel(
        bytes _state,
        uint8 _v,
        bytes32 _r,
        bytes32 _s)
        public 
        payable
    {
        // check the account opening a channel signed the initial state
        address s = _getSig(_state, _v, _r, _s);
        // consider if this is required, reduces ability for 3rd party to facilitate txs 
        require(s == msg.sender || s == tx.origin);
        bond = _decodeState(_state);
        require(partyA == s);
        require(balanceA == msg.value);
        state = _state;

        bonded += msg.value;
    }

    function joinChannel(uint8 _v, bytes32 _r, bytes32 _s) public payable{
        // require the channel is not open yet
        require(booleans[0] == 0);

        // check that the state is signed by the sender and sender is in the state
        address _joiningParty = _getSig(state, _v, _r, _s);

        require(_joiningParty == partyB);
        require(balanceB == msg.value);

        bonded += msg.value;

        require(bond == bonded);
        booleans[0] = 1;
    }

    function closeChannelWithTimeout(bytes _state, uint8[2] sigV, bytes32[2] sigR, bytes32[2] sigS) public {
        address _partyA = _getSig(_state, sigV[0], sigR[0], sigS[0]);
        address _partyB = _getSig(_state, sigV[1], sigR[1], sigS[1]);

        require(_hasAllSigs(_partyA, _partyB));

        InterpreterInterface deployedInterpreter = InterpreterInterface(registry.resolveAddress(interpreter));
        //deployedInterpreter.closeWithTimeoutGame(_gameIndex, _state, sigV, sigR, sigS);
        require(deployedInterpreter.isOpen() == 1);

        balanceA = deployedInterpreter.balanceA();
        balanceB = deployedInterpreter.balanceB();

        _payout();
        booleans[0] = 0;
    }


    function closeChannel(bytes _state, uint8[2] sigV, bytes32[2] sigR, bytes32[2] sigS) public {
        bond = _decodeState(_state);

        address _partyA = _getSig(_state, sigV[0], sigR[0], sigS[0]);
        address _partyB = _getSig(_state, sigV[1], sigR[1], sigS[1]);

        require(_isClose(_state));

        require(_hasAllSigs(_partyA, _partyB));

        booleans[0] = 0;
        _payout();
    }


    function _payout() internal {
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

    function _decodeState(bytes _state) internal returns(uint256 totalBalance){
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

        return total;
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
