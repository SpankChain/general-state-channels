// 'use strict'

// const utils = require('./helpers/utils')

// const ChannelManager = artifacts.require("./ChannelManager.sol")
// const Judge = artifacts.require("./JudgePaymentChannel.sol")
// const Interpreter = artifacts.require("./InterpretPaymentChannel.sol")

// let cm
// let jg
// let int

// let event_args

// contract('Single direction payment channel', function(accounts) {
//   it("Payment Channel", async function() {
//     cm = await ChannelManager.new()
//     jg = await Judge.new()
//     int = await Interpreter.new()


//     // State encoding
//     // We simply replace the sequence number with the receiver balance
//     // Account 0 is the bonded hub making signed payments
//     // Account 1 is the receiver of payments, they may sign and close any payment

//     // [isClose]
//     // [sender]
//     // [receiver]
//     // [senderBond]
//     // [receiverBalance]

//     // ----------- valid state -------------- //
//     var sentinel = padBytes32(web3.toHex(0))
//     var addressA = padBytes32(accounts[0])
//     var addressB = padBytes32(accounts[1])
//     var bond = padBytes32(web3.toHex(web3.toWei(10, 'ether')))
//     var balance = padBytes32(web3.toHex(0))

//     var msg = sentinel +
//         addressA.substr(2, addressA.length) +
//         addressB.substr(2, addressB.length) +
//         bond.substr(2, bond.length) + 
//         balance.substr(2, balance.length)

//     console.log('State input: ' + msg)


//     // Hashing and signature
//     var hmsg = web3.sha3(msg, {encoding: 'hex'})
//     console.log('hashed msg: ' + hmsg)

//     var sig1 = await web3.eth.sign(accounts[0], hmsg)

//     let res = await cm.openChannel(accounts[1], 0, 1337, int.address, jg.address, msg, sig1, {from: accounts[0], value: web3.toWei(10, 'ether')})
//     let numChan = await cm.numChannels()

//     event_args = res.logs[0].args

//     let channelId = event_args.channelId
//     console.log('Channels created: ' + numChan.toNumber() + ' channelId: ' + channelId)
//     console.log('{Simulated network send from hub to receiver of initial state}')
    
//     var sig2 = await web3.eth.sign(accounts[1], hmsg)

//     await cm.joinChannel(channelId, msg, sig1, sig2, {from: accounts[1]})

//     let open = await cm.getChannel(channelId)
//     console.log('Channel joined, open: ' + open[8][0])

//     await cm.exerciseJudge(channelId, 'run(bytes)', sig1, msg)

//     open = await cm.getChannel(channelId)



//     let _seq = await jg.b()
//     let _addr = await jg.a1()
//     console.log('recovered bond num: ' + _seq)
//     console.log('recovered addressA: ' + _addr)
//     console.log('account[0]: ' + accounts[1])
//     console.log('Judge resolution: ' + open[8][2])

//     console.log('\n')
//     console.log('Starting payments...')

//     // State 1

//     sentinel = padBytes32(web3.toHex(0))
//     addressA = accounts[0]
//     addressB = accounts[1]
//     bond = padBytes32(web3.toHex(web3.toWei(10, 'ether')))
//     balance = padBytes32(web3.toHex(web3.toWei(1, 'ether')))

//     msg = sentinel + 
//         addressA.substr(2, addressA.length) +
//         addressB.substr(2, addressB.length) +
//         bond.substr(2, bond.length) + 
//         balance.substr(2, balance.length)

//     hmsg = web3.sha3(msg, {encoding: 'hex'})
//     console.log('hashed msg: ' + hmsg)

//     sig1 = await web3.eth.sign(accounts[0], hmsg)
//     //console.log('State signature: ' + sig1)

//     console.log('\nState_1: ' + msg)


//     console.log('{Simulated network send of payment state:action 1:add}')
//     console.log('{Receiver validating state, and signing}\n')

//     // State 2

//     sentinel = padBytes32(web3.toHex(0))
//     var addressA = padBytes32(accounts[0])
//     var addressB = padBytes32(accounts[1])
//     var bond = padBytes32(web3.toHex(web3.toWei(10, 'ether')))
//     var balance = padBytes32(web3.toHex(web3.toWei(3, 'ether')))

//     var msg = sentinel + 
//         addressA.substr(2, addressA.length) +
//         addressB.substr(2, addressB.length) +
//         bond.substr(2, bond.length) + 
//         balance.substr(2, balance.length)

//     hmsg = web3.sha3(msg, {encoding: 'hex'})
//     console.log('hashed msg: ' + hmsg)

//     sig1 = await web3.eth.sign(accounts[0], hmsg)
//     //console.log('State signature: ' + sig1)

//     console.log('\nState_2: ' + msg)


//     console.log('{Simulated network send of payment state:action 2:add}')
//     console.log('{Receiver validating state, and signing}\n')

//     console.log('Closing Channel...')

//     await cm.exerciseJudge(channelId, 'run(bytes)', sig1, msg)

//     sig2 = await web3.eth.sign(accounts[1], hmsg)

//     console.log('balance sender before close: ' + web3.fromWei(web3.eth.getBalance(accounts[0])))
//     console.log('balance receiver before close: ' + web3.fromWei(web3.eth.getBalance(accounts[1])))

//     await cm.closeChannel(channelId, msg, sig1, sig2)

//     console.log('balance sender after close: ' + web3.fromWei(web3.eth.getBalance(accounts[0])))
//     console.log('balance receiver after close: ' + web3.fromWei(web3.eth.getBalance(accounts[1])))

//     open = await cm.getChannel(channelId)

//     console.log('Channel closed by two party signature on close sentinel')

//     _seq = await int.ba()
//     console.log('recovered balance num: ' + _seq)

//     console.log('Channel status: ' + open[8][0])

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