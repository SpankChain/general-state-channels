pragma solidity ^0.4.18;

import "./ExtensionInterface.sol";

contract EtherExtension is ExtensionInterface {

    uint256 public total = 0;

    address public partyA;
    address public partyB;
    uint256 public balanceA;
    uint256 public balanceB;

    bytes public state;

    function EtherExtension() {

    }

    function setState(bytes _s) {
          uint256 _balanceA;
          uint256 _balanceB;
          address _addressA;
          address _addressB;

          assembly {
              _addressA := mload(add(_s, 96))
              _addressB := mload(add(_s, 128))
              _balanceA := mload(add(_s, 160))
              _balanceB := mload(add(_s, 192))
          }

          partyA = _addressA;
          partyB = _addressB;
          balanceA = _balanceA;
          balanceB = _balanceB;
          total = _balanceA + _balanceB;

          state = _s;
    }

}