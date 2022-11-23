var covid = require('../covid2.js');
var assert = require('assert');

// --- Population Lookup Table ---
describe('Population Lookup Table', function () {
  it('no arguments should return 1', function () {
    assert.equal(1, covid.p());
  });
  it('null argument should return 1', function () {
    assert.equal(1, covid.p(null));
  });
  it('invalid argument should return 1', function () {
    assert.equal(1, covid.p({ x: 1, y: 2 }));
  });
  it('string not in table should return 1', function () {
    let s = "Random String";
    assert.equal(1, covid.p(s));
  });
  it('Norwy should return 5378857', function () {
    assert.equal(5378857, covid.p("Norway"));
  });
  it('Ivory Coast should return 25716544', function () {
    assert.equal(25716544, covid.p("Cote d'Ivoire"));
  });
});

// --- Name Lookup Table ---
describe('Country Name Lookup Table', function () {
  it('no arguments should return undefined', function () {
    assert.equal(undefined, covid.countryName());
  });
  it('null should return null', function () {
    assert.equal(null, covid.countryName(null));
  });
  it('Taiwan* should return Taiwan', function () {
    assert.equal("Taiwan", covid.countryName("Taiwan*"));
  });
});

// --- RegionList ---
describe('RegionList', function () {
  it('no arguments should return empty list', function () {
    assert.deepEqual([], covid.regionList());
  });
  it('null should return empty list', function () {
    assert.deepEqual([], covid.regionList(null));
  });
  it('Invalid region name should return empty list', function () {
    assert.deepEqual([], covid.regionList("Jalla Jalla"));
    assert.deepEqual([], covid.regionList(""));
    assert.deepEqual([], covid.regionList({ x: 1 }));
    assert.deepEqual([], covid.regionList(10));
  });
  it('Asia and Europe should return lists of reasonable lengths', function () {
    let list = covid.regionList("Asia");
    console.log(list.length);
    assert.ok(list.length > 50 && list.length < 60);
    assert.ok(['Japan', 'Thailand', 'Brunei', 'Nepal'].every(x => list.includes(x)));

    list = covid.regionList("Europe");
    console.log(list.length);
    assert.ok(list.length > 50 && list.length < 60);
    assert.ok(['Norway', 'UK', 'France', 'Estonia'].every(x => list.includes(x)));

    list = covid.regionList("South America");
    console.log(list.length);
    assert.ok(list.length > 10 && list.length < 20);
    assert.ok(['Colombia', 'Brazil', 'Chile', 'Paraguay'].every(x => list.includes(x)));
  });
});

// --- smoothData ---
describe('smoothData', function () {
  it('no arguments should return null', function () {
    assert.equal(null, covid.smoothData());
  });
  it('null should return null', function () {
    assert.equal(null, covid.smoothData(null));
  });
  it('non-array input should return null', function () {
    assert.equal(null, covid.smoothData("string"));
    assert.equal(null, covid.smoothData(12345));
  });
  it('empty array argument should return null', function () {
    assert.equal(null, covid.smoothData([]));
  });
  it('if array length is 1 return the same with c: added to object', function () {
    assert.deepEqual([{ y: 1, c: 0 }], covid.smoothData([{ y: 1 }]));
  });
  it('if array length is 1 return the same with c: added to object', function () {
    assert.deepEqual([{ y: 1, c: 0 }], covid.smoothData([{ y: 1, c: 0 }]));
  });
  it('array length 2 return the same with c: added to object', function () {
    let i = [{ y: 1, c: 0 }, { y: 1, c: 0 }];
    assert.deepEqual([{ y: 1, c: 0 }, { y: 1, c: 0 }], covid.smoothData(i));
  });
  it('array length 2 return the same with c: added to object', function () {
    let i = [{ y: 1, c: 0 }, { y: 1, c: 0 }, { y: 1, c: 0 }];
    assert.deepEqual([{ y: 1, c: 0 }, { y: 1, c: 0 }, { y: 1, c: 0 }], covid.smoothData(i));
  });
});

// --- calculateWorld ---
describe('calculateworld', function () {
  let sweden = {
    country: 'Sweden',
    population: 9,
    data: [{ t: "2020-01-30", y: 2, d: 3 }]
  };
  let norway = {
    country: 'Norway',
    population: 4.5,
    data: [{ t: "2020-01-30", y: 10, d: 9 }]
  };
  let world = {
    country: 'World',
    population: 4.5,
    data: [{ t: "2020-01-30", y: 10, d: 9 }]
  };
  it('1 return null on empty input list', function () {
    assert.equal(null, covid.calculateWorld('World', []));
  });
  it('2 return null if null data array', function () {
    let n = {
      data: null
    };
    assert.equal(null, covid.calculateWorld('', n));
  });
  it('3 return null if empty data array', function () {
    let n = {
      data: []
    };
    assert.equal(null, covid.calculateWorld('', n));
  });
  it('4 input length = 1, make sure population is equal', function () {
    assert.equal(norway.population, covid.calculateWorld('', [norway]).population);
  });
  it('5 input length = 2, make sure population adds', function () {
    assert.equal(norway.population + norway.population, covid.calculateWorld('', [norway, norway]).population);
  });
  it('6 input length = 2, make sure population adds', function () {
    let result = covid.calculateWorld('', [norway, sweden]);
    assert.equal(norway.population + sweden.population, result.population);
  });
  it('7 input length = 1, make sure d and y are the same', function () {
    let result = covid.calculateWorld('', [norway]);
    assert.equal(norway.data[0].y, result.data[0].y);
    assert.equal(norway.data[0].d, result.data[0].d);
  });
  it('8 input length = 1, result should be the same except for name', function () {
    let result = {
      country: 'World',
      population: 4.5,
      data: [{ t: "2020-01-30", y: 10, d: 9 }]
    };
    assert.deepEqual(result, covid.calculateWorld('World', [norway]));
  });
  it('9 input length = 2, make sure everything adds', function () {
    norway.data = [{ t: "2020-01-30", y: 10, d: 9 }, { t: "2020-01-31", y: 1, d: 1 }, { t: "2020-02-01", y: 1, d: 1 }];
    sweden.data = [{ t: "2020-01-30", y: 11, d: 3 }, { t: "2020-01-31", y: 1, d: 1 }, { t: "2020-02-01", y: 1, d: 1 }];
    world.data = [{ t: "2020-01-30", y: 21, d: 12 }, { t: "2020-01-31", y: 2, d: 2 }, { t: "2020-02-01", y: 2, d: 2 }];
    world.population = norway.population + sweden.population;
    assert.deepEqual(world, covid.calculateWorld('World', [norway, sweden]));
  });
  it('10 input length = 10000, verify pop/d/y add up', function () {
    let a = [];
    let len = 10000;
    norway.data = [{ t: "2020-02-01", y: 2, d: 3 }];
    for (let x = 0; x < len; x++) {
      a.push(norway);
    }
    world.population = len * norway.population;
    world.data = [{ t: norway.data[0].t, y: len * norway.data[0].y, d: len * norway.data[0].d }];
    assert.deepEqual(world, covid.calculateWorld('World', a));
  });
});
