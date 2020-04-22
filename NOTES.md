
Unsigned octet (8 bits).
Unsigned short integers (16 bits).
Unsigned long integers (32 bits).
Unsigned long long integers (64 bits).

The AMQP specifications impose these limits on data:
* Maximum size of a short string: 255 octets.
* Maximum size of a long string or field table: 32-bit size.
* Maximum size of a frame payload: 32-bit size.
* Maximum size of a content: 64-bit size.


Uses network byte ordering (Big-endian)

Little endian is reverse of written notation (why am I always forgetting this)

0x001f0 - BE
0xf0100 - LE


TODO:

Consider moving things like basic, queue and exchange off dependence upon the
AMQPConnection structure, and using something like an AMQPChannel structure (which 
would hold a connection).

This would allow for data persistence across calls to the server, which would make
error handling, and logging when 'Ok' calls are recieved, much easier.