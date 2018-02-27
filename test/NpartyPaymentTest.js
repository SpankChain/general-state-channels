// 'use strict'

// const utils = require('./helpers/utils')

// const ChannelManager = artifacts.require("./ChannelManager.sol")
// const Interpreter = artifacts.require("./InterpretNPartyPayments.sol")

// let cm
// let int
// let sigV = []
// let sigR = []
// let sigS = []

// let event_args

// contract('N Party payment channel', function(accounts) {
//   it("Payment Channel", async function() {
//     cm = await ChannelManager.new()
//     int = await Interpreter.new()


//     // State encoding
//     // We simply replace the sequence number with the receiver balance
//     // Account 0 is the bonded hub making signed payments
//     // Account 1 is the receiver of payments, they may sign and close any payment

//     // [isClose]
//     // [sequenceNum]
//     // [numberOfParticpants]
//     // [addressA]
//     // [addressB]
//     // ....
//     // [addressN]
//     // [balanceA]
//     // [balanceB]
//     // ....
//     // [balanceN]

//     // ----------- valid state -------------- //
//     var msg

//     msg = generateState(0, 0, 3, accounts[0], accounts[1], accounts[2], 10, 5, 2)


//     // Hashing and signature
//     var hmsg = web3.sha3(msg, {encoding: 'hex'})
//     console.log('hashed msg: ' + hmsg)

//     var sig1 = await web3.eth.sign(accounts[0], hmsg)
//     var r = sig1.substr(0,66)
//     var s = "0x" + sig1.substr(66,64)
//     var v = 28

//     let res = await cm.openChannel(web3.toWei(5, 'ether'), 1337, int.address, msg, v, r, s, {from: accounts[0], value: web3.toWei(10, 'ether')})
//     let numChan = await cm.numChannels()

//     let _b1= await int.b1()
//     let _b2 = await int.b2()
//     let _b3 = await int.b3()
//     let _a = await int.a()
//     let _b = await int.b()
//     let _c = await int.c()
//     let _n = await int.numParties()
//     console.log('recovered balanceA: ' + _b1)
//     console.log('recovered balanceB: ' + _b2)
//     console.log('recovered balanceC: ' + _b3)
//     console.log('recovered addressA: ' + _a)
//     console.log('recovered addressB: ' + _b)
//     console.log('recovered addressC: ' + _c)
//     console.log('recovered party number: ' + _n)

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

//     var sig3 = await web3.eth.sign(accounts[2], hmsg)
//     var r3 = sig3.substr(0,66)
//     var s3 = "0x" + sig3.substr(66,64)
//     var v3 = 27

//     await cm.joinChannel(channelId, msg, v3, r3, s3, {from: accounts[2], value: web3.toWei(2, 'ether')})
    
//     open = await cm.getChannel(channelId)
//     console.log('Channel joined, open: ' + open[5][0])

//     //await cm.exerciseJudge(channelId, 'run(bytes)', v, r, s, msg)

//     console.log('\n')
//     console.log('Starting payments...')

//     // State 1
//     msg = generateState(0, 1, 3, accounts[0], accounts[1], accounts[2], 8, 6, 3)

//     hmsg = web3.sha3(msg, {encoding: 'hex'})

//     sig1 = await web3.eth.sign(accounts[0], hmsg)
//     r = sig1.substr(0,66)
//     s = "0x" + sig1.substr(66,64)
//     v = 27

//     console.log('\nState_1: ' + msg)


//     console.log('{Simulated network send of payment state:action 1:add B, 1:add C, 2:sub A}')
//     console.log('{Receiver validating state, and signing}\n')

//     sig2 = await web3.eth.sign(accounts[1], hmsg)
//     r2 = sig2.substr(0,66)
//     s2 = "0x" + sig2.substr(66,64)
//     v2 = 27

//     console.log('{Simulated network send of payment state:action 1:add B, 1:add C, 2:sub A}')
//     console.log('{Receiver validating state, and signing}\n')

//     var sig3 = await web3.eth.sign(accounts[2], hmsg)
//     var r3 = sig3.substr(0,66)
//     var s3 = "0x" + sig3.substr(66,64)
//     var v3 = 27

//     // State 2

//     msg = generateState(1, 2, 3, accounts[0], accounts[1], accounts[2], 10, 4, 3)

//     hmsg = web3.sha3(msg, {encoding: 'hex'})

//     sig1 = await web3.eth.sign(accounts[0], hmsg)
//     r = sig1.substr(0,66)
//     s = "0x" + sig1.substr(66,64)
//     v = 28

//     console.log('\nState_2: ' + msg)


//     console.log('{Simulated network send of payment state:action 2:add A, 2:sub B}')
//     console.log('{Receiver validating state, and signing}\n')

//     sig2 = await web3.eth.sign(accounts[1], hmsg)
//     r2 = sig2.substr(0,66)
//     s2 = "0x" + sig2.substr(66,64)
//     v2 = 28

//     console.log('{Simulated network send of payment state:action 1:add B, 1:add C, 2:sub A}')
//     console.log('{Receiver validating state, and signing}\n')

//     var sig3 = await web3.eth.sign(accounts[2], hmsg)
//     var r3 = sig3.substr(0,66)
//     var s3 = "0x" + sig3.substr(66,64)
//     var v3 = 27

//     console.log('Closing Channel...')

//     // broken for payments
//     //await cm.exerciseJudge(channelId, 'run(bytes)', v, r, s, msg)

//     console.log('balance A before close: ' + web3.fromWei(web3.eth.getBalance(accounts[0])))
//     console.log('balance B before close: ' + web3.fromWei(web3.eth.getBalance(accounts[1])))
//     console.log('balance C before close: ' + web3.fromWei(web3.eth.getBalance(accounts[2])))

//     sigV = []
//     sigR = []
//     sigS = []

//     sigV.push(v)
//     sigV.push(v2)
//     sigV.push(v3)
//     sigR.push(r)
//     sigR.push(r2)
//     sigR.push(r3)
//     sigS.push(s)
//     sigS.push(s2)
//     sigS.push(s3)

// //     console.log(sigV)
// //     console.log(sigR)
    
//     // this needs getter to access in N party interpreter
//     // let isjoinA = await int.participants(accounts[0])[3]
//     // let isjoinB = await int.participants(accounts[1])[3]
//     // let isjoinC = await int.participants(accounts[2])[3]

//     // console.log('isJoined A: ' + isjoinA)
//     // console.log('isJoined B: ' + isjoinB)
//     // console.log('isJoined C: ' + isjoinC)

//     await cm.closeChannel(channelId, msg, sigV, sigR, sigS)

//     console.log('balance A after close: ' + web3.fromWei(web3.eth.getBalance(accounts[0])))
//     console.log('balance B after close: ' + web3.fromWei(web3.eth.getBalance(accounts[1])))
//     console.log('balance C after close: ' + web3.fromWei(web3.eth.getBalance(accounts[2])) + '\n')

//     _b1= await int.b1()
//     _b2 = await int.b2()
//     _b3 = await int.b3()
//     _a = await int.a()
//     _b = await int.b()
//     _c = await int.c()
//     _n = await int.numParties()
//     console.log('recovered balanceA: ' + _b1)
//     console.log('recovered balanceB: ' + _b2)
//     console.log('recovered balanceC: ' + _b3)
//     console.log('recovered addressA: ' + _a)
//     console.log('recovered addressB: ' + _b)
//     console.log('recovered addressC: ' + _c)
//     console.log('recovered party number: ' + _n)


//     // Settle state case
//     // init state
//     int = await Interpreter.new()

//     console.log('\nSettle State Case')
//     msg = generateState(0, 0, 3, accounts[0], accounts[1], accounts[2], 10, 5, 2)

//     console.log('State input: ' + msg)


//     // Hashing and signature
//     hmsg = web3.sha3(msg, {encoding: 'hex'})

//     sig1 = await web3.eth.sign(accounts[0], hmsg)
//     r = sig1.substr(0,66)
//     s = "0x" + sig1.substr(66,64)
//     v = 28

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

//     var sig3 = await web3.eth.sign(accounts[2], hmsg)
//     var r3 = sig3.substr(0,66)
//     var s3 = "0x" + sig3.substr(66,64)
//     var v3 = 27

//     await cm.joinChannel(channelId, msg, v3, r3, s3, {from: accounts[2], value: web3.toWei(2, 'ether')})
    
//     open = await cm.getChannel(channelId)
//     console.log('Channel joined, open: ' + open[5][0])

//     // Settle State Case

//     console.log('\n')

//     console.log('Party B starting settleState')
//     msg = generateState(0, 1, 3, accounts[0], accounts[1], accounts[2], 10, 4, 3)

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

//     sig3 = await web3.eth.sign(accounts[2], hmsg)
//     r3 = sig3.substr(0,66)
//     s3 = "0x" + sig3.substr(66,64)
//     v3 = 28

//     sigV = []
//     sigR = []
//     sigS = []

//     sigV.push(v)
//     sigV.push(v2)
//     sigV.push(v3)
//     sigR.push(r)
//     sigR.push(r2)
//     sigR.push(r3)
//     sigS.push(s)
//     sigS.push(s2)
//     sigS.push(s3)

//     await cm.startSettleState(channelId, 'run(bytes)', sigV, sigR, sigS, msg)

//     open = await cm.getChannel(channelId)

//     console.log('settlement period ends: ' + open[4])
//     console.log('current time stamp: ' + Math.round((new Date()).getTime() / 1000) + '\n')

//     console.log('Party A challenging settle state with higher sequence num')

//     msg = generateState(0, 2, 3, accounts[0], accounts[1], accounts[2], 10, 4, 3)

//     console.log('State input: ' + msg)


//     // Hashing and signature
//     hmsg = web3.sha3(msg, {encoding: 'hex'})

//     sig1 = await web3.eth.sign(accounts[0], hmsg)
//     r = sig1.substr(0,66)
//     s = "0x" + sig1.substr(66,64)
//     v = 27

//     sig2 = await web3.eth.sign(accounts[1], hmsg)
//     r2 = sig2.substr(0,66)
//     s2 = "0x" + sig2.substr(66,64)
//     v2 = 27

//     sig3 = await web3.eth.sign(accounts[2], hmsg)
//     r3 = sig3.substr(0,66)
//     s3 = "0x" + sig3.substr(66,64)
//     v3 = 28

//     console.log('balance A before close: ' + web3.fromWei(web3.eth.getBalance(accounts[0])))
//     console.log('balance B before close: ' + web3.fromWei(web3.eth.getBalance(accounts[1])))
//     console.log('balance C before close: ' + web3.fromWei(web3.eth.getBalance(accounts[2])))

//     sigV = []
//     sigR = []
//     sigS = []

//     sigV.push(v)
//     sigV.push(v2)
//     sigV.push(v3)
//     sigR.push(r)
//     sigR.push(r2)
//     sigR.push(r3)
//     sigS.push(s)
//     sigS.push(s2)
//     sigS.push(s3)

// //     console.log(sigV)
// //     console.log(sigR)

//     await cm.challengeSettleState(channelId, msg, sigV, sigR, sigS, 'run(bytes)')
//     await cm.closeWithTimeout(channelId);

//     console.log('balance A after close: ' + web3.fromWei(web3.eth.getBalance(accounts[0])))
//     console.log('balance B after close: ' + web3.fromWei(web3.eth.getBalance(accounts[1])))
//     console.log('balance C after close: ' + web3.fromWei(web3.eth.getBalance(accounts[2])) + '\n')

//     _b1= await int.b1()
//     _b2 = await int.b2()
//     _b3 = await int.b3()
//     _a = await int.a()
//     _b = await int.b()
//     _c = await int.c()
//     _n = await int.numParties()
//     console.log('recovered balanceA: ' + _b1)
//     console.log('recovered balanceB: ' + _b2)
//     console.log('recovered balanceC: ' + _b3)
//     console.log('recovered addressA: ' + _a)
//     console.log('recovered addressB: ' + _b)
//     console.log('recovered addressC: ' + _c)
//     console.log('recovered party number: ' + _n)


//     // msg = generateState(0, 3, accounts[0], accounts[1], 8, 7)

//     // console.log('State input: ' + msg)


//     // // Hashing and signature
//     // hmsg = web3.sha3(msg, {encoding: 'hex'})

//     // sig1 = await web3.eth.sign(accounts[0], hmsg)
//     // r = sig1.substr(0,66)
//     // s = "0x" + sig1.substr(66,64)
//     // v = 28

//     // sig2 = await web3.eth.sign(accounts[1], hmsg)
//     // r2 = sig2.substr(0,66)
//     // s2 = "0x" + sig2.substr(66,64)
//     // v2 = 27

//     // sigV = []
//     // sigR = []
//     // sigS = []

//     // sigV.push(v)
//     // sigV.push(v2)
//     // sigR.push(r)
//     // sigR.push(r2)
//     // sigS.push(s)
//     // sigS.push(s2)

//     // await cm.challengeSettleState(channelId, msg, sigV, sigR, sigS, 'run(bytes)')

//     // open = await cm.getChannel(channelId)

//     // console.log('\nchallenged new state: ' + open[7])
//     // console.log('\nclosing channel with settle timeout')

//     // console.log('balance sender before close: ' + web3.fromWei(web3.eth.getBalance(accounts[0])))
//     // console.log('balance receiver before close: ' + web3.fromWei(web3.eth.getBalance(accounts[1])))

//     // await cm.closeWithTimeout(channelId);

//     // open = await cm.getChannel(channelId)

//     // _seq = await int.b1()
//     // _addr = await int.b2()
//     // console.log('recovered balance A: ' + _seq)
//     // console.log('recovered balance B: ' + _addr)
//     // console.log('balance sender after close: ' + web3.fromWei(web3.eth.getBalance(accounts[0])))
//     // console.log('balance receiver after close: ' + web3.fromWei(web3.eth.getBalance(accounts[1])) + '\n')
//     // console.log('Channel status: ' + open[5][0])
//     // // TODO decide what to do with invalid state sends. Clients should probably just
//     // // respond saying they wont sign it, please give me a correct one or I'll close 
//     // // with previous state.

//     // // challenge settle State
//     // // Here we build a case where the two parties can not agree on a state that has
//     // // a close boolean sentinel. The parties must start a settlement period where the
//     // // last highest sequence agreed upon non-close sentinel state may be presented

//   })

// })

// function generateState(sentinel, seq, numParty, addyA, addyB, addyC, balA, balB, balC) {
//     var sentinel = padBytes32(web3.toHex(sentinel))
//     var sequence = padBytes32(web3.toHex(seq))
//     var numP = padBytes32(web3.toHex(numParty))
//     var addressA = padBytes32(addyA)
//     var addressB = padBytes32(addyB)
//     var addressC = padBytes32(addyC)
//     var balanceA = padBytes32(web3.toHex(web3.toWei(balA, 'ether')))
//     var balanceB = padBytes32(web3.toHex(web3.toWei(balB, 'ether')))
//     var balanceC = padBytes32(web3.toHex(web3.toWei(balC, 'ether')))

//     var m = sentinel +
//         sequence.substr(2, sequence.length) +
//         numP.substr(2, numP.length) +
//         addressA.substr(2, addressA.length) +
//         addressB.substr(2, addressB.length) +
//         addressC.substr(2, addressC.length) +
//         balanceA.substr(2, balanceA.length) + 
//         balanceB.substr(2, balanceB.length) +
//         balanceC.substr(2, balanceC.length)

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