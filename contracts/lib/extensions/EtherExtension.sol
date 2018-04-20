pragma solidity ^0.4.18;

import "../../MultiSig.sol";

// TODO: Make these extensions libraries that take address inputs to read
// state stored on the msig contracts

library EtherExtension {

    // uint256 public total = 0;

    // address public partyA;
    // address public partyB;
    // uint256 public balanceA;
    // uint256 public balanceB;

    // bytes public state;

    function getPartyA(bytes _s) public constant returns(address _partyA) {
        //bytes _s = MultiSig(_msig).state();
        assembly {
            _partyA := mload(add(_s, 96))
        }
    }

    function getPartyB(bytes _s) public constant returns(address _partyB) {
        //bytes memory _s = MultiSig(_msig).state();
        assembly {
            _partyB := mload(add(_s, 96))
        }
    }

    function getBalanceA(bytes _s) public constant returns(uint256 _balanceA) {
        //bytes memory _s = MultiSig(_msig).state();
        assembly {
            _balanceA := mload(add(_s, 160))
        }
    }

    function getBalanceB(bytes _s) public constant returns(uint256 _balanceB) {
        //bytes memory _s = MultiSig(_msig).state();
        assembly {
            _balanceB := mload(add(_s, 192))
        }
    }

    function getTotal(bytes _s) public constant returns(uint256) {
        //bytes memory _s = MultiSig(_msig).state();
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