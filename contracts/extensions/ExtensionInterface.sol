pragma solidity ^0.4.18;

contract ExtensionInterface {
    bool public extension = true;

    /// @dev simply a boolean to indicate this is the contract we expect to be
    function isExtension() public view returns (bool){
      return extension;
    }

    function setState() {}
}