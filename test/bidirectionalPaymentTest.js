// 'use strict'

// const utils = require('./helpers/utils')

// const ChannelManager = artifacts.require("./ChannelManager.sol")
// const Interpreter = artifacts.require("./InterpretBidirectional.sol")

// let cm
// let int
// let sigV = []
// let sigR = []
// let sigS = []

// let event_args

// contract('Bi-direction payment channel', function(accounts) {
//   it("Payment Channel", async function() {
//     cm = await ChannelManager.new()
//     int = await Interpreter.new()


//     // State encoding
//     // We simply replace the sequence number with the receiver balance
//     // Account 0 is the bonded hub making signed payments
//     // Account 1 is the receiver of payments, they may sign and close any payment

//     // [isClose]
//     // [sequenceNum]
//     // [addressA]
//     // [addressB]
//     // [balanceA]
//     // [balanceB]

//     // ----------- valid state -------------- //
//     var msg

//     msg = generateState(0, 0, accounts[0], accounts[1], 10, 5)


//     // Hashing and signature
//     var hmsg = web3.sha3(msg, {encoding: 'hex'})
//     console.log('hashed msg: ' + hmsg)

//     var sig1 = await web3.eth.sign(accounts[0], hmsg)
//     var r = sig1.substr(0,66)
//     var s = "0x" + sig1.substr(66,64)
//     var v = 27

//     let res = await cm.openChannel(web3.toWei(5, 'ether'), 1337, int.address, msg, v, r, s, {from: accounts[0], value: web3.toWei(10, 'ether')})
//     let numChan = await cm.numChannels()

//     event_args = res.logs[0].args

//     let channelId = event_args.channelId
//     console.log('Channels created: ' + numChan.toNumber() + ' channelId: ' + channelId)
//     console.log('{Simulated network send from A to receiver of initial state}')
    
//     var sig2 = await web3.eth.sign(accounts[1], hmsg)
//     var r2 = sig2.substr(0,66)
//     var s2 = "0x" + sig2.substr(66,64)
//     var v2 = 28

//     await cm.joinChannel(channelId, msg, v2, r2, s2, {from: accounts[1], value: web3.toWei(5, 'ether')})

//     let open = await cm.getChannel(channelId)
//     console.log('Channel joined, open: ' + open[5][0])

//     //await cm.exerciseJudge(channelId, 'run(bytes)', v, r, s, msg)

//     open = await cm.getChannel(channelId)



//     let _seq = await int.b1()
//     let _addr = await int.b2()
//     let _bond = await int.bond()
//     console.log('recovered balanceA: ' + _seq)
//     console.log('recovered balanceB: ' + _addr)
//     console.log('amount eth on Interpreter: ' + _bond)
//     console.log('Judge resolution: ' + open[5][2])

//     console.log('\n')
//     console.log('Starting payments...')

//     // State 1
//     msg = generateState(0, 1, accounts[0], accounts[1], 9, 6)

//     hmsg = web3.sha3(msg, {encoding: 'hex'})

//     sig1 = await web3.eth.sign(accounts[0], hmsg)
//     r = sig1.substr(0,66)
//     s = "0x" + sig1.substr(66,64)
//     v = 27

//     console.log('\nState_1: ' + msg)


//     console.log('{Simulated network send of payment state:action 1:add B, 1:sub A}')
//     console.log('{Receiver validating state, and signing}\n')

//     var sig2 = await web3.eth.sign(accounts[1], hmsg)
//     r2 = sig2.substr(0,66)
//     s2 = "0x" + sig2.substr(66,64)
//     v2 = 27

//     // State 2

//     msg = generateState(1, 2, accounts[0], accounts[1], 11, 4)

//     hmsg = web3.sha3(msg, {encoding: 'hex'})

//     sig1 = await web3.eth.sign(accounts[0], hmsg)
//     r = sig1.substr(0,66)
//     s = "0x" + sig1.substr(66,64)
//     v = 27

//     console.log('\nState_2: ' + msg)


//     console.log('{Simulated network send of payment state:action 2:add A, 2:sub B}')
//     console.log('{Receiver validating state, and signing}\n')

//     console.log('Closing Channel...')

//     // await cm.exerciseJudge(channelId, 'run(bytes)', sig1, msg)

//     sig2 = await web3.eth.sign(accounts[1], hmsg)
//     r2 = sig2.substr(0,66)
//     s2 = "0x" + sig2.substr(66,64)
//     v2 = 27

//     console.log('balance sender before close: ' + web3.fromWei(web3.eth.getBalance(accounts[0])))
//     console.log('balance receiver before close: ' + web3.fromWei(web3.eth.getBalance(accounts[1])))

//     sigV = []
//     sigR = []
//     sigS = []

//     sigV.push(v)
//     sigV.push(v2)
//     sigR.push(r)
//     sigR.push(r2)
//     sigS.push(s)
//     sigS.push(s2)

//     console.log(sigV)
//     console.log(sigR)


//     await cm.closeChannel(channelId, msg, sigV, sigR, sigS)

//     console.log('balance sender after close: ' + web3.fromWei(web3.eth.getBalance(accounts[0])))
//     console.log('balance receiver after close: ' + web3.fromWei(web3.eth.getBalance(accounts[1])) + '\n')

//     let _addrA = await int.a()
//     let _addrB = await int.b()
//     //let _tempSigs1 = await cm._tempSigs(0)
//     // let _tempSigs2 = await cm._tempSigs(1)
//     // let _length = await cm._length()
//     // console.log('recovered length: ' + _length)
//     // console.log('recovered sig addresses: ' + _tempSigs1)
//     // console.log('recovered sig addresses: ' + _tempSigs2)
//     console.log('recovered addressA: ' + _addrA)
//     console.log('recovered addressB: ' + _addrB)
//     console.log('account[0]: ' + accounts[0])
//     console.log('account[1]: ' + accounts[1])


//     // Invalid state challenge case

//     // ----------- valid state -------------- //
//     msg = generateState(0, 0, accounts[0], accounts[1], 10, 5)

//     console.log('State input: ' + msg)


//     // Hashing and signature
//     hmsg = web3.sha3(msg, {encoding: 'hex'})
//     console.log('hashed msg: ' + hmsg)

//     sig1 = await web3.eth.sign(accounts[0], hmsg)
//     r = sig1.substr(0,66)
//     s = "0x" + sig1.substr(66,64)
//     v = 27

//     res = await cm.openChannel(web3.toWei(5, 'ether'), 0, int.address, msg, v, r, s, {from: accounts[0], value: web3.toWei(10, 'ether')})
//     numChan = await cm.numChannels()

//     event_args = res.logs[0].args

//     channelId = event_args.channelId
//     console.log('Channels created: ' + numChan.toNumber() + ' channelId: ' + channelId)
//     console.log('{Simulated network send from hub to receiver of initial state}')
    
//     sig2 = await web3.eth.sign(accounts[1], hmsg)
//     r2 = sig2.substr(0,66)
//     s2 = "0x" + sig2.substr(66,64)
//     v2 = 28

//     await cm.joinChannel(channelId, msg, v2, r2, s2, {from: accounts[1], value: web3.toWei(5, 'ether')})

//     open = await cm.getChannel(channelId)
//     console.log('Channel joined, open: ' + open[5][0])

//     // invalid state
//     msg = generateState(0, 1, accounts[0], accounts[1], 100, 5)

//     console.log('State input: ' + msg)


//     // Hashing and signature
//     hmsg = web3.sha3(msg, {encoding: 'hex'})
//     console.log('hashed msg: ' + hmsg)

//     sig1 = await web3.eth.sign(accounts[0], hmsg)
//     r = sig1.substr(0,66)
//     s = "0x" + sig1.substr(66,64)
//     v = 27

//     console.log('{Simulated network send from hub to receiver of invalid state}')
//     console.log('{requesting a valid state or starting settlement period}\n')

//     console.log('Party B excersizing judge to begin settlement')

//     //await cm.exerciseJudge(channelId, 'run(bytes)', sig1, msg)

//     //await cm.closeWithChallenge(channelId)

//     await cm.start

//     open = await cm.getChannel(channelId)



//     _seq = await int.b1()
//     _addr = await int.b2()
//     console.log('recovered balance A: ' + _seq)
//     console.log('recovered balance B: ' + _addr)
//     console.log('account[0]: ' + accounts[1])
//     console.log('Judge resolution: ' + open[5][2])

//     console.log('\n')

//     console.log('Party B starting settleState')
//     msg = generateState(0, 2, accounts[0], accounts[1], 9, 6)

//     console.log('State input: ' + msg)


//     // Hashing and signature
//     hmsg = web3.sha3(msg, {encoding: 'hex'})

//     sig1 = await web3.eth.sign(accounts[0], hmsg)
//     r = sig1.substr(0,66)
//     s = "0x" + sig1.substr(66,64)
//     v = 28

//     sig2 = await web3.eth.sign(accounts[1], hmsg)
//     r2 = sig2.substr(0,66)
//     s2 = "0x" + sig2.substr(66,64)
//     v2 = 28

//     sigV = []
//     sigR = []
//     sigS = []

//     sigV.push(v)
//     sigV.push(v2)
//     sigR.push(r)
//     sigR.push(r2)
//     sigS.push(s)
//     sigS.push(s2)

//     await cm.startSettleState(channelId, 'run(bytes)', sigV, sigR, sigS, msg)

//     open = await cm.getChannel(channelId)

//     console.log('settlement period ends: ' + open[4])
//     console.log('current time stamp: ' + Math.round((new Date()).getTime() / 1000) + '\n')

//     console.log('Party A challenging settle state with higher sequence num')

//     msg = generateState(0, 3, accounts[0], accounts[1], 8, 7)

//     console.log('State input: ' + msg)


//     // Hashing and signature
//     hmsg = web3.sha3(msg, {encoding: 'hex'})

//     sig1 = await web3.eth.sign(accounts[0], hmsg)
//     r = sig1.substr(0,66)
//     s = "0x" + sig1.substr(66,64)
//     v = 28

//     sig2 = await web3.eth.sign(accounts[1], hmsg)
//     r2 = sig2.substr(0,66)
//     s2 = "0x" + sig2.substr(66,64)
//     v2 = 27

//     sigV = []
//     sigR = []
//     sigS = []

//     sigV.push(v)
//     sigV.push(v2)
//     sigR.push(r)
//     sigR.push(r2)
//     sigS.push(s)
//     sigS.push(s2)

//     await cm.challengeSettleState(channelId, msg, sigV, sigR, sigS, 'run(bytes)')

//     open = await cm.getChannel(channelId)

//     console.log('\nchallenged new state: ' + open[7])
//     console.log('\nclosing channel with settle timeout')

//     console.log('balance sender before close: ' + web3.fromWei(web3.eth.getBalance(accounts[0])))
//     console.log('balance receiver before close: ' + web3.fromWei(web3.eth.getBalance(accounts[1])))

//     await cm.closeWithTimeout(channelId);

//     open = await cm.getChannel(channelId)

//     _seq = await int.b1()
//     _addr = await int.b2()
//     console.log('recovered balance A: ' + _seq)
//     console.log('recovered balance B: ' + _addr)
//     console.log('balance sender after close: ' + web3.fromWei(web3.eth.getBalance(accounts[0])))
//     console.log('balance receiver after close: ' + web3.fromWei(web3.eth.getBalance(accounts[1])) + '\n')
//     console.log('Channel status: ' + open[5][0])
//     // TODO decide what to do with invalid state sends. Clients should probably just
//     // respond saying they wont sign it, please give me a correct one or I'll close 
//     // with previous state.

//     // challenge settle State
//     // Here we build a case where the two parties can not agree on a state that has
//     // a close boolean sentinel. The parties must start a settlement period where the
//     // last highest sequence agreed upon non-close sentinel state may be presented

//   })

// })

// function generateState(sentinel, seq, addyA, addyB, balA, balB) {
//     var sentinel = padBytes32(web3.toHex(sentinel))
//     var sequence = padBytes32(web3.toHex(seq))
//     var addressA = padBytes32(addyA)
//     var addressB = padBytes32(addyB)
//     var balanceA = padBytes32(web3.toHex(web3.toWei(balA, 'ether')))
//     var balanceB = padBytes32(web3.toHex(web3.toWei(balB, 'ether')))

//     var m = sentinel +
//         sequence.substr(2, sequence.length) +
//         addressA.substr(2, addressA.length) +
//         addressB.substr(2, addressB.length) +
//         balanceA.substr(2, balanceA.length) + 
//         balanceB.substr(2, balanceB.length)

//     return m
// }

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