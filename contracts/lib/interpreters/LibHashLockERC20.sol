pragma solidity ^0.4.23;

import "../token/HumanStandardToken.sol";

library LibHashLockERC20 {
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

    function finalizeState(bytes _s) returns (bool) {
        // Just dont send here, force the balace to be withdrawn from
        // a special function on the metachannel
        return true;
    }

    function updateHTLCtoken(address _b, uint256 _a, address _token) public returns (bool) {
        // send token balance
        HumanStandardToken specificToken = HumanStandardToken(_token);
        require(specificToken.balanceOf(this) >= _a);
        specificToken.transfer(_b, _a);
    }
}