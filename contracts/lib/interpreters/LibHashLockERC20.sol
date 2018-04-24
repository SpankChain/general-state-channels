pragma solidity ^0.4.23;

import "./LibInterpreterInterface.sol";
// TODO get token interface

contract LibHashLockERC20 is LibInterpreterInterface {
    // State
    // [0-31] isClose flag
    // [32-63] sequence
    // [64-95] timeout
    // [96-127] sender
    // [128-159] receiver
    // [160-191] bond 
    // [192-223] balance A
    // [224-255] balance B
    // [256-287] lockTXroot
    // [288-319] metachannelAddress

    address public specificToken;

    function LibHTLCtoken(address _token) {
        specificToken = _token;
    }

    function finalizeState(bytes _s) returns (bool) {
        // Just dont send here, force the balace to be withdrawn from
        // a special function on the metachannel
    }

    function update(address _b, uint256 _a) returns (bool) {
        // send ether balance
        //specificToken.transfer(_b, _a);
    }
}