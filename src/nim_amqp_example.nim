import argparse
import chronicles
import streams

import nim_amqp

when isMainModule:
    let exchangeName = "nim_amqp_consumer_test"
    let queueName = "nim_amqp_consumer"
    let routingKey = "consumer-test"

    let chan = connect("rabbit.nexus", "testing", "testing", vhost="testing").createChannel()
    chan.createExchange(exchangeName, "direct")
    chan.createAndBindQueue(queueName, exchangeName, routingKey)

    proc msgHandler(chan: AMQPChannel, message: ContentData) =
        ## Handle messages
        ##
        warn "Got a message", contentType=message.header.propertyList.contentType, body=message.body.readAll()

        # This permanently removes the message from the queue
        chan.acknowledgeMessage(0, useChanContentTag=true)

    chan.registerMessageHandler(msgHandler)
    chan.startBlockingConsumer(queueName, noLocal=false)
