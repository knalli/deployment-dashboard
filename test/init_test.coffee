util = require 'util'
{App} = require './../src/lib/dashboard'

###
  Some e2e tests (integration) of end user configurations.
###

module.exports =

  testSimpleEmptyProject_WithoutOptions: (test) ->
    test.expect 2
    app = new App
    test.ok app, "App object should not be empty."
    test.throws((->
      app.init()), Error, "Dashboard object should not be empty.")
    test.done()

  testSimpleEmptyProject: (test) ->
    test.expect 2
    app = new App
    test.ok app, "App object should not be empty."
    app.init({})
    test.ok app.dashboard, "Dashboard object should not be empty."
    test.done()

  testSimpleProject: (test) ->
    test.expect 4
    app = new App
    test.ok app, "App object should not be empty."
    app.init({port: 3001})
    app.initDashboard (dashboard) ->
      dashboard.cluster 'home.local',
        display: 'Home Netzwork'
        hosts  :
          router:
            hostname   : 'router.home.local'
            credentials:
              username: 'root'
              password: 'root'
            modules    :
              'voip'    :
                disabled: false
              'internet':
                disabled: false
            handlers   :
              test:
                type: 'check_mock'
    app.run()
    test.ok app.dashboard, "Dashboard object should not be empty."
    test.equal app.dashboard.cluster('na'), undefined, "Cluster object should be empty because it is invalid."
    test.ok app.dashboard.cluster('home.local'), "Cluster object should not be empty because it is valid."
    test.done()