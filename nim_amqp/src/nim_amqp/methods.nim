## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import ./utils
import ./protocol

type AMQPClass* = ref object of RootObj
    classId*: uint16
    className*: string
    
type AMQPMethod* = ref object of AMQPClass
    methodId*: uint16
    methodName*: string
    arguments*: string

proc extractMethod*(frame: AMQPFrame): AMQPMethod =
    ## Extracts the basic data for an AMQP method call (does not parse arguments)
    var offset = 0;

    new(result)

    result.classId = extractUint16(frame.payload, offset)
    assert(result.classId == 10)
    result.className = "connection"
    offset += 2

    result.methodId = extractUint16(frame.payload, offset)
    assert(result.methodId == 10)
    result.methodName = "start"
    offset += 2

    result.arguments = frame.payload[offset..(frame.payloadSize-1)]

type AMQPMethodCallback = (proc(payload: string): ref AMQPMethod)