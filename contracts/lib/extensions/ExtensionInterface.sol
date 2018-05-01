pragma solidity ^0.4.23;

import './ExtensionInterface.sol';

contract ExtensionInterface {

    function open(bytes _state, address _initiator) public returns (bool);

    function join(bytes _state, address _responder) public returns (bool);

    function update(bytes _state) public returns (bool);

    function finalize(bytes _state) public returns (bool);

    function finalizeByzantine(bytes _state) public returns (bool);

    //function update(address _b, uint256 _a) public returns (bool) {}
}