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
import ../frames
import ../types
import ../utils

type AMQPConnectionError* = object of AMQPError

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


proc connectionStart*(conn: AMQPConnection, stream: Stream)
proc connectionStartOk*(conn: AMQPConnection, args: ConnectionStartOkArgs)
proc readConnectionStartArgs*(stream: Stream): ConnectionStartArgs
proc newConnectionStartOkArgs*(): ConnectionStartOkArgs

var connectionMethodMap* = MethodMap()
# These are only for incoming calls
connectionMethodMap[10] = connectionStart


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
    csoArgs.response = fmt("\0{conn.username}\0{conn.password}")   # Will need the SASL implementation for this
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


proc toWire*(this: ConnectionStartOkArgs): Stream =
    ## Converts an AMQPConnectionStartOk structure to wire format
    result = newStringStream()
    this.clientProperties["product"] = FieldTableValue(valType: ftShortString, shortStringVal: "nim-amqp")

    # client-properties
    let cpft = this.clientProperties.toWire().readAll()
    result.write(swapEndian(uint32(len(cpft))))
    result.write(cpft)
    # mechanism
    result.write(uint8(len(this.mechanism)))
    result.write(this.mechanism)
    # response (SASL)
    result.write(uint32(len(this.response)))
    result.write(this.response)
    # locale
    result.write(uint8(len(this.locale)))
    result.write(this.locale)


proc connectionStartOk*(conn: AMQPConnection, args: ConnectionStartOkArgs) = 
    ## Implementation of connection.start-ok for AMQP
    let argString = args.toWire().readAll()

    let frame = AMQPFrame(
        payloadType: ptString,
        frameType: 1,
        channel: 0,
        payloadSize: uint32(len(argString)),
        payloadString: argString
    )

    sendFrame(conn, frame)
    

# ----------------------------------------------------------------------------------------------------------------------
# connection::secure
# ----------------------------------------------------------------------------------------------------------------------
type MethodConnectionSecure* = object
    challenge: string


# ----------------------------------------------------------------------------------------------------------------------
# connection::tune
# ----------------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------------
# connection::tune-ok
# ----------------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------------
# connection::open
# ----------------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------------
# connection::close
# ----------------------------------------------------------------------------------------------------------------------
type MethodConnectionClose* = object
    reply_code*: uint16
    reply_text*: string

proc extractConnectionClose*(stream: Stream): MethodConnectionClose =
    return result

# ----------------------------------------------------------------------------------------------------------------------
# connection::close-ok
# ----------------------------------------------------------------------------------------------------------------------
