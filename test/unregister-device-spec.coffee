_                = require 'lodash'
mongojs          = require 'mongojs'
Datastore        = require 'meshblu-core-datastore'
Cache            = require 'meshblu-core-cache'
redis            = require 'fakeredis'
uuid             = require 'uuid'
UnregisterDevice = require '../'

describe 'UnregisterDevice', ->
  beforeEach (done) ->
    database = mongojs 'unregister-device-test', ['devices']
    @datastore = new Datastore
      database: database
      collection: 'devices'

    database.devices.remove done

    @cache = new Cache client: redis.createClient uuid.v1()

  beforeEach ->
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    @sut = new UnregisterDevice {@datastore, @cache, @uuidAliasResolver}

  describe '->do', ->
    context 'when given a valid request', ->
      beforeEach (done) ->
        record =
          uuid: 'should-be-removed-uuid'

        @datastore.insert record, done

      beforeEach (done) ->
        record =
          uuid: 'should-not-be-removed-uuid'

        @datastore.insert record, done

      beforeEach (done) ->
        request =
          metadata:
            responseId: 'its-electric'
            toUuid: 'should-be-removed-uuid'

        @sut.do request, (error, @response) => done error

      it 'should remove the device', (done) ->
        @datastore.findOne {uuid: 'should-be-removed-uuid'}, (error, device) =>
          return done error if error?
          expect(device).to.not.exist
          done()

      it 'should not remove the other device', (done) ->
        @datastore.findOne {uuid: 'should-not-be-removed-uuid'}, (error, device) =>
          return done error if error?
          expect(device.uuid).to.equal 'should-not-be-removed-uuid'
          done()

      it 'should return a 204', ->
        expectedResponse =
          metadata:
            responseId: 'its-electric'
            code: 204
            status: 'No Content'

        expect(@response).to.deep.equal expectedResponse

    context 'when given a valid invalid', ->
      beforeEach (done) ->
        request =
          metadata:
            responseId: 'its-electric'

        @sut.do request, (error, @response) => done error

      it 'should return a 422', ->
        expectedResponse =
          metadata:
            responseId: 'its-electric'
            code: 422
            status: 'Unprocessable Entity'

        expect(@response).to.deep.equal expectedResponse
