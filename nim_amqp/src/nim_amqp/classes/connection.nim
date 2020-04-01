## 
## Connection structures and procedures
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import strformat
import streams
import strutils
import system
import tables

import ../errors
import ../field_table
import ../types
import ../utils

type AMQPConnectionClassError* = object of AMQPError

type ConnectionStartArgs* = object
    versionMajor*: uint8
    versionMinor*: uint8
    serverProperties*: FieldTable
    mechanisms*: seq[string]
    locales*: seq[string]
method `$`*(this: ConnectionStartArgs): string {.base.} =
    ## repr for AMQPConnectionStart
    var res: seq[string]
    res.insert(fmt"connection.start(version-major={this.versionMajor}, version-minor={this.versionMinor}, ", res.len)
    res.insert(fmt"server-properties={this.serverProperties}, ", res.len)
    res.insert(fmt"mechanisms={this.mechanisms}, locales={this.locales})", res.len)
    result = res.join("")

type ConnectionStartOkArgs* = object
    clientProperties*: FieldTable
    mechanism*: string
    response*: string
    locale*: string
method toWire*(this: ConnectionStartOkArgs): Stream {.base.} =
    ## Converts an AMQPConnectionStartOk structure to wire format
    result = newStringStream()
    # FIXME: The table freaks RabbitMQ the fuck out, not sure why atm, but it's not needed for proper negotiation
    # this.clientProperties["client-name"] = FieldTableValue(valType: ftShortString, shortStringVal: "nim-amqp")

    # Class and Method IDs
    result.write(swapEndian(uint16(10)))
    result.write(swapEndian(uint16(11)))

    # client-properties
    let cpft = this.clientProperties.toWire().readAll()
    result.write(swapEndian(uint32(len(cpft))))
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
    result.write(swapEndian(uint16(10)))
    result.write(swapEndian(uint16(31)))

    result.write(swapEndian(this.channel_max))
    result.write(swapEndian(this.frame_max))
    result.write(swapEndian(this.heartbeat))

    result.setPosition(0)


proc connectionStart*(conn: AMQPConnection, stream: Stream)
proc connectionStartOk*(conn: AMQPConnection, args: ConnectionStartOkArgs)
proc connectionTune*(conn: AMQPConnection, stream: Stream)
proc connectionTuneOk*(conn: AMQPConnection, args: ConnectionTuneOkArgs)
proc connectionOpen*(conn: AMQPConnection)
proc connectionOpenOk*(conn: AMQPConnection, stream: Stream)
proc connectionClose*(conn: AMQPConnection, reply_code: uint16 = 200, reply_text="Normal shutdown", classId, 
                     methodId: uint16 = 0)
proc connectionClose*(conn: AMQPConnection, stream: Stream)
proc connectionCloseOk*(conn: AMQPConnection)
proc connectionCloseOk*(conn: AMQPConnection, stream: Stream)
proc readConnectionStartArgs*(stream: Stream): ConnectionStartArgs
proc newConnectionStartOkArgs*(): ConnectionStartOkArgs

var connectionMethodMap* = MethodMap()
# These are only for incoming calls
connectionMethodMap[10] = connectionStart
connectionMethodMap[30] = connectionTune
connectionMethodMap[41] = connectionOpenOk
connectionMethodMap[50] = connectionClose
connectionMethodMap[51] = connectionCloseOk


# ----------------------------------------------------------------------------------------------------------------------
# connection::start
# ----------------------------------------------------------------------------------------------------------------------

proc connectionStart*(conn: AMQPConnection, stream: Stream) = 
    ## connection.start method for AMQP
    # Read the data
    let args = stream.readConnectionStartArgs()

    # Validate the data

    # Respond by issuing connection.start-ok
    # FIXME: Hardcoded stuff
    var csoArgs = newConnectionStartOkArgs()
    csoArgs.mechanism = "PLAIN"
    csoArgs.locale = args.locales[0]
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

    let frame = AMQPFrame(
        frameType: 1,
        channel: swapEndian(uint16(0)),
        payloadType: ptString,
        payloadSize: swapEndian(uint32(len(argString))),
        payloadString: argString
    )

    let sendRes = conn.frameSender(conn, frame)
    if sendRes.error:
        raise newException(AMQPConnectionClassError, sendRes.result)
    conn.frameHandler(conn)
    

# ----------------------------------------------------------------------------------------------------------------------
# connection::secure
# ----------------------------------------------------------------------------------------------------------------------



# ----------------------------------------------------------------------------------------------------------------------
# connection::tune
# ----------------------------------------------------------------------------------------------------------------------
proc connectionTune*(conn: AMQPConnection, stream: Stream) =
    ## connection.tune implementation
    var args = ConnectionTuneOkArgs()
    args.channel_max = stream.readUint16Endian()
    args.frame_max = stream.readUint32Endian()
    args.heartbeat = stream.readUint16Endian()

    connectionTuneOk(conn, args)


# ----------------------------------------------------------------------------------------------------------------------
# connection::tune-ok
# ----------------------------------------------------------------------------------------------------------------------
proc connectionTuneOk*(conn: AMQPConnection, args: ConnectionTuneOkArgs) =
    ## connection.tune-ok implementation
    let argString = args.toWire().readAll()

    let frame = AMQPFrame(
        frameType: 1,
        channel: swapEndian(uint16(0)),
        payloadType: ptString,
        payloadSize: swapEndian(uint32(len(argString))),
        payloadString: argString
    )

    let sendRes = conn.frameSender(conn, frame)
    if sendRes.error:
        raise newException(AMQPConnectionClassError, sendRes.result)

    connectionOpen(conn)


# ----------------------------------------------------------------------------------------------------------------------
# connection::open
# ----------------------------------------------------------------------------------------------------------------------
proc connectionOpen*(conn: AMQPConnection) =
    let vhost = "/"
    let stream = newStringStream()

    stream.write(swapEndian(uint16(10)))
    stream.write(swapEndian(uint16(40)))

    stream.write(uint8(len(vhost)))
    stream.write(vhost)

    stream.write(uint8(0))
    stream.write("")
    stream.write(uint8(0))

    stream.setPosition(0)

    let payload = stream.readAll()

    ## connection.open implementation
    let frame = AMQPFrame(
        frameType: 1,
        channel: swapEndian(uint16(0)),
        payloadType: ptString,
        payloadSize: swapEndian(uint32(len(payload))),
        payloadString: payload
    )

    let sendRes = conn.frameSender(conn, frame)
    if sendRes.error:
        raise newException(AMQPConnectionClassError, sendRes.result)
        
    conn.frameHandler(conn)

    connectionClose(conn)

# ----------------------------------------------------------------------------------------------------------------------
# connection::open-ok
# ----------------------------------------------------------------------------------------------------------------------
proc connectionOpenOk*(conn: AMQPConnection, stream: Stream) =
    ## connection.open-ok implementation

# ----------------------------------------------------------------------------------------------------------------------
# connection::close
# ----------------------------------------------------------------------------------------------------------------------
proc connectionClose*(conn: AMQPConnection, reply_code: uint16 = 200, reply_text="Normal shutdown", classId, 
                     methodId: uint16 = 0) =
    ## connection.close -- Client response
    let stream = newStringStream()

    stream.write(swapEndian(uint16(10)))
    stream.write(swapEndian(uint16(50)))

    stream.write(swapEndian(reply_code))
    stream.write(uint8(len(reply_text)))
    stream.write(reply_text)

    stream.write(swapEndian(classId))
    stream.write(swapEndian(methodId))

    stream.setPosition(0)

    let payload = stream.readAll()

    let frame = AMQPFrame(
        frameType: 1,
        channel: swapEndian(uint16(0)),
        payloadType: ptString,
        payloadSize: swapEndian(uint32(len(payload))),
        payloadString: payload
    )

    let sendRes = conn.frameSender(conn, frame)
    if sendRes.error:
        raise newException(AMQPConnectionClassError, sendRes.result)
        
    conn.frameHandler(conn)


proc connectionClose*(conn: AMQPConnection, stream: Stream) =
    ## connection.close -- Server response
    let code = swapEndian(stream.readUint16())
    let reason = stream.readStr(int(stream.readUint8()))

    let class = swapEndian(stream.readUint16())
    let meth = swapEndian(stream.readUint16())

    connectionCloseOk(conn)

# ----------------------------------------------------------------------------------------------------------------------
# connection::close-ok
# ----------------------------------------------------------------------------------------------------------------------
proc connectionCloseOk*(conn: AMQPConnection) =
    ## connection.close-ok implementation
    let stream = newStringStream()

    stream.write(swapEndian(uint16(10)))
    stream.write(swapEndian(uint16(51)))
    stream.setPosition(0)

    let payload = stream.readAll()

    let frame = AMQPFrame(
        frameType: 1,
        channel: swapEndian(uint16(0)),
        payloadType: ptString,
        payloadSize: swapEndian(uint32(len(payload))),
        payloadString: payload
    )

    let sendRes = conn.frameSender(conn, frame)
    if sendRes.error:
        raise newException(AMQPConnectionClassError, sendRes.result)


proc connectionCloseOk*(conn: AMQPConnection, stream: Stream) =
    ## connection.close-ok -- Server response
    return