# Deployment Dashboard

## Install requirements

1. Install all dependencies via NPM: `npm install`.
2. Install all dependencies via Bower: `node_modules/.bin/bower install`.
3. Ensure you have a global installed Grunt.

## Start the Example

1. All resources have to be rebuild, i.e. right after checkout or update: `grunt`
2. Start `node_modules/.bin/coffee src/index.coffee Dashboard`.

# Customize your own Dashboard

1. Copy the existing `Dashboard.coffee` to something like `CustomDashboardYourProject.coffee`. The file pattern `CustomDashboard*` is included in the `.gitignore`.
2. [Customize it.](DashboardConfig.md).
3. Start `node_modules/.bin/coffee src/index.coffee CustomDashboardYourProject` or whatever you named your dashboard.

# License

All stuff from this repository is licensed unter MIT. Copyright 2013 by Jan Philipp.