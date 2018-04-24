pragma solidity ^0.4.23;

import "./LibInterpreterInterface.sol";

contract LibBidirectionalEther is LibInterpreterInterface {
    // State
    // [0-31] isClose flag
    // [32-63] address sender
    // [64-95] address receiver
    // [96-127] bond 
    // [128-159] balance of receiver

    function finalizeState(bytes _state) public returns (bool) {
        address _a = getPartyA(_state);
        address _b = getPartyB(_state);
        uint256 _balA = getBalanceA(_state);
        uint256 _balB = getBalanceB(_state);

        _a.transfer(_balA);
        _b.transfer(_balB);
    }

    function getPartyA(bytes _s) public constant returns(address _partyA) {
        assembly {
            _partyA := mload(add(_s, 96))
        }
    }

    function getPartyB(bytes _s) public constant returns(address _partyB) {
        assembly {
            _partyB := mload(add(_s, 96))
        }
    }

    function getBalanceA(bytes _s) public constant returns(uint256 _balanceA) {
        assembly {
            _balanceA := mload(add(_s, 160))
        }
    }

    function getBalanceB(bytes _s) public constant returns(uint256 _balanceB) {
        assembly {
            _balanceB := mload(add(_s, 192))
        }
    }

    function getTotal(bytes _s) public constant returns(uint256) {
        uint256 _a;
        uint256 _b;

        assembly {
            _b := mload(add(_s, 160))
            _b := mload(add(_s, 192))
        }

        // TODO: safemath
        return _a + _b;
    }
}