pragma solidity ^0.4.23;

import "../../CTFRegistry.sol";

library LibBidirectionalEther {
    // State
    // [0-31] isClose flag

    function finalizeState(bytes _state) public {
        require(getTotal(_state) == getBalanceA(_state) + getBalanceB(_state));

        getPartyA(_state).transfer(getBalanceA(_state));
        getPartyB(_state).transfer(getBalanceB(_state));
    }

    function finalizeByzantine(bytes _state) public {
        CTFRegistry registry = CTFRegistry(getRegistry(_state));
        address _meta = registry.resolveAddress(getMetaAddress(_state));
        uint256 _total = getTotal(_state);

        require(getTotal(_state) <= address(this).balance, 'tried finalizing ether state that does not match bnded value');
        _meta.transfer(_total);   
    }

    function getMetaAddress(bytes _s) public pure returns(bytes32 _meta) {
        assembly {
            _meta := mload(add(_s, 224))
        }
    }

    function getRegistry(bytes _s) public pure returns(address _reg) {
        assembly {
            _reg := mload(add(_s, 256))
        }
    }

    function getPartyA(bytes _s) public pure returns(address _partyA) {
        assembly {
            _partyA := mload(add(_s, 288))
        }
    }

    function getPartyB(bytes _s) public pure returns(address _partyB) {
        assembly {
            _partyB := mload(add(_s, 320))
        }
    }

    function getBalanceA(bytes _s) public pure returns(uint256 _balanceA) {
        assembly {
            _balanceA := mload(add(_s, 352))
        }
    }

    function getBalanceB(bytes _s) public pure returns(uint256 _balanceB) {
        assembly {
            _balanceB := mload(add(_s, 384))
        }
    }

    function getTotal(bytes _s) public pure returns(uint256) {
        uint256 _a;
        uint256 _b;

        assembly {
            _a := mload(add(_s, 352))
            _b := mload(add(_s, 384))
        }

        // TODO: safemath
        return _a + _b;
    }
}