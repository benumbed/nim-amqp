## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##

type AMQPClass* = object of RootObj
    classId*: uint16
    className*: string
    
type AMQPMethod* = ref object of AMQPClass
    methodId*: uint16
    methodName*: string

type AMQPMethodCallback = (proc(payload: string): ref AMQPMethod)