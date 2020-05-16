## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##

type StrWithError* = tuple[result: string, error: bool]

type AMQPError* = object of system.CatchableError
    class*: uint16
    meth*: uint16
    code*: uint16

template newAMQPException*(exceptn: typedesc, message: string, classId: uint16 = 0, methId: uint16 = 0, statusCode: uint16 = 0): untyped =
    ## Creates an exception object of type ``exceptn`` and sets its ``msg`` field
    ## to `message`. Returns the new exception object.
    (ref exceptn)(class: classId, meth: methId, code: statusCode, msg: message)


type
    AMQPNotImplementedError* = object of AMQPError
    AMQPVersionError* = object of AMQPError
    AMQPSocketClosedError* = object of AMQPError