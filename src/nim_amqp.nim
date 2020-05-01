## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
# import net
import asyncnet, asyncdispatch
import strformat
import system
import tables

import nim_amqp/errors
import nim_amqp/frames
import nim_amqp/field_table
import nim_amqp/protocol
import nim_amqp/types
import nim_amqp/classes/connection
import nim_amqp/classes/channel

var channelTracking: Table[int, AMQPChannel]
var nextChannel: int = 0

proc connect*(host, username, password: string, vhost="/", port = 5672, tuning = AMQPTuning()): AMQPConnection =
    ## Creates a new AMQP connection
    result = newAMQPConnection(host, username, password, port)
    result.tuning = tuning
    result.newAMQPChannel(number=0, frames.handleFrame, frames.sendFrame).connectionOpen(vhost)


proc assignAvailableChannel(conn: AMQPConnection): AMQPChannel =
    ## Loops through the channelTracking table and tries to find an unused channel number
    ##
    nextChannel.inc

    if int(nextChannel) notin channelTracking or not channelTracking[nextChannel].active:
        channelTracking[nextChannel] = conn.newAMQPChannel(number=uint16(nextChannel), frames.handleFrame, 
                                                            frames.sendFrame)
        return channelTracking[nextChannel]
    
    var chNum = 1   # Channel 0 is reserved
    while chNum <= int(conn.tuning.channelMax):
        if int(chNum) notin channelTracking or not channelTracking[chNum].active:
            nextChannel = if (chNum == int(conn.tuning.channelMax)): 1 else: chNum + 1
            channelTracking[chNum] = conn.newAMQPChannel(number=uint16(chNum), frames.handleFrame, frames.sendFrame)
            return channelTracking[chNum]

    raise newException(AMQPError, fmt"Available channels exhausted (max: {conn.tuning.channelMax})")


proc createChannel*(conn: AMQPConnection): AMQPChannel =
    ## Creates a new channel on the existing connection.
    ##
    result = conn.assignAvailableChannel()
    result.channelOpen()


proc removeChannel*(chan: AMQPChannel) =
    ## Removes the provided channel, and closes it on the server
    ##
    if int(chan.number) notin channelTracking:
        raise newException(AMQPError, fmt"Provided channel '{chan.number}' isn't in the global channel tracking table")

    chan.channelClose()
    chan.active = false
    channelTracking.del(int(chan.number))


proc createExchange*(chan: AMQPChannel, exchangeName: string, exchangeType: string, passive: bool, durable: bool, 
                      autoDelete: bool, internal: bool, noWait: bool, arguments = FieldTable()) = 
    ## Creates a new exchange on the server
    ## `exchangeName`: The name of the exchange to create
    ## `exchangeType`: Type of exchange to create (direct, fanout, topic, headers)
    ## `passive`: If true, will not raise an error when attempting to create an exchange that already exists. When this
    ##            is set, all arguments except `exchangeName` and `noWait` are ignored.
    ## `durable`: If true, will create a durable (persisted on reboot) exchange
    ## `autoDelete`: If set, this exchange will be deleted after all bound queues are finished used it
    ## `internal`: This exchange will not be visible to publishers, and can only connect to other exchanges
    ## `noWait`: Indicates client is not waiting for exchange creation
    ## `arguments`: field-table passed to server. This is server implementation specific.


proc removeExchange*(chan: AMQPChannel, exchangeName: string, ifUnused: bool, noWait: bool) =
    ## Removes an exchange from the server
    ##


proc publish*(chan: AMQPChannel) =
    ## Publish a message to the server
    ##

proc startBlockingConsumer*(chan: AMQPChannel) = 
    ## Starts a consumer process
    ## NOTE: This function enters a blocking loop, and will not return until the connection is terminated!
    ## (TODO: Define a way to register callbacks for recieved messages)

proc startAsyncConsumer*(chan: AMQPChannel) =
    ## Starts an async-compatible consumer
    ##


when isMainModule:
    # let ssl_ctx = net.newContext()
    var sock = newAsyncSocket()
    # var sock = newSocket(buffered=true)
    waitFor sock.connect("localhost", Port(5672))
    # asyncnet.wrapSocket(ssl_ctx, sock)

    # let frame = sock.readFrame()

    runForever()

    sock.close()
