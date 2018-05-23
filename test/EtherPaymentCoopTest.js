'use strict'

// Bi-direction Ether Payment Channel Tests

import MerkleTree from './helpers/MerkleTree'

const MultiSig = artifacts.require("./MultiSig.sol")
const Registry = artifacts.require("./CTFRegistry.sol")
const MetaChannel = artifacts.require("./MetaChannel.sol")

// Interpreters / Extension
const PaymentChannel = artifacts.require("./LibBidirectionalEther.sol")
const EtherExtension = artifacts.require("./EtherExtension.sol")

const Utils = require('./helpers/utils')
const ethutil = require('ethereumjs-util')

// State
let reg
let msig
let ethExtInst
let ethExtAddress

let partyA
let partyB

let subchannelRootHash

// channel code
let metachannel
let metaChannelBytecode
let metachannelCTFaddress
// library addresses
let paymentchannel
let paymentchanneladdress

// sig storage
let metachannelCTFsigA
let metachannelCTFsigB
let s0sigA
let s0sigB
let s1sigA
let s1sigB
let s2sigA
let s2sigB
let s3sigA
let s3sigB

// state storage
let metaCTF
let s0
let s0marshall
let s1
let s1marshall
let s2
let s2marshall
let s3
let s3marshall

// payment sub channel state storage
let roothash
let ethChannelID
let ss0
let ss0marshall
let ss1 
let ss1marshall

contract('Test Ether Payments', function(accounts) {

  before(async () => {
    partyA = accounts[1]
    partyB = accounts[2]

    reg = await Registry.new()
    paymentchannel = await PaymentChannel.new()
    paymentchanneladdress = paymentchannel.address
  })

  it("counterfactually instantiate meta-channel", async () => {
    // TODO: Use web3 to get predeployed bytecode with appended constructor args
    var args = [reg.address, partyA, partyB]
    var signers = [partyA, partyB]

    metachannel = await MetaChannel.new(reg.address, partyA, partyB)
    metaCTF = await Utils.getCTFstate(metachannel.constructor.bytecode, signers, args)
    metachannelCTFaddress = await Utils.getCTFaddress(metaCTF)
  })

  it("both parties sign metachannel ctf code, store sigs", async () => {
    metachannelCTFsigA = await web3.eth.sign(partyA, metachannelCTFaddress)
    metachannelCTFsigB = await web3.eth.sign(partyB, metachannelCTFaddress)
  })

  it("deploy MultiSig", async () => {
    msig = await MultiSig.new(metachannelCTFaddress, reg.address)
  })

  it("deploy ether Extension", async () => {
    ethExtInst = await EtherExtension.new()
    ethExtAddress = ethExtInst.address
  })

  it("generate initial ether state", async () => {
    var inputs = []
    inputs.push(0) // is close
    inputs.push(0) // sequence
    inputs.push(partyA) // partyA address
    inputs.push(partyB) // partyB address
    inputs.push(metachannelCTFaddress) // counterfactual metachannel address
    inputs.push('0x0') // sub-channel root hash
    inputs.push(web3.toWei(10, 'ether')) // balance in ether partyA
    inputs.push(web3.toWei(20, 'ether')) // balance in ether partyB

    s0 = inputs
    s0marshall = Utils.marshallState(inputs)
  })

  it("partyA signs state and opens msig agreement", async () => {
    s0sigA = await web3.eth.sign(partyA, web3.sha3(s0marshall, {encoding: 'hex'}))
    var r = s0sigA.substr(0,66)
    var s = "0x" + s0sigA.substr(66,64)
    var v = parseInt(s0sigA.substr(130, 2)) + 27

    var receipt = await msig.openAgreement(s0marshall, ethExtAddress, v, r, s, {from: accounts[1], value: web3.toWei(10, 'ether')})
    var gasUsed = receipt.receipt.gasUsed
    //console.log('Gas Used: ' + gasUsed)
    
  })

  it("partyB signs state and joins msig agreement", async () => {
    s0sigB = await web3.eth.sign(partyB, web3.sha3(s0marshall, {encoding: 'hex'}))
    var r = s0sigB.substr(0,66)
    var s = "0x" + s0sigB.substr(66,64)
    var v = parseInt(s0sigB.substr(130, 2)) + 27

    var receipt = await msig.joinAgreement(s0marshall, ethExtAddress, v, r, s, {from: accounts[2], value: web3.toWei(20, 'ether')})
    var gasUsed = receipt.receipt.gasUsed
    //console.log('Gas Used: ' + gasUsed)
  })

  it("generate ether payment channel state", async () => {
    ethChannelID = web3.sha3(Math.random())
    // Since channels are now library logic, we can resuse deploys between channels
    // We probably don't need to counterfactually instantiate a lib for every channel
    var subchannelInputs = []
    subchannelInputs.push(0) // is close
    subchannelInputs.push(0) // is force push channel
    subchannelInputs.push(0) // subchannel sequence
    subchannelInputs.push(0) // timeout length ms
    subchannelInputs.push(paymentchanneladdress) // ether payment interpreter library address
    subchannelInputs.push(ethChannelID) // ID of subchannel
    subchannelInputs.push(metachannelCTFaddress) // counterfactual metachannel address
    subchannelInputs.push(reg.address) // CTF registry address
    subchannelInputs.push('0x0') // subchannel tx roothash
    subchannelInputs.push(partyA) // partyA in the subchannel
    subchannelInputs.push(partyB) // partyB in the subchannel
    subchannelInputs.push(web3.toWei(0, 'ether')) // balance of party A in subchannel (ether)
    subchannelInputs.push(web3.toWei(10, 'ether')) // balance of party B in subchannel (ether)

    ss0 = subchannelInputs
    ss0marshall = Utils.marshallState(subchannelInputs)
    
    var hash = web3.sha3(ss0marshall, {encoding: 'hex'})
    var buf = Utils.hexToBuffer(hash)
    var elems = []
    elems.push(buf)
    var merkle = new MerkleTree(elems)

    subchannelRootHash = Utils.bufferToHex(merkle.getRoot())

    //console.log(merkle.root())

    var inputs = []
    inputs.push(0) // is close
    inputs.push(1) // sequence
    inputs.push(partyA) // partyA address
    inputs.push(partyB) // partyB address
    inputs.push(metachannelCTFaddress) // counterfactual metachannel address
    inputs.push(subchannelRootHash) // sub-channel root hash
    inputs.push(web3.toWei(10, 'ether')) // balance in ether partyA
    inputs.push(web3.toWei(10, 'ether')) // balance in ether partyB

    s1 = inputs
    s1marshall = Utils.marshallState(inputs)
  })

  it("both parties sign state: s1", async () => {
    s1sigA = await web3.eth.sign(partyA, web3.sha3(s1marshall, {encoding: 'hex'}))
    s1sigB = await web3.eth.sign(partyB, web3.sha3(s1marshall, {encoding: 'hex'}))
  })

  it("generate ether channel payment", async () => {
    var subchannelInputs = []
    subchannelInputs.push(0) // is close
    subchannelInputs.push(0) // is force push channel
    subchannelInputs.push(1) // subchannel sequence
    subchannelInputs.push(0) // timeout length ms
    subchannelInputs.push(paymentchanneladdress) // ether payment interpreter library address
    subchannelInputs.push(ethChannelID) // ID of subchannel
    subchannelInputs.push(metachannelCTFaddress) // counterfactual metachannel address
    subchannelInputs.push(reg.address) // CTF registry address
    subchannelInputs.push('0x0') // subchannel tx roothash
    subchannelInputs.push(partyA) // partyA in the subchannel
    subchannelInputs.push(partyB) // partyB in the subchannel
    subchannelInputs.push(web3.toWei(1, 'ether')) // balance of party A in subchannel (ether)
    subchannelInputs.push(web3.toWei(9, 'ether')) // balance of party B in subchannel (ether)

    ss1 = subchannelInputs
    ss1marshall = Utils.marshallState(subchannelInputs)
    
    var hash = web3.sha3(s1marshall, {encoding: 'hex'})
    var buf = Utils.hexToBuffer(hash)
    // TODO: deal with all subchannels stored as elems array, and how to replace
    // each channel independently when they are updated
    var elems = []
    elems.push(buf)
    var merkle = new MerkleTree(elems)

    subchannelRootHash = Utils.bufferToHex(merkle.getRoot())

    //console.log(merkle.root())

    var inputs = []
    inputs.push(0) // is close
    inputs.push(2) // sequence
    inputs.push(partyA) // partyA address
    inputs.push(partyB) // partyB address
    inputs.push(metachannelCTFaddress) // counterfactual metachannel address
    inputs.push(subchannelRootHash) // sub-channel root hash
    inputs.push(web3.toWei(10, 'ether')) // balance in ether partyA
    inputs.push(web3.toWei(10, 'ether')) // balance in ether partyB

    s2 = inputs
    s2marshall = Utils.marshallState(inputs)    
  })

  it("both parties sign state: s2", async () => {
    s2sigA = await web3.eth.sign(partyA, web3.sha3(s2marshall, {encoding: 'hex'}))
    s2sigB = await web3.eth.sign(partyB, web3.sha3(s2marshall, {encoding: 'hex'}))
  })

  it("generate close channel state", async () => {
    var inputs = []
    inputs.push(1) // is close
    inputs.push(3) // sequence
    inputs.push(partyA) // partyA address
    inputs.push(partyB) // partyB address
    inputs.push(metachannelCTFaddress) // counterfactual metachannel address
    inputs.push('0x0') // sub-channel root hash
    inputs.push(web3.toWei(11, 'ether')) // balance in ether partyA
    inputs.push(web3.toWei(19, 'ether')) // balance in ether partyB

    s3 = inputs
    s3marshall = Utils.marshallState(inputs)    
  })

  it("both parties sign state: s3", async () => {
    s3sigA = await web3.eth.sign(partyA, web3.sha3(s3marshall, {encoding: 'hex'}))
    s3sigB = await web3.eth.sign(partyB, web3.sha3(s3marshall, {encoding: 'hex'}))

    //     // bytes memory prefix = "\x19Ethereum Signed Message:\n32";
    //     // bytes32 h = keccak256(_d);

    //     // bytes32 prefixedHash = keccak256(prefix, h);

    //     // address a = ecrecover(prefixedHash, _v, _r, _s);

    // let state = '0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001e8524370b7caf8dc62e3effbca04ccc8e493ffe0000000000000000000000004c88305c5f9e4feb390e6ba73aaef4c64284b7bc2ac9e9cc73b053f1000bd69f308f0cee94e1894b6fe8f49ca8d3f63c9fb135d80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000016345785d8a000000000000000000000000000000000000000000000000000002c68af0bb140000'
    // s3sigA = await web3.eth.sign(accounts[0], web3.sha3(state, {encoding: 'hex'}))

    // let stateHash = web3.sha3(state, {encoding: 'hex'})
    // //stateHash = web3.sha3(stateHash, {encoding: 'hex'})
    // //let h = web3.sha3(prefix+stateHash, {encoding: 'hex'})

    // //let msg = Utils.hexToBuffer(stateHash)
    // let msg = Utils.hexToBuffer(stateHash)
    // //let prefix = Buffer.from('\u0019Ethereum Signed Message:\n' + msg.length.toString(), 'utf-8')
    // //let msgHash = ethutil.sha3(Buffer.concat([prefix, msg]))
    // let msgHash = ethutil.hashPersonalMessage(msg)
    // //console.log(msgHash)
    // let h = web3.sha3('\x19Ethereum Signed Message:\n' + stateHash.length.toString() + stateHash)

    // let s1 = ethutil.ecsign(msgHash, new Buffer('c87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3', 'hex'))

    // console.log(s3sigA)
    // console.log(ethutil.toRpcSig(s1.v, s1.r, s1.s))
    // let rec = ethutil.ecrecover(ethutil.sha3(Buffer.from(`\x19Ethereum Signed Message:\n`+(s3marshall.length)+s3marshall, 32)), s1.v, s1.r, s1.s)
    // console.log(web3.sha3(Utils.bufferToHex(rec), {encoding: 'hex'}))
    //     // 0x0000000000000000000000000000000000000000000000000000000000000001
    //     // 0x0000000000000000000000000000000000000000000000000000000000000003
    //     // 0x000000000000000000000000f17f52151ebef6c7334fad080c5704d77216b732
    //     // 0x000000000000000000000000c5fdf4076b8f3a5357c5e395ab970b5b54098fef
    //     // 0x89c1aaef79c7f1b8ab4457d60de98a5cb7194b3ed1ed288e6c9a8653aca0d547
    //     // 0x0000000000000000000000000000000000000000000000000000000000000000
    //     // 0x00000000000000000000000000000000000000000000000098a7d9b8314c0000
    //     // 0x00000000000000000000000000000000000000000000000107ad8f556c6c0000
  })

  it("closes the channel", async () => {
    var r = s3sigA.substr(0,66)
    var s = "0x" + s3sigA.substr(66,64)
    var v = parseInt(s3sigA.substr(130, 2)) + 27

    var r2 = s3sigB.substr(0,66)
    var s2 = "0x" + s3sigB.substr(66,64)
    var v2 = parseInt(s3sigB.substr(130, 2)) + 27

    var sigV = []
    var sigR = []
    var sigS = []

    sigV.push(v)
    sigV.push(v2)
    sigR.push(r)
    sigR.push(r2)
    sigS.push(s)
    sigS.push(s2)

    var balA = await web3.fromWei(web3.eth.getBalance(accounts[1]), 'ether')
    var balB = await web3.fromWei(web3.eth.getBalance(accounts[2]), 'ether')
    //console.log('Balance A before close: ' + balA)
    //console.log('Balance B before close: ' + balB)

    var receipt = await msig.closeAgreement(s3marshall, sigV, sigR, sigS)
    var gasUsed = receipt.receipt.gasUsed
    //console.log('Gas Used: ' + gasUsed)

    balA = await web3.fromWei(web3.eth.getBalance(accounts[1]), 'ether')
    balB = await web3.fromWei(web3.eth.getBalance(accounts[2]), 'ether')
    //console.log('Balance A after close: ' + balA)
    //console.log('Balance B after close: ' + balB)
  })
})