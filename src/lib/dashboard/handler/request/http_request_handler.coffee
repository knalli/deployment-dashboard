Q = require 'q'
http = require 'http'
https = require 'https'


singleRequestFn = (config) ->
  deferred = Q.defer()
  try
    request = (if config.port is 443 then https else http).request config, (response) ->
      result = ''
      response.on 'data', (chunk) ->
        result += chunk
      response.on 'end', ->
        deferred.resolve result
    request.on 'error', (err) ->
      deferred.reject err
    request.end()
  catch e
    deferred.reject e
  return deferred.promise

multiRequestFn = (configs) ->
  deferred = Q.defer()
  promises = []
  for config in configs
    promises.push singleRequestFn(config)
  Q.allSettled(promises).then (results) ->
    wrapperResult = []
    for result in results
      if result.state is 'fulfilled'
        wrapperResult.push result.value
      else
        wrapperResult.push (error: result.reason)
    deferred.resolve wrapperResult
  return deferred.promise


# Export class
module.exports =
  id: 'HTTP'
  handler: ({emitter, cluster, host, options}) ->
    if options.request
      singleRequestFn options.request
    else if options.requests
      multiRequestFn options.requests
    else
      Q.when false