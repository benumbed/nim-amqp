## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##

import strformat
import net
import system
import strutils


proc extractUint32(data: string, offset: int): uint32 =
    ## Takes character data from a string, and extracts a uint32 from it at `offset`
    result = 0
    for i in 0..3:
        result = result or (uint32(data[offset+i]) shl ((3-i)*8))

proc extractUint16(data: string, offset: int): uint16 =
    ## Takes character data from a string, and extracts a uint16 from it at `offset`
    result = 0
    for i in 0..1:
        result = result or (uint16(data[offset+i]) shl ((1-i)*8))


type AMQPClass* = ref object of RootObj
    classId*: uint16
    className*: string
    
type AMQPMethod* = ref object of AMQPClass
    methodId*: uint16
    methodName*: string
    
type AMQPConnectionStart* = ref object of AMQPMethod
    versionMajor*: uint8
    versionMinor*: uint8
    mechanisms*: seq[string]
    locales*: seq[string]

method fromWire(this: AMQPConnectionStart, data: string): AMQPConnectionStart {.base.} = 
    new(result)
    var offset = 0;

    result.classId = extractUint16(data, offset)
    assert(result.classId == 10)
    offset += 2

    result.methodId = extractUint16(data, offset)
    assert(result.methodId == 10)
    offset += 2

    # version
    result.versionMajor = uint8(data[offset])
    offset += 1
    result.versionMinor = uint8(data[offset])
    offset += 1

    # server-properties
    let sp_size = extractUint32(data, offset)
    offset += 4+int(sp_size)

    # mechanisms
    let mech_size = extractUint32(data, offset)
    offset += 4
    let mechs = data[offset..(offset+int(mech_size-1))]
    offset += int(mech_size)
    result.mechanisms = mechs.strip().split()

    # locales
    let loc_size = extractUint32(data, offset)
    offset += 4
    let locs = data[offset..(offset+int(loc_size-1))]
    offset += int(loc_size)
    result.locales = locs.strip().split()

method `$`(this: AMQPConnectionStart): string {.base.} =
    var res: seq[string]
    res.insert(fmt"connection.start(version-major={this.versionMajor}, version-minor={this.versionMinor}, ", res.len)
    res.insert(fmt"server-properties=<coming soon>)", res.len)
    res.insert(fmt"mechanisms={this.mechanisms}, locales={this.locales})", res.len)

    result = res.join("")

when isMainModule:
    # let ssl_ctx = net.newContext()
    # var sock = asyncnet.newAsyncSocket()
    var sock = newSocket(buffered=true)
    # asyncnet.wrapSocket(ssl_ctx, sock)

    sock.connect("localhost", Port(5672), 5)

    let header = "AMQP\0\0\9\1"
    let sent = sock.trySend(header)
    
    let data = sock.recv(7, 500)
    if data.len() == 0:
        echo "Response from server was empty!"
        system.quit(QuitFailure)

    let frame_type = int(data[0])
    let channel = extractUint16(data, 1)
    echo fmt"Frame Type: {frame_type:#d} Channel: {channel:#d}"

    let payload_size = extractUint32(data, 3)
    echo fmt"Payload Size: {payload_size:#x} ({payload_size:#d}B)"

    let recv_data = sock.recv(int(payload_size)+1, 500)
    # Ensure the frame-end octet matches the spec
    assert(byte(recv_data[payload_size]) == 0xCE)
    
    # BEGIN -- Method Frame
    let payload = recv_data[0..(payload_size-1)]

    let cstart = AMQPConnectionStart().fromWire(payload)
    echo cstart

    sock.close()
