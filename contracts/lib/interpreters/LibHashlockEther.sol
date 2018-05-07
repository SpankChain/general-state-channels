pragma solidity ^0.4.23;

library LibHashlockEther {
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

    function finalizeState(bytes _s) public returns (bool) {
        // Just dont send here, force the balace to be withdrawn from
        // a special function on the metachannel
        return true;
    }

    function update(address _b, uint256 _a) public returns (bool) {
        // send ether balance
        _b.transfer(_a);
    }
}