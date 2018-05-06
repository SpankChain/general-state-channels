module.exports = {
  latestTime: function latestTime() {
    return web3.eth.getBlock('latest').timestamp
  },

  increaseTime: function increaseTime(duration) {
    const id = Date.now()

    return new Promise((resolve, reject) => {
      web3.currentProvider.sendAsync({
        jsonrpc: '2.0',
        method: 'evm_increaseTime',
        params: [duration],
        id: id,
      }, e1 => {
        if (e1) return reject(e1)

        web3.currentProvider.sendAsync({
          jsonrpc: '2.0',
          method: 'evm_mine',
          id: id+1,
        }, (e2, res) => {
          return e2 ? reject(e2) : resolve(res)
        })
      })
    })
  },

  increaseTimeTo: function increaseTimeTo(target) {
    let now = this.latestTime()
    if (target < now) throw Error(`Cannot increase current time(${now}) to a moment in the past(${target})`)
    let diff = target - now
    return this.increaseTime(diff)
  },

  assertThrowsAsync: async function assertThrowsAsync(fn, regExp) {
    let f = () => {};
    try {
      await fn();
    } catch(e) {
      f = () => {throw e};
    } finally {
      assert.throws(f, regExp);
    }
  },

  duration: {
    seconds: function(val) { return val},
    minutes: function(val) { return val * this.seconds(60) },
    hours:   function(val) { return val * this.minutes(60) },
    days:    function(val) { return val * this.hours(24) },
    weeks:   function(val) { return val * this.days(7) },
    years:   function(val) { return val * this.days(365)}
  },

  getBytes: function getBytes(input) {
    if(66-input.length <= 0) { return web3.toHex(input) }
    return this.padBytes32(web3.toHex(input))
  },

  marshallState: function marshallState(inputs) {
    var m = this.getBytes(inputs[0])

    for(var i=1; i<inputs.length;i++) {
      m += this.getBytes(inputs[i]).substr(2, this.getBytes(inputs[i]).length)
    }
    return m
  },

  getCTFaddress: async function getCTFaddress(_r) {
    return web3.sha3(_r, {encoding: 'hex'})
  },

   getCTFstate: async function getCTFaddress(_contract, _signers, _args) {
    _args.unshift(_contract.constructor.bytecode)
    var _m = this.marshallState(_args)
    _signers.push(_m)
    var _r = this.marshallState(_signers)
    return _r
  }, 

  padBytes32: function padBytes32(data){
    // TODO: check input is hex / move to TS
    let l = 66-data.length

    let x = data.substr(2, data.length)

    for(var i=0; i<l; i++) {
      x = 0 + x
    }
    return '0x' + x
  },

  rightPadBytes32: function rightPadBytes32(data){
    let l = 66-data.length

    for(var i=0; i<l; i++) {
      data+=0
    }
    return data
  }
}