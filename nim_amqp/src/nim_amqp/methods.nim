## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import streams

import ./utils
import ./protocol
import ./errors

type AMQPMethodError* = object of AMQPError

type AMQPClass* = ref object of RootObj
    classId*: uint16
    className*: string
    
type AMQPMethod* = ref object of AMQPClass
    methodId*: uint16
    methodName*: string
    arguments*: Stream

proc extractMethod*(frame: AMQPFrame): AMQPMethod =
    ## Extracts the basic data for an AMQP method call (does not parse arguments)
    new(result)

    result.classId = frame.payload.readUint16Endian()
    result.methodId = frame.payload.readUint16Endian()
    result.arguments = frame.payload
