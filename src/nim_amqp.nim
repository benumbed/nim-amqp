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


proc createChannel*(conn: AMQPConnection): AMQPChannel =
    ## Creates a new channel on the existing connection.  For simplicity's sake, nim-amqp does not track channels for 
    ## you, and attempting to create a channel which already exists is an error, so you'll need to track active 
    ## channels in your code.
    ##
    nextChannel.inc
    let chan = conn.newAMQPChannel(number=uint16(nextChannel), frames.handleFrame, frames.sendFrame)
    chan.channelOpen()

    # Provide for channel reuse after close
    if nextChannel in channelTracking and not channelTracking[nextChannel].active:
        # Wipe out the old channel info, because clearing it would require knowledge of the structure
        channelTracking[nextChannel] = conn.newAMQPChannel(number=uint16(nextChannel), frames.handleFrame, frames.sendFrame)
    else:
        channelTracking[nextChannel] = chan

    return channelTracking[nextChannel]


proc removeChannel*(chan: AMQPChannel) =
    ## Will remove the provided channel as an active connection
    ##
    if int(chan.number) notin channelTracking:
        raise newException(AMQPError, fmt"Provided channel '{chan.number}' isn't in the global channel tracking table")

    chan.channelClose()
    chan.active = false
    channelTracking.del(int(chan.number))


when isMainModule:
    # let ssl_ctx = net.newContext()
    var sock = newAsyncSocket()
    # var sock = newSocket(buffered=true)
    waitFor sock.connect("localhost", Port(5672))
    # asyncnet.wrapSocket(ssl_ctx, sock)

    # let frame = sock.readFrame()

    runForever()

    sock.close()
