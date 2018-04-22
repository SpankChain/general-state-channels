pragma solidity ^0.4.23;

import "../../MultiSig.sol";

library EtherExtension {

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