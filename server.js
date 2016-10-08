'use strict';

const base = 'https://localhost:7777';

const Hapi = require('hapi');
const fs = require('fs');
const good = require('good');
const h2o2 = require('h2o2');
const server = new Hapi.Server();

server.connection({
  port: 7778,
  tls: {
    key: fs.readFileSync('.key.pem'),
    cert: fs.readFileSync('.cert.pem'),
  },
});

server.register({
  register: h2o2,
}).then(() => {
  return server.register({
    register: good,
    options: {
      reporters: {
        toConsole: [{
          module: 'good-squeeze',
          name: 'Squeeze',
          args: [{
            log: '*',
            response: '*',
          }]
        }, {
          module: 'good-console'
        }, 'stdout']
      }
    }
  });
}).then(() => {
  server.route({
    method: '*',
    path: '/{path*}',
    handler: {
      proxy: {
        passThrough: true,
        rejectUnauthorized: false,
        mapUri: (request, callback) => {
          const redirect = `${base}/${request.params.path}${request.url.search}`;
          callback(null, redirect);
        },
      },
    },
  });

  server.start(err => {
    if (err) {
      throw err;
    }

    console.log(`Server running at: ${server.info.uri}`);
  });
}).catch(err => {
  console.log(err);
});
