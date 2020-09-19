## 
## Connection structures and procedures
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import chronicles
import net
import strformat
import streams
import strutils
import system
import tables

import ../errors
import ../endian
import ../field_table
import ../types
import ../utils

type AMQPConnectionError* = object of AMQPError

const RMQCompatibleProducts = @["RabbitMQ"]

type ConnectionStartArgs* = object
    versionMajor*: uint8
    versionMinor*: uint8
    serverProperties*: FieldTable
    mechanisms*: seq[string]
    locales*: seq[string]
    # NOTE: This is _not_ part of the spec, it's a discriminator
    isRMQCompatible*: bool

type ConnectionStartOkArgs* = object
    clientProperties*: FieldTable
    mechanism*: string
    response*: string
    locale*: string
method toWire*(this: ConnectionStartOkArgs): Stream {.base.} =
    ## Converts an AMQPConnectionStartOk structure to wire format
    result = newStringStream()

    this.clientProperties["product"] = FieldTableValue(valType: ftLongString, longStringVal: "nim-amqp")
    this.clientProperties["version"] = FieldTableValue(valType: ftLongString, longStringVal: "0.1.0")
    this.clientProperties["platform"] = FieldTableValue(valType: ftLongString, longStringVal: "Linux")
    this.clientProperties["copyright"] = FieldTableValue(valType: ftLongString, longStringVal: "Copyright (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com>")
    this.clientProperties["information"] = FieldTableValue(valType: ftLongString, longStringVal: "None")

    # Class and Method IDs
    result.write(swapEndian(uint16(10)))
    result.write(swapEndian(uint16(11)))

    # client-properties
    let cpft = this.clientProperties.toWire().readAll()
    result.write(swapEndian(uint32(cpft.len)))
    result.write(cpft)
    # mechanism
    result.write(uint8(len(this.mechanism)))
    result.write(this.mechanism)
    # response (SASL)
    result.write(swapEndian(uint32(len(this.response))))
    result.write(this.response)
    # locale
    result.write(uint8(len(this.locale)))
    result.write(this.locale)
    
    result.setPosition(0)    


proc connectionStart*(chan: AMQPChannel)
proc connectionStartOk*(chan: AMQPChannel, args: ConnectionStartOkArgs)
proc connectionSecure*(chan: AMQPChannel)
proc connectionSecureOk*(chan: AMQPChannel, response: string)
proc connectionTune*(chan: AMQPChannel)
proc connectionTuneOk*(chan: AMQPChannel)
proc connectionOpen*(chan: AMQPChannel, vhost: string = "/")
proc connectionOpenOk*(chan: AMQPChannel)
proc connectionClose*(chan: AMQPChannel, reply_code: uint16 = 200, reply_text="Normal shutdown", classId, 
                     methodId: uint16 = 0)
proc connectionCloseIncoming(chan: AMQPChannel)
proc connectionCloseOk*(chan: AMQPChannel)
proc connectionCloseOkIncoming(chan: AMQPChannel)
proc readConnectionStartArgs*(stream: Stream): ConnectionStartArgs
proc newConnectionStartOkArgs*(): ConnectionStartOkArgs

var connectionMethodMap* = MethodMap()
# These are only for incoming calls
connectionMethodMap[10] = connectionStart
connectionMethodMap[20] = connectionSecure
connectionMethodMap[30] = connectionTune
connectionMethodMap[41] = connectionOpenOk
connectionMethodMap[50] = connectionCloseIncoming
connectionMethodMap[51] = connectionCloseOkIncoming


# ----------------------------------------------------------------------------------------------------------------------
# connection::start
# ----------------------------------------------------------------------------------------------------------------------

proc connectionStart*(chan: AMQPChannel) =
    ## connection.start method for AMQP
    ##
    let stream = chan.curFrame.payloadStream
    # Read the data
    let args = stream.readConnectionStartArgs()
    chan.conn.meta.isRMQCompatible = args.isRMQCompatible

    # Validate the data

    # Respond by issuing connection.start-ok
    # FIXME: Hardcoded stuff
    var csoArgs = newConnectionStartOkArgs()
    csoArgs.mechanism = "PLAIN"
    csoArgs.locale = args.locales[0]
    # This is all SASL PLAIN really is
    csoArgs.response = fmt("\0{chan.conn.username}\0{chan.conn.password}")
    
    connectionStartOk(chan, csoArgs)


proc readConnectionStartArgs*(stream: Stream): ConnectionStartArgs = 
    ## Takes an AMQPMethod, fresh from wire extraction, and converts it to an internal connection.start structure map

    # version
    result.versionMajor = stream.readUint8()
    result.versionMinor = stream.readUint8()

    # server-properties
    let sp_size = stream.readUint32Endian()
    result.serverProperties = extractFieldTable(newStringStream(stream.readStr(int(sp_size))))

    result.isRMQCompatible = if (result.serverProperties["product"].longStringVal in RMQCompatibleProducts): true 
                             else: false

    # mechanisms
    let mech_size = stream.readUint32Endian()
    let mechs = stream.readStr(int(mech_size))
    result.mechanisms = mechs.strip().split()

    # locales
    let loc_size = stream.readUint32Endian()
    let locs = stream.readStr(int(loc_size))
    result.locales = locs.strip().split()


# ----------------------------------------------------------------------------------------------------------------------
# connection::start-ok
# ----------------------------------------------------------------------------------------------------------------------

proc newConnectionStartOkArgs*(): ConnectionStartOkArgs =
    ## Creates a new MethodConnectionStartOk with the classId and methodId set properly
    result.clientProperties = new(FieldTable)


proc connectionStartOk*(chan: AMQPChannel, args: ConnectionStartOkArgs) = 
    ## Implementation of connection.start-ok for AMQP
    let argString = args.toWire().readAll()

    try:
        discard chan.frames.sender(chan, chan.constructMethodFrame(argString), expectResponse = true)
    except TimeoutError:
        raise newException(AMQPConnectionError, """Sending 'connection.start-ok' timed-out, this could be caused by 
                           invalid credentials""".singleLine)


# ----------------------------------------------------------------------------------------------------------------------
# connection::secure
# ----------------------------------------------------------------------------------------------------------------------
proc connectionSecure*(chan: AMQPChannel) =
    ## connection.secure implementation
    ##
    # let stream = chan.curFrame.payloadStream
    # let chalSize = swapEndian(stream.readUint32())
    # let chalString = stream.readStr(int(chalSize))
    # TODO: SASL/Alternative Auth Mechanisms?
    raise newException(AMQPNotImplementedError, "connection.secure is not implemented")


# ----------------------------------------------------------------------------------------------------------------------
# connection::secure-ok
# ----------------------------------------------------------------------------------------------------------------------
proc connectionSecureOk*(chan: AMQPChannel, response: string) = 
    ## connection.secure-ok implementation
    raise newException(AMQPNotImplementedError, "connection.secure-ok is not implemented")


# ----------------------------------------------------------------------------------------------------------------------
# connection::tune
# ----------------------------------------------------------------------------------------------------------------------
proc connectionTune*(chan: AMQPChannel) =
    ## connection.tune implementation
    ##
    let stream = chan.curFrame.payloadStream
    let channelMax = stream.readUint16Endian()
    let frameMax = stream.readUint32Endian()
    let heartbeat = stream.readUint16Endian()

    if chan.conn.tuning.channelMax == 0:
        chan.conn.tuning.channelMax = channelMax
    if chan.conn.tuning.frameMax == 0:
        chan.conn.tuning.frameMax = frameMax
    if chan.conn.tuning.heartbeat == 0:
        chan.conn.tuning.heartbeat = heartbeat

    debug "connection.tune", channelMax=channelMax, frameMax=frameMax, heartbeat=heartbeat

    chan.connectionTuneOk()


# ----------------------------------------------------------------------------------------------------------------------
# connection::tune-ok
# ----------------------------------------------------------------------------------------------------------------------
proc connectionTuneOk*(chan: AMQPChannel) =
    ## connection.tune-ok implementation.  Client can request its own tuning parameters by setting the values in 
    ## `tuning` within the connection.
    ##
    let stream = newStringStream()

    # Class and Method IDs
    stream.write(swapEndian(uint16(AMQP_CLASS_CONNECTION)))
    stream.write(swapEndian(uint16(31)))

    stream.write(swapEndian(chan.conn.tuning.channelMax))
    stream.write(swapEndian(chan.conn.tuning.frameMax))
    stream.write(swapEndian(chan.conn.tuning.heartbeat))
    stream.setPosition(0)

    discard chan.frames.sender(chan, chan.constructMethodFrame(stream))


# ----------------------------------------------------------------------------------------------------------------------
# connection::open
# ----------------------------------------------------------------------------------------------------------------------
proc connectionOpen*(chan: AMQPChannel, vhost: string = "/") =
    ## connection.open implementation
    let stream = newStringStream()

    stream.write(swapEndian(uint16(AMQP_CLASS_CONNECTION)))
    stream.write(swapEndian(uint16(40)))

    stream.write(uint8(len(vhost)))
    stream.write(vhost)

    # Reserved stuff that RabbitMQ freaks out about if it's not there
    # https://www.rabbitmq.com/amqp-0-9-1-reference.html#connection.open
    stream.write(uint8(0))
    stream.write("")
    stream.write(uint8(0))

    stream.setPosition(0)

    discard chan.frames.sender(chan, chan.constructMethodFrame(stream), expectResponse = true)


# ----------------------------------------------------------------------------------------------------------------------
# connection::open-ok
# ----------------------------------------------------------------------------------------------------------------------
proc connectionOpenOk*(chan: AMQPChannel) =
    ## connection.open-ok implementation
    ##
    chan.conn.ready = true

# ----------------------------------------------------------------------------------------------------------------------
# connection::close
# ----------------------------------------------------------------------------------------------------------------------
proc connectionClose*(chan: AMQPChannel, reply_code: uint16 = 200, reply_text="Normal shutdown", classId, 
                     methodId: uint16 = 0) =
    ## connection.close -- Client response
    let stream = newStringStream()

    stream.write(swapEndian(uint16(AMQP_CLASS_CONNECTION)))
    stream.write(swapEndian(uint16(50)))

    stream.write(swapEndian(reply_code))
    stream.write(uint8(len(reply_text)))
    stream.write(reply_text)

    stream.write(swapEndian(classId))
    stream.write(swapEndian(methodId))

    stream.setPosition(0)

    # chan.conn.ready = false

    discard chan.frames.sender(chan, chan.constructMethodFrame(stream), expectResponse = true)


proc connectionCloseIncoming(chan: AMQPChannel) =
    ## connection.close -- Sent from server
    ##
    let stream = chan.curFrame.payloadStream

    let code = swapEndian(stream.readUint16())
    let reason = stream.readStr(int(stream.readUint8()))

    let class = swapEndian(stream.readUint16())
    let meth = swapEndian(stream.readUint16())

    debug "Server requested to close connection", code=code, reason=reason, class=class, meth=meth
    chan.connectionCloseOk()

    if code != 200:
        raise newAMQPException(AMQPConnectionError, reason, class, meth, code)


# ----------------------------------------------------------------------------------------------------------------------
# connection::close-ok
# ----------------------------------------------------------------------------------------------------------------------

# TODO: initiate shutdown of the thread/process from here
proc connectionCloseOk*(chan: AMQPChannel) =
    ## connection.close-ok implementation -- Client 
    let stream = newStringStream()

    stream.write(swapEndian(uint16(AMQP_CLASS_CONNECTION)))
    stream.write(swapEndian(uint16(51)))
    stream.setPosition(0)

    discard chan.frames.sender(chan, chan.constructMethodFrame(stream))

    chan.conn.ready = false


proc connectionCloseOkIncoming(chan: AMQPChannel) =
    ## connection.close-ok -- Server response
    ##
    chan.conn.ready = false
    let peerInfo = chan.conn.sock.getPeerAddr()
    debug "Closed connection to server", serverAddr=peerInfo[0], serverPort=peerInfo[1]
