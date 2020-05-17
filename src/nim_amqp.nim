## 
## Implementation of the AMQP protocol in pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import chronicles
import net
import strformat
import streams
import system
import tables

import nim_amqp/errors
import nim_amqp/frames
import nim_amqp/protocol
import nim_amqp/types
import nim_amqp/classes/basic
import nim_amqp/classes/connection
import nim_amqp/classes/channel
import nim_amqp/classes/exchange
import nim_amqp/classes/queue

var channelTracking: Table[int, AMQPChannel]
var nextChannel: int = 0
var consumerLoopRunning = false

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
    result = newAMQPConnection(host, username, password, port, tuning=tuning)
    result.newAMQPChannel(number=0, frames.handleFrame, frames.sendFrame).connectionOpen(vhost)


proc reconnect*(conn: AMQPConnection) =
    ## Takes an existing connection and tries to reconnect to the server
    ## 
    conn.sock.connect(conn.host, conn.port, timeout=conn.connectTimeout)


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
    ## Closes the active channel
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
    ## `queueName`: Name of the queue to remove
    ## `ifUnused`: Only remove the queue if it is not in use
    ## `ifEmpty`: Only remove the queue if it is empty
    ## `noWait`: Tell server to not send a response
    ## 
    chan.queueDelete(queueName, ifUnused, ifEmpty, noWait)


proc publish*(chan: AMQPChannel, exchangeName: string, routingKey: string, mandatory: bool, immediate: bool) =
    ## Publish a message to the server
    ## 
    ## `exchangeName`: Exchange to publish message to
    ## `routingKey`: The routing key to provide to the exchange 
    ## `mandatory`: If the message cannot be routed, it will be returned via basic.return
    ## `immediate`: If true, and the server cannot route the message to a consumer immedaitely the server will return 
    ##              the message (via basic.return)
    ##
    chan.basicPublish(exchangeName, routingKey, mandatory, immediate)


proc registerMessageHandler*(chan: AMQPChannel, callback: ConsumerMsgCallback) =
    ## Registers a handler (scoped to current channel) that is called when the server sends a message to a consumer
    ## 
    ## `callback`: The procedure to call when the server sends a message to a consumer
    ## 
    chan.messageCallback = callback


proc registerReturnedMessageHandler*(chan: AMQPChannel, callback: MessageReturnCallback) =
    ## Registers a handler for returned messages on the current channel.  This is used when the server returns messages
    ## from a `publish` with either `mandatory` or `immediate` set.
    ##
    ## `callback`: The procedure to call when the server returns a message
    ## 
    chan.returnCallback = callback


proc startBlockingConsumer*(chan: AMQPChannel, reconnect=true) =
    ## Starts a consumer process
    ## **NOTE**: This function enters a blocking loop, and will not return until the connection is terminated or CTRL+C
    ##           is sent to the process.
    ##
    ## `reconnect`: Will try to automatically reconnect on error.  The number of reconnect attempts is controlled from
    ##              the `maxReconnectAttempts` variable on the active connection.
    if isnil chan.messageCallback:
        raise newException(AMQPError, "The internal consumer loop requires you to set the message handler callback")

    info "Starting the nim-amqp blocking consumer"
    
    consumerLoopRunning = true
    proc killLoop() {.noconv.} =
      info "Keyboard interrupt received, exiting loop"
      consumerLoopRunning = false

    setControlCHook(killLoop)

    var reconAttempts = 0

    while consumerLoopRunning and chan.active and chan.conn.ready:
        try:
            chan.handleFrame
        except AMQPError as e:
            if not chan.active or not chan.conn.ready:
                # TODO: Make reconnects actually work
                if reconAttempts <= chan.conn.maxReconnectAttempts:
                    reconAttempts.inc
                    error "Recieved an exception in blocking loop, attempting to reconnect", exception=e.msg
                    chan.conn.reconnect
                    reconAttempts = 0
                else:
                    raise newException(AMQPError, "Surpassed the allowed number of reconnects")

    unsetControlCHook()
    chan.disconnect()


proc startAsyncConsumer*(chan: AMQPChannel) =
    ## Starts an async-compatible consumer
    ##


when isMainModule:
    let chan = connect("localhost", "guest", "guest").createChannel()
    chan.createExchange("nim_amqp_test", "direct")
    chan.createAndBindQueue("nim_amqp_test_queue", "nim_amqp_test", "content-test")
    chan.basicConsume("nim_amqp_test_queue", "content-test", false, false, false, false)
    proc msgHandler(chan: AMQPChannel, header: AMQPContentHeader, body: Stream) =
        ## Handle messages
        echo "Got a message!"
        echo "content-type: ", header.propertyList.contentType
        echo "body:\n", body.readAll()
        

    chan.registerMessageHandler(msgHandler)
    chan.startBlockingConsumer
    quit(0)
