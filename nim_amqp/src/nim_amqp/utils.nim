## 
## Utility methods for the Nim AMQP library
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import streams
import system

type StrWithError* = tuple[output: string, error: bool]

# Inspired by https://github.com/status-im/nim-stew/blob/1c4293b3e754b5ea68a188b60b192801162cd44e/stew/endians2.nim#L29
when defined(gcc) or defined(llvm_gcc) or defined(clang):
    func swapUint16(val: uint16): uint16 {.importc: "__builtin_bswap16", nodecl.}
    func swapUint32(val: uint32): uint32 {.importc: "__builtin_bswap32", nodecl.}
    func swapUint64(val: uint64): uint64 {.importc: "__builtin_bswap64", nodecl.}
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
     