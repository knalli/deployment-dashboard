angular.module('dashboard').directive 'timeAgo', ($window) ->
  restrict: 'A'
  link : (scope, element, attrs) ->
    pastTime = 0
    updateText = -> angular.element(element).text "#{Math.round((new Date().getTime() - pastTime)/1000)}"
    attrs.$observe 'timeAgo', (value) ->
      pastTime = value
    intervalObj = $window.setInterval updateText, 1000
    element.bind '$destroy', ->
      $window.clearInterval intervalObj
    return