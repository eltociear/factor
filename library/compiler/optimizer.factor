! :folding=indent:collapseFolds=1:

! $Id$
!
! Copyright (C) 2004 Slava Pestov.
! 
! Redistribution and use in source and binary forms, with or without
! modification, are permitted provided that the following conditions are met:
! 
! 1. Redistributions of source code must retain the above copyright notice,
!    this list of conditions and the following disclaimer.
! 
! 2. Redistributions in binary form must reproduce the above copyright notice,
!    this list of conditions and the following disclaimer in the documentation
!    and/or other materials provided with the distribution.
! 
! THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
! INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
! FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
! DEVELOPERS AND CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
! SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
! PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
! OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
! WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
! OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
! ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

IN: compiler
USE: lists
USE: stack
USE: combinators
USE: namespaces
USE: kernel
USE: inference
USE: words
USE: prettyprint
USE: logic

! The optimizer transforms dataflow IR to dataflow IR. Currently
! it simply removes literals that are eventually dropped, and
! never arise as inputs to any other type of function. Such
! 'dead' literals arise when combinators are inlined and
! quotations are lifted to their call sites.

: scan-literal ( node -- )
    #! If the node represents a literal push, add the literal to
    #! the list being constructed.
    "scan-literal" [ drop ] apply-dataflow ;

: (scan-literals) ( dataflow -- )
    [ scan-literal ] each ;

: scan-literals ( dataflow -- list )
    [ (scan-literals) ] make-list ;

: scan-branches ( branches -- )
    #! Collect all literals from all branches.
    [ node-param get ] bind [ [ scan-literal ] each ] each ;

: mentions-literal? ( literal list -- )
    #! Does the given list of result objects refer to this
    #! literal?
    [ dup cons? [ car over = ] [ drop f ] ifte ] some? ;

: consumes-literal? ( literal node -- ? )
    #! Does the dataflow node consume the literal?
    [
        node-consume-d get mentions-literal? swap
        node-consume-r get mentions-literal? nip or
    ] bind ;

: produces-literal? ( literal node -- ? )
    #! Does the dataflow node produce the literal?
    [
        node-produce-d get mentions-literal? swap
        node-produce-r get mentions-literal? nip or
    ] bind ;

: (can-kill?) ( literal node -- ? )
    #! Return false if the literal appears as input to this
    #! node, and this node is not a stack operation.
    2dup consumes-literal? >r produces-literal? r> or not ;

: can-kill? ( literal dataflow -- ? )
    #! Return false if the literal appears in any node in the
    #! list.
    [ dupd "can-kill" [ (can-kill?) ] apply-dataflow ] all? nip ;

: kill-set ( dataflow -- list )
    #! Push a list of literals that may be killed in the IR.
    dup scan-literals [ over can-kill? ] subset nip ;

: can-kill-branches? ( literal node -- ? )
    #! Check if the literal appears in either branch.
    2dup consumes-literal? [
        2drop f
    ] [
        [ node-param get ] bind [ dupd can-kill? ] all? nip
    ] ifte ;

: (kill-node) ( literals node -- )
    swap [ over (can-kill?) ] all? [ , ] [ drop ] ifte ;

: kill-node ( literals node -- )
    #! Remove the literals from the node and , it if it is not a
    #! NOP.
    "kill-node" [ (kill-node) ] apply-dataflow ;

: kill-nodes ( literals dataflow -- dataflow )
    #! Remove literals and construct a list.
    [ [ dupd kill-node ] each drop ] make-list ;

: optimize ( dataflow -- dataflow )
    #! Remove redundant literals from the IR. The original IR
    #! is destructively modified.
    dup kill-set swap kill-nodes ;

: kill-branches ( literals node -- )
    [
        node-param [ [ dupd kill-nodes ] map nip ] change
    ] extend , ;

#push [
    consumes-literal? not
] "can-kill" set-word-property

#push [
    [ node-param get ] bind ,
] "scan-literal" set-word-property

#label [
    [ node-param get ] bind (scan-literals)
] "scan-literal" set-word-property

#label [
    [ node-param get ] bind can-kill?
] "can-kill" set-word-property

#label [ ( literals node -- )
    [ node-param [ kill-nodes ] change ] extend ,
] "kill-node" set-word-property

#ifte [ scan-branches ] "scan-literal" set-word-property
#ifte [ can-kill-branches? ] "can-kill" set-word-property
#ifte [ kill-branches ] "kill-node" set-word-property

#generic [ scan-branches ] "scan-literal" set-word-property
#generic [ can-kill-branches? ] "can-kill" set-word-property
#generic [ kill-branches ] "kill-node" set-word-property

#2generic [ scan-branches ] "scan-literal" set-word-property
#2generic [ can-kill-branches? ] "can-kill" set-word-property
#2generic [ kill-branches ] "kill-node" set-word-property

! Don't care about inputs to recursive combinator calls
#call-label [ 2drop t ] "can-kill" set-word-property

#drop [ 2drop t ] "can-kill" set-word-property
#dup [ 2drop t ] "can-kill" set-word-property
#swap [ 2drop t ] "can-kill" set-word-property

: reduce-stack-op ( literals node map -- node )
    #! If certain values passing through a stack op are being
    #! killed, the stack op can be reduced, in extreme cases
    #! to a no-op.
    -rot [
        node-consume-d get [
            dup cons? [ car over contains? ] [ drop f ] ifte
        ] map nip
        swap assoc node-op set
    ] extend ;

#over [ 2drop t ] "can-kill" set-word-property
#over [
    [
        [ [ f f ] | #over ]
        [ [ f t ] | #dup ]
        [ [ t f ] | #nop ]
        [ [ t t ] | #nop ]
    ] reduce-stack-op ,
] "kill-node" set-word-property

#pick [ 2drop t ] "can-kill" set-word-property
#pick [
    [
        [ [ f f f ] | #pick ]
        [ [ f f t ] | #over ]
        [ [ f t f ] | #over ]
        [ [ f t t ] | #dup ]
        [ [ t f f ] | #nop ]
        [ [ t f t ] | #nop ]
        [ [ t t f ] | #nop ]
        [ [ t t t ] | #nop ]
    ] reduce-stack-op ,
] "kill-node" set-word-property

#>r [ 2drop t ] "can-kill" set-word-property
#r> [ 2drop t ] "can-kill" set-word-property
