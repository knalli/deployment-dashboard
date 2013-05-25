Q = require 'q'
util = require 'util'


myMockRequestHandler = ({cluster, host, options}) ->
  deferred = Q.defer()
  setTimeout( (->
    if host.id is 'host'
      deferred.resolve
        backend:
          build: '42'
          version: '1.3.4'
          release: '1.3.4-42'
          states: (started: true)
        frontend:
          build: '41'
          version: '1.2.1'
          release: '1.2.1-41'
          states: (started: true)
    else if host.id is 'app1'
      deferred.resolve
        backend:
          build: '41'
          version: '1.3.4'
          release: '1.3.4-41'
          states: (started: true)
        frontend:
          build: '41'
          version: '1.2.1'
          release: '1.2.1-41'
          states: (started: true)
        support:
          build: '10'
          version: '1.0.1'
          release: '1.0.1-10'
          states: (started: true)
    else if host.id is 'app2'
      deferred.resolve
        backend:
          build: '42'
          version: '1.3.4'
          release: '1.3.4-42'
          states: (stopped: true)
        frontend:
          build: '40'
          version: '1.2.1'
          release: '1.2.1-40'
          states: (stopped: true)
        support:
          build: '10'
          version: '1.0.1'
          release: '1.0.1-10'
          states: (started: true)
    else
      # Fake an unreachable host exception.
      deferred.reject level: 'connection-socket', code: 'ENOTFOUND', message: 'Fake: Host not configured (example).'
  ), 1)
  return deferred.promise


myMockAfterRequestIsModuleStillUp2Date = ({data}) ->
  if data
    for own moduleId, moduleData of data
      switch moduleId
        when 'backend'
          moduleData.available =
            build: '42'
            version: '1.3.4'
            release: '1.3.4-42'
        when 'frontend'
          moduleData.available =
            build: '41'
            version: '1.2.1'
            release: '1.2.1-41'
  return data


myMockSendResultsToDashboard = ({data, host, cluster, handler, dashboard}) ->
  for own moduleId, module of data
    result =
      clusterId: cluster.id
      hostId: host.id
      moduleId: moduleId
      data: module
      states : module.states
    dashboard.updateModule result


myMockActionHandler = (type, context, dashboard) ->
  if type is 'update'
    cluster = dashboard.getCluster(context.clusterId)
    host = dashboard.getHost(cluster, context.hostId)
    module_ = dashboard.getModule(host, context.moduleId)
    module_.states.updating = on
    dashboard.updateModule
      clusterId: cluster.id
      hostId: host.id
      moduleId: module_.id
      data: module_
      states : module_.states
    # Update complete in 5 secs.
    setTimeout((->
      module_.states.updating = off
      module_.build = parseInt(module_.data.build) + 1
      module_.release = "#{module_.data.version}-#{module_.build}"
      dashboard.updateModule
        clusterId: cluster.id
        hostId: host.id
        moduleId: module_.id
        data: module_
        states : module_.states
    ), 5000)
    # Revert update in 20 secs.
    setTimeout((->
      module_.build = parseInt(module_.data.build) - 1
      module_.release = "#{module_.data.version}-#{module_.build}"
      dashboard.updateModule
        clusterId: cluster.id
        hostId: host.id
        moduleId: module_.id
        data: module_
        states : module_.states
    ), 20000)
  return


module.exports = (app) ->

  app.init(interval: 120, port: 3000)
  app.initActionHandler myMockActionHandler

  app.initDashboard ( (dashboard) ->
    dashboard.handler 'defaultHandler', (
      steps: [(
        fn: myMockRequestHandler
        options: (
          actions: [(
            id: 'checkFreshness'
            fn: myMockAfterRequestIsModuleStillUp2Date
          )]
          finalizes: [(
            id: 'apply_config'
            fn: myMockSendResultsToDashboard
          )]
        ) # end-options
      )]
    )

    dashboard.cluster 'demo1', (
      display: 'Demo Cluster 1'
      hosts:
        'host':
          hostname: 'host.cluster1.lan'
          modules:
            'backend':
              display: 'Backend'
            'frontend':
              display: 'Frontend'
          handlers:
            main:
              type: 'defaultHandler'
    )


    dashboard.cluster 'demo2', (
      display: 'Demo Cluster 2'
      hosts:
        app1:
          display: 'App 1'
          hostname: 'host1.cluster2.lan'
          modules:
            backend:
              display: 'Backend'
            frontend:
              display: 'Frontend'
            support:
              display: 'Support'
          handlers:
            main:
              type: 'defaultHandler'
        app2:
          display: 'App 2'
          hostname: 'host2.cluster2.lan'
          modules:
            backend:
              display: 'Backend'
            frontend:
              display: 'Frontend'
            support:
              display: 'Support'
          handlers:
            main:
              type: 'defaultHandler'
        db1:
          display: 'Db 2'
          hostname: 'db1.cluster2.lan'
          modules:
            db:
              display: 'Database'
            support:
              display: 'Support'
          handlers:
            main:
              type: 'defaultHandler'
    )
  )