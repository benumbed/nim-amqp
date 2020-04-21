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

const CLASS_ID: uint16 = 10

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

type ConnectionTuneOkArgs* = object
    channel_max*: uint16
    frame_max*: uint32
    heartbeat*: uint16
method toWire*(this: ConnectionTuneOkArgs): Stream {.base.} =
    ## Converts a ConnectionTuneOkArgs struct to wire format
    result = newStringStream()

    # Class and Method IDs
    result.write(swapEndian(uint16(CLASS_ID)))
    result.write(swapEndian(uint16(31)))

    result.write(swapEndian(this.channel_max))
    result.write(swapEndian(this.frame_max))
    result.write(swapEndian(this.heartbeat))

    result.setPosition(0)


proc connectionStart*(conn: AMQPConnection, stream: Stream, channel: uint16)
proc connectionStartOk*(conn: AMQPConnection, args: ConnectionStartOkArgs)
proc connectionSecure*(conn:AMQPConnection, stream: Stream, channel: uint16)
proc connectionSecureOk*(conn:AMQPConnection, response: string)
proc connectionTune*(conn: AMQPConnection, stream: Stream, channel: uint16)
proc connectionTuneOk*(conn: AMQPConnection, args: ConnectionTuneOkArgs)
proc connectionOpen*(conn: AMQPConnection, vhost: string = "/")
proc connectionOpenOk*(conn: AMQPConnection, stream: Stream, channel: uint16)
proc connectionClose*(conn: AMQPConnection, reply_code: uint16 = 200, reply_text="Normal shutdown", classId, 
                     methodId: uint16 = 0)
proc connectionClose*(conn: AMQPConnection, stream: Stream, channel: uint16)
proc connectionCloseOk*(conn: AMQPConnection)
proc connectionCloseOk*(conn: AMQPConnection, stream: Stream, channel: uint16)
proc readConnectionStartArgs*(stream: Stream): ConnectionStartArgs
proc newConnectionStartOkArgs*(): ConnectionStartOkArgs

var connectionMethodMap* = MethodMap()
# These are only for incoming calls
connectionMethodMap[10] = connectionStart
connectionMethodMap[20] = connectionSecure
connectionMethodMap[30] = connectionTune
connectionMethodMap[41] = connectionOpenOk
connectionMethodMap[50] = connectionClose
connectionMethodMap[51] = connectionCloseOk


proc sendFrame(conn: AMQPConnection, payload: string, payloadSize: uint32, callback: FrameHandlerProc = nil) = 
    let frame = AMQPFrame(
        frameType: 1,
        channel: swapEndian(uint16(0)),
        payloadType: ptString,
        payloadSize: swapEndian(payloadSize),
        payloadString: payload
    )

    let sendRes = conn.frameSender(conn, frame)
    if sendRes.error:
        raise newException(AMQPConnectionError, sendRes.result)

    if callback != nil:
        callback(conn)


# ----------------------------------------------------------------------------------------------------------------------
# connection::start
# ----------------------------------------------------------------------------------------------------------------------

proc connectionStart*(conn: AMQPConnection, stream: Stream, channel: uint16) = 
    ## connection.start method for AMQP
    # Read the data
    let args = stream.readConnectionStartArgs()
    conn.isRMQCompatible = args.isRMQCompatible

    # Validate the data

    # Respond by issuing connection.start-ok
    # FIXME: Hardcoded stuff
    var csoArgs = newConnectionStartOkArgs()
    csoArgs.mechanism = "PLAIN"
    csoArgs.locale = args.locales[0]
    # This is all SASL PLAIN really is
    csoArgs.response = fmt("\0{conn.username}\0{conn.password}")
    
    connectionStartOk(conn, csoArgs)


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


proc connectionStartOk*(conn: AMQPConnection, args: ConnectionStartOkArgs) = 
    ## Implementation of connection.start-ok for AMQP
    let argString = args.toWire().readAll()

    try:
        sendFrame(conn, argString, uint32(len(argString)), conn.frameHandler)
    except TimeoutError:
        raise newException(AMQPConnectionError, """Sending 'connection.start-ok' timed-out, this could be caused by 
                           invalid credentials""".singleLine)
    

# ----------------------------------------------------------------------------------------------------------------------
# connection::secure
# ----------------------------------------------------------------------------------------------------------------------
proc connectionSecure*(conn:AMQPConnection, stream: Stream, channel: uint16) =
    ## connection.secure implementation
    let chalSize = swapEndian(stream.readUint32())
    let chalString = stream.readStr(int(chalSize))
    # TODO: SASL/Alternative Auth Mechanisms?
    raise newException(AMQPNotImplementedError, "connection.secure is not implemented")


# ----------------------------------------------------------------------------------------------------------------------
# connection::secure-ok
# ----------------------------------------------------------------------------------------------------------------------
proc connectionSecureOk*(conn:AMQPConnection, response: string) = 
    ## connection.secure-ok implementation
    raise newException(AMQPNotImplementedError, "connection.secure-ok is not implemented")


# ----------------------------------------------------------------------------------------------------------------------
# connection::tune
# ----------------------------------------------------------------------------------------------------------------------
proc connectionTune*(conn: AMQPConnection, stream: Stream, channel: uint16) =
    ## connection.tune implementation
    var args = ConnectionTuneOkArgs()
    args.channel_max = stream.readUint16Endian()
    args.frame_max = stream.readUint32Endian()
    args.heartbeat = stream.readUint16Endian()

    connectionTuneOk(conn, args)


# TODO: Provide for client tuning parameters, right now we just accept what the server wants
# ----------------------------------------------------------------------------------------------------------------------
# connection::tune-ok
# ----------------------------------------------------------------------------------------------------------------------
proc connectionTuneOk*(conn: AMQPConnection, args: ConnectionTuneOkArgs) =
    ## connection.tune-ok implementation
    let argString = args.toWire().readAll()

    sendFrame(conn, argString, uint32(len(argString)))


# ----------------------------------------------------------------------------------------------------------------------
# connection::open
# ----------------------------------------------------------------------------------------------------------------------
proc connectionOpen*(conn: AMQPConnection, vhost: string = "/") =
    ## connection.open implementation
    let stream = newStringStream()

    stream.write(swapEndian(uint16(CLASS_ID)))
    stream.write(swapEndian(uint16(40)))

    stream.write(uint8(len(vhost)))
    stream.write(vhost)

    # Reserved stuff that RabbitMQ freaks out about if it's not there
    # https://www.rabbitmq.com/amqp-0-9-1-reference.html#connection.open
    stream.write(uint8(0))
    stream.write("")
    stream.write(uint8(0))

    stream.setPosition(0)

    let payload = stream.readAll()

    sendFrame(conn, payload, uint32(len(payload)), conn.frameHandler)


# ----------------------------------------------------------------------------------------------------------------------
# connection::open-ok
# ----------------------------------------------------------------------------------------------------------------------
proc connectionOpenOk*(conn: AMQPConnection, stream: Stream, channel: uint16) =
    ## connection.open-ok implementation
    conn.connectionReady = true

# ----------------------------------------------------------------------------------------------------------------------
# connection::close
# ----------------------------------------------------------------------------------------------------------------------
proc connectionClose*(conn: AMQPConnection, reply_code: uint16 = 200, reply_text="Normal shutdown", classId, 
                     methodId: uint16 = 0) =
    ## connection.close -- Client response
    let stream = newStringStream()

    stream.write(swapEndian(uint16(CLASS_ID)))
    stream.write(swapEndian(uint16(50)))

    stream.write(swapEndian(reply_code))
    stream.write(uint8(len(reply_text)))
    stream.write(reply_text)

    stream.write(swapEndian(classId))
    stream.write(swapEndian(methodId))

    stream.setPosition(0)

    let payload = stream.readAll()

    sendFrame(conn, payload, uint32(len(payload)), conn.frameHandler)


#  TODO: Put handlers in this which will handle close errors from server based on provided values
proc connectionClose*(conn: AMQPConnection, stream: Stream, channel: uint16) =
    ## connection.close -- Server response
    let code = swapEndian(stream.readUint16())
    let reason = stream.readStr(int(stream.readUint8()))

    let class = swapEndian(stream.readUint16())
    let meth = swapEndian(stream.readUint16())

    debug "Server requested to close connection", code=code, reason=reason, class=class, meth=meth
    connectionCloseOk(conn)


# ----------------------------------------------------------------------------------------------------------------------
# connection::close-ok
# ----------------------------------------------------------------------------------------------------------------------

# TODO: initiate shutdown of the thread/process from here
proc connectionCloseOk*(conn: AMQPConnection) =
    ## connection.close-ok implementation -- Client 
    let stream = newStringStream()

    stream.write(swapEndian(uint16(CLASS_ID)))
    stream.write(swapEndian(uint16(51)))
    stream.setPosition(0)

    let payload = stream.readAll()

    sendFrame(conn, payload, uint32(len(payload)))

    conn.connectionReady = false


proc connectionCloseOk*(conn: AMQPConnection, stream: Stream, channel: uint16) =
    ## connection.close-ok -- Server response
    conn.connectionReady = false
    let peerInfo = conn.sock.getPeerAddr()
    debug "Closed connection to server", serverAddr=peerInfo[0], serverPort=peerInfo[1]
