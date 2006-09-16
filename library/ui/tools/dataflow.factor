! Copyright (C) 2006 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
IN: gadgets-dataflow
USING: namespaces arrays sequences io inference math kernel
generic prettyprint words gadgets opengl gadgets-panes
gadgets-labels gadgets-theme gadgets-presentations
gadgets-buttons gadgets-borders gadgets-scrolling
gadgets-frames gadgets-workspace optimizer models ;

GENERIC: node>gadget ( height node -- gadget )

! Representation of shuffle nodes
TUPLE: shuffle-gadget value ;

: literal-theme ( shuffle -- )
    T{ solid f { 0.6 0.6 0.6 1.0 } } swap set-gadget-boundary ;

: word-theme ( shuffle -- )
    T{ solid f { 1.0 0.6 0.6 1.0 } } swap set-gadget-boundary ;

C: shuffle-gadget ( node -- gadget )
    [ set-shuffle-gadget-value ] keep
    dup delegate>gadget ;

: shuffled-offsets ( shuffle -- seq )
    dup shuffle-in swap shuffle-out
    [ swap index ] map-with ;

: shuffled-endpoints ( w h seq seq -- seq )
    [ [ 30 * 15 + ] map ] 2apply
    >r over r> [ - ] map-with >r [ - ] map-with r>
    [ 0 swap 2array ] map >r [ 2array ] map-with r>
    [ 2array ] 2map ;

: draw-shuffle ( gadget seq seq -- )
    >r >r rect-dim first2 r> r> shuffled-endpoints
    [ first2 gl-line ] each ;

M: shuffle-gadget draw-gadget*
    { 0 0 0 1 } gl-color
    dup shuffle-gadget-value
    shuffled-offsets [ length ] keep
    draw-shuffle ;

: node-dim ( n -- dim ) 30 * 10 swap 2array ;

: shuffle-dim ( shuffle -- dim )
    dup shuffle-in length swap shuffle-out length max
    node-dim ;

M: shuffle-gadget pref-dim*
    shuffle-gadget-value shuffle-dim ;

M: #shuffle node>gadget nip node-shuffle <shuffle-gadget> ;

! Stack height underneath a node
TUPLE: height-gadget value ;

C: height-gadget ( value -- gadget )
    [ set-height-gadget-value ] keep
    dup delegate>gadget ;

M: height-gadget pref-dim*
    height-gadget-value node-dim ;

M: height-gadget draw-gadget*
    { 0 0 0 1 } gl-color
    dup height-gadget-value dup draw-shuffle ;

! Calls and pushes
TUPLE: node-gadget value height ;

C: node-gadget ( gadget node height -- gadget )
    [ set-node-gadget-height ] keep
    [ set-node-gadget-value ] keep
    swap <default-border> over set-gadget-delegate
    dup faint-boundary ;

M: node-gadget pref-dim*
    dup delegate pref-dim
    swap dup node-gadget-height [
        node-dim
    ] [
        node-gadget-value node-shuffle shuffle-dim
    ] ?if vmax ;

M: #call node>gadget
    nip
    [ node-param word-name <label> ] keep
    [ f <node-gadget> ] keep node-param <object-presentation>
    dup word-theme ;

M: #push node>gadget
    nip [
        >#push< [ literalize unparse ] map " " join <label>
    ] keep f <node-gadget> dup literal-theme ;

! #if #dispatch #label
: <child-nodes> ( seq -- seq )
    [ length ] keep
    [
        >r number>string "Child " swap append <label> r>
        <object-presentation>
    ] 2map ;

: default-node-content ( node -- gadget )
    dup node-children <child-nodes>
    swap class word-name <mono-label> add* make-pile
    { 5 5 } over set-pack-gap ;

M: object node>gadget
    nip dup default-node-content swap f <node-gadget> ;

UNION: full-height-node #if #dispatch #label ;

M: full-height-node node>gadget
    dup default-node-content swap rot <node-gadget> ;

! Constructing the graphical representation; first we compute
! stack heights
SYMBOL: d-height

: compute-child-heights ( node -- )
    node-children dup empty? [
        drop
    ] [
        [
            [ (compute-heights) d-height get ] { } make drop
        ] map supremum d-height set
    ] if ;

: (compute-heights) ( node -- )
    [
        d-height get over 2array ,
        dup compute-child-heights
        dup node-out-d length over node-in-d length -
        d-height [ + ] change
        node-successor (compute-heights)
    ] when* ;

: normalize-height ( seq -- seq )
    [
        [ dup first swap second node-in-d length - ] map infimum
    ] keep
    [ first2 >r swap - r> 2array ] map-with ;

: compute-heights ( nodes -- pairs )
    [ 0 d-height set (compute-heights) ] { } make
    normalize-height ;

! Then we create gadgets for every node
: print-node ( d-height node -- )
    dup full-height-node? [
        node>gadget
    ] [
        [ node-in-d length - <height-gadget> ] 2keep
        node>gadget swap 2array
        make-pile 1 over set-pack-fill
    ] if , ;

: <dataflow-graph> ( node -- gadget )
    compute-heights [
        dup empty? [ dup first first <height-gadget> , ] unless
        [ first2 print-node ] each
    ] { } make
    make-shelf 1 over set-pack-align ;

! The UI tool
TUPLE: dataflow-gadget history search ;

dataflow-gadget {
    {
        "Dataflow"
        { "Back" T{ key-down f { C+ } "b" } [ dataflow-gadget-history go-back ] }
        { "Forward" T{ key-down f { C+ } "f" } [ dataflow-gadget-history go-forward ] }
    }
} define-commands

: <dataflow-pane> ( history -- gadget )
    gadget get dataflow-gadget-history
    [ <dataflow-graph> gadget. ]
    <pane-control> ;

C: dataflow-gadget ( -- gadget )
    f <history> over set-dataflow-gadget-history {
        { [ <dataflow-pane> ] f [ <scroller> ] @center }
    } make-frame* ;

M: dataflow-gadget call-tool* ( node dataflow -- )
    dup dataflow-gadget-history add-history
    dataflow-gadget-history set-model ;

IN: tools

: show-dataflow ( quot -- )
    dataflow optimize dataflow-gadget call-tool ;
