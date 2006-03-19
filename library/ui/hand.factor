! Copyright (C) 2005, 2006 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
IN: gadgets
USING: gadgets-labels gadgets-layouts kernel math namespaces
queues sequences ;

! Hand state

SYMBOL: hand-gadget

SYMBOL: hand-clicked
SYMBOL: hand-click-loc

SYMBOL: hand-buttons
V{ } clone hand-buttons set-global

TUPLE: hand ;

C: hand ( -- hand )
    dup delegate>gadget ;

<hand> hand set-global

: button-gesture ( buttons gesture -- )
    #! Send a gesture like [ button-down 2 ]; if nobody
    #! handles it, send [ button-down ].
    swap hand-clicked get-global 3dup >r add r> handle-gesture
    [ nip handle-gesture drop ] [ 3drop ] if ;

: update-clicked ( -- )
    hand-gadget get-global hand-clicked set-global
    hand get rect-loc hand-click-loc set-global ;

: send-button-down ( event -- )
    update-clicked
    dup hand-buttons get-global push
    [ button-down ] button-gesture ;

: send-button-up ( event -- )
    dup hand-buttons get-global delete
    [ button-up ] button-gesture ;

: send-scroll-wheel ( up/down -- )
    [ wheel-up ] [ wheel-down ] ?
    hand-gadget get-global handle-gesture drop ;

: drag-gesture ( -- )
    #! Send a gesture like [ drag 2 ]; if nobody handles it,
    #! send [ drag ].
    hand-buttons get-global first [ drag ] button-gesture ;

: fire-motion ( -- )
    #! Fire a motion gesture to the gadget underneath the hand,
    #! and if a mouse button is down, fire a drag gesture to the
    #! gadget that was clicked.
    [ motion ] hand-gadget get-global handle-gesture drop
    hand-buttons get-global empty? [ drag-gesture ] unless ;

: each-gesture ( gesture seq -- )
    [ handle-gesture* drop ] each-with ;

: hand-gestures ( new old -- )
    drop-prefix reverse-slice
    [ mouse-leave ] swap each-gesture
    fire-motion
    [ mouse-enter ] swap each-gesture ;

: focus-gestures ( new old -- )
    drop-prefix reverse-slice
    [ lose-focus ] swap each-gesture
    [ gain-focus ] swap each-gesture ;

: request-focus ( gadget -- )
    dup focusable-child swap find-world
    dup focused-ancestors >r
    [ set-world-focus ] keep
    focused-ancestors r> focus-gestures ;

: drag-loc ( gadget -- loc )
    hand get rect-loc hand-click-loc get-global v- ;

: relevant-help ( seq -- help )
    [ gadget-help ] map [ ] find nip ;

: show-message ( string/f -- )
    #! Show a message in the status bar.
    world-status [ set-label-text* ] [ drop ] if* ;

: update-help ( -- string )
    #! Update mouse-over help message.
    hand-gadget get-global parents [ relevant-help ] keep
    dup empty? [ 2drop ] [ peek show-message ] if ;

: under-hand ( -- seq )
    #! A sequence whose first element is the world and last is
    #! the current gadget, with all parents in between.
    hand-gadget get-global parents reverse-slice ;

: move-hand ( loc world -- )
    under-hand >r over hand get set-rect-loc
    pick-up hand-gadget set-global
    under-hand r> hand-gestures update-help ;

: update-hand ( world -- )
    #! Called when a gadget is removed or added.
    hand get rect-loc swap move-hand ;

: layout-done ( gadget -- )
    find-world [
        dup update-hand world-handle repaint-handle
    ] when* ;

: layout-queued ( -- )
    invalid dup queue-empty?
    [ drop ] [ deque dup layout layout-done layout-queued ] if ;
