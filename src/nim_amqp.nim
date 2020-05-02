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
import nim_amqp/classes/exchange
import nim_amqp/classes/queue

var channelTracking: Table[int, AMQPChannel]
var nextChannel: int = 0

proc connect*(host, username, password: string, vhost="/", port = 5672, tuning = AMQPTuning()): AMQPConnection =
    ## Creates a new AMQP connection, authenticates, and then connects to the provided `vhost`
    ## 
    ## `host`: The AMQP host to connect to
    ## `username`: Username to use to authenticate
    ## `password`: Password to use to authenticate
    ## `vhost`: vhost to connect to, defaults to '/'
    ## `port`: Port number on the server to connect to, defaults to 5672
    ## `tuning`: AMQP tuning parameters, defaults to blank structure
    ##
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
            nextChannel = chNum # Assign it the current channel because it will increment on the next call of this proc
            channelTracking[chNum] = conn.newAMQPChannel(number=uint16(chNum), frames.handleFrame, frames.sendFrame)
            return channelTracking[chNum]

    raise newException(AMQPError, fmt"Available channels exhausted (max: {conn.tuning.channelMax})")


proc createChannel*(conn: AMQPConnection): AMQPChannel =
    ## Creates a new channel on the existing connection.  Note that nim-amqp manages the channel numbers for you at the
    ## current time.  In the future, manual management will be made available.
    ##
    result = conn.assignAvailableChannel()
    result.channelOpen()


proc removeChannel*(chan: AMQPChannel) =
    ## Removes the channel, and closes it on the server.
    ##
    if int(chan.number) notin channelTracking:
        raise newException(AMQPError, fmt"Provided channel '{chan.number}' isn't in the global channel tracking table")

    chan.channelClose()
    chan.active = false


proc disconnect*(chan: AMQPChannel) =
    ## Nicely disconnects from the server (sets 200 status on connection.close)
    ## 
    if chan.active:
        chan.removeChannel()
    chan.connectionClose()


proc createExchange*(chan: AMQPChannel, exchangeName, exchangeType: string, passive = false, durable = true, 
                    autoDelete = false, internal = false, noWait = false, arguments = FieldTable()) = 
    ## Creates a new exchange on the server
    ## 
    ## `exchangeName`: The name of the exchange to create
    ## `exchangeType`: Type of exchange to create (direct, fanout, topic, headers)
    ## `passive`: If true, will not raise an error when attempting to create an exchange that already exists. When this
    ##            is set, all arguments except `exchangeName` and `noWait` are ignored.
    ## `durable`: If true, will create a durable (persisted on reboot) exchange
    ## `autoDelete`: If set, this exchange will be deleted after all bound queues are finished used it
    ## `internal`: This exchange will not be visible to publishers, and can only connect to other exchanges
    ## `noWait`: Indicates client is not waiting for exchange creation
    ## `arguments`: field-table passed to server. This is server implementation specific.
    ##
    chan.exchangeDeclare(exchangeName, exchangeType, passive, durable, autoDelete, internal, noWait, arguments)


proc removeExchange*(chan: AMQPChannel, exchangeName: string, ifUnused = false, noWait = false) =
    ## Removes an exchange from the server
    ##
    chan.exchangeDelete(exchangeName, ifUnused, noWait)


proc bindQueueToExchange*(chan: AMQPChannel, queueName, exchangeName, routingKey: string, noWait = false, 
                            arguments = FieldTable()) =
    ## Binds a queue `queueName` to exchange `exchangeName` using `routingKey`
    ##
    ## `queueName`: Name of the queue to bind
    ## `exchangeName`: Name of the exchange to bind to
    ## `routingKey`: Routing key to associate with queue on the exchange
    ## `noWait`: Tell server to not send a response
    ##
    chan.queueBind(queueName, exchangeName, routingKey, noWait, arguments)


proc createAndBindQueue*(chan: AMQPChannel, queueName, exchangeName, routingKey: string, noWait = false, 
                            arguments = FieldTable()) =
    ## Creates a queue then binds it to the specified queue with `routingKey`.  This proc does not expose all the 
    ## functionality of `createQueue`, and will simply create a non-exclusive, durable queue.
    ## 
    ## `queueName`: Name of the queue to create, and bind
    ## `exchangeName`: Name of the exchange to bind to
    ## `routingKey`: Routing key to associate with queue on the exchange
    ## `noWait`: Tell server to not send a response
    ##
    chan.queueDeclare(queueName, durable = true, exclusive = false, noWait=noWait)
    chan.queueBind(queueName, exchangeName, routingKey, noWait=noWait)


proc removeQueue*(chan: AMQPChannel, queueName: string, ifUnused = false, ifEmpty = false, noWait = false) = 
    ## Removes a queue from the server.  Removing a queue will also automatically unbind the queue from any exchanges
    ##
    chan.queueDelete(queueName, ifUnused, ifEmpty, noWait)


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
