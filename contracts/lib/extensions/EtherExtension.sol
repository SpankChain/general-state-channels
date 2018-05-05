pragma solidity ^0.4.23;

//import "./ExtensionInterface.sol";

library EtherExtension {

    function getPartyA(bytes _s) public pure returns(address _partyA) {
        assembly {
            _partyA := mload(add(_s, 96))
        }
    }

    function getPartyB(bytes _s) public pure returns(address _partyB) {
        assembly {
            _partyB := mload(add(_s, 128))
        }
    }

    function getBalanceA(bytes _s) public pure returns(uint256 _balanceA) {
        assembly {
            _balanceA := mload(add(_s, 224))
        }
    }

    function getBalanceB(bytes _s) public pure returns(uint256 _balanceB) {
        assembly {
            _balanceB := mload(add(_s, 256))
        }
    }

    function getTotal(bytes _s) public pure returns(uint256) {
        uint256 _a;
        uint256 _b;

        assembly {
            _b := mload(add(_s, 224))
            _b := mload(add(_s, 256))
        }

        // TODO: safemath
        return _a + _b;
    }

    function open(bytes _state) public {
        require(msg.value > 0, 'Tried opening an ether agreement with 0 msg value');
        //require(_initiator == getPartyA(_state), 'Party A does not mactch signature recovery');
        //ensure the amount sent to open channel matches the signed state balance
        require(getBalanceA(_state) == msg.value, 'msg value does not match partyA state balance');
    }

    function join(bytes _state) public {
        require(msg.value > 0, 'Tried joining an ether agreement with 0 msg value');
        // ensure the amount sent to join channel matches the signed state balance
        //require(_responder == getPartyB(_state), 'Party B does not mactch signature recovery');
        // ensure the sender of funds is partyA.. not sure if this is a hard require
        require(getBalanceB(_state) == msg.value, 'msg value does not match partyB state balance');
        // Require bonded is the sum of balances in state
        //require(getTotal(_state) == address(this).balance, 'Ether total deposited does not match state balance');
    }

    function update(bytes _state) public {
        require(msg.value != 0);

        //require(address(this).balance + msg.value == getTotal(_state));
    }

    function finalizeByzantine(bytes _state, address _metachannel) public {
        require(getTotal(_state) <= address(this).balance, 'tried finalizing ether state that does not match bnded value');
        address(_metachannel).transfer(getTotal(_state));     
    }

    function finalize(bytes _state) public returns (bool) {
        //require(getTotal(_state) == address(this).balance, 'tried finalizing ether state that does not match bnded value');
        getPartyA(_state).transfer(getBalanceA(_state));
        getPartyA(_state).transfer(getBalanceB(_state));  
    }
}