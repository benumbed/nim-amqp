# Nim AMQP Library (nim-amqp)
AMQP 0-9-1 implementation in Nim.  

## NOTES
* This is RabbitMQ flavored AMQP 0-9-1.  The engineers who wrote RabbitMQ and the architects that designed AMQP 0-9-1 did not agree on some things (and to be fair the AMQP 0-9-1 spec contradicts itself in several important places), and so the RabbitMQ path was followed since it's a very common AMQP server.

* This library is still a work in progress (AKA don't use this in production).  While the basic pub/sub capabilities are there, there's a lot of error handling and niceties that haven't been added yet.
* The library is currently only tested on Linux, so there may be gotchas in other OSes. I haven't had time to set up CI for this project yet.
 
There are two ways to use this library, the abstraction layer, which exists in `nim_amqp.nim` or the AMQP class-based layer (not recommended).  Efforts are made to keep the documentation in the abstraction layer up to date as it changes.  The same can not be said for the class modules right now.

Currently, the library is synchronous.  There is a desire to make it `multisync` (Nim's terminology for sync/async hybrid code), however this was my first project I tackled while learning Nim, so async support was temporarily shelved while I got my feet under me.

You can write your own consumer, or you can use the `startBlockingConsumer` procedure within `nim_amqp.nim`.  Note that if you use the included consumer loop, you'll need to at least register a message callback (`registerMessageHandler`) so the consumer has somewhere to send the messages it recieves.  For an incredibly basic example of how to use the abstraction layer, see the bottom of `nim_amqp.nim`.

To generate the API documentation, run `nim doc -o=docs/ --project src/nim_amqp.nim` from the root of this repo. Like the rest of the library, the docs are a work in progress, but the abstraction layer is relatively well documented at this time.

## Installation
```
nimble install nim-amqp
```

## Usage Examples
**Note:** You'll need an AMQP server like RabbitMQ running locally to run this example. I recommend the `rabbitmq` Docker container.

### Simple Consumer
```nim
import nim_amqp

let chan = connect("localhost", "guest", "guest").createChannel()
chan.createExchange("nim_amqp_test", "direct")
chan.createAndBindQueue("nim_amqp_test_queue", "nim_amqp_test", "content-test")

proc msgHandler(chan: AMQPChannel, message: ContentData) =
    ## Handle messages
    ##
    warn "Got a message", contentType=message.header.propertyList.contentType, body=message.body.readAll()

    # This permanently removes the message from the queue
    chan.acknowledgeMessage(0, useChanContentTag=true)


chan.registerMessageHandler(msgHandler)
chan.startBlockingConsumer("nim_amqp_test_queue", false, false, false, false)
```