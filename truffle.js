require('dotenv').config();
require('babel-register');
require('babel-polyfill');

module.exports = {
    networks: {
        development: {
            host: 'localhost',
            port: 8545,
            network_id: '*',
        },
        testrpc: {
            host: 'localhost',
            port: 8545,
            network_id: '*',
        },
        ganache: {
            host: 'localhost',
            port: 7545,
            network_id: '*',
        },
    },
};