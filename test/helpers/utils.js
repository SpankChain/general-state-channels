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
  }
}