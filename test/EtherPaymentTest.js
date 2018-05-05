'use strict'

// Bi-direction Ether Payment Channel Tests

//const utils = require('./helpers/utils')
const Utils = require('./helpers/utils')

const MultiSig = artifacts.require("./MultiSig.sol")
const Registry = artifacts.require("./CTFRegistry.sol")
const MetaChannel = artifacts.require("./MetaChannel.sol")

// Interpreters / Extension
const CTFPaymentChannel = artifacts.require("./LibBidirectionalEther.sol")
const EtherExtension = artifacts.require("./EtherExtension.sol")

// State
let reg
let msig
let ethExtInst
let ethExtAddress

let partyA
let partyB

let metachannel
let metaChannelBytecode
let metachannelCTFaddress

// sig storage
let metachannelCTFsigA
let metachannelCTFsigB
let s0sigA
let s0sigB
let s1sigA
let s1sigB
let s2sigA
let s2sigB

// state storage
let metaCTF
let s0
let s1
let s2
let s3

contract('Test Ether Payments', function(accounts) {

  before(async () => {
    partyA = accounts[1]
    partyB = accounts[2]

    reg = await Registry.new()
  })

  it("counterfactually instantiate meta-channel", async () => {
    // TODO: Use web3 to get predeployed bytecode with appended constructor args
    var args = [reg.address, partyA, partyB]
    var signers = [partyA, partyB]

    metachannel = await MetaChannel.new(reg.address, partyA, partyB)
    metaCTF = await Utils.getCTFstate(metachannel, signers, args)
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
    // We zero out the eth extension for now
    //ethExt = '0x0'
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

    s0 = Utils.compileState(inputs)
  })

  it("partyA signs state and opens msig agreement", async () => {
    s0sigA = await web3.eth.sign(partyA, web3.sha3(s0, {encoding: 'hex'}))
    var r = s0sigA.substr(0,66)
    var s = "0x" + s0sigA.substr(66,64)
    var v = parseInt(s0sigA.substr(130, 2)) + 27

    var receipt = await msig.openAgreement(s0, ethExtAddress, v, r, s, {from: accounts[1], value: web3.toWei(10, 'ether')})
    var gasUsed = receipt.receipt.gasUsed
    //console.log('Gas Used: ' + gasUsed)
    var t = await msig.partyA()

    console.log(t)
    console.log(partyA)
  })

  // it("partyA signs state and opens msig agreement", async () => {
  //   s0sigA = await web3.eth.sign(partyA, web3.sha3(s0, {encoding: 'hex'}))
  //   var r = s0sigA.substr(0,66)
  //   var s = "0x" + s0sigA.substr(66,64)
  //   var v = parseInt(s0sigA.substr(130, 2)) + 27

  //   var receipt = await msig.openAgreement(s0, ethExt, v, r, s, {from: accounts[1], value: web3.toWei(10, 'ether')})
  //   var gasUsed = receipt.receipt.gasUsed
  //   //console.log('Gas Used: ' + gasUsed)
  // })

})