! Copyright (C) 2004, 2005 Slava Pestov.
! Copyright (C) 2005 Mackenzie Straight.
! See http://factor.sf.net/license.txt for BSD license.
IN: threads
USING: errors io-internals kernel kernel-internals lists
namespaces ;
 
! Core of the multitasker. Used by io-internals.factor and
! in-thread.factor.

: run-queue ( -- queue ) 9 getenv ;
: set-run-queue ( queue -- ) 9 setenv ;
: init-threads ( -- ) <queue> set-run-queue ;

: next-thread ( -- quot )
    run-queue dup queue-empty? [
        drop f
    ] [
        deque set-run-queue
    ] ifte ;

: schedule-thread ( quot -- ) run-queue enque set-run-queue ;

: stop ( -- )
    #! If there is a quotation in the run queue, call it,
    #! otherwise wait for I/O.
    pending-io? [ 10 io-multiplex ] when
    next-thread [ call ] [ -1 io-multiplex stop ] ifte* ;

: yield ( -- )
    #! Add the current continuation to the run queue, and yield
    #! to the next quotation. The current continuation will
    #! eventually be restored by a future call to stop or
    #! yield.
    [ schedule-thread stop ] callcc0 ;
