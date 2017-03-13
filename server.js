'use strict';

const Boom = require('boom');
const Hapi = require('hapi');
const inert = require('inert');

const Tap = require('./tap');

const SCOPE_ADDR = process.env.SCOPE_ADDR || '127.1.1.1';
const server = new Hapi.Server();

let lastId = 0;

server.app.taps = Object.create(null);

server.connection({
  address: SCOPE_ADDR,
  port: 8080,
  labels: 'scope',
});

function removeTap(id) {
  const tap = server.app.taps[id];
  return tap.server.stop().then(() => {
    delete server.app.taps[id];
  });
}

module.exports = server.register(inert)
.then(() => {
  server.route({
    method: 'GET',
    path: '/',
    handler: (request, reply) => {
      reply.file('public/index.html');
    },
  });

  server.route({
    method: 'GET',
    path: '/taps',
    handler: (request, reply) => reply(Object.keys(server.app.taps).map(key =>
      server.app.taps[key].info
    )),
  });

  server.route({
    method: 'GET',
    path: '/tap/{id}',
    handler: (request, reply) => {
      const tap = server.app.taps[request.params.id];
      if (!tap) {
        return reply(Boom.notFound('tap'));
      }

      return reply(tap.info);
    },
  });

  server.route({
    method: 'GET',
    path: '/tap/{id}/routes',
    handler: (request, reply) => {
      const tap = server.app.taps[request.params.id];
      if (!tap) {
        return reply(Boom.notFound('tap'));
      }

      return reply(Object.keys(tap.routes).map(key => tap.routes[key].info));
    },
  });

  server.route({
    method: 'POST',
    path: '/tap/{id}/pinned',
    handler: (request, reply) => {
      const opts = request.payload;
      const tap = server.app.taps[request.params.id];
      if (!tap) {
        return reply(Boom.notFound('tap'));
      }

      tap.pinResponse(opts.method, opts.path, opts.response);

      return reply();
    },
  });

  server.route({
    method: 'DELETE',
    path: '/tap/{id}/pinned',
    handler: (request, reply) => {
      const opts = request.payload;
      const tap = server.app.taps[request.params.id];
      if (!tap) {
        return reply(Boom.notFound('tap'));
      }

      tap.unpinResponse(opts.method, opts.path);

      return reply();
    },
  });

  server.route({
    method: 'POST',
    path: '/tap',
    handler: (request, reply) => {
      const id = ++lastId; // eslint-disable-line no-plusplus
      const opts = request.payload;
      const tap = new Tap(id, opts.address, opts.port, opts.label);

      tap.start().then(() => {
        server.app.taps[id] = tap;
        reply(tap.info);
      }, err => reply(Boom.badRequest(err)));
    },
  });

  server.route({
    method: 'DELETE',
    path: '/tap/{id}',
    handler: (request, reply) => {
      removeTap(request.params.id)
      .then(() => reply())
      .catch(err => reply(Boom.badRequest(err)));
    },
  });

  return server;
});
