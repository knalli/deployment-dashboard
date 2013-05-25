Dashboard = require './dashboard'
Scheduler = require './scheduler'
get_request_handler = require './handler/request'

util = require 'util'
Q = require 'q'
{EventEmitter2} = require 'eventemitter2'

# Defaults
DEFAULTS = PORT: 3000


class App

  constructor : ->
    @dashboardRoomName = 'activities'
    @emitter = new EventEmitter2(wildcard: true, delimiter: '.', maxListeners: 100)
    @dashboard = new Dashboard(@emitter)

  init : ({interval, port, writeStateFile}) ->
    @interval = interval or undefined
    @port = port or DEFAULTS.PORT
    @dashboard.init()
    @express = require 'express'
    @app = @express()
    @server = require('http').createServer(@app)
    @io = require('socket.io').listen(@server)
    @io.set 'log level', 2

    # Write out the current dashboard state (debugging purpose).
    if writeStateFile
      @emitter.on 'app.scheduler.round.end', =>
        require('fs').writeFile 'dashboard-state-complete.json', JSON.stringify(@dashboard.getComplete()), (err) ->
          if err
            util.error 'NO SAVE', err
          else
            util.log 'SAVED'

    # Default Express init.
    @initExpressFn = (app) =>
      app.configure =>
        app.use @express.logger 'dev'
        app.use @express.bodyParser()
        app.use @express.methodOverride()
        app.use @express.errorHandler()
        app.use @express.static "#{__dirname}/../../../www-root"
        app.use app.router
        routes = require './routes/routes'
        routes app
      util.log "[APP] Server (Express) configured."
      return

    # Default SocketIO init.
    @initSocketIoFn = (io) =>
      io.sockets.on 'connection', (socket) =>
        socket.join(@dashboardRoomName)
        dashboard = @dashboard.getComplete()
        dashboard.options = (interval: @interval)
        socket.emit 'config', dashboard
        socket.on 'ui.update', (data) => @handleUiUpdate(data)
        socket.on 'ui.action', (data) => @handleUiAction(data)
      @emitter.on 'dashboard.cluster.update', ({cluster}) =>
        @io.sockets.in(@dashboardRoomName).emit 'update', (cluster: (id: cluster.id, data: cluster.data, states: cluster.states))
      @emitter.on 'dashboard.host.update', ({host}) =>
        @io.sockets.in(@dashboardRoomName).emit 'update', (host: (id: host.id, clusterId: host.clusterId, data: host.data, states: host.states))
      @emitter.on 'dashboard.module.update', ({module}) =>
        @io.sockets.in(@dashboardRoomName).emit 'update', (module: (id: module.id, hostId: module.hostId, clusterId: module.clusterId, data: module.data, states: module.states))
      util.log "[APP] Server (SocketIO) configured."
      return

  initEmitter : (@initEmitterFn) ->

  initServer : (@initServerFn) ->

  initSocketIo : (@initSocketIoFn) ->

  initDashboard : (@initDashboardFn) ->

  initActionHandler : (@initActionHandler) ->

  handleUiAction: (data) ->
    util.log "[APP] Handling UI-Action"
    return unless data?.action?.property and data?.context
    switch data.action.property
      when 'check'
        @scheduler.scheduleWithPriority data.context
      when 'update'
        if typeof @initActionHandler is 'function'
          @initActionHandler data.action.property, data.context, @dashboard
    return

  handleUiUpdate: (data) ->
    util.log "[APP] Handling UI-Event"
    return unless data?.action and data?.context
    # Flipping module
    if data.context.clusterId and data.context.hostId and data.context.moduleId
      util.log "[APP] Handling UI-Event: Module"
      cluster = @dashboard.getCluster data.context.clusterId
      return unless cluster
      host = @dashboard.getHost cluster, data.context.hostId
      return unless host
      module = @dashboard.getModule host, data.context.moduleId
      return unless module
      if typeof data.action.property is 'string'
        @applyModuleState(cluster, host, module, data.action.property, data.action.value)()
        return true
    else if data.context.clusterId and data.context.hostId
      util.log "[APP] Handling UI-Event: Host"
      cluster = @dashboard.getCluster data.context.clusterId
      return unless cluster
      host = @dashboard.getHost cluster, data.context.hostId
      return unless host
      if typeof data.action.property is 'string'
        @applyHostState(cluster, host, data.action.property, data.action.value)()
        return true
    return

  log: ->
    @dashboard.log()

  run : ->

    # Running: Configuration emitter.
    @emitter.on '_log.dashboard.*', (params) ->
      if params.module
        util.log "[DASHBOARD] #{params.action or 'none'} /#{params.cluster}/#{params.host}/#{params.module}"
      else if params.host
        util.log "[DASHBOARD] #{params.action or 'none'} /#{params.cluster}/#{params.host}"
      else if params.cluster
        util.log "[DASHBOARD] #{params.action or 'none'} /#{params.cluster}"
    @emitter.on 'log.plugin.*', (params) ->
      util.log "[DASHBOARD] #{params.event}"

    @initEmitterFn(@emitter) if @initEmitterFn

    # Running: Initialize and run dashboard.
    @initDashboardFn(@dashboard) if @initDashboardFn
    @dashboard.run()

    # Running: Initialize and run server.
    @initExpressFn(@app)
    @initSocketIoFn(@io)
    @initServerFn(@server, @app, @io) if @initServerFn

    # Running: Bind server
    @server.listen @port
    util.log "[APP] Server ready (Port: #{@port})."

    # Running: Init & execute scheduler.
    @scheduler = new Scheduler this, @dashboard, @emitter
    @scheduler.run(@interval)

    return

  applyClusterState : (cluster, property, value) ->
    () =>
      @dashboard.updateClusterState cluster.id, property, value

  applyHostState : (cluster, host, property, value) ->
    () =>
      @dashboard.updateHostState cluster.id, host.id, property, value

  applyModuleState : (cluster, host, module, property, value) ->
    () =>
      @dashboard.updateModuleState cluster.id, host.id, module.id, property, value



module.exports = App