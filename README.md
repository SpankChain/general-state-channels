# general-state-channels

# WIP!

A POC combining insights derived from L4, Lightning, Eth, Raiden, and Spankchain research. This system abstracts the idea of a state channel by allowing two participants to agree about the value of their bond in the channel. As long as both parties can come to consensus on this top level balance, then many iterations of more complex logic may be played out that ultimately settles to this balance. As most state updates in cryptocurrency applications result in balance or ownership updates, this system could be useful. Only in cases that parties can't agree to the outcome of a complex state transition must they deploy the logic to settle the top level balance. 

## Table of Contents:

- Supported Systems
  - Single Direction Paywall Channel
  - Bi-directional Payment Channel
  - Crypto Kitties Battle Channel
- Background Information
- Bond Manager API
  - openChannel
  - joinChannel
  - closeChannel
- Interpreter API
  - checkpointState
  - startSettleState
  - challengeSettleState
  - closeWithTimeout
- Interpreter Interface
- Roadmap
- Contributing

## Background Information:

TODO Outline Layer 2 solutions, L4 research, Spankchain research

### Definitions:

Bond Manager: The contract responsible for opening and closing channels. It holds the balances decided in final states of closed sub-channels.

Channel Registery: TODO

Special Payment Channel: TODO

Sub-channel: TODO

Interpreters: These are the contracts that hold the logic responsible for assembling state bytes into meaningful representations. ie constructing the balances in a payment channel or determining the winner of a game. They are counterfactually instantiated and provide judgement on valid state transitions.

### Overview:

This POC is comprised of one on-chain special multisig contract and a system of counterfactually instantiated interepreter contracts that may never be deployed on-chain as long as the channel participants can agree on state transitions. Multiple state channels/games may be played on the same channel bond. Closing the channel will only require reconstructing some final agreed upon state on the bond and not the intermediary final states of any other game that was not challenged and closed without channel consensus. This is like nesting many channels into one bonded channel.

The registry contract builds a reference for agreed upon byte code for interpreters that may be counterfacutally deployed when necessary. Before opening a channel on the bond manager contract, both parties must compile the byte code of the SPC and sign a state containing a message that both parties agree to use this set of rules in case of settlement. The SPC has logic to handle multiple sub-channels attached to its state. When a new channel is to be loaded off-chain, the balances are correctly updated in the state transition to seed the new channel and both parties sign this transition.

To open a channel the client must assemble the initial state (more specs on this to come) with the participants they plan to interact with. They sign this state and pass it to the `openChannel()` function. To join the channel, the participants in the initial state must sign the state and provide this signature to the `joinChannel()` function in the manager. Once both parties in the state have joined the channel it is flagged open and any settlements or closing may begin.

Closing a channel may happen in two ways, fast with consensus or slow with byzantine faults with and a settlement period. To fast close, the state must be signed with an initial sentinel value in its sequence of bytes that represents the participants will to close to the channel. If all parties have signed a state transition with this flag then the state may be acted upon immediately by the manager and interpreter contract to settle any balances, wagers, or state outcome. If this flag is not present and the participants can't agree on the final state, the settlement game starts and accepts the highest sequence signed state. This logic holds true for the SPC and any attached sub-channels. Only the SPC and the sub-channel in question need to be deployed to the main chain in the event of dispute in any given sub-channel.


## Bond Manager API:

The bond manager currently exposes the following to clients for opening, joining, and closing channels.

It takes two contructor arguments:

```
- bytes32 Counterfactual SPC address
- address Registry Address
```

### openChannel

```bondManager.openChannel(bond, settlementPeriod, interpreter, initialState, signature, {from: participantAddress, value: bond})```

Called by the initiator of a channel.

Parameters:

- bytes initialState: bytes array of the initial state as defined by each intepreter application
signature inputes
- uint8 v
- bytes32 r
- bytes32 s

Example

### joinChannel

```bondManager.joinChannel(signature, {from: participantAddress, value: bond})```

Called by parties in the initial state to join the channel

Parameters:

signature inputs
- uint8 v
- bytes32 r
- bytes32 s


### closeChannel

```bondManager.closeChannel(state, signatures[])```

quick close called by anyone with state that has a flag to close and all participant signatures

Parameters:
- bytes state: the checkpoint state 
signature inputs array
- uint8[] v
- bytes32[] r
- bytes32[] s

## Interpreter API:

### startSettleState

```interpreter(channelID, state, signatures)```

called by anyone with valid signatures on state that does not have close flag

Parameters:
- bytes32 channelID: The channel id that references the channel in the manager contract
- bytes state: the checkpoint state 
signature inputs array
- uint8[] v
- bytes32[] r
- bytes32[] s

### challengeSettleState

```interpreter.challengeSettleState(channelID, state, signatures)```

called by anyone within the settlement period that has a higher sequence numbered state signed by all parties

Parameters:
- bytes32 channelID: The channel id that references the channel in the manager contract
- bytes state: the checkpoint state 
signature inputs array
- uint8[] v
- bytes32[] r
- bytes32[] s

### closeWithTimeout

```interpreter.closeWithTimeout(channelID)```

called by anyone after the settlement period has ended

Parameters:
- bytes32 channelID: The channel id that references the channel in the manager contract

## Interpreter Interface

All interpreter contracts must implement the following interface. Interpreters are predefined contracts that return boolean results that the channel manager needs to open, settle, and close. TODO create a guideline on how developers may structure custom interpreter contracts for their applications that will work with the channel manager.

### isClose

```function isClose(bytes _data) public returns (bool);```

### isSequenceHigher

```function isSequenceHigher(bytes _data1, bytes _data2) public returns (bool);```

### isAddressInState

```function isAddressInState(address _queryAddress) public returns (bool);```

### hasAllSigs

```function hasAllSigs(address[] recoveredAddresses) public returns (bool);```

### quickClose

```function quickClose(bytes _data) public returns (bool);```


## Future Work / Roadmap

TODO

## Contribution

TODO

