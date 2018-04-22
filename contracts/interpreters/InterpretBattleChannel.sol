pragma solidity ^0.4.23;

import "./InterpreterInterface.sol";
import "../ChannelRegistry.sol";

contract InterpretBattleChannel is InterpreterInterface {
    // State
    // [0-31] isClose flag
    // [32-63] sequence number
    // [64-95] wager ether
    // [96-127] number of cats in channel
    // battle cat 1
    // [] owner
    // [] kitty id
    // [] base power
    // [] wins
    // [] losses
    // [] level
    // [] cool down
    // [] HP hit point
    // [] DP defense points
    // [] AP attack points
    // [] A1 attack action
    // [] A2 attack action
    // [] A3 attack action
    // [] chosen attack
    // battle cat 2
    // ...

    // Attack Lookup table
    // [0] = Attack1 damage
    // [1] = Attack2 damage
    // [2] = Attack3 damage
    // ...

    uint8[12] attacks = [12, 24, 4, 16, 32, 2, 20, 8, 40, 36, 14, 28];

    struct BattleKitty {
        uint128 basePower;
        // uint64 wins;
        // uint64 loses;
        // uint8 level;
        uint64 coolDown;
        uint128[3] baseStats;
        uint8[3] attacks;
        uint8 chosenAttack;
        address owner;
        uint256 balance;
        bool inState;
        bool joined;
    }

    mapping(address => BattleKitty) public battleKitties;
    // ---------------

    bool allJoin = false;
    uint256 public numJoined = 0;
    uint256 public numParties = 0;

    address[] partyArr;
    
    bytes32 public CTFMetaAddress;
    ChannelRegistry public registry;

    modifier onlyMeta() {
        require(msg.sender == registry.resolveAddress(CTFMetaAddress));
        _;
    }

    function InterpretBattleChannel(bytes32 _CTFMetaAddress, address _registry) {
        CTFMetaAddress = _CTFMetaAddress;
        registry = ChannelRegistry(_registry);
    }

    // TODO: Restrict to modifier
    function initState(bytes _data) onlyMeta returns (bool) {
        _decodeState(_data);
        return true;
    }

    function isClose(bytes _data) public returns(bool) {
        uint isClosed;

        assembly {
            isClosed := mload(add(_data, 32))
        }

        require(isClosed == 1);
        return true;
    }

    function isSequenceHigher(bytes _data) public returns (bool) {
        uint isHigher1;
        uint isHigher2;

        bytes memory _s = state;

        assembly {
            isHigher1 := mload(add(_s, 64))
            isHigher2 := mload(add(_data, 64))
        }

        require(isHigher1 < isHigher2);
        return true;
    }


    function challenge(address _violator, bytes _state) public {
        // todo
        // require(1==2);
    }

    function getExtType() public returns(uint8 _ext) {
      bytes memory _state = state;
        assembly {
            _ext := mload(add(_state, 96))
        }
    }


    function _decodeState(bytes state) internal {
        uint numKitties;
        address _tempA;
        uint _id;
        uint128 _basePower;
        //uint64 _wins;
        //uint64 _losses;
        //uint8 _level;
        uint64 _coolDown;
        uint128 _hp;
        uint128 _dp;
        uint128 _ap;
        uint8 _a1;
        uint8 _a2;
        uint8 _a3;
        uint8 _chosenAttack;

        assembly {
            numKitties := mload(add(state, 128))
        }

        numParties = numKitties;

        for(uint i=0; i<numKitties; i++){
            uint pos = 0;

            pos = 160+(11*32*i);

            assembly {
                _tempA:= mload(add(state, pos))
                _id :=mload(add(state, add(pos,32)))
                _basePower :=mload(add(state, add(pos,64)))
                //_wins :=mload(add(state, add(pos,96)))
                //_losses :=mload(add(state, add(pos,128)))
                //_level :=mload(add(state, add(pos,96)))
                _coolDown :=mload(add(state, add(pos,96)))
                _hp :=mload(add(state, add(pos,128)))
                _dp :=mload(add(state, add(pos,160)))
                _ap :=mload(add(state, add(pos,192)))
                _a1 :=mload(add(state, add(pos,224)))
                _a2 :=mload(add(state, add(pos,256)))
                _a3 :=mload(add(state, add(pos,288)))
                _chosenAttack := mload(add(state, add(pos, 320)))
            }

            if(battleKitties[_tempA].owner == 0x0) {
                partyArr.push(_tempA);
            }

            battleKitties[_tempA].owner = _tempA;
            battleKitties[_tempA].inState = true;
            battleKitties[_tempA].basePower = _basePower;
            battleKitties[_tempA].baseStats[0] = _hp;
            battleKitties[_tempA].baseStats[1] = _dp;
            battleKitties[_tempA].baseStats[2] = _ap;
            battleKitties[_tempA].attacks[0] = _a1;
            battleKitties[_tempA].attacks[1] = _a2;
            battleKitties[_tempA].attacks[2] = _a3;
            battleKitties[_tempA].chosenAttack = _chosenAttack;
        }
    }

}