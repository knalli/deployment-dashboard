angular.module('dashboard').controller 'DashboardController', ($scope) ->
  $scope.clusters = []
  $scope.jobs = []

  $scope.flip = (event) ->
    element = angular.element(event.target)
    socket.emit 'ui.update',
      context:
        clusterId: element.parents('.db-cluster').data('cluster')
        hostId: element.parents('.db-host-container').data('host')
        moduleId: element.parents('.db-module').data('module')
      action:
        property: 'collapsed'
        value: element.parents('.face').hasClass('front')


  $scope.slide = (event) ->
    element = angular.element(event.target)
    socket.emit 'ui.update',
      context:
        clusterId: element.parents('.db-cluster').data('cluster')
        hostId: element.parents('.db-host-container').data('host')
      action:
        property: 'collapsed'
        value: !element.parents('.db-host-container').find('.db-host').hasClass('hide')

  $scope.action = (event, action) ->
    element = angular.element(event.target)
    socket.emit 'ui.action',
      context:
        clusterId: element.parents('.db-cluster').data('cluster')
        hostId: element.parents('.db-host-container').data('host')
        moduleId: element.parents('.db-module').data('module')
      action:
        property: action

  $scope.updateClusterData = (data) ->
    for own clusterId, clusterData of $scope.pipelines when pipeline.id is data.pipelineId
      for item in pipeline.items when item.id is data.itemId
        for own key, value of data
          item[key] = value
    return

  $scope.updatePipelineJobData = (data) ->
    buildTypes = ['lastBuild', 'lastCompletedBuild', 'lastStableBuild', 'lastSuccessfulBuild']
    for pipeline in $scope.pipelines when pipeline.id is data.pipelineId
      for buildType in buildTypes
        pipeline[buildType] = data[buildTypes]
      pipeline.jobUpdatedAt = data.updatedAt
    return

  socket = io.connect location.origin
  $scope.server = state: 'disconnected', states: []

  handleState = (state) ->
    ->
      $scope.server.state = state
      $scope.server.states.push (time: new Date().getTime(), state: state)
      $scope.$apply()

  socket.on 'connecting', handleState 'connecting'
  socket.on 'connect', handleState 'connected'
  socket.on 'disconnect', handleState 'disconnected'
  socket.on 'connect_failed', handleState 'failed'
  socket.on 'error', handleState 'error'
  socket.on 'reconnect', handleState 'reconnected'
  socket.on 'reconnecting', handleState 'reconnecting'
  socket.on 'reconnect_failed', handleState 'refailed'

  socket.on 'config', (data) ->
    $scope.clusters = data.clusters
    $scope.options = data.options
    $scope.lastSync = new Date().getTime()
    $scope.$apply()
    return

  socket.on 'update', (data) ->
    console.log 'dashboard.updated', data
    if data.module
      moduleUpdate = data.module
      for cluster in $scope.clusters when cluster.id is moduleUpdate.clusterId
        for host in cluster.hosts when host.id is moduleUpdate.hostId
          for module in host.modules when module.id is moduleUpdate.id
            module.updatedAt = moduleUpdate.updatedAt if moduleUpdate.updatedAt
            module.data = moduleUpdate.data if moduleUpdate.data
            module.states = moduleUpdate.states if moduleUpdate.states
    else if data.host
      hostUpdate = data.host
      for cluster in $scope.clusters when cluster.id is hostUpdate.clusterId
        for host in cluster.hosts when host.id is hostUpdate.id
          host.updatedAt = host.updatedAt if host.updatedAt
          host.states = hostUpdate.states if hostUpdate.states
          host.data = hostUpdate.data if hostUpdate.data
    else if data.cluster
      clusterUpdate = data.cluster
      for cluster in $scope.clusters when cluster.id is clusterUpdate.id
        cluster.updatedAt = cluster.updatedAt if cluster.updatedAt
        cluster.states = clusterUpdate.states if clusterUpdate.states
        cluster.data = clusterUpdate.data if clusterUpdate.data
    $scope.lastSync = new Date().getTime()
    $scope.$apply()

  return