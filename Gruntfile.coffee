#global module:false
module.exports = (grunt) ->

  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'
    banner: '/*! <%= pkg.title || pkg.name %> - v<%= pkg.version %> - ' +
      '<%= grunt.template.today("yyyy-mm-dd") %>\n' +
      '<%= pkg.homepage ? "* " + pkg.homepage + "\\n" : "" %>' +
      '* Copyright (c) <%= grunt.template.today("yyyy") %> <%= pkg.author.name %>;' +
      ' Licensed <%= _.pluck(pkg.licenses, "type").join(", ") %> */\n'
    clean:
      'dist-scripts' : ['./www-root/scripts']
      'dist-styles' : ['./www-root/styles']
    concat:
      options:
        banner: '<%= banner %>'
        stripBanners: true
      dist:
        src: ['lib/<%= pkg.name %>.js']
        dest: 'dist/<%= pkg.name %>.js'
    uglify:
      options:
        banner: '<%= banner %>'
      dist:
        src: '<%= concat.dist.dest %>'
        dest: 'dist/<%= pkg.name %>.min.js'
    compass:
      dist:
        options:
          sassDir: 'src/www-root/sass'
          cssDir: 'www-root/styles'
          environment: 'production'
      dev:
        options:
          sassDir: 'src/www-root/sass'
          cssDir: 'www-root/styles'
    coffee:
      options: (bare : true, sourceMap : false)
      stage :
        expand : true
        ext : '.js'
        src : ['**/*.coffee']
        dest : './www-root/scripts/'
        cwd : 'src/www-root'
    jshint:
      options:
        curly: true
        eqeqeq: true
        immed: true
        latedef: true
        newcap: true
        noarg: true
        sub: true
        undef: true
        unused: true
        boss: true
        eqnull: true
        browser: true
        globals:
          jQuery: true
      lib_test:
        src: ['lib/**/*.js', 'test/**/*.js']
    nodeunit:
      all: ['test/**/*_test.coffee']
    watch:
      www_coffee:
        files: 'src/www-root/**/*.coffee'
        tasks: ['coffee:stage']
      www_sass:
        files: 'src/www-root/sass/**/*'
        tasks: ['compass:dev']
      backend:
        files: ['src/lib/**/*', 'test/**/*']
        tasks: ['nodeunit:all']

  require('matchdep').filterDev('grunt-*').forEach(grunt.loadNpmTasks)

  grunt.registerTask 'default', ['coffee:stage', 'compass:dist']
  grunt.registerTask 'dev', ['coffee:stage', 'compass:dev', 'watch']
  grunt.registerTask 'test', ['nodeunit']