## 
## Implementation of the AMQP protocol in (hopefully) pure Nim
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import tables

import ./connection

# This is a map to methods to handle incoming data from the server
let ConnectionServerProcMap = {
    # start
    10: amqpConnectionStartFromWire,
    # secure -- security mechanism challenge
    20: nil,
    # tune -- propose connection tuning parameters
    30: nil,
    # open-ok
    41: nil,
    # close
    50: nil,
    # close-ok
    51: nil,
}.toTable()

# Map to conversion methods from internal client data structures to wire protocol to send to the server
let ConnectionClientProcMap = {
    # start-ok
    11: toWire,
    # secure-ok -- security mechanism response
    21: nil,
    # tune-ok -- negotiate connection tuning parameters
    31: nil,
    # open -- open connection to virtual host
    40: nil,
    # close
    50: nil,
    # close-ok
    51: nil,
}.toTable()
