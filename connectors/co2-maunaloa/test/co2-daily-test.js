var processLine = require('../co2-daily').processLine;
var assert = require('assert');

describe('processLine', function () {
  it('single line with valid input', function () {
    let line = "  2000 1 9 123.45   232  ";
    let res = {
      t: 9,
      y: 123.45,
      year: 2000
    }
    let result = processLine(line);
    console.log(result)
    assert.deepEqual(res, result)
  });
  it('invalid year should return null', function () {
    let line = "  2021 1 9 123.45   232  ";
    assert.deepEqual(null, processLine(line))
  })
  it('invalid year in the past should return null', function () {
    let line = "1700 1 9 123.45   232  ";
    assert.deepEqual(null, processLine(line))
  })
  it('invalid month should return null', function () {
    let line = "2019 13 9 123.45   232  ";
    assert.deepEqual(null, processLine(line))
  })
  it('invalid day should return null', function () {
    let line = "  2020 1 32 123.45   232  ";
    assert.deepEqual(null, processLine(line))
  })
})

