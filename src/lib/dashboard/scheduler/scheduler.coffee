get_request_handler = require './../handler/request'

util = require 'util'
Q = require 'q'
{EventEmitter2} = require 'eventemitter2'


class Scheduler

  constructor : (@app, @dashboard, @emitter) ->

  run : (interval) ->

    # Running: Perform first scheduling.
    @schedule()

    # Running: Perform next schedules.
    if interval
      fn = =>
        @schedule()
      setInterval fn, interval * 1000
      util.log "[APP] Interval set to #{interval} seconds."

    return

  schedule: -> @_schedule()

  scheduleWithPriority: ({clusterId, hostId}) ->
    if clusterId and hostId
      @_schedule clusterId, hostId

  _schedule: (filterClusterId, filterHostId) ->
    @emitter.emit 'app.scheduler.round.start', ({})
    util.log "[APP] Checks will be scheduled (filters: cluster=#{filterClusterId}, host=#{filterHostId})."

    logOnError = (err) ->
      util.error "[APP] Error: #{err.code}: #{err.message or 'No message'}"

    allStepsPromises = []
    # For each cluster
    for cluster in @dashboard.data.clusters when (!filterClusterId or cluster.id is filterClusterId)
      continue if cluster.disabled
      clusterPromises = []
      # For each host
      for host in cluster.hosts when (!filterHostId or host.id is filterHostId)
        continue if host.disabled
        hostPromises = []
        hostDeferred = Q.defer()
        clusterPromises.push hostDeferred.promise
        # For each host-handler
        for hostHandlerOptions in host.handlers
          type = hostHandlerOptions.type
          # Should be a type, otherwise ignore it.
          continue unless type
          handler = @dashboard.getHandler(type)
          # Should be a valid handler, otherwise ignore it.
          continue unless handler
          handlerPromises = []
          # For each step
          for step in handler.steps
            continue if step.disabled
            stepDeferred = Q.defer()
            allStepsPromises.push stepDeferred.promise
            handlerPromises.push stepDeferred.promise
            if typeof step.fn is 'function'
              util.log "[APP] Create new step #{type} with function..."
              requestHandler = step.fn
            else if step.type
              # 1: Build the request handler
              util.log "[APP] Create new step #{type}.#{step.type}..."
              requestHandler = get_request_handler(step.type)
            continue unless requestHandler
            options = step.options or ({})
            # 2: Call request handler, getting promise.
            util.log "[APP] Start step #{type}.#{step.type}..."
            requestPromise = requestHandler({cluster, host, options})
            requestPromise.fail logOnError
            requestPromise.fail @_buildHostExceptionHandler(host, step)
            # The request promise itself is an important host promise.
            hostPromises.push requestPromise
            # 3: For each action, apply it in a promise chain.
            # The result of an action will be the argument of the next (chaining).
            stepPromise = requestPromise
            if step.options.actions
              for action in step.options.actions
                util.log "[APP] Add action in step's chain #{type}.#{action.id}..."
                stepPromise = stepPromise.then @_buildStepAction(action)
            # 4: For each finalize, apply it but without promise chain.
            # Each finalize will get the same arguments.
            for finalize in step.options.finalizes
              util.log "[APP] Add finalize in step's chain #{type}.#{finalize.id}..."
              stepPromise.then @_buildStepFinalize(finalize, {host, cluster, handler})
            # Always resolve the step deferred object (for allStepsPromises, handlerPromises).
            stepPromise.fin stepDeferred.resolve
          # end step
        # end host-handler
        Q.all(hostPromises).then hostDeferred.resolve, hostDeferred.reject
        Q.all(hostPromises).then(@app.applyHostState(cluster, host, 'available', true), @app.applyHostState(cluster, host, 'available', false))
      # end host
      if clusterPromises.length
        Q.all(clusterPromises).then(@app.applyClusterState(cluster, 'available', true), @app.applyClusterState(cluster, 'available', false))
    # end cluster

    # After all checks are fulfilled, this will fire a global callback.
    if allStepsPromises.length
      Q.allSettled(allStepsPromises).then (results) =>
        @emitter.emit 'app.scheduler.round.end', (numOfChecks: allStepsPromises.length, numOfResults: results.length)
        util.log "[APP] Checks (#{allStepsPromises.length}) are fulfilled (#{results.length})."
        return
      @emitter.emit 'app.scheduler.round.init', (numOfChecks: allStepsPromises.length)
      util.log "[APP] Checks (#{allStepsPromises.length}) are scheduled."
    else
      @emitter.emit 'app.scheduler.round.init', (numOfChecks: 0)
      @emitter.emit 'app.scheduler.round.end', (numOfChecks: 0, numOfResults: 0)
      util.log "[APP] Checks all okay because no steps."

    return

  _buildStepAction : (action) ->
    (data) ->
      action.fn {data}

  _buildStepFinalize : (finalize, {host, cluster, handler}) ->
    (data) =>
      dashboard = @dashboard
      finalize.fn {data, host, cluster, handler, dashboard}

  _buildFinalize : (handler) ->
    (results) =>
      wrapResult = []
      results.forEach (result) ->
        if result.state is 'fulfilled'
          wrapResult.push result.value
        else
          wrapResult.push undefined
      handler.finalize wrapResult

  _buildHostExceptionHandler: (host, step) ->
    (err) =>
      @dashboard.updateHostException(host.clusterId, host.id, err, (stepType: step.type))



module.exports = Scheduler