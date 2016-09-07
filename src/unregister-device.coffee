_             = require 'lodash'
http          = require 'http'
DeviceManager = require 'meshblu-core-manager-device'

class UnregisterDevice
  constructor: ({@cache,@uuidAliasResolver,@datastore,@jobManager}) ->
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

    @deviceManager.findOne {uuid: toUuid}, (error, message) =>
      return callback error if error?
      return @_doCallback request, 404, callback unless message?

      newAuth =
        uuid: toUuid

      @_createJob {messageType: 'unregister', jobType: 'DeliverUnregisterSent', fromUuid: toUuid, message, auth: newAuth}, (error) =>
        return callback error if error?

        @deviceManager.recycle {uuid: toUuid}, (error) =>
          return callback error if error?
          return @_doCallback request, 204, callback

  _createJob: ({messageType, jobType, toUuid, message, fromUuid, auth}, callback) =>
    request =
      data: message
      metadata:
        auth: auth
        toUuid: toUuid
        fromUuid: fromUuid
        jobType: jobType
        messageType: messageType

    @jobManager.createRequest 'request', request, callback

module.exports = UnregisterDevice
