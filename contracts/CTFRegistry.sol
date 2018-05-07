pragma solidity ^0.4.23;

contract CTFRegistry {
    mapping(bytes32 => address) registry;
    bytes public _code;
    uint public len;

    event ContractDeployed(address deployedAddress);

    function resolveAddress(bytes32 _CTFaddress) public view returns(address) {
        return registry[_CTFaddress];
    }

    // fix: remove _CTFBytes and pull the bytes from the state
    function deployCTF(bytes _state, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {
        bytes32 _CTFaddress = keccak256(_state);
        //bytes32 _CTFaddress = keccak256(_sigs);
        //bytes32 _CTFaddress = keccak256(_r[0], _s[0], _v[0], _r[1], _s[1], _v[1]);

        address a;
        address b;
        bytes memory c;
        
        (a, b) = _decodeAddresses(_state);
        (c) = _decodeContractCode(_state);

        address deployedAddress;
        assembly {
            deployedAddress := create(0, add(c, 0x20), mload(c))
            // invalidJumLabel no longer compiles in solc v0.4.12 and higher
            //jumpi(invalidJumpLabel, iszero(extcodesize(deployedAddress)))
        }

        for(uint i=0; i<2; i++) {
            address _signer = _getSig(_CTFaddress, _v[i], _r[i], _s[i]);
            if (_signer != a) require(_signer == b);
            if (_signer != b) require(_signer == a);
        }

        // or
        //address _partyA = _getSig(_state, _v[0], _r[0], _s[0]);
        //address _partyB = _getSig(_state, _v[1], _r[1], _s[1]);
        //require(a == partyA && b == partyB);
        
        registry[_CTFaddress] = deployedAddress;
        emit ContractDeployed(deployedAddress);
    }

    function _decodeAddresses(bytes _state) internal pure returns(address A, address B){
        // State
        // [32] address A
        // [64] address B
        // [96] Contract Length
        // [] Contract Codes

        assembly {
            A := mload(add(_state, 32))
            B := mload(add(_state, 64))
        }
    }

    function _decodeContractCode(bytes _state) internal pure returns(bytes){
        uint _length = _state.length;
        uint _newlength = _length - 96;
        bytes memory output = new bytes(_newlength);
        for (uint i = 96; i<_length; i++) {
          output[i-96] = _state[i];
        }
        return output;
    }

    function _getSig(bytes32 _h, uint8 _v, bytes32 _r, bytes32 _s) internal pure returns(address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";

        bytes32 prefixedHash = keccak256(prefix, _h);

        address a = ecrecover(prefixedHash, _v, _r, _s);

        //address a = ECRecovery.recover(prefixedHash, _s);

        return(a);
    }
}