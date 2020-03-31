## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##

type AMQPError* = ref object of Exception
type AMQPNotImplementedError* = object of AMQPError