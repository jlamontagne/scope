'use strict';

const Hoek = require('hoek');
const Wreck = require('wreck');

class Route {
  constructor(method, path) {
    this.info = {
      method,
      path,
      pinned: null,
      responses: [],
    };
  }

  addResponse(response) {
    const headers = Hoek.clone(response.headers);
    delete headers['content-length'];

    return new Promise((resolve, reject) => {
      Wreck.read(response, null, (error, payload) => {
        if (error) {
          return reject(error);
        }

        this.info.responses.push({
          headers,
          payload: payload.toString(),
        });

        // Keep up to 10 recent responses
        const trim = this.info.responses.length - 10;
        if (trim > 0) {
          this.info.responses.splice(0, trim);
        }

        return resolve(this.info);
      });
    });
  }

  getResponses() {
    return this.info.responses;
  }

  pinResponse(response) {
    this.info.pinned = response;
    return this.info;
  }

  unpinResponse() {
    this.info.pinned = null;
    return this.info;
  }

  getPinnedResponse() {
    return this.info.pinned;
  }

  clearResponses() {
    this.info.responses = [];
    return this.info;
  }
}

module.exports = Route;
