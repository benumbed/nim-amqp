## 
## Utility methods for the Nim AMQP library
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import strformat
import strutils
import system

proc readRawAMQPVersion*(ver: string): string {.inline.} = 
    fmt"{ver[0..3]}{int(ver[4])}{int(ver[5])}{int(ver[6])}{int(ver[7])}"

proc wireAMQPVersion*(ver: string): string {.inline.} =
    ## Converts a dotted-style version string to the proper AMQP wire version
    result = "AMQP"
    result.add(char(0))
    for tok in ver.split("."):
        result.add(char(tok.parseUInt()))


proc singleLine*(this: string): string =
    ## Takes a multi-line string collapses it
    var toks: seq[string]

    for tok in this.split("\n"):
        toks.add(tok.strip())

    result = toks.join(" ")

