chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'

expect = chai.expect

describe 'rightscale', ->
  beforeEach ->
    @robot =
      respond: sinon.spy()
      hear: sinon.spy()

    require('../src/rightscale')(@robot)

  it 'registers a respond listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(rightscale login) (.*)/i)
    expect(@robot.respond).to.have.been.calledWith(/(rightscale me) ([a-zA-Z0-9]*)$/i)
    expect(@robot.respond).to.have.been.calledWith(/(rightscale me deployment) (.*)/i)