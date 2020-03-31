## 
## Class-related things
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import tables

import ./types
import ./utils
import ./classes/basic
import ./classes/channel
import ./classes/connection
import ./classes/exchange
import ./classes/queue
import ./classes/tx

let amqpClassMap = {
    # connection
    uint16(10): connectionMethodMap,
    # channel
    uint16(20): channelMethodMap,
    # exchange
    uint16(40): exchangeMethodMap,
    # queue
    uint16(50): queueMethodMap,
    # basic
    uint16(60): basicMethodMap,
    # tx
    uint16(70): txMethodMap
}.toTable()


proc classMethodDispatcher*(conn: AMQPConnection, frame: AMQPFrame) =
    let classId = frame.payloadStream.readUint16Endian()
    let methodId = frame.payloadStream.readUint16Endian()
    ## AMQP class dispatcher
    amqpClassMap[classId][methodId](conn, frame.payloadStream)