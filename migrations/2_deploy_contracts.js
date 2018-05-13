const MultiSig = artifacts.require("./MultiSig.sol")
const Registry = artifacts.require("./CTFRegistry.sol")
const MetaChannel = artifacts.require("./MetaChannel.sol")

// Interpreters / Extension
const PaymentChannel = artifacts.require("./LibBidirectionalEther.sol")
const EtherExtension = artifacts.require("./EtherExtension.sol")

module.exports = async function(deployer) {
  let eth = await EtherExtension.new()
  console.log('ether extension address: ' + eth.address)

  let pay = await PaymentChannel.new()
  console.log('Bidirectional Ether interpreter address: ' + pay.address)
}