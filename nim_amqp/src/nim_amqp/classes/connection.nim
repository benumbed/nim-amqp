## 
## Connection structures and procedures
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import strformat
import streams
import strutils
import system

import ../methods
import ../utils
import ../errors
import ../field_table

type AMQPConnectionError* = object of AMQPError


# ----------------------------------------------------------------------------------------------------------------------
# connection::start
# ----------------------------------------------------------------------------------------------------------------------

type AMQPConnectionStart* = ref object of AMQPMethod
    versionMajor*: uint8
    versionMinor*: uint8
    serverProperties*: FieldTable
    mechanisms*: seq[string]
    locales*: seq[string]
method `$`*(this: AMQPConnectionStart): string {.base.} =
    ## repr for AMQPConnectionStart
    var res: seq[string]
    res.insert(fmt"connection.start(version-major={this.versionMajor}, version-minor={this.versionMinor}, ", res.len)
    res.insert(fmt"server-properties={this.serverProperties}, ", res.len)
    res.insert(fmt"mechanisms={this.mechanisms}, locales={this.locales})", res.len)
    result = res.join("")


proc extractConnectionStart*(meth: AMQPMethod): AMQPConnectionStart = 
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

type AMQPConnectionStartOk* = object of AMQPMethod
    clientProperties*: string
    mechanism: string
    response: string
    locale: string


proc connectionStartOktoWire*(this: AMQPConnectionStartOk): string =
    ## Converts an AMQPConnectionStartOk structure to wire format
    return ""