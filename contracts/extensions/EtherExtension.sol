pragma solidity ^0.4.18;

import "./ExtensionInterface.sol";

contract EtherExtension is ExtensionInterface {

    uint256 public total = 0;

    uint256 public balanceA;
    uint256 public balanceB;

    bytes public state;

    function EtherExtension() {

    }

    function setState(bytes _s) {
          uint256 _balanceA;
          uint256 _balanceB;
          assembly {
              _balanceA := mload(add(_s, 160))
              _balanceB := mload(add(_s, 192))
          }

          balanceA = _balanceA;
          balanceB = _balanceB;
          total = _balanceA + _balanceB;

          state = _s;
    }

}