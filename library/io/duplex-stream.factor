! Copyright (C) 2005 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
IN: io
USING: kernel ;

TUPLE: duplex-stream in out ;

M: duplex-stream stream-flush
    duplex-stream-out stream-flush ;

M: duplex-stream stream-readln
    duplex-stream-in stream-readln ;

M: duplex-stream stream-read1
    duplex-stream-in stream-read1 ;

M: duplex-stream stream-read
    duplex-stream-in stream-read ;

M: duplex-stream stream-write1
    duplex-stream-out stream-write1 ;

M: duplex-stream stream-write
    duplex-stream-out stream-write ;

M: duplex-stream stream-terpri
    duplex-stream-out stream-terpri ;

M: duplex-stream stream-format
    duplex-stream-out stream-format ;

M: duplex-stream with-nested-stream
    duplex-stream-out with-nested-stream ;

M: duplex-stream stream-close
    #! The output stream is closed first, in case both streams
    #! are attached to the same file descriptor, the output
    #! buffer needs to be flushed before we close the fd.
    dup
    duplex-stream-out stream-close
    duplex-stream-in stream-close ;

M: duplex-stream set-timeout
    2dup
    duplex-stream-in set-timeout
    duplex-stream-out set-timeout ;