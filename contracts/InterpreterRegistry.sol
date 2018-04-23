pragma solidity ^0.4.23;

contract InterpreterRegistry {
    mapping(bytes32 => address) registry;

    event LibraryDeployed(address deployedAddress, bytes32 ID);

    function resolveAddress(bytes32 _ID) public view returns(address) {
        return registry[_ID];
    }

    // fix: remove _CTFBytes and pull the bytes from the state
    function setInterpreter(address _intLib, bytes32 _ID) public {
        bytes32 _CTFaddress = keccak256(_state);
        registry[_ID] = _intLib;
        ContractDeployed(_intLib, _ID);
    }
}