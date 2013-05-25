angular.module('dashboard').filter 'reverse', ->
  (items) ->
    items.slice().reverse()