_             = require 'lodash'
http          = require 'http'
DeviceManager = require 'meshblu-core-manager-device'

class UnregisterDevice
  constructor: ({@cache,@uuidAliasResolver,@datastore}) ->
    @deviceManager = new DeviceManager {@cache,@uuidAliasResolver,@datastore}

  _doCallback: (request, code, callback) =>
    response =
      metadata:
        responseId: request.metadata.responseId
        code: code
        status: http.STATUS_CODES[code]
    callback null, response

  do: (request, callback) =>
    {toUuid} = request.metadata

    return @_doCallback request, 422, callback unless toUuid?
    @deviceManager.remove {uuid: toUuid}, (error) =>
      return callback error if error?
      return @_doCallback request, 204, callback

module.exports = UnregisterDevice
