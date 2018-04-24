pragma solidity ^0.4.23;

import './ExtensionInterface.sol';

contract ExtensionInterface {

    function open(bytes _state) public view returns (bool);

    function join(bytes _state) public view returns (bool);

    function update(bytes _state) public view returns (bool);

    function finalize(bytes _state) public view returns (bool);

    function finalizeByzantine(bytes _state) public view returns (bool);

    //function update(address _b, uint256 _a) public returns (bool) {}
}