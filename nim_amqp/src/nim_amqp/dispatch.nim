## 
## Dispatcher for class methods
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
# import streams
# import tables

# import ./utils
# import ./protocol
# import ./methods
# import ./classes/connection

# # type methodMap* = Table[int, Table[int, proc (meth: AMQPMethod): ref AMQPMethod]]
# type methodMap* = Table[uint32, Table[uint32, proc (meth: AMQPMethod): AMQPMethod]]

# var mMap*: methodMap

# # mMap[10].add(10, extractConnectionStart)

# mMap = {
#     10: {
#         10: extractConnectionStart,
#         50: extractConnectionClose
#     }
# }.toTable()


# proc dispatchMethod*(frame: AMQPFrame): AMQPMethod =
#     let meth = new(AMQPMethod)

#     meth.classId = frame.payload.readUint16Endian()
#     meth.methodId = frame.payload.readUint16Endian()
#     meth.arguments = frame.payload

#     # if not mMap.hasKey(meth.classId):

#     var cls = mMap[meth.classId]

#     mMap[meth.classId][meth.methodId](meth)
