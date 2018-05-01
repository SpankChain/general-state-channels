pragma solidity ^0.4.23;

import "./LibInterpreterInterface.sol";
import "../token/HumanStandardToken.sol";

contract LibBidirectionalERC20 is LibInterpreterInterface {
    // State
    // [0-31] isClose flag
    // [32-63] address sender
    // [64-95] address receiver
    // [96-127] bond 
    // [128-159] balance of receiver

    // TODO: Update byte sequence
    function getTokenAddress(bytes _s) public pure returns (address _token) {
        assembly {
            _token := mload(add(_s, 224))
        }
    }

    function finalizeState(bytes _state) public returns (bool) {
        require(getTotal(_state) == getBalanceA(_state) + getBalanceB(_state));

        HumanStandardToken _t = HumanStandardToken(getTokenAddress(_state));
        require(getTotal(_state) == _t.balanceOf(this), 'tried finalizing token state that does not match bnded value');

        _t.transfer(getPartyA(_state), getBalanceA(_state));
        _t.transfer(getPartyB(_state), getBalanceB(_state));
    }

    function getPartyA(bytes _s) public pure returns(address _partyA) {
        assembly {
            _partyA := mload(add(_s, 96))
        }
    }

    function getPartyB(bytes _s) public pure returns(address _partyB) {
        assembly {
            _partyB := mload(add(_s, 96))
        }
    }

    function getBalanceA(bytes _s) public pure returns(uint256 _balanceA) {
        assembly {
            _balanceA := mload(add(_s, 160))
        }
    }

    function getBalanceB(bytes _s) public pure returns(uint256 _balanceB) {
        assembly {
            _balanceB := mload(add(_s, 192))
        }
    }

    function getTotal(bytes _s) public pure returns(uint256) {
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