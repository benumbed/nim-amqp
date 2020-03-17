## 
## Utility methods for the Nim AMQP library
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
type StrWithError* = tuple[output: string, error: bool]

proc extractUint32*(data: string, offset: int): uint32 =
    ## Takes character data from a string, and extracts a uint32 from it at `offset`
    result = 0
    for i in 0..3:
        result = result or (uint32(data[offset+i]) shl ((3-i)*8))

proc extractUint16*(data: string, offset: int): uint16 =
    ## Takes character data from a string, and extracts a uint16 from it at `offset`
    result = 0
    for i in 0..1:
        result = result or (uint16(data[offset+i]) shl ((1-i)*8))    