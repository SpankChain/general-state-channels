'use strict'

const utils = require('./helpers/utils')
// const fs = require('fs')
// const solc = require('solc')

const BondManager = artifacts.require("./BondManager.sol")
const Registry = artifacts.require("./ChannelRegistry.sol")
const SPC = artifacts.require("./InterpretSpecialChannel.sol")
const Payment = artifacts.require("./InterpretPaymentChannel.sol")
const TwoPartyPayment = artifacts.require("./InterpretBidirectional.sol")

let bm
let reg
let spc
let pay
let twopay

let event_args

contract('counterfactual payment channel', function(accounts) {
  it("Payment Channel", async function() {
    reg = await Registry.new()
    // counterfactual code should be pulled from compiled code not from deployed, quick hack for now
    spc = await SPC.new(reg.address)

    console.log('Begin creating counterfactual SPC contract...')
    var ctfcode = spc.constructor.bytecode
    // supply the SPC constructor arg by appending it to the contracts bytecode
    var regA = reg.address
    regA = padBytes32(regA)
    ctfcode = ctfcode + regA.substr(2, regA.length)

    //console.log('SPC bytecode: ' + ctfcode)
    console.log('Begin signing and register ctf address...\n')

    var ctfSPCstate = generateRegistryState(accounts[0], accounts[1], ctfcode)

    // Hashing and signature
    var CTFhmsg = web3.sha3(ctfSPCstate, {encoding: 'hex'})
    console.log('hashed msg: ' + CTFhmsg + '\n')

    var CTFsig1 = await web3.eth.sign(accounts[0], CTFhmsg)
    var ctfr1 = CTFsig1.substr(0,66)
    var ctfs1 = "0x" + CTFsig1.substr(66,64)
    var ctfv1 = parseInt(CTFsig1.substr(130, 2)) + 27

    console.log('party 1 signature of SPC CTF bytecode: '+CTFsig1+'\n')

    var CTFsig2 = await web3.eth.sign(accounts[1], CTFhmsg)
    var ctfr2 = CTFsig2.substr(0,66)
    var ctfs2 = "0x" + CTFsig2.substr(66,64)
    var ctfv2 = parseInt(CTFsig2.substr(130, 2)) + 27

    console.log('party 2 signature of SPC CTF bytecode: '+CTFsig2+'\n')

    var ctfsigV = []
    var ctfsigR = []
    var ctfsigS = []

    ctfsigV.push(ctfv1)
    ctfsigV.push(ctfv2)
    ctfsigR.push(ctfr1)
    ctfsigR.push(ctfr2)
    ctfsigS.push(ctfs1)
    ctfsigS.push(ctfs2)

    // construct an identifier for the counterfactual address
    //var CTFaddress = '0x' + sig1.substr(2, 2) + sig2.substr(2,2)
    var CTFsigs = CTFsig1+CTFsig2.substr(2, CTFsig2.length)
    //var CTFsigs = ctfr1 + ctfs1.substr(2, ctfs1.length) + web3.toHex(ctfv1) + ctfr2.substr(2, ctfr2.length) + ctfs2.substr(2, ctfs2.length) + web3.toHex(ctfv2)
    //var CTFaddress = web3.sha3(CTFsigs, {encoding: 'hex'})
    var CTFaddress = CTFhmsg
    console.log('counterfactual address: ' + CTFaddress)
    console.log('SPC contract is now counterfactually instantiated\n')
    console.log('Deploying bond manager...')

    bm = await BondManager.new(CTFaddress, reg.address)

    // generate SPC state
    // do before bond manageer deploy, reduce bm to one tx
    var initialState = generateInitSPCState(0, 0, 0, accounts[0], accounts[1], 20, 20)
    console.log('Initial State: ' + initialState + '\n')

    // Hashing and signature
    var hmsg = web3.sha3(initialState, {encoding: 'hex'})
    console.log('hashed msg: ' + hmsg)

    var sig1 = await web3.eth.sign(accounts[0], hmsg)
    var r = sig1.substr(0,66)
    var s = "0x" + sig1.substr(66,64)
    var v = parseInt(sig1.substr(130, 2)) + 27

    console.log('{Simulated network send from A to receiver of initial state}')
    
    var sig2 = await web3.eth.sign(accounts[1], hmsg)
    var r2 = sig2.substr(0,66)
    var s2 = "0x" + sig2.substr(66,64)
    var v2 = parseInt(sig2.substr(130, 2)) + 27

    await bm.openChannel(initialState, v, r, s, {from: accounts[0], value: web3.toWei(20, 'ether')})

    await bm.joinChannel(v2, r2, s2, {from: accounts[1], value: web3.toWei(20, 'ether')})

    console.log('BondManager channel open\n')
    console.log('PartyA counterfactually instantiating single direction payment channel...')

    var single = await Payment.new()
    var ctfpaymentcode = single.constructor.bytecode

    var ctfpaymentstate = generateRegistryState(accounts[0], accounts[1], ctfpaymentcode)

    var paymentCTFhmsg = web3.sha3(ctfpaymentstate, {encoding: 'hex'})
    console.log('payment channel CTF hashed msg: ' + paymentCTFhmsg + '\n')

    var paymentCTFsig1 = await web3.eth.sign(accounts[0], paymentCTFhmsg+ '\n')
    var payctfr1 = paymentCTFsig1.substr(0,66)
    var payctfs1 = "0x" + paymentCTFsig1.substr(66,64)
    var payctfv1 = parseInt(paymentCTFsig1.substr(130, 2)) + 27

    console.log('partyB signing CTF channel')
    var paymentCTFsig2 = await web3.eth.sign(accounts[1], paymentCTFhmsg+'\n')
    var payctfr2 = paymentCTFsig2.substr(0,66)
    var payctfs2 = "0x" + paymentCTFsig2.substr(66,64)
    var payctfv2 = parseInt(paymentCTFsig2.substr(130, 2)) + 27

    var ctfpaysigV = []
    var ctfpaysigR = []
    var ctfpaysigS = []

    ctfpaysigV.push(payctfv1)
    ctfpaysigV.push(payctfv2)
    ctfpaysigR.push(payctfr1)
    ctfpaysigR.push(payctfr2)
    ctfpaysigS.push(payctfs1)
    ctfpaysigS.push(payctfs2)

    var paymentCTFsigs = paymentCTFsig1+paymentCTFsig2.substr(2, paymentCTFsig2.length)
    //var paymentCTFaddress = web3.sha3(paymentCTFsigs, {encoding: 'hex'})
    var paymentCTFaddress = paymentCTFhmsg
    console.log('paywall counterfactual address: ' + paymentCTFaddress)

    // Note we reduce the balance of partyA to represent committing 10 ether to the paywall
    var state1 = generatePaywallSPCState(
      0, 
      1, 
      0, 
      accounts[0], 
      accounts[1], 
      10, 
      20,
      7,
      1,
      paymentCTFaddress,
      0,
      0,
      0,
      accounts[0],
      accounts[1],
      10,
      0
    )

    hmsg = web3.sha3(state1, {encoding: 'hex'})
    console.log('hashed msg: ' + hmsg)

    sig1 = await web3.eth.sign(accounts[0], hmsg)
    r = sig1.substr(0,66)
    s = "0x" + sig1.substr(66,64)
    v = parseInt(sig1.substr(130, 2)) + 27

    console.log('{Simulated network send from A to receiver of state_1}')
    
    sig2 = await web3.eth.sign(accounts[1], hmsg)
    r2 = sig2.substr(0,66)
    s2 = "0x" + sig2.substr(66,64)
    v2 = parseInt(sig2.substr(130, 2)) + 27

    console.log('State_1: ' + state1+'\n')
    console.log('Generating payment...')

    var state2 = generatePaywallSPCState(
      0, 
      2, 
      1, 
      accounts[0], 
      accounts[1], 
      10, 
      20,
      7,
      1,
      paymentCTFaddress,
      0,
      1,
      0,
      accounts[0],
      accounts[1],
      9,
      1
    )

    hmsg = web3.sha3(state2, {encoding: 'hex'})
    console.log('hashed msg: ' + hmsg)

    sig1 = await web3.eth.sign(accounts[0], hmsg)
    r = sig1.substr(0,66)
    s = "0x" + sig1.substr(66,64)
    v = parseInt(sig1.substr(130, 2)) + 27

    console.log('{Simulated network send from A to receiver of state_2}')
    
    sig2 = await web3.eth.sign(accounts[1], hmsg)
    r2 = sig2.substr(0,66)
    s2 = "0x" + sig2.substr(66,64)
    v2 = parseInt(sig2.substr(130, 2)) + 27

    console.log('State_2: ' + state2+'\n')



    console.log('loading state with new channel Bidirectional payment channel...')
    var double = await TwoPartyPayment.new()
    var ctfbidirectionalcode = double.constructor.bytecode

    var bidirectionalCTFhmsg = web3.sha3(ctfbidirectionalcode, {encoding: 'hex'})
    console.log('bidirectional payment channel CTF hashed msg: ' + bidirectionalCTFhmsg + '\n')

    var bidirectionalCTFsig1 = await web3.eth.sign(accounts[0], bidirectionalCTFhmsg + '\n')
    console.log('partyB signing bidirectional CTF channel')
    var bidirectionalCTFsig2 = await web3.eth.sign(accounts[1], bidirectionalCTFhmsg + '\n')

    var bidirectionalCTFsigs = bidirectionalCTFsig1+bidirectionalCTFsig2.substr(2, bidirectionalCTFsig2.length)
    var bidirectionalCTFaddress = web3.sha3(bidirectionalCTFsigs, {encoding: 'hex'})
    console.log('bidirectional counterfactual address: ' + bidirectionalCTFaddress + '\n')

    var state3 = generateBidirectionalSPCState(
      0, 
      3, 
      2, 
      accounts[0], 
      accounts[1], 
      5, 
      15,
      7,
      1,
      paymentCTFaddress,
      0,
      1,
      0,
      accounts[0],
      accounts[1],
      9,
      1,
      8, // statelength
      2,
      bidirectionalCTFaddress,
      0,
      0,
      0,
      accounts[0],
      accounts[1],
      10, //bond total
      5,
      5
    )

    var hmsgv2 = web3.sha3(state3, {encoding: 'hex'})
    console.log('hashed msg: ' + hmsgv2)

    var sig1v2 = await web3.eth.sign(accounts[0], hmsgv2)
    var rv2 = sig1v2.substr(0,66)
    var sv2 = "0x" + sig1v2.substr(66,64)
    var vv2 = parseInt(sig1v2.substr(130, 2)) + 27

    console.log('{Simulated network send from A to receiver of state_3}')
    
    var sig2v2 = await web3.eth.sign(accounts[1], hmsgv2)
    var r2v2 = sig2v2.substr(0,66)
    var s2v2 = "0x" + sig2v2.substr(66,64)
    var v2v2 = parseInt(sig2v2.substr(130, 2)) + 27

    console.log('State_3: ' + state3+'\n')


    console.log('counterfactually instantiating crypto kitties channel')




    console.log('Party A starting settlement of paywall channel...')
    console.log('Deploying SPC and Paywall code to registry...')

    // Does any of this work? Is it a good idea? 
    // Why is a Raven like a writing desk?

    //await reg.deployCTF(ctfcode, CTFsigs)
    // should decode contract bytes from state
    await reg.deployCTF(ctfcode, ctfSPCstate, ctfsigV, ctfsigR, ctfsigS)

    let deployAddress = await reg.resolveAddress(CTFaddress)
    console.log(CTFaddress)
    console.log('---')
    console.log(CTFsigs)
    console.log('---')
    console.log(ctfsigR[0]+ctfsigS[0]+ctfsigV[0])
    console.log('----')
    console.log(ctfr1+ctfs1.substr(2, ctfs1.length)+ctfv1)
    console.log(CTFsig1)
    console.log('-----')
    console.log(ctfr2+ctfs2+ctfv2)
    console.log(CTFsig2)
    // reregister the spc instance to the one the registry deployed
    spc = await SPC.at(deployAddress);

    console.log('counterfactual SPC contract deployed and mapped by registry: ' + deployAddress)

    //await reg.deployCTF(ctfpaymentcode, paymentCTFsigs)
    await reg.deployCTF(ctfpaymentcode, ctfpaymentstate, ctfpaysigV, ctfpaysigR, ctfpaysigS)

    deployAddress = await reg.resolveAddress(paymentCTFaddress)

    console.log('counterfactual Paywall contract deployed and mapped by registry: ' + deployAddress)

    console.log('party A starting settlement of paywall channel...\n')

    var sigV = []
    var sigR = []
    var sigS = []

    sigV.push(v)
    sigV.push(v2)
    sigR.push(r)
    sigR.push(r2)
    sigS.push(s)
    sigS.push(s2)

    await spc.startSettleStateGame(1, state2, sigV, sigR, sigS)

    let spcPartyA = await spc.partyA()
    let spcBalA = await spc.balanceA()
    let spcPartyB = await spc.partyB()
    let spcBalB = await spc.balanceB()

    let subchan = await spc.getSubChannel(1)

    console.log('address A: '+ spcPartyA+' balance A: '+ spcBalA)
    console.log('address B: '+ spcPartyB+' balance B: '+ spcBalB)
    console.log('sub channel struct in settlement: ' + subchan[1]+'\n')

    console.log('Party B challenging settlement...')



    console.log('party A closing sub channel with timeout...')
    await spc.closeWithTimeoutGame(state2, 1, sigV, sigR, sigS)

    console.log('sub channel closed')
    spcPartyA = await spc.partyA()
    spcBalA = await spc.balanceA()
    spcPartyB = await spc.partyB()
    spcBalB = await spc.balanceB()
    console.log('address A: '+ spcPartyA+' balance A: '+ spcBalA)
    console.log('address B: '+ spcPartyB+' balance B: '+ spcBalB)

    let ctfpaywall = await Payment.at(deployAddress)

    let ctfpaywallbala = await ctfpaywall.balanceA()
    console.log('ctf paywall balance A: ' + ctfpaywallbala)
    let ctfpaywallbalb = await ctfpaywall.balanceB()
    console.log('ctf paywall balance B: ' + ctfpaywallbalb)

    // let newBm = BondManager.at(deployAddress)
    // let testBm = await newBm.test()
    // console.log('Test should be 420: ' + testBm)

    // console.log('begin settling byzantine bond manager state...')

    // await bm.startSettleState(0, sigV, sigR, sigS, state2)

    // bm.closeChannel()
  })

})

function generateBidirectionalSPCState(
  _sentinel, 
  _seq, 
  _numChan, 
  _addyA, 
  _addyB, 
  _balA, 
  _balB, 
  _stateLength, 
  _intType, 
  _CTFAddress,
  _CTFsentinel,
  _CTFsequence,
  _CTFsettlementPeriod,
  _CTFsender,
  _CTFreceiver,
  _CTFbond,
  _CTFbalanceReceiver,
  _stateLength2,
  _intType2, 
  _CTFAddress2,
  _CTFsentinel2,
  _CTFsequence2,
  _CTFsettlementPeriod2,
  _CTFsender2,
  _CTFreceiver2,
  _CTFbond2,
  _CTFbalanceA2,
  _CTFbalanceB2
) {

    var sentinel = padBytes32(web3.toHex(_sentinel))
    var sequence = padBytes32(web3.toHex(_seq))
    var numChannels = padBytes32(web3.toHex(_numChan))
    var addressA = padBytes32(_addyA)
    var addressB = padBytes32(_addyB)
    var balanceA = padBytes32(web3.toHex(web3.toWei(_balA, 'ether')))
    var balanceB = padBytes32(web3.toHex(web3.toWei(_balB, 'ether')))

    var stateLength = padBytes32(web3.toHex(_stateLength))
    var intType = padBytes32(web3.toHex(_intType))
    var CTFaddress = padBytes32(_CTFAddress)
    var CTFsentinel = padBytes32(web3.toHex(_CTFsentinel))
    var CTFsequence = padBytes32(web3.toHex(_CTFsequence))
    var CTFsettlementPeriod = padBytes32(web3.toHex(_CTFsettlementPeriod))
    var CTFsender = padBytes32(_CTFsender)
    var CTFreceiver = padBytes32(_CTFreceiver)
    var CTFbond = padBytes32(web3.toHex(web3.toWei(_CTFbond, 'ether')))
    var CTFbalanceReceiver = padBytes32(web3.toHex(web3.toWei(_CTFbalanceReceiver, 'ether')))

    var stateLength2 = padBytes32(web3.toHex(_stateLength2))
    var intType2 = padBytes32(web3.toHex(_intType2))
    var CTFaddress2 = padBytes32(_CTFAddress2)
    var CTFsentinel2 = padBytes32(web3.toHex(_CTFsentinel2))
    var CTFsequence2 = padBytes32(web3.toHex(_CTFsequence2))
    var CTFsettlementPeriod2 = padBytes32(web3.toHex(_CTFsettlementPeriod2))
    var CTFsender2 = padBytes32(_CTFsender2)
    var CTFreceiver2 = padBytes32(_CTFreceiver2)
    var CTFbond2 = padBytes32(web3.toHex(web3.toWei(_CTFbond2, 'ether')))
    var CTFbalanceA2 = padBytes32(web3.toHex(web3.toWei(_CTFbalanceA2, 'ether')))
    var CTFbalanceB2 = padBytes32(web3.toHex(web3.toWei(_CTFbalanceB2, 'ether')))


    var m = sentinel +
        sequence.substr(2, sequence.length) +
        numChannels.substr(2,numChannels.length) +
        addressA.substr(2, addressA.length) +
        addressB.substr(2, addressB.length) +
        balanceA.substr(2, balanceA.length) + 
        balanceB.substr(2, balanceB.length) +
        stateLength.substr(2, stateLength.length) +
        intType.substr(2, intType.length) +
        CTFaddress.substr(2, CTFaddress.length) +
        CTFsentinel.substr(2, CTFsentinel.length) +
        CTFsequence.substr(2, CTFsequence.length) +
        CTFsettlementPeriod.substr(2, CTFsettlementPeriod.length) +
        CTFsender.substr(2, CTFsender.length) +
        CTFreceiver.substr(2, CTFreceiver.length) +
        CTFbond.substr(2, CTFbond.length) +
        CTFbalanceReceiver.substr(2, CTFbalanceReceiver.length)+
        stateLength2.substr(2, stateLength2.length) +
        intType2.substr(2, intType2.length) +
        CTFaddress2.substr(2, CTFaddress2.length) +
        CTFsentinel2.substr(2, CTFsentinel2.length) +
        CTFsequence2.substr(2, CTFsequence2.length) +
        CTFsettlementPeriod2.substr(2, CTFsettlementPeriod2.length) +
        CTFsender2.substr(2, CTFsender2.length) +
        CTFreceiver2.substr(2, CTFreceiver2.length) +
        CTFbond2.substr(2, CTFbond2.length) +
        CTFbalanceA2.substr(2, CTFbalanceA2.length) +
        CTFbalanceB2.substr(2, CTFbalanceB2.length)

    return m
}


function generatePaywallSPCState(
  _sentinel, 
  _seq, 
  _numChan, 
  _addyA, 
  _addyB, 
  _balA, 
  _balB, 
  _stateLength, 
  _intType, 
  _CTFAddress,
  _CTFsentinel,
  _CTFsequence,
  _CTFsettlementPeriod,
  _CTFsender,
  _CTFreceiver,
  _CTFbond,
  _CTFbalanceReceiver
) {
    // SPC State
    // [
    //    32 isClose
    //    64 sequence
    //    96 numInstalledChannels
    //    128 address 1
    //    160 address 2
    //    192 balance 1
    //    224 balance 2
    //    -----------------------------
    //    256 channel 1 state length
    //    288 channel 1 interpreter type
    //    320 channel 1 CTF address
    //    [
    //        isClose
    //        sequence
    //        settlement period length
    //        address sender
    //        address receiver 
    //        bond
    //        balance receiver
    //    ]
    // ]

    var sentinel = padBytes32(web3.toHex(_sentinel))
    var sequence = padBytes32(web3.toHex(_seq))
    var numChannels = padBytes32(web3.toHex(_numChan))
    var addressA = padBytes32(_addyA)
    var addressB = padBytes32(_addyB)
    var balanceA = padBytes32(web3.toHex(web3.toWei(_balA, 'ether')))
    var balanceB = padBytes32(web3.toHex(web3.toWei(_balB, 'ether')))

    var stateLength = padBytes32(web3.toHex(_stateLength))
    var intType = padBytes32(web3.toHex(_intType))
    var CTFaddress = padBytes32(_CTFAddress)
    var CTFsentinel = padBytes32(web3.toHex(_CTFsentinel))
    var CTFsequence = padBytes32(web3.toHex(_CTFsequence))
    var CTFsettlementPeriod = padBytes32(web3.toHex(_CTFsettlementPeriod))
    var CTFsender = padBytes32(_CTFsender)
    var CTFreceiver = padBytes32(_CTFreceiver)
    var CTFbond = padBytes32(web3.toHex(web3.toWei(_CTFbond, 'ether')))
    var CTFbalanceReceiver = padBytes32(web3.toHex(web3.toWei(_CTFbalanceReceiver, 'ether')))


    var m = sentinel +
        sequence.substr(2, sequence.length) +
        numChannels.substr(2,numChannels.length) +
        addressA.substr(2, addressA.length) +
        addressB.substr(2, addressB.length) +
        balanceA.substr(2, balanceA.length) + 
        balanceB.substr(2, balanceB.length) +
        stateLength.substr(2, stateLength.length) +
        intType.substr(2, intType.length) +
        CTFaddress.substr(2, CTFaddress.length) +
        CTFsentinel.substr(2, CTFsentinel.length) +
        CTFsequence.substr(2, CTFsequence.length) +
        CTFsettlementPeriod.substr(2, CTFsettlementPeriod.length) +
        CTFsender.substr(2, CTFsender.length) +
        CTFreceiver.substr(2, CTFreceiver.length) +
        CTFbond.substr(2, CTFbond.length) +
        CTFbalanceReceiver.substr(2, CTFbalanceReceiver.length)

    return m
}

function generateInitSPCState(sentinel, seq, numChan, addyA, addyB, balA, balB) {
    // SPC State
    // [
    //    32 isClose
    //    64 sequence
    //    96 numInstalledChannels
    //    128 address 1
    //    160 address 2
    //    192 balance 1
    //    224 balance 2
    //    -----------------------------
    //    256 channel 1 state length
    //    288 channel 1 interpreter type
    //    320 channel 1 CTF address
    //    [
    //        isClose
    //        sequence
    //        settlement period length
    //        channel specific state
    //        ...
    //    ]
    //    channel 2 state length
    //    channel 2 interpreter type
    //    channel 2 CTF address
    //    [
    //        isClose
    //        sequence
    //        settlement period length
    //        channel specific state
    //        ...
    //    ]
    //    ...
    // ]
    var sentinel = padBytes32(web3.toHex(sentinel))
    var sequence = padBytes32(web3.toHex(seq))
    var numChannels = padBytes32(web3.toHex(numChan))
    var addressA = padBytes32(addyA)
    var addressB = padBytes32(addyB)
    var balanceA = padBytes32(web3.toHex(web3.toWei(balA, 'ether')))
    var balanceB = padBytes32(web3.toHex(web3.toWei(balB, 'ether')))

    var m = sentinel +
        sequence.substr(2, sequence.length) +
        numChannels.substr(2,numChannels) +
        addressA.substr(2, addressA.length) +
        addressB.substr(2, addressB.length) +
        balanceA.substr(2, balanceA.length) + 
        balanceB.substr(2, balanceB.length)

    return m
}

function generateRegistryState(partyA, partyB, bytecode) {
    var addressA = padBytes32(partyA)
    var addressB = padBytes32(partyB)

    var m = 
        addressA +
        addressB.substr(2, addressB.length) +
        bytecode.substr(2, bytecode.length)

    return m
}

function padBytes32(data){
  let l = 66-data.length
  let x = data.substr(2, data.length)

  for(var i=0; i<l; i++) {
    x = 0 + x
  }
  return '0x' + x
}

function rightPadBytes32(data){
  let l = 66-data.length

  for(var i=0; i<l; i++) {
    data+=0
  }
  return data
}

