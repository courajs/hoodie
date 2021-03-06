module.exports.register = register
module.exports.register.attributes = {
  name: 'hoodie-public',
  dependencies: 'inert'
}

var fs = require('fs')
var path = require('path')

var relative = require('require-relative')

function register (server, options, next) {
  var app = path.join(options.config.paths.public, 'index.html')
  var hoodieVersion
  try {
    hoodieVersion = relative(
      'hoodie/package.json',
      process.cwd()
    ).version
  } catch (err) {
    hoodieVersion = 'development'
  }

  server.route([{
    method: 'GET',
    path: '/{p*}',
    handler: {
      directory: {
        path: options.config.paths.public,
        listing: false,
        index: true
      }
    }
  }, {
    method: 'GET',
    path: '/hoodie',
    handler: function (request, reply) {
      reply({
        hoodie: true,
        name: options.config.name,
        version: hoodieVersion
      })
    }
  }, {
    method: 'GET',
    path: '/hoodie/client.js',
    handler: {
      file: path.join(options.config.paths.data, 'client.js')
    }
  }, {
    method: 'GET',
    path: '/hoodie/client.min.js',
    handler: {
      file: path.join(options.config.paths.data, 'client.min.js')
    }
  }])

  // serve app whenever an html page is requested
  // and no other document is available
  // TODO: do not serve app when request.path starts with `/hoodie/`
  server.ext('onPostHandler', function (request, reply) {
    var response = request.response

    if (!response.isBoom) {
      return reply.continue()
    }

    var is404 = response.output.statusCode === 404
    var isHTML = /text\/html/.test(request.headers.accept)

    // We only care about 404 for html requests...
    if (!is404 || !isHTML) {
      return reply.continue()
    }

    // Serve index.html
    reply(fs.createReadStream(app))
  })

  return next()
}
