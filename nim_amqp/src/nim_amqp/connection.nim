## 
## Connection structures and procedures
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import strformat
import strutils

import ./methods
import ./utils


# ----------------------------------------------------------------------------------------------------------------------
# connection::start
# ----------------------------------------------------------------------------------------------------------------------

type AMQPConnectionStart* = object of AMQPMethod
    versionMajor*: uint8
    versionMinor*: uint8
    mechanisms*: seq[string]
    locales*: seq[string]

method `$`(this: AMQPConnectionStart): string {.base.} =
    var res: seq[string]
    res.insert(fmt"connection.start(version-major={this.versionMajor}, version-minor={this.versionMinor}, ", res.len)
    res.insert(fmt"server-properties=<coming soon>, ", res.len)
    res.insert(fmt"mechanisms={this.mechanisms}, locales={this.locales})", res.len)

    result = res.join("")

proc amqpConnectionStartFromWire*(payload: string): AMQPConnectionStart = 
    var offset = 0;

    result.classId = extractUint16(payload, offset)
    assert(result.classId == 10)
    result.className = "connection"
    offset += 2

    result.methodId = extractUint16(payload, offset)
    assert(result.methodId == 10)
    result.methodName = "start"
    offset += 2

    # version
    result.versionMajor = uint8(payload[offset])
    offset += 1
    result.versionMinor = uint8(payload[offset])
    offset += 1

    # server-properties
    let sp_size = extractUint32(payload, offset)
    offset += 4+int(sp_size)

    # mechanisms
    let mech_size = extractUint32(payload, offset)
    offset += 4
    let mechs = payload[offset..(offset+int(mech_size-1))]
    offset += int(mech_size)
    result.mechanisms = mechs.strip().split()

    # locales
    let loc_size = extractUint32(payload, offset)
    offset += 4
    let locs = payload[offset..(offset+int(loc_size-1))]
    offset += int(loc_size)
    result.locales = locs.strip().split()


# ----------------------------------------------------------------------------------------------------------------------
# connection::start-ok
# ----------------------------------------------------------------------------------------------------------------------

type AMQPConnectionStartOk* = object of AMQPMethod
    clientProperties*: string
    mechanism: string
    response: string
    locale: string

proc toWire*(this: AMQPConnectionStartOk): string =
    ## Converts an AMQPConnectionStartOk structure to wire format
    return ""