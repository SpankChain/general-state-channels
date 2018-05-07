const Buffer = require('buffer').Buffer
const util = require('ethereumjs-util')
const localUtils = require('./utils')

function combinedHash(first, second) {
  if(!second) {
    return first
  }
  if (!first) {
    return second
  }
  let sorted = Buffer.concat([first, second].sort(Buffer.compare))

  return util.sha3(sorted)
}

function deduplicate (buffers) {
  return buffers.filter((buffer, i) => {
    return buffers.findIndex(e => e.equals(buffer)) === i
  })
}

function getPair (index, layer) {
  let pairIndex = index % 2 ? index - 1 : index + 1
  if (pairIndex < layer.length) {
    return layer[pairIndex]
  } else {
    return null
  }
}

function getLayers (elements) {
  if (elements.length === 0) {
    return [[Buffer.from('')]]
  }
  let layers = []
  layers.push(elements)
  while (layers[layers.length - 1].length > 1) {
    layers.push(getNextLayer(layers[layers.length - 1]))
  }
  return layers
}

function getNextLayer (elements) {
  return elements.reduce((layer, element, index, arr) => {
    if (index % 2 === 0) {
      layer.push(combinedHash(element, arr[index + 1]))
    }
    return layer
  }, [])
}

export default class MerkleTree {

  constructor(_elements) {
    if(!_elements.every(localUtils.isHash)){
      throw new Error('elements must be 32 byte buffers')
    }
    const e = { elements: deduplicate(_elements) }
    Object.assign(this, e)
    this.elements.sort(Buffer.compare)

    const l = { layers: getLayers(this.elements) }
    Object.assign(this, l)
  }

  getRoot() {
    if(!this.root) {
      let r = { root:this.layers[this.layers.length - 1][0] }
      Object.assign(this, r)
    }
    return this.root
  }

  verify(proof, element) {
    return this.root.equals(proof.reduce((hash, pair) => combinedHash(hash, pair), element))
  }

  proof(element) {
    let index = this.elements.findIndex(e => e.equals(element))
    if (index === -1) {
      throw new Error('element not found in merkle tree')
    }

    return this.layers.reduce((proof, layer) => {
      let pair = getPair(index, layer)
      if (pair) {
        proof.push(pair)
      }
      index = Math.floor(index / 2)
      return proof
    }, [])
  }

}