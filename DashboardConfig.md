# Dashboard Configuration

## Concept: Deployment Dashboard

The main idea of this project is having a quick overview of installed and maintainable software modules of different
enviroments. Think about your several enviroments of a multi-module system: Development, Testing, Staging. Mostly, the
infrastructure scaling depends on the deployment step: A dev system is perhaps not a cluster, but the staging one.

Each enviroment is called a `cluster` which can be a container of only one `host` or a list of several `hosts`.

Each `host` contains one or more `modules` which represent a piece of software installed on the server. This is
completly customizable. You can add real software like `httpd` or custom "fakes" like `frontend`. Even something like
`database-schema` is possible if you build the corresponding `check handlers`.

### Infrastructure

1. A dashboard has 1..n clusters.
2. A cluster has 1..n hosts.
3. A host has 1..n modules.

### Checks

A `check handler` is actually an abstract definition or chain of some activities. Basically, every `check handler`
must start with a `request handler` which collects all data (a HTTP request, a SSH request or even only a function).

After the `request handler` returns data, a chain of `actions` intercept and transform the data: Data reduction, data
modification, data filtering.

Finally, the dashboard has to be notified about changes (mostly: `dashboard.updateModule(...)`.

1. A check contains at least one step.
2. A step contains exactly one request handler. A handler should return a Promise.
3. A step contains no, one or multiple action handlers. At least one is recommended. All handlers will be called in a chain.
4. A step contains no, one or multiple finalizers. At least one is recommended. All handlers will be called side by side.

### Realtime: Easy-Peasy

All updates are in near-realtime realized with SocketIO (WebSocket hopefully) and AngularJS.

## Structure of the Configuration File

A Dashboard Configuration File `Dashboard.coffee` (or another name you like) returns basically a function descriptor
just like a Gruntfile.

The main function provides `app` which is the application context of a dashboard. In this context, you can apply
additional configurations including the dashboard itself.

## Main options

```javascript
app.init({
  interval: 120,
  port: 3000
});
```

The `interval` is optional; only an explicit interval (in seconds) will enable a periodacally check.

The `port` for the express server is optional; the default is `3000`.

## Dashboard options

```javascript
app.initDashboard(function (dashboard) {

  // Handlers
  // Dashboard Infrastructure

});
```

Basically, this defines a setup function descriptor only for the dashboard. It provides `dashboard` which is the
dashboard configuration object.

### Infrastructure

Let's imagine, we have only one server (`host1`). Because the infrastructure setup requires a group (called cluster), a
simple configuration looks like this:

```javascript
dashboard.cluster('cluster1', {
  display: 'Demo Cluster 1',
  hosts: {
    host1: {
      hostname: 'host1.cluster1.lan'
    }
  }
});
```

Each host should be defined at least one module and one handler:

```javascript
dashboard.cluster('cluster1', {
  display: 'Demo Cluster 1',
  hosts: {
    host1: {
      hostname: 'host1.cluster1.lan',
      modules: {
        backend: {
          display: 'Backend'
        },
        frontend: {
          display: 'Frontend'
        }
      },
      handlers: {
        main: {
          type: 'defaultHandler'
        }
      }
    }
  }
});
```

All names of the used identifiers (`cluster1`, `host1`, `backend`, `frontend`, `main`, `defaultHandler`) are completely
customizeable.

### Check Handler

This simple handler is defined like this:

```javascript
dashboard.handler('defaultHandler', {
  steps: [{
    fn: myMockRequestHandler,
    options: {
      actions: [{
        id: 'checkFreshness',
        fn: myMockAfterRequestIsModuleStillUp2Date
      }],
      finalizes: [{
        id: 'apply_config',
        fn: myMockSendResultsToDashboard
      }]
    }
  }]
});
```

1. `myMockRequestHandler`: produces some data (version of modules for the host)
2. `myMockAfterRequestIsModuleStillUp2Date`: enrichs the data with additional availability of versions
3. `myMockSendResultsToDashboard`: applies the data to the dashboard object

#### Request Handler

A request handler is either defined as a function which returns a promise:

```javascript
var myMockRequestHandler = function (params) {
  var cluster = params.cluster,
      host = params.host,
      options = params.options,
      deferred = Q.defer();

  // ...

  return deferred.promise;
};
```

Or it is one of the available internal request handler types:

```javascript
dashboard.handler('defaultHandlerWithHttp', {
  steps: [{
    type: 'http',
    options: {
      requests: [{
        host: 'example.org',
        port: 80,
        path: '/a.html'
      }, {
        host: 'example.org',
        port: 80,
        path: '/b.html'
      }, {
        host: 'example.org',
        port: 80,
        path: '/c.html'
      }]
    }
  }]
});
```

```javascript
dashboard.handler('defaultHandlerWithSsh', {
  steps: [{
    type: 'ssh',
    options: {
      commands: [
      'yum list installed',
      'yum list'
      ]
    }
  }]
});
```

Note: Both internal request handlers resolves to an array with the same size like the specified requests or commands.
This means, the first example will resolved to an array with three items (regardless whether resolved or not) and the
second one will have two items.

#### Action Handler

The `action handler` is the connection between a `request handler` and the `finalizer` Mostly, the esult of a request
handler is probaly not useful updating the dashboard.

An action handler we be called always with `data` (in `params`) and *SHOULD* always return `data` unless the data should
be reducted. The next action handler (or the finalizer) will be called with the return value of the previous action
handler.

```javascript
var myActionHandler = function (params) {
  var data = params.data;
  return data;
}
```

#### Finalizer

Basically, a finalizer is nothing else than a special `action handler`. While all `action handlers` will be called in
chain, the finalizer will be called in parallel and their return value will be ignored.