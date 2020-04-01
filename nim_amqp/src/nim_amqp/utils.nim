## 
## Utility methods for the Nim AMQP library
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import streams
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


template uintSelect*[T](value: T): auto =
    ## So this basically just takes an incoming int type, and swaps it for a uint of the same bit depth
    when sizeof(T) == 8:
        uint64    
    elif sizeof(T) == 4:
        uint32
    elif sizeof(T) == 2:
        uint16

# Inspired by https://github.com/status-im/nim-stew/blob/1c4293b3e754b5ea68a188b60b192801162cd44e/stew/endians2.nim#L29
when defined(gcc) or defined(llvm_gcc) or defined(clang):
    func swapUint(val: uint16): uint16 {.importc: "__builtin_bswap16", nodecl.}
    func swapUint(val: uint32): uint32 {.importc: "__builtin_bswap32", nodecl.}
    func swapUint(val: uint64): uint64 {.importc: "__builtin_bswap64", nodecl.}
elif defined(vcc):
    proc swapUint(a: uint16): uint16 {.importc: "_byteswap_ushort", cdecl, header: "<intrin.h>".}
    proc swapUint(a: uint32): uint32 {.importc: "_byteswap_ulong", cdecl, header: "<intrin.h>".}
    proc swapUint(a: uint64): uint64 {.importc: "_byteswap_uint64", cdecl, header: "<intrin.h>".}

proc readUint16Endian*(stream: Stream): uint16 =
    ## Reads a uint16 off the stream, and if the current arch is littleEndian, converts it
    result = if cpuEndian == littleEndian: swapUint(stream.readUint16()) else: stream.readUint16()

proc readUint32Endian*(stream: Stream): uint32 =
    ## Reads a uint32 off the stream, and if the current arch is littleEndian, converts it
    result = if cpuEndian == littleEndian: swapUint(stream.readUint32()) else: stream.readUint32()

proc readUint64Endian*(stream: Stream): uint64 =
    ## Reads a uint64 off the stream, and if the current arch is littleEndian, converts it
    result = if cpuEndian == littleEndian: swapUint(stream.readUint64()) else: stream.readUint64()
     
proc readInt16Endian*(stream: Stream): int16 =
    ## Reads a int16 off the stream, and if the current arch is littleEndian, converts it
    result = if cpuEndian == littleEndian: int16(swapUint(stream.readUint16())) else: stream.readInt16()

proc readInt32Endian*(stream: Stream): int32 =
    ## Reads a int32 off the stream, and if the current arch is littleEndian, converts it
    result = if cpuEndian == littleEndian: int32(swapUint(stream.readUint32())) else: stream.readInt32()

proc readInt64Endian*(stream: Stream): int64 =
    ## Reads a int64 off the stream, and if the current arch is littleEndian, converts it
    result = if cpuEndian == littleEndian: int64(swapUint(stream.readUint64())) else: stream.readInt64()

proc readFloatEndian*(stream: Stream): float32 =
    ## Reads a float32 off the stream, and if the current arch is littleEndian, converts it
    result = if cpuEndian == littleEndian: float32(swapUint(stream.readUint32())) else: stream.readFloat32()

proc readFloat64Endian*(stream: Stream): float64 =
    ## Reads a float32 off the stream, and if the current arch is littleEndian, converts it
    result = if cpuEndian == littleEndian: float64(swapUint(stream.readUint64())) else: stream.readFloat64()


template streamReaderSelect*[T](v: T): auto =
    ## Selects which stream reader to use based on the byte depth of `v`
    when sizeof(T) == 8:
        stream.readUint64()  
    elif sizeof(T) == 4:
        stream.readUint32()
    elif sizeof(T) == 2:
        stream.readUint16()

template selectSwapper[T](v: T): auto =
    ## Selects what swapping call chain to use based on the type of `v`
    when type(T) is (int16 or int32 or int64 or float or float32 or float64):
        T(swapUint(streamReaderSelect(v)))
    else:
        swapUint(streamReaderSelect(v))

proc readAndReturnNumericEndian*[T](stream: Stream, value: T): T =
    ## Will read a (u)int, flip it's endianness and return it back
    result = if cpuEndian == littleEndian: selectSwapper(value) else: selectSwapper(value)

proc readNumericEndian*[T](stream: Stream, value: var T) =
    ## Will read a (u)int, flip it's endianness and set `value` to the read and flipped value
    value = if cpuEndian == littleEndian: selectSwapper(value) else: selectSwapper(value)


proc swapEndian*[T](value: T, srcEndian = cpuEndian, retEndian = bigEndian): T {.inline.} =
    ## Returns the incoming int type with it's endianness flipped.  Defaults to returning bigEndian.
    # This just makes sure we don't swap endianness if they already match, probably rare, but
    # bigEndian machines do exist.
    if srcEndian == retEndian:
        return value

    when type(T) is (uint16 or uint32 or uint64 or uint):
        return swapUint(value)
    else:
        return cast[T](swapUint(cast[uintSelect(value)](value)))