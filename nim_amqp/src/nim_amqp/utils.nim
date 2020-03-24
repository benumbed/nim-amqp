## 
## Utility methods for the Nim AMQP library
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import streams
import strformat
import system

type StrWithError* = tuple[output: string, error: bool]

proc readRawAMQPVersion*(ver: string): string = fmt"{ver[0..3]}{int(ver[4])}{int(ver[5])}{int(ver[6])}{int(ver[7])}"

# Inspired by https://github.com/status-im/nim-stew/blob/1c4293b3e754b5ea68a188b60b192801162cd44e/stew/endians2.nim#L29
when defined(gcc) or defined(llvm_gcc) or defined(clang):
    func swapUint16(val: uint16): uint16 {.importc: "__builtin_bswap16", nodecl.}
    func swapUint32(val: uint32): uint32 {.importc: "__builtin_bswap32", nodecl.}
    func swapUint64(val: uint64): uint64 {.importc: "__builtin_bswap64", nodecl.}
    # Placeholders
    func swapInt16(val: int16): int16 {.importc: "__builtin_bswap16", nodecl.}
    func swapInt32(val: int32): int32 {.importc: "__builtin_bswap32", nodecl.}
    func swapInt64(val: int64): int64 {.importc: "__builtin_bswap64", nodecl.}
elif defined(vcc):
    proc swapUint16(a: uint16): uint16 {.importc: "_byteswap_ushort", cdecl, header: "<intrin.h>".}
    proc swapUint32(a: uint32): uint32 {.importc: "_byteswap_ulong", cdecl, header: "<intrin.h>".}
    proc swapUint64(a: uint64): uint64 {.importc: "_byteswap_uint64", cdecl, header: "<intrin.h>".}

proc readUint16Endian*(stream: Stream): uint16 =
    ## Reads a uint16 off the stream, and if the current arch is littleEndian, converts it
    result = if cpuEndian == littleEndian: swapUint16(stream.readUint16()) else: stream.readUint16()

proc readUint32Endian*(stream: Stream): uint32 =
    ## Reads a uint32 off the stream, and if the current arch is littleEndian, converts it
    result = if cpuEndian == littleEndian: swapUint32(stream.readUint32()) else: stream.readUint32()

proc readUint64Endian*(stream: Stream): uint64 =
    ## Reads a uint64 off the stream, and if the current arch is littleEndian, converts it
    result = if cpuEndian == littleEndian: swapUint64(stream.readUint64()) else: stream.readUint64()
     
# Placeholders
proc readInt16Endian*(stream: Stream): int16 =
    ## Reads a int16 off the stream, and if the current arch is littleEndian, converts it
    result = if cpuEndian == littleEndian: swapInt16(stream.readInt16()) else: stream.readInt16()

proc readInt32Endian*(stream: Stream): int32 =
    ## Reads a int32 off the stream, and if the current arch is littleEndian, converts it
    result = if cpuEndian == littleEndian: swapInt32(stream.readInt32()) else: stream.readInt32()

proc readInt64Endian*(stream: Stream): int64 =
    ## Reads a int64 off the stream, and if the current arch is littleEndian, converts it
    result = if cpuEndian == littleEndian: swapInt64(stream.readInt64()) else: stream.readInt64()

# FIXME: These won't work due to uint
proc readFloatEndian*(stream: Stream): float =
    ## Reads a float32 off the stream, and if the current arch is littleEndian, converts it
    result = if cpuEndian == littleEndian: float(swapUint32(stream.readUint32())) else: stream.readFloat32()

proc readFloat64Endian*(stream: Stream): float64 =
    ## Reads a float32 off the stream, and if the current arch is littleEndian, converts it
    result = if cpuEndian == littleEndian: float64(swapUint64(stream.readUint64())) else: stream.readFloat64()    