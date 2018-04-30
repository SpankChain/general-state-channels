pragma solidity ^0.4.23;

import "./ExtensionInterface.sol";
import "../token/HumanStandardToken.sol";

contract ERC20Extension is ExtensionInterface {
    // TODO: Update byte sequence
    function getTokenAddress(bytes _s) public view returns (address _token) {
        assembly {
            _token := mload(add(_s, 224))
        }
    }

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
        require(_initiator == getPartyA(_state), 'Party A does not mactch signature recovery');
        // get the token instance used to allow funds to msig
        HumanStandardToken _t = HumanStandardToken(getTokenAddress(_state));
        // ensure the amount sent to open channel matches the signed state balance
        require(_t.allowance(getPartyA(_state), this) == getBalanceA(_state), 'value does not match partyA state balance');
        // complete the tranfer of partyA approved tokens
        _t.transferFrom(getPartyA(_state), this, getBalanceA(_state));
        return true;
    }

    function join(bytes _state, address _responder) public view returns (bool) {
        // ensure the amount sent to join channel matches the signed state balance
        require(_responder == getPartyB(_state), 'Party B does not mactch signature recovery');
        // get the token instance used to allow funds to msig
        HumanStandardToken _t = HumanStandardToken(getTokenAddress(_state));

        // ensure the amount sent to open channel matches the signed state balance
        require(_t.allowance(getPartyB(_state), this) == getBalanceB(_state), 'value does not match partyA state balance');
        // complete the tranfer of partyA approved tokens
        _t.transferFrom(getPartyA(_state), this, getBalanceA(_state));

        // Require bonded is the sum of balances in state
        require(getTotal(_state) == _t.balanceOf(this), 'token total deposited does not match state balance');
    }

    function update(bytes _state) public view returns (bool) {
        // get the token instance used to allow funds to msig
        HumanStandardToken _t = HumanStandardToken(getTokenAddress(_state));

        if(_t.allowance(getPartyA(_state), this) > 0) {
            _t.transferFrom(getPartyA(_state), this, _t.allowance(getPartyA(_state), this));
        } else if (_t.allowance(getPartyA(_state), this) > 0) {
            _t.transferFrom(getPartyB(_state), this, _t.allowance(getPartyB(_state), this));
        }

        require(getTotal(_state) == _t.balanceOf(this), 'token total deposited does not match state balance');
    }

    function finalizeByzantine(bytes _state) public view returns (bool) {
        address _a = getPartyA(_state);
        address _b = getPartyB(_state);

        HumanStandardToken _t = HumanStandardToken(getTokenAddress(_state));
        require(getTotal(_state) == _t.balanceOf(this), 'tried finalizing ether state that does not match bnded value');

        _t.transfer(_a, getBalanceA(_state));
        _t.transfer(_b, getBalanceB(_state));
    }
}