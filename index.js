'use strict';

const serverPromise = require('./server');

serverPromise.then(server =>
  server.start()
  .then(() => {
    const scope = server.select('scope');
    const protocol = scope.info.protocol;
    const address = scope.info.address;
    const port = scope.info.port;
    console.log(`Scope interface: ${protocol}://${address}:${port}`);
  })
)
.catch(err => console.log(err)); // eslint-disable-line no-console
