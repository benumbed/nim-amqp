
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