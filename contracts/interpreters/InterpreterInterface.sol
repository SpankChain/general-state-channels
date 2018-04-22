pragma solidity ^0.4.23;

contract InterpreterInterface {
    bool public interpreter = true;
    uint public isClosed = 0; // 1: Channel open 1: Channel closed 0
    bytes32 public statehash;
    bytes public state; // The state read by extensions on the msig

    /// @dev simply a boolean to indicate this is the contract we expect to be
    function isInterpreter() public view returns (bool){
      return interpreter;
    }

    function isClose(bytes _data) public returns (bool);

    function reconcileState() public returns (bool);

    function isSequenceHigher(bytes _data) public returns (bool);

    function initState(bytes _state) returns (bool);

    function finalizeState() returns (bool);

    function getExtType() returns (uint8);

    function () public payable {

    }

}