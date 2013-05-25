class Util

  # project-backend.noarch            1.0.0-155              @/project-backend-1.0.0-155.noarch
  @resolveDataByLine : (line) ->
    data = line.match /([^\s]+)\.([^\s]+)\s+([^\s]+)\s+([^\s]+)/
    (name: data[1], arch: data[2], version: data[3], repository: data[4]) if data

  @resolveDataByLines : (lines) ->
    results = []
    for line in lines.split('\n')
      line = line.trim()
      continue unless line
      result = Util.resolveDataByLine line
      results.push(result) if result
    return results

module.exports = Util