pragma solidity ^0.4.18;

contract ChannelRegistry {
    mapping(bytes32 => address) registry;
    bytes32 public ctfaddy;

    event ContractDeployed(address deployedAddress);

    function resolveAddress(bytes32 _CTFaddress) public view returns(address) {
        return registry[_CTFaddress];
    }

    function deployCTF(bytes _CTFbytes, bytes _state, uint8[2] _v, bytes32[2] _r, bytes32[2] _s) public {
        address deployedAddress;
        assembly {
            deployedAddress := create(0, add(_CTFbytes, 0x20), mload(_CTFbytes))
            // invalidJumLabel no longer compiles in solc v0.4.12 and higher
            //jumpi(invalidJumpLabel, iszero(extcodesize(deployedAddress)))
        }

        bytes32 _CTFaddress = keccak256(_state);
        //bytes32 _CTFaddress = keccak256(_sigs);
        //bytes32 _CTFaddress = keccak256(_r[0], _s[0], _v[0], _r[1], _s[1], _v[1]);

        var (a, b) = _decodeState(_state);
        for(uint i=2; i<2; i++) {
            address _signer = _getSig(_state, _v[i], _r[i], _s[i]);
            if (_signer != a) require(_signer == b);
        }

        ctfaddy = _CTFaddress;

        registry[_CTFaddress] = deployedAddress;
        ContractDeployed(deployedAddress);
    }

    function _decodeState(bytes _state) internal returns(address A, address B){
        assembly {
            A := mload(add(_state, 32))
            B := mload(add(_state, 64))
        }
    }

    function _getSig(bytes _d, uint8 _v, bytes32 _r, bytes32 _s) internal pure returns(address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 h = keccak256(_d);

        bytes32 prefixedHash = keccak256(prefix, h);

        address a = ecrecover(prefixedHash, _v, _r, _s);

        //address a = ECRecovery.recover(prefixedHash, _s);

        return(a);
    }
}