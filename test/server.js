/* eslint-env node, mocha */

'use strict';

const assert = require('assert');

let server;
let scope;

before(() =>
  require('../server') // eslint-disable-line global-require
  .then((_server) => {
    server = _server;
  })
);

beforeEach(() => {
  scope = server.select('scope');
});

describe('on start', () => {
  it('should have a scope connection', () => {
    assert(scope.connections.length === 1);
  });

  it('should have no tap connections', () => {
    const taps = server.select('tap');
    assert(taps.connections.length === 0);
  });
});

describe('scope', () => {
  describe('GET /', () => {
    it('should respond with the browser interface', () =>
      scope.inject({
        method: 'GET',
        url: '/',
      }).then((res) => {
        assert(res.payload.indexOf('<html>') >= 0);
        assert.equal(res.statusCode, 200);
      })
    );
  });

  describe('POST /tap', () => {
    it('should create a tap', () =>
      scope.inject({
        method: 'POST',
        url: '/tap',
        payload: {
          address: 'http://localhost:1234',
          port: 9000,
          label: 'blah',
        },
      }).then((res) => {
        const tap = JSON.parse(res.payload);
        assert.equal(res.statusCode, 200);
        assert(tap.id > 0, 'tap has an id');
        assert.equal(tap.label, 'blah');
        assert.equal(tap.port, 9000);
        assert.equal(tap.address, 'http://localhost:1234');
      })
    );
  });
});
