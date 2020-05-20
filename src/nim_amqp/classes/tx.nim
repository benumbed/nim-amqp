## 
## Implements the `tx` class and associated methods
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import chronicles
import streams
import tables

import ../errors
import ../types
import ../utils

type AMQPTxError* = object of AMQPError

proc txSelectOk*(chan: AMQPChannel)
proc txCommitOk*(chan: AMQPChannel)
proc txRollbackOk*(chan: AMQPChannel)

var txMethodMap* = MethodMap()
txMethodMap[11] = txSelectOk
txMethodMap[21] = txCommitOk
txMethodMap[31] = txRollbackOk


proc txSelect*(chan: AMQPChannel) = 
    ## Sets the current channel to use transactions
    ##
    let stream = newStringStream()
    writeMethodInfo(stream, AMQP_CLASS_TX, uint16(10))

    debug "Sending tx.select"
    discard chan.frames.sender(chan, chan.constructMethodFrame(stream), expectResponse=true)


proc txSelectOk*(chan: AMQPChannel) = 
    ## Server responding to a tx.select
    ##
    debug "Got tx.select-ok"


proc txCommit*(chan: AMQPChannel) =
    ## Commits the current transaction
    ##
    let stream = newStringStream()
    writeMethodInfo(stream, AMQP_CLASS_TX, uint16(20))

    debug "Sending tx.commit"
    discard chan.frames.sender(chan, chan.constructMethodFrame(stream), expectResponse=true)


proc txCommitOk*(chan: AMQPChannel) =
    ## Server responding to a tx.commit
    ##
    debug "Got tx.commit-ok"


proc txRollback*(chan: AMQPChannel) =
    ## Rolls back a transaction
    ##
    let stream = newStringStream()
    writeMethodInfo(stream, AMQP_CLASS_TX, uint16(30))

    debug "Sending tx.rollback"
    discard chan.frames.sender(chan, chan.constructMethodFrame(stream), expectResponse=true)


proc txRollbackOk*(chan: AMQPChannel) =
    ## Server responding to a tx.rollback
    ##
    debug "Got tx.rollback-ok"