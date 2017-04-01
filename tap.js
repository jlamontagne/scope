'use strict';

const fs = require('fs');
const url = require('url');
const h2o2 = require('h2o2');
const Hapi = require('hapi');
const Route = require('./route');

const SCOPE_ADDR = process.env.SCOPE_ADDR || '127.1.1.1';

function routeKey(method, path) {
  if (path.charAt(0) === '/') {
    return `${method.toLowerCase()}__${path}`;
  }

  return `${method.toLowerCase()}__/${path}`;
}

class Tap {
  constructor(id, address, port, label) {
    const parts = url.parse(address);
    const labels = ['tap'];

    let tls;

    if (parts.protocol.includes('https')) {
      tls = {
        key: fs.readFileSync('.key.pem'),
        cert: fs.readFileSync('.cert.pem'),
      };
    }

    if (label) {
      labels.push(label);
    }

    // Separate server so we can easily shut it down later.
    this.server = new Hapi.Server();

    this.server.connection({
      address: SCOPE_ADDR,
      port,
      labels,
      tls,
    });

    this.routes = Object.create(null);

    this.info = {
      id,
      address,
      port,
      label,
    };
  }

  addRoute(method, path) {
    const key = routeKey(method, path);
    const route = new Route(method, path);
    this.routes[key] = route;
    console.log(`[tap:${this.info.label}] created route: ${method} ${path}`);
    return route;
  }

  getRoute(method, path) {
    const key = routeKey(method, path);
    return this.routes[key];
  }

  getResponses(method, path) {
    const route = this.getRoute(method, path);
    if (route) {
      return route.getResponses();
    }

    return null;
  }

  pinResponse(method, path, response) {
    const route = this.getRoute(method, path);
    if (!route) {
      throw new Error(`No route for ${method} ${path}`);
    }

    return route.pinResponse(response);
  }

  unpinResponse(method, path) {
    const route = this.getRoute(method, path);
    if (!route) {
      throw new Error(`No route for ${method} ${path}`);
    }

    return route.unpinResponse();
  }

  clearResponses(method, path) {
    const route = this.getRoute(method, path);
    if (!route) {
      throw new Error(`No route for ${method} ${path}`);
    }

    return route.clearResponses();
  }

  clearAllResponses() {
    Object.keys(this.routes).forEach(key => this.routes[key].clearResponses());
  }

  start() {
    return this.server.register(h2o2).then(() => {
      this.server.route({
        method: '*',
        path: '/{path*}',
        config: {
          pre: [(request, reply) => {
            // FIXME support root path
            // console.log(request);
            // console.log(`method: ${request.method}, path: ${request.params.path}`);
            let route = this.getRoute(request.method, request.params.path);
            if (!route) {
              route = this.addRoute(request.method, request.params.path);
            }

            const pinnedResponse = route.getPinnedResponse();

            if (pinnedResponse) {
              const response = reply(pinnedResponse.payload);

              Object.keys(pinnedResponse.headers).forEach(name =>
                response.header(name, pinnedResponse.headers[name])
              );

              // We reply immediately here with the pinned response
              return response.takeover();
            }

            // Otherwise we continue as normal
            return reply();
          }],
        },
        handler: {
          proxy: {
            // Disable encodings so we can inspect responses
            acceptEncoding: false,
            passThrough: true,
            // Ignore SSL certificate errors
            rejectUnauthorized: false,
            mapUri: (req, callback) => {
              const uri = `${this.info.address}/${req.params.path}${req.url.search}`;
              callback(null, uri);
            },
            onResponse: (err, response, request, reply) => {
              if (err) {
                this.server.log(['error'], err);
              }

              reply(response);

              const route = this.getRoute(request.method, request.params.path);
              route.addResponse(response);
            },
          },
        },
      });
    })
    .then(() => this.server.start())
    .then(() => this.logStarted())
    .then(() => this);
  }

  logStarted() {
    const conn = this.server.info;
    const addr = `${conn.protocol}://${conn.address}:${conn.port}`;
    const label = this.info.label;
    console.log(`[tap:${label}] created: ${addr} -> ${this.info.address}`);
  }
}

module.exports = Tap;
