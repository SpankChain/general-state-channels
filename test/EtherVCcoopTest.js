'use strict'

// Bi-direction Ether Payment Channel Tests

import MerkleTree from './helpers/MerkleTree'

const MultiSig = artifacts.require("./MultiSig.sol")
const Registry = artifacts.require("./CTFRegistry.sol")
const MetaChannel = artifacts.require("./MetaChannel.sol")

// Interpreters / Extension
const VirtualChannel = artifacts.require("./LibVirtualEthChannel.sol")
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
let virtualchannel
let virtualchanneladdress

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