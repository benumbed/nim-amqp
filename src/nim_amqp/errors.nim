## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##

type StrWithError* = tuple[result: string, error: bool]

type AMQPError* = object of system.CatchableError
type AMQPNotImplementedError* = object of AMQPError