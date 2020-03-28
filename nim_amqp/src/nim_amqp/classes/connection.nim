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

import ../methods
import ../utils
import ../errors
import ../field_table

type AMQPConnectionError* = object of AMQPError


# ----------------------------------------------------------------------------------------------------------------------
# connection::start
# ----------------------------------------------------------------------------------------------------------------------

type MethodConnectionStart* = ref object of AMQPMethod
    versionMajor*: uint8
    versionMinor*: uint8
    serverProperties*: FieldTable
    mechanisms*: seq[string]
    locales*: seq[string]
method `$`*(this: MethodConnectionStart): string {.base.} =
    ## repr for AMQPConnectionStart
    var res: seq[string]
    res.insert(fmt"connection.start(version-major={this.versionMajor}, version-minor={this.versionMinor}, ", res.len)
    res.insert(fmt"server-properties={this.serverProperties}, ", res.len)
    res.insert(fmt"mechanisms={this.mechanisms}, locales={this.locales})", res.len)
    result = res.join("")


proc extractConnectionStart*(meth: AMQPMethod): MethodConnectionStart = 
    ## Takes an AMQPMethod, fresh from wire extraction, and converts it to an internal connection.start structure map
    new(result)
    
    # This works because result is a ref.  So we type-shift it to AMQPMethod, then assign the fields from meth 
    # (because we're derefrencing via [])
    # https://nim-lang.org/docs/manual.html#types-reference-and-pointer-types
    AMQPMethod(result)[] = meth[]

    # version
    result.versionMajor = meth.arguments.readUint8()
    result.versionMinor = meth.arguments.readUint8()

    # server-properties
    let sp_size = meth.arguments.readUint32Endian()
    result.serverProperties = extractFieldTable(newStringStream(meth.arguments.readStr(int(sp_size))))

    # mechanisms
    let mech_size = meth.arguments.readUint32Endian()
    let mechs = meth.arguments.readStr(int(mech_size))
    result.mechanisms = mechs.strip().split()

    # locales
    let loc_size = meth.arguments.readUint32Endian()
    let locs = meth.arguments.readStr(int(loc_size))
    result.locales = locs.strip().split()


# ----------------------------------------------------------------------------------------------------------------------
# connection::start-ok
# ----------------------------------------------------------------------------------------------------------------------

type MethodConnectionStartOk* = ref object of AMQPMethod
    clientProperties*: FieldTable
    mechanism*: string
    response*: string
    locale*: string

proc newMethodConnectionStartOk*(): MethodConnectionStartOk =
    ## Creates a new MethodConnectionStartOk with the classId and methodId set properly
    new(result)

    result.classId = 10
    result.methodId = 11
    result.clientProperties = new(FieldTable)


proc toWire*(this: MethodConnectionStartOk): Stream =
    ## Converts an AMQPConnectionStartOk structure to wire format
    result = newStringStream()
    this.clientProperties["product"] = FieldTableValue(valType: ftShortString, shortStringVal: "nim-amqp")

    let cpft = this.clientProperties.toWire().readAll()
    result.write(swapEndian(uint32(len(cpft))))
    result.write(cpft)
    result.write(uint8(len(this.mechanism)))
    result.write(this.mechanism)
    result.write(uint32(len(this.response)))
    result.write(this.response)
    result.write(uint8(len(this.locale)))
    result.write(this.locale)


# ----------------------------------------------------------------------------------------------------------------------
# connection::secure
# ----------------------------------------------------------------------------------------------------------------------
type MethodConnectionSecure* = object of AMQPMethod
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
type MethodConnectionClose* = ref object of AMQPMethod
    reply_code*: uint16
    reply_text*: string

proc extractConnectionClose*(meth: AMQPMethod): MethodConnectionClose =
    return result

# ----------------------------------------------------------------------------------------------------------------------
# connection::close-ok
# ----------------------------------------------------------------------------------------------------------------------
