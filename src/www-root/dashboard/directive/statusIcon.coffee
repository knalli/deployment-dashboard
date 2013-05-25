angular.module('dashboard').directive 'statusIcon', ->
  restrict: 'E'
  replace: true
  template: '<span class="icon-wrapper"><i></i></span>'
  scope:
    expression: '=expr'
    spinnerExpression: '=spinnerExpr'
  link : (scope, element, attrs) ->
      element = element.find('i')
      scope.$watch 'expression', (newValue) ->
        if newValue
          element.addClass(attrs.eqClass).removeClass(attrs.neClass)
        else
          element.addClass(attrs.neClass).removeClass(attrs.eqClass)
        return
      scope.$watch 'spinnerExpression', (newValue) ->
        if newValue
          element.addClass('icon-spin')
        else
          element.removeClass('icon-spin')
        return
      return