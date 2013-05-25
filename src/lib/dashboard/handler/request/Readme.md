# SSH

```javascript
var sshHandler = require('./src/lib/dashboard/handler/request/ssh_request_handler').handler;

var promise = sshHandler({
  cluster: {
    id: 'cluster'
  },
  host: {
    id: 'host',
    hostname: 'host.example.lan'
    credentials: {
      username: 'john'
      password: 'doe'
    }
  },
  options: {
    commands: ['echo 1']
  }
});

promise.then(function (results) {
  assert("1", results[0);
});
```