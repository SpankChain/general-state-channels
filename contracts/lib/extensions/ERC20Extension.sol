pragma solidity ^0.4.23;

import "./ExtensionInterface.sol";

contract ERC20Extension is ExtensionInterface {
    function open(bytes _state) public view returns (bool) {}

    function join(bytes _state) public view returns (bool) {}

    function update(bytes _state) public view returns (bool) {}
}