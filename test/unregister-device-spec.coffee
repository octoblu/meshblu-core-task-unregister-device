_                = require 'lodash'
mongojs          = require 'mongojs'
Datastore        = require 'meshblu-core-datastore'
Cache            = require 'meshblu-core-cache'
redis            = require 'fakeredis'
UnregisterDevice = require '../'
JobManager       = require 'meshblu-core-job-manager'
UUID             = require 'uuid'
RedisNS          = require '@octoblu/redis-ns'

describe 'UnregisterDevice', ->
  beforeEach (done) ->
    @redisKey = UUID.v1()
    database = mongojs 'unregister-device-test', ['devices']

    @jobManager = new JobManager
      client: new RedisNS 'job-manager', redis.createClient @redisKey
      timeoutSeconds: 1
      jobLogSampleRate: 1

    @datastore = new Datastore
      database: database
      collection: 'devices'

    database.devices.remove done

    @cache = new Cache client: redis.createClient UUID.v1()

  beforeEach ->
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    @sut = new UnregisterDevice {@datastore, @cache, @uuidAliasResolver, @jobManager}

  describe '->do', ->
    context 'when given a valid request', ->
      beforeEach (done) ->
        record =
          uuid: 'should-be-removed-uuid'
          something: 'else'

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

      describe 'JobManager gets DeliverUnregisterSent job', (done) ->
        beforeEach (done) ->
          @jobManager.getRequest ['request'], (error, @request) =>
            done error

        it 'should be a config messageType', ->
          expect(@request).to.exist

          message =
            uuid:"should-be-removed-uuid"
            something: 'else'

          auth =
            uuid: 'thank-you-for-considering'
            token: 'the-environment'

          {rawData, metadata} = @request
          expect(metadata.auth).to.deep.equal uuid: 'should-be-removed-uuid'
          expect(metadata.jobType).to.equal 'DeliverUnregisterSent'
          expect(metadata.fromUuid).to.equal 'should-be-removed-uuid'
          expect(JSON.parse rawData).to.containSubset message

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
