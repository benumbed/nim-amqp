# Nim AMQP Library
AMQP 0-9-1 implementation in Nim.  

**NOTE:** This is RabbitMQ flavored AMQP 0-9-1.  The engineers who wrote RabbitMQ and the architects that designed AMQP 0-9-1 did not agree on some things (and to be fair the AMQP 0-9-1 spec contracticts itself in several important places), and so the RabbitMQ path was followed since it's a very common AMQP server.

**NOTE 2:** This library is still a work in progress.  While the basic pub/sub capabilities are there, there's a lot of error handling and niceties that haven't been added yet.  AKA this library is a work in progress.  It's also currently only tested on Linux, so there may be gotchas in other OSes.

There are two ways to use this library, the abstraction layer, which exists in `nim_amqp.nim` or the AMQP class-based layer (not recommended).  Efforts are made to keep the documentation in the abstraction layer up to date as it changes.  The same can not be said for the class modules right now.

Currently, the library is synchronous.  There is a desire to make it `multisync` (Nim's terminology for sync/async hybrid code), however this was my first project I tackled while learning Nim, so async support was temporarily shelved while I got my feet under me.

You can write your own consumer, or you can use the `startBlockingConsumer` procedure within `nim_amqp.nim`.  Note that if you use the included consumer loop, you'll need to at least register a message callback (`registerMessageHandler`) so the consumer has somewhere to send the messages it recieves.  For an incredibly basic example of how to use the abstraction layer, see the bottom of `nim_amqp.nim`.