pragma solidity ^0.4.23;

import "../../MultiSig.sol";
import "./ExtensionInterface.sol";

contract EtherExtension is ExtensionInterface {

    function getPartyA(bytes _s) public view returns(address _partyA) {
        assembly {
            _partyA := mload(add(_s, 96))
        }
    }

    function getPartyB(bytes _s) public view returns(address _partyB) {
        assembly {
            _partyB := mload(add(_s, 96))
        }
    }

    function getBalanceA(bytes _s) public view returns(uint256 _balanceA) {
        assembly {
            _balanceA := mload(add(_s, 160))
        }
    }

    function getBalanceB(bytes _s) public view returns(uint256 _balanceB) {
        assembly {
            _balanceB := mload(add(_s, 192))
        }
    }

    function getTotal(bytes _s) public view returns(uint256) {
        uint256 _a;
        uint256 _b;

        assembly {
            _b := mload(add(_s, 160))
            _b := mload(add(_s, 192))
        }

        // TODO: safemath
        return _a + _b;
    }

    function open(bytes _state, address _initiator) public view returns (bool) {
        require(msg.value > 0, 'Tried opening an ether agreement with 0 msg value');
        require(_initiator == getPartyA(_state), 'Party A does not mactch signature recovery');
        // ensure the amount sent to open channel matches the signed state balance
        require(getBalanceA(_state) == msg.value, 'msg value does not match partyA state balance');
        return true;
    }

    function join(bytes _state, address _responder) public view returns (bool) {
        // ensure the amount sent to join channel matches the signed state balance
        require(_responder == getPartyB(_state), 'Party B does not mactch signature recovery');
        // ensure the sender of funds is partyA.. not sure if this is a hard require
        require(getBalanceB(_state) == msg.value, 'msg value does not match partyB state balance');
        // Require bonded is the sum of balances in state
        require(getTotal(_state) == this.balance, 'Ether total deposited does not match state balance');
    }

    function update(bytes _state) public view returns (bool) {
        require(msg.value != 0);

        uint256 _balA = getBalanceA(_state);
        uint256 _balB = getBalanceB(_state);
        uint256 _total = getTotal(_state);

        require(this.balance + msg.value == _total);
    }

    function finalizeByzantine(bytes _state) public view returns (bool) {
        address _a = getPartyA(_state);
        address _b = getPartyB(_state);
        
        require(getTotal(_state) == this.balance, 'tried finalizing ether state that does not match bnded value');
        _a.transfer(getBalanceA(_state));
        _b.transfer(getBalanceB(_state));      
    }
}