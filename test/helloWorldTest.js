// 'use strict'

// const utils = require('./helpers/utils')

// const ChannelManager = artifacts.require("./ChannelManager.sol")
// const Judge = artifacts.require("./JudgeHelloWorld.sol")
// const Interpreter = artifacts.require("./InterpretHelloWorld.sol")

// let cm
// let jg
// let int

// let event_args

// contract('Hello World Channel', function(accounts) {
//   it("General State Channel Testing", async function() {
//     cm = await ChannelManager.new()
//     jg = await Judge.new()
//     int = await Interpreter.new()

//     var msg = '0x01';
//     var hmsg = web3.sha3(msg, {encoding: 'hex'})
//     var sig1 = await web3.eth.sign(accounts[0], hmsg)

//     let res = await cm.openChannel(accounts[1], web3.toWei(2, 'ether'), 1337, int.address, jg.address, msg, sig1, {from: accounts[0], value: web3.toWei(2, 'ether')})
//     let numChan = await cm.numChannels()

//     event_args = res.logs[0].args

//     let channelId = event_args.channelId
//     console.log('Channels created: ' + numChan.toNumber() + ' channelId: ' + channelId)

//     var sig2 = await web3.eth.sign(accounts[1], hmsg)

//     await cm.joinChannel(channelId, msg, sig1, sig2, {from: accounts[1], value: web3.toWei(2, 'ether')})

//     let open = await cm.getChannel(channelId)
//     console.log('Channel joined, open: ' + open[8][0])

//     // State encoding

//     // Rounds will be played that builf the word "hello"
//     // The first person will sign state containing "h"
//     // followed by the second account recieving and checking the letter
//     // If the letter is not in "hello" then they may present the invalid state
//     // If valid the second will sign "h". At this point state is agreed and may be checkpointed
//     // Account 2 will then concat "e" transforming state to "he" and send this to account1
//     // repeat until "hello" is signed by both parties and close the state
//     // there is no wager so the interpreter should just return the bond

//     // we build the first 32 byte word with a sentinel value indicating the party is 
//     // interested in closing this channel

//     // ----------- valid final state -------------- //
//     var sentinel = padBytes32(web3.toHex(1))
//     var sequence = padBytes32(web3.toHex(1))

//     var h = padBytes32(web3.toHex('h'))
//     var e = padBytes32(web3.toHex('e'))
//     var l = padBytes32(web3.toHex('l'))
//     var o = padBytes32(web3.toHex('o'))

//     console.log('Sequence number: ' + sequence)

//     msg = sentinel + 
//               sequence.substr(2, sequence.length) + 
//               h.substr(2, h.length) + 
//               e.substr(2, e.length) + 
//               l.substr(2, l.length) + 
//               l.substr(2, l.length) +
//               o.substr(2, o.length)

//     console.log('State input: ' + msg)

//     // -------------------------------------------- //

//     // let msgArr = [msg]
//     // msgArr.push(padBytes32(web3.toHex('deadbeef')))
//     // console.log(msgArr)

//     // Hashing and signature
//     hmsg = web3.sha3(msg, {encoding: 'hex'})
//     console.log('hashed msg: ' + hmsg)

//     sig1 = await web3.eth.sign(accounts[0], hmsg)
//     // we slice the sig in solidity now to reduce call depth 
//     // var r = sig1.substr(0,66)
//     // var s = "0x" + sig1.substr(66,64)
//     // var v = 28

//     await cm.exerciseJudge(channelId, 'run(bytes)', sig1, msg)

//     sig2 = await web3.eth.sign(accounts[1], hmsg)
//     // var r2 = sig2.substr(0, 66)
//     // var s2 = "0x" + sig2.substr(66, 64)
//     // var v2 = 27

//     await cm.closeChannel(channelId, msg, sig1, sig2)

//     open = await cm.getChannel(channelId)

//     console.log('Channel closed by two party signature on close sentinel')

//     console.log('Signing address: ' + accounts[0])

//     let load = await jg.temp()
//     console.log('assembly data stored: ' + load)

//     let _seq = await jg.s()
//     console.log('recovered sequence num: ' + _seq)

//     console.log('Judge resolution: ' + open[8][2])

//     // build an invalid state, signed by one of the parties. Excersize the judge so that it
//     // may fail and set the violator and state of violation. Then use the interpreter proxy call
//     // to resolve the action of sending the violators bond to the challenger.

//     console.log('\n')
//     console.log('Starting game...')
//     // Initial State

//     sentinel = padBytes32(web3.toHex(0))
//     sequence = padBytes32(web3.toHex(1))

//     h = padBytes32(web3.toHex('h'))

//     msg = sentinel + 
//               sequence.substr(2, sequence.length) + 
//               h.substr(2, h.length)

//     hmsg = web3.sha3(msg, {encoding: 'hex'})
//     console.log('hashed msg: ' + hmsg)

//     sig1 = await web3.eth.sign(accounts[0], hmsg)
//     //console.log('State signature: ' + sig1)

//     console.log('\nState_0: ' + msg)
//     // Open new Channel

//     res = await cm.openChannel(accounts[1], web3.toWei(2, 'ether'), 1337, int.address, jg.address, msg, sig1, {from: accounts[0], value: web3.toWei(2, 'ether')})
//     numChan = await cm.numChannels()

//     event_args = res.logs[0].args

//     channelId = event_args.channelId
//     console.log('Channels created: ' + numChan.toNumber() + ' channelId: ' + channelId)

//     console.log('{Simulated network send of channelId and state}')
//     console.log('{Player 2 validating initial state, signing, and joining channel}\n')

//     sig2 = await web3.eth.sign(accounts[1], hmsg)

//     await cm.joinChannel(channelId, msg, sig1, sig2, {from: accounts[1], value: web3.toWei(2, 'ether')})

//     open = await cm.getChannel(channelId)
//     console.log('Channel joined, open: ' + open[8][0])



//     // State 2

//     console.log('Starting game...\n')
//     console.log('Player 2 assembling state_1 _he_')
//     // Initial State

//     sentinel = padBytes32(web3.toHex(0))
//     sequence = padBytes32(web3.toHex(2))

//     msg = sentinel + 
//               sequence.substr(2, sequence.length) + 
//               h.substr(2, h.length) +
//               e.substr(2, e.length)

//     console.log('State_1: ' + msg)

//     hmsg = web3.sha3(msg, {encoding: 'hex'})
//     console.log('hashed msg: ' + hmsg)

//     sig2 = await web3.eth.sign(accounts[1], hmsg)
//     //console.log('State signature: ' + sig2)

//     console.log('{Simulated network send of player 2 State_1}')
//     console.log('{Player 1 validating State_1, and signing}\n')

//     sig1 = await web3.eth.sign(accounts[0], hmsg)


//     //console.log('State signature: ' + sig1)
//     // State 3

//     console.log('Player 1 assembling state_2 _hel_')
//     console.log('Player also signals to checkpoint this state transitition')
//     // Initial State

//     sentinel = padBytes32(web3.toHex(0))
//     sequence = padBytes32(web3.toHex(3))

//     msg = sentinel + 
//               sequence.substr(2, sequence.length) + 
//               h.substr(2, h.length) +
//               e.substr(2, e.length) +
//               l.substr(2, l.length)

//     console.log('State_2: ' + msg)

//     hmsg = web3.sha3(msg, {encoding: 'hex'})
//     console.log('hashed msg: ' + hmsg)

//     sig1 = await web3.eth.sign(accounts[0], hmsg)
//     //console.log('State signature: ' + sig2)

//     console.log('{Simulated network send of player 1 State_2}')
//     console.log('{Player 2 validating State_2, and signing with agreement to checkpoint}\n')

//     sig2 = await web3.eth.sign(accounts[1], hmsg)

//     await cm.checkpointState(channelId, msg, sig1, sig2, sequence)
//     console.log('State checkpointed\n')


//     // State 4

//     console.log('Player 2 incorrectly assembling state_3 _help_')
//     // Initial State

//     sentinel = padBytes32(web3.toHex(0))
//     sequence = padBytes32(web3.toHex(4))

//     var p = padBytes32(web3.toHex('p'))

//     msg = sentinel + 
//               sequence.substr(2, sequence.length) + 
//               h.substr(2, h.length) +
//               e.substr(2, e.length) +
//               l.substr(2, l.length) +
//               p.substr(2, p.length)

//     console.log('State_3: ' + msg)

//     hmsg = web3.sha3(msg, {encoding: 'hex'})
//     console.log('hashed msg: ' + hmsg)

//     sig2 = await web3.eth.sign(accounts[1], hmsg)
//     //console.log('State signature: ' + sig2)

//     console.log('{Simulated network send of player 2 State_3}')
//     console.log('{Player 2 validating State_2, and catches an error localy}')
//     console.log('Closing channel with judge')

//     await cm.exerciseJudge(channelId, 'run(bytes)', sig2, msg)
//     open = await cm.getChannel(channelId)
//     console.log('Judge resolution: ' + open[8][2])

//     await cm.closeWithChallenge(channelId)
//     open = await cm.getChannel(channelId)
//     console.log('Channel status: ' + open[8][0])

//     // hello world game question: State grows in this game so if the word 
//     // was longer than "hello world" the judge would not be able to verify state
//     // general state channels still needs a clever judge like truebit or clever
//     // handling of the state representation. 
//   })

// })


// function padBytes32(data){
//   let l = 66-data.length
//   let x = data.substr(2, data.length)

//   for(var i=0; i<l; i++) {
//     x = 0 + x
//   }
//   return '0x' + x
// }

// function rightPadBytes32(data){
//   let l = 66-data.length

//   for(var i=0; i<l; i++) {
//     data+=0
//   }
//   return data
// }