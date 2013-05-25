util = require 'util'


class Config

  data : null
  initialized : false

  constructor : () ->
    @data = clusters: [], handlers: []

  init: ->

  handler : (id, config) ->
    if config
      handler = @buildHandler id, config
      @setHandler id, handler
      return handler
    else
      return @getHandler id

  cluster : (id, config) ->
    if config
      cluster = @buildCluster id, config
      @setCluster id, cluster
      if config.hosts
        for own hostId, hostConfig of config.hosts
          @host(cluster.id, hostId, hostConfig)
      return cluster
    else
      return @getCluster id

  host : (clusterId = 'default', id, config) ->
    cluster = @getCluster(clusterId)
    if config
      host = @buildHost id, config
      @setHost cluster, id, host
      if config.modules
        for own moduleId, moduleConfig of config.modules
          @module(cluster.id, host.id, moduleId, moduleConfig)
      if config.handlers
        for own handlerId, handlerConfig of config.handlers
          @hostHandler(cluster.id, host.id, handlerId, handlerConfig)
      return host
    else
      return @getHost cluster, id

  'module' : (clusterId = 'default', hostId = 'default', id, config) ->
    cluster = @getCluster(clusterId)
    host = @getHost(cluster, hostId)
    if config
      module = @buildModule id, config
      @setModule host, id, module
      return module
    else
      return @getModule host, id

  hostHandler : (clusterId = 'default', hostId = 'default', id, config) ->
    cluster = @getCluster(clusterId)
    host = @getHost(cluster, hostId)
    if config
      handler = @buildHostHandler id, config
      @setHostHandler host, id, handler
      return handler
    else
      return @getHostHandler host, id

  buildHandler : (id, {display, disabled, steps}) ->
    id : id
    disabled : disabled
    display: display
    steps: steps

  buildCluster : (id, {display, disabled}) ->
    id : id
    hosts: []
    handlers: []
    disabled : disabled
    display: display or id

  buildHost : (id, {disabled, display, hostname, connectivity, credentials}) ->
    id : id
    modules: []
    handlers: []
    disabled : disabled
    display: display or id
    hostname: hostname
    connectivity: if connectivity then @buildHostConnectivity connectivity
    credentials: credentials

  buildModule : (id, {disabled, display}) ->
    id : id
    handlers: []
    disabled : disabled
    display: display or id

  buildHostHandler : (id, {type, options}) ->
    id : id
    type: type
    options: options

  getHandler : (id) ->
    for handler in @data.handlers when handler.id is id
      return handler
    return

  setHandler : (id, config) ->
    config.id = id
    @data.handlers.push config
    @fireEvent 'create',
      handler: config
    return

  getCluster : (id) ->
    for cluster in @data.clusters when cluster.id is id
      return cluster
    return

  setCluster : (id, config) ->
    config.id = id
    @data.clusters.push config
    @fireEvent 'create',
      cluster: config
    return

  getHost : (cluster, id) ->
    if cluster
      for host in cluster.hosts when host.id is id
        return host
    return

  setHost : (cluster, id, config) ->
    if cluster
      config.id = id
      config.clusterId = cluster.id
      cluster.hosts.push config
      @fireEvent 'create',
        cluster: cluster
        host: config
    return

  getModule : (host, id) ->
    if host
      for module in host.modules when module.id is id
        return module
    return

  setModule : (host, id, config) ->
    if host
      config.id = id
      config.hostId = host.id
      config.clusterId = host.clusterId
      host.modules.push config
      @fireEvent 'create',
        cluster: @getCluster host.clusterId
        host: host
        module: config
    return

  getHostHandler : (host, id) ->
    if host
      for handler in host.handlers when handler.id is id
        return handler
    return

  setHostHandler : (host, id, config) ->
    if host
      config.id = id
      config.hostId = host.id
      config.clusterId = host.clusterId
      host.handlers.push config
    return

  buildHostConnectivity: (config) ->
    return config

  updateModule: ({clusterId, hostId, moduleId, data, states}) ->
    cluster = @getCluster clusterId
    return unless cluster
    host = @getHost cluster, hostId
    return unless host
    module = @getModule host, moduleId
    return unless module
    module.data = ({}) unless module.data
    module.states = ({}) unless module.states
    @updateModuleData module.data, data
    if states
      for own property, value of states
        module.states[property] = value
    module.updatedAt = new Date().getTime()
    @fireEvent 'update',
      cluster: @cleanSensitiveData cluster
      host: @cleanSensitiveData host
      module: @cleanSensitiveData module

  updateModuleData: (data, {build, version, release, available}) ->
    data.build = build if build
    data.release = release if release
    data.version = version if version
    if available
      data.available = ({}) unless data.available
      @updateModuleData(data.available, available) if available

  updateClusterState: (id, property, value, surpressEvents) ->
    cluster = @getCluster id
    return unless cluster
    cluster.states = ({}) unless cluster.states
    cluster.states[property] = value
    # Remove any error object
    cluster.states.error = undefined
    cluster.updatedAt = new Date().getTime()
    unless surpressEvents
      @fireEvent 'update',
        cluster: @cleanSensitiveData cluster
    return

  updateHostState: (clusterId, id, property, value, surpressEvents) ->
    cluster = @getCluster clusterId
    return unless cluster
    host = @getHost cluster, id
    return unless host
    host.states = ({}) unless host.states
    host.states[property] = value
    if property is 'available' and value is true
      # Remove any error object
      host.states.error = undefined
    host.updatedAt = new Date().getTime()
    unless surpressEvents
      @fireEvent 'update',
        cluster: @cleanSensitiveData cluster
        host: @cleanSensitiveData host
    return

  updateModuleState: (clusterId, hostId, id, property, value, surpressEvents) ->
    cluster = @getCluster clusterId
    return unless cluster
    host = @getHost cluster, hostId
    return unless host
    module = @getModule host, id
    return unless module
    module.states = ({}) unless module.states
    module.states[property] = value
    # Remove any error object
    module.states.error = undefined
    unless surpressEvents
      @fireEvent 'update',
        cluster: @cleanSensitiveData cluster
        host: @cleanSensitiveData host
        module: @cleanSensitiveData module
    return

  updateHostException: (clusterId, hostId, err, details, surpressEvents) ->
    cluster = @getCluster clusterId
    return unless cluster
    host = @getHost cluster, hostId
    return unless host
    @updateHostState clusterId, hostId, 'available', false, true
    host.states.error =
      message: err.message
      code: err.code
      errno: err.errno
      syscall: err.syscall
      level: err.level
      details: details
    unless surpressEvents
      @fireEvent 'update',
        cluster: @cleanSensitiveData cluster
        host: @cleanSensitiveData host
    return

  cleanSensitiveData: (data) ->
    result = data
    if typeof data is 'object'
      if typeof data.length is 'undefined'
        result = ({})
        for own key, value of data
          if key in ['credentials', 'username', 'password', 'privateKeyLocation', 'port']
            result[key] = '**hidden**'
          else if typeof value is 'object'
            result[key] = @cleanSensitiveData value
          else
            result[key] = value
      else
        result = (@cleanSensitiveData item for item in data)
    result

  getComplete: ->
    result = clusters: (cluster for own clusterId, cluster of @cleanSensitiveData @data.clusters)
    # Improving usage in AngularJS, transform maps into arrays.
    for cluster in result.clusters
      cluster.handlers = undefined
      cluster.hosts = (host for own hostId, host of cluster.hosts)
      for host in cluster.hosts
        host.handlers = undefined
        host.modules = (module for own moduleId, module of host.modules)
        for module in host.modules
          module.handlers = undefined
    return result

  fireEvent: (event, data) ->

  log : ->
    util.log 'DashboardConfig'
    util.log "Clusters: " + util.inspect @data.clusters, colors: true, depth: null, showHidden: true


module.exports = Config