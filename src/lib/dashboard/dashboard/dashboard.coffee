DashboardDataConfig = require './dashboard_config'


class Dashboard extends DashboardDataConfig

  constructor : (@emitter) ->
    super()

  init: ->
    super()
    if @emitter
      emitter = @emitter
      emitter.on 'dashboard.cluster.*', ({action, cluster}) ->
        emitter.emit "log.dashboard.cluster", (action: action, cluster: cluster.id, event: @event)
      emitter.on 'dashboard.host.*', ({action, cluster, host}) ->
        emitter.emit 'log.dashboard.host', (action: action, cluster: cluster.id, host: host.id, event: @event)
      emitter.on 'dashboard.module.*', ({action, cluster, host, module}) ->
        emitter.emit 'log.dashboard.module', (action: action, cluster: cluster.id, host: host.id, module: module.id, event: @event)

  run : ->

  fireEvent: (action, {cluster, host, module, handler}) ->
    if module
      @emitter.emit "dashboard.module.#{action}", {action, cluster, host, module}
    else if host
      @emitter.emit "dashboard.host.#{action}", {action, cluster, host}
    else if cluster
      @emitter.emit "dashboard.cluster.#{action}", {action, cluster}


module.exports = Dashboard