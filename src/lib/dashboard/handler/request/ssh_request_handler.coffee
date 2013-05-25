util = require 'util'
Q = require 'q'
SshConnection = require 'ssh2'
fs = require 'fs'


###
  Convenient method.

  This wraps the commandLine into a dedicated ssh command.

  Returns a new command line (string).
###
wrapCommandInViaRouting = (commandLine, host) ->
  "ssh #{host} \"#{commandLine}\""

###
  Convenient method.

  This executes the $commandLine at the given $connection and stores the result
  into the $result[resultId].

  Return is a Promise.
###
execCommandLineAndResolve = (connection, commandLine, resultId, result) ->
  deferred = Q.defer()
  connection.exec commandLine, (err, stream) ->
    throw err if err
    stream.on 'data', (data, extended) ->
      if extended isnt 'stderr'
        result[resultId] += data
      return
    stream.on 'exit', deferred.resolve
  return deferred.promise

###
  Convenient method.

  * A ssh connection will be built up for the given $username@$host:$port.
  * If a $privateKeyLocation is given, it will be used.
  * Otherwise a $password should be provided.
  * Each given commandLine in $commandLines will be performed.
  * Neither the order of executions nor the single request can be garantued.

  Returns a Promise.
###
handlerFn = ({emitter, host, via, port, username, password, privateKeyLocation, commandLines}) ->
  # Build up the result array (for n commands, there will be n result items).
  result = ('' for commandLine in commandLines)
  # Determine the real target host for a physical connection.
  targetHost = via?.host or host

  # Main Deferred
  deferred = Q.defer()

  connection = new SshConnection()
  connection.on 'error', ( (err) ->
    emitter.emit("log.plugin.request.ssh.connection.failed", err.message) if emitter
    deferred.reject err
    return
  )
  connection.on 'end', (->
    emitter.emit("log.plugin.request.ssh.connection.closed") if emitter
    deferred.resolve(result)
  )
  connection.on 'ready', (->
    emitter.emit("log.plugin.request.ssh.connection.open") if emitter
    promises = []
    for commandLine, resultId in commandLines
      # Wrap commandline with inline ssh if this is required.
      commandLine = wrapCommandInViaRouting(commandLine, host) if via?.host
      promises.push execCommandLineAndResolve connection, commandLine, resultId, result

    # Close connection of all promises are resolved (regardless with success or failure).
    Q.allSettled(promises).then ->
      # If all command promises are resolved, we can terminate the connection.
      # This will implictly fire the connection.end event.
      connection.end()
  )

  try
    connection.connect
      host: targetHost
      port: port or 22
      username: username
      password: password
      privateKey: if privateKeyLocation then fs.readFileSync(privateKeyLocation)
  catch e
    deferred.reject e

  return deferred.promise


module.exports =
  id: 'SSH'
  handler: ({emitter, cluster, host, options}) ->
    config =
      emitter: emitter
      host: host.hostname
      via: if host.connectivity?.hostname then (host: host.connectivity?.hostname)
      port: host.connectivity?.port or host.port
      username: host.connectivity?.credentials?.username or host.credentials?.username
      password: host.connectivity?.credentials?.password or host.credentials?.password
      privateKeyLocation: host.connectivity?.credentials?.privateKeyLocation or host.credentials?.privateKeyLocation
      commandLines: options.commands
    return handlerFn(config)