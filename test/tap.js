/* eslint-env node, mocha */

'use strict';

const assert = require('assert');
const Hapi = require('hapi');
const Tap = require('../tap');

describe('tap', () => {
  let echoServer;
  let apiUri;
  let apiRequest;
  let tap;

  before(() => {
    // Simple reversing echo server
    echoServer = new Hapi.Server();
    const connection = echoServer.connection({
      address: '127.0.0.1',
      host: 'localhost',
    });
    echoServer.route({
      method: 'POST',
      path: '/echo',
      handler: (request, reply) => {
        apiRequest = request;
        const reverse = request.payload.test.split('').reverse().join('');
        reply(reverse).header('x-reversed', 'yup');
      },
    });

    echoServer.start().then(() => {
      apiUri = connection.info.uri;
      tap = new Tap(1, apiUri, 9001, 'api-tap');
      return tap.start();
    });
  });

  describe('#addRoute', () => {
    it('returns a route', () => {
      const route = tap.addRoute('GET', '/foo');
      assert.deepEqual(route.info, {
        method: 'GET',
        path: '/foo',
        pinned: null,
        responses: [],
      });
    });
  });

  describe('#getRoute', () => {
    beforeEach(() => {
      tap.addRoute('GET', '/foo');
    });

    it('returns a route', () => {
      const route = tap.getRoute('GET', '/foo');
      assert.deepEqual(route.info, {
        method: 'GET',
        path: '/foo',
        pinned: null,
        responses: [],
      });
    });

    describe('when the route doesn\'t exist', () => {
      it('returns null', () => {
        assert.equal(tap.getRoute('GET', '/nope'), null);
      });
    });
  });

  describe('#pinResponse', () => {
    it('should pin the response on the route', () => {
      const response = tap.pinResponse('GET', '/foo', {
        headers: {},
        payload: 'foo',
      });

      assert.deepEqual(response, {
        method: 'GET',
        path: '/foo',
        pinned: {
          headers: {},
          payload: 'foo',
        },
        responses: [],
      });
    });

    describe('when the route doesn\'t exist', () => {
      it('should throw an error', () =>
        assert.throws(() => tap.pinResponse('GET', '/nope', {}))
      );
    });
  });

  describe('#unpinResponse', () => {
    beforeEach(() => tap.pinResponse('GET', '/foo', { payload: 'foo' }));

    it('should clear any pinned response on the route', () => {
      const response = tap.unpinResponse('GET', '/foo');

      assert.deepEqual(response, {
        method: 'GET',
        path: '/foo',
        pinned: null,
        responses: [],
      });
    });

    describe('when the route doesn\'t exist', () => {
      it('should throw an error', () =>
        assert.throws(() => tap.unpinResponse('GET', '/nope', {}))
      );
    });
  });

  describe('when a request is made to an unpinned endpoint', () => {
    let request;

    beforeEach(() => {
      request = {
        method: 'POST',
        url: '/echo',
        payload: { test: 'hello' },
        headers: {
          'x-foo': 'bar',
        },
      };
    });

    afterEach(() => tap.clearAllResponses());

    it('should send the request headers to the API', () =>
      tap.server.inject(request).then(() => {
        assert.equal(apiRequest.headers['x-foo'], 'bar');
      })
    );

    it('should send the request payload to the API', () =>
      tap.server.inject(request).then(() => {
        assert.deepEqual(apiRequest.payload, { test: 'hello' });
      })
    );

    it('should return the headers from the API', () =>
      tap.server.inject(request).then((res) => {
        assert.deepEqual(res.headers['x-reversed'], 'yup');
      })
    );

    it('should return the payload from the API', () =>
      tap.server.inject(request).then((res) => {
        assert.equal(res.payload, 'olleh');
      })
    );

    it('should save the response', () =>
      tap.server.inject(request).then(() => {
        const responses = tap.getResponses('POST', '/echo');
        assert.equal(responses[0].payload, 'olleh');
      })
    );

    describe('#getResponses', () => {
      it('should return the responses', () =>
        tap.server.inject(request).then(() => {
          const responses = tap.getResponses('POST', '/echo');
          assert.equal(responses[0].payload, 'olleh');
        })
      );
    });

    describe('#clearResponses', () => {
      it('should clear the responses', () =>
        tap.server.inject(request).then(() => {
          const route = tap.clearResponses('POST', '/echo');
          assert.deepEqual(route.responses, []);
        })
      );
    });
  });

  describe('when multiple requests are made to an unpinned endpoint', () => {
    let request;

    beforeEach(() => {
      request = {
        method: 'POST',
        url: '/echo',
        payload: { test: null },
      };
    });

    afterEach(() => tap.clearAllResponses());

    it('should return each response from the API', () => {
      request.payload.test = 'one';
      tap.server.inject(request).then((res) => {
        assert.equal(res.payload, 'eno');
      });
      request.payload.test = 'two';
      tap.server.inject(request).then((res) => {
        assert.equal(res.payload, 'owt');
      });
    });

    describe('#getResponses', () => {
      it('should return the responses', () => {
        request.payload.test = 'one';
        return tap.server.inject(request).then(() => {
          request.payload.test = 'two';
          return tap.server.inject(request);
        }).then(() => {
          const responses = tap.getResponses('POST', '/echo');
          assert.equal(responses[0].payload, 'eno');
          assert.equal(responses[1].payload, 'owt');
        });
      });
    });

    describe('#clearAllResponses', () => {
      it('should clear all the responses', () => {
        request.payload.test = 'one';
        return tap.server.inject(request).then(() => {
          request.payload.test = 'two';
          return tap.server.inject(request);
        }).then(() => {
          tap.clearAllResponses();
          assert.deepEqual(tap.getResponses('POST', '/echo'), []);
        });
      });
    });
  });

  describe('when a response is pinned', () => {
    beforeEach(() => tap.pinResponse('POST', '/echo', {
      headers: { 'x-foo': 'bar' },
      payload: 'pinned',
    }));

    describe('and a request is made to the pinned endpoint', () => {
      let request;

      beforeEach(() => {
        request = {
          method: 'POST',
          url: '/echo',
          payload: { test: 'hello' },
          headers: {
            'x-foo': 'bar',
          },
        };
      });

      it('should return the pinned response headers', () =>
        tap.server.inject(request).then((res) => {
          assert.equal(res.headers['x-foo'], 'bar');
          assert.equal(res.headers['x-reversed'], undefined);
        })
      );

      it('should return the pinned payload', () =>
        tap.server.inject(request).then((res) => {
          assert.equal(res.payload, 'pinned');
        })
      );
    });
  });
});
