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

import ./methods
import ./utils
import ./errors
import ./field_table

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
    res.insert(fmt"server-properties=<coming soon>, ", res.len)
    res.insert(fmt"mechanisms={this.mechanisms}, locales={this.locales})", res.len)
    result = res.join("")


proc extractFieldTable(stream: Stream): FieldTable =
    ## Extracts a field-table out of `stream`
    new(result)

    while not stream.atEnd():
        let keySize = stream.readInt8()
        let key = stream.readStr(keySize)
        let valType = FieldTableValueType(stream.readChar())
        var value: FieldTableValue

        if valType == ftFieldTable:
            value = FieldTableValue(valType: ftFieldTable, tableVal: stream.readAll())
        # TODO: Finish this
        else:
            let valSize = stream.readUint32Endian()
            let intermediateValue = stream.readStr(int(valSize))
            value = FieldTableValue()

        result[key] = value


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
    # Read from stream until the current position == sp_size
    echo meth.arguments.peekStr(int(sp_size))
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