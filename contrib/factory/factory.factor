
IN: factory

USING: kernel namespaces generic math sequences hashtables io arrays words
       prettyprint lists concurrency
       xlib x concurrent-widgets simple-error-handler ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

DEFER: workspace-menu
DEFER: wm-frame?
DEFER: manage-window
DEFER: window-list
DEFER: refresh-window-list
DEFER: layout-frame
DEFER: mapped-windows

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: popup-window ( -- ) mouse-sensor move-window raise-window map-window ;

: popup-window% [ popup-window ] with-window-object ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

SYMBOL: root-menu

: setup-root-menu ( -- )
  create-menu root-menu set
  "black" lookup-color root-menu get set-window-background%
  "xterm"  [ "launch program..." print ] root-menu get add-popup-menu-item
  "xlogo"  [ "launch program..." print ] root-menu get add-popup-menu-item
  "xclock" [ "launch program..." print ] root-menu get add-popup-menu-item
  "xload"  [ "launch program..." print ] root-menu get add-popup-menu-item
  "emacs"  [ "launch program..." print ] root-menu get add-popup-menu-item
  "Workspaces"
    [ workspace-menu get popup-window% ] root-menu get add-popup-menu-item ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: MouseMask
  [ ButtonPressMask
    ButtonReleaseMask
    PointerMotionMask ] 0 [ execute bitor ] reduce ;

: drag-mouse-loop ( position -- )
  MouseMask mask-event XAnyEvent-type			! position type
  { { [ dup MotionNotify = ]
      [ drop drag-mouse-loop ] }
    { [ dup ButtonRelease = ]
      [ drop						! position
        mouse-sensor					! push release
        ungrab-server
        CurrentTime ungrab-pointer
        flush-dpy ] }
    { [ t ] [ drop "drag-mouse-loop ignoring event" print drag-mouse-loop ] } }
  cond ;

: drag-mouse ( -- )
  MouseMask grab-pointer grab-server mouse-sensor drag-mouse-loop ;

: drag-mouse% [ drag-mouse ] with-window-object ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: drag-move-window ( -- ) drag-mouse swap v- window-position v+ move-window ;

: drag-move-window% [ drag-move-window ] with-window-object ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: drag-resize-window ( -- ) drag-mouse nip window-position v- resize-window ;

: drag-resize-window% [ drag-resize-window ] with-window-object ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

GENERIC: move-request-x
GENERIC: move-request-y
GENERIC: move-request-position
GENERIC: execute-move-request
GENERIC: size-request-width
GENERIC: size-request-height
GENERIC: size-request-size
GENERIC: execute-size-request

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! wm-root
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

TUPLE: wm-root ;

: create-wm-root ( window -- )
  >r dpy get r> <window>			! <window>
  <wm-root>					! <window> <wm-root>
  [ set-delegate ] keep				! <wm-root>
  [ add-to-window-table ] keep			! <wm-root>

  [ SubstructureRedirectMask
    SubstructureNotifyMask
    ButtonPressMask
    ButtonReleaseMask
    KeyPressMask
    KeyReleaseMask ] 0 [ execute bitor ] reduce	! <wm-frame> mask

  over select-input% ;				! <wm-frame>

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! M: wm-root handle-map-request-event
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: id>obj ( id -- obj )
  dup			! id id
  window-table get hash	! id obj-or-f
  dup
  [ swap drop ]
  [ drop >r dpy get r> <window> ]
  if ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

M: wm-root handle-map-request-event ( event <wm-root> -- )
  drop XMapRequestEvent-window id>obj				! obj

  { { [ dup wm-frame? ]
      [ map-window% ] }

    { [ dup valid-window?% not ]
      [ "Not a valid window." print drop ] }

    { [ dup window-override-redirect% 1 = ]
      [ "Not reparenting: " print
        "new window has override_redirect attribute set." print
        drop ] }

    { [ t ] [ window-id manage-window ] } }

  cond ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Words for working with an XConfigureRequestEvent
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: bit-test ( a b -- t-or-f ) bitand 0 = not ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: move-request-x? ( event -- ) XConfigureRequestEvent-value_mask CWX bit-test ;
: move-request-y? ( event -- ) XConfigureRequestEvent-value_mask CWY bit-test ;

: move-request? ( event -- ? ) dup move-request-x? swap move-request-y? or ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: size-request-width? ( event -- )
  XConfigureRequestEvent-value_mask CWWidth bit-test ;

: size-request-height? ( event -- )
  XConfigureRequestEvent-value_mask CWHeight bit-test ;

: size-request? ( event -- )
  dup size-request-width? swap size-request-height? or ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! M: wm-root handle-configure-request-event
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

M: wm-root move-request-x ( event wm-root -- x )
  drop
  dup move-request-x?
  [ XConfigureRequestEvent-x ]
  [ XConfigureRequestEvent-window [ window-x ] with-win ]
  if ;

M: wm-root move-request-y ( event wm-root -- y )
  drop
  dup move-request-y?
  [ XConfigureRequestEvent-y ]
  [ XConfigureRequestEvent-window [ window-y ] with-win ]
  if ;

M: wm-root move-request-position ( event wm-root -- { x y } )
  2dup move-request-x -rot move-request-y 2array ;

M: wm-root execute-move-request ( event wm-root -- )
  dupd move-request-position swap XConfigureRequestEvent-window move-window+ ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

M: wm-root size-request-width ( event wm-root -- width )
  drop
  dup size-request-width?
  [ XConfigureRequestEvent-width ]
  [ XConfigureRequestEvent-window [ window-width ] with-win ]
  if ;

M: wm-root size-request-height ( event wm-root -- height )
  drop 
  dup size-request-height?
  [ XConfigureRequestEvent-height ]
  [ XConfigureRequestEvent-window [ window-height ] with-win ]
  if ;

M: wm-root size-request-size ( event wm-root -- { width height } )
  2dup size-request-width -rot size-request-height 2array ;

M: wm-root execute-size-request ( event wm-root -- )
  dupd size-request-size swap XConfigureRequestEvent-window resize-window+ ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

M: wm-root handle-configure-request-event ( event wm-root -- )
  over move-request? [ 2dup execute-move-request ] when
  over size-request? [ 2dup execute-size-request ] when
  drop drop ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! M: wm-root handle-button-press-event
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

M: wm-root handle-button-press-event ( event wm-root -- )
  drop						! event

  { { [ dup XButtonEvent-button Button1 = ]
      [ root-menu get window-map-state% IsUnmapped =
        [ XButtonEvent-root-position root-menu get move-window%
          root-menu get raise-window%
          root-menu get map-window% ]
        [ root-menu get unmap-window% ]
        if ] }

    { [ dup XButtonEvent-button Button2 = ]
      [ window-list get window-map-state% IsUnmapped =
        [ XButtonEvent-root-position window-list get move-window%
          window-list get raise-window%
          window-list get refresh-window-list
          window-list get map-window% ]
        [ window-list get unmap-window% ]
        if ] } }

  cond ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! M: wm-root handle-key-press-event
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

! M: wm-root handle-key-press-event ( event wm-root -- )
!   drop
!   { { [ dup XKeyEvent-keycode 67 = ]
!       [ workspace-1 get switch-to-workspace ] }
!     { [ dup XKeyEvent-keycode 68 = ]
!       [ workspace-2 get switch-to-workspace ] }
!     { [ dup XKeyEvent-keycode 69 = ]
!       [ workspace-3 get switch-to-workspace ] }
!     { [ dup XKeyEvent-keycode 70 = ]
!       [ workspace-4 get switch-to-workspace ] } }
!   cond ;

M: wm-root handle-key-press-event ( event wm-root -- )
  drop
  { { [ dup XKeyEvent-keycode 67 = ]
      [ "Switch to workspace 1" print drop ] }
    { [ dup XKeyEvent-keycode 68 = ]
      [ "Switch to workspace 2" print drop ] }
    { [ dup XKeyEvent-keycode 69 = ]
      [ "Switch to workspace 3" print drop ] }
    { [ dup XKeyEvent-keycode 70 = ]
      [ "Switch to workspace 4" print drop ] }
    { [ t ]
      [ "wm-root ignoring key press" print drop ] } }
  cond ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

TUPLE: wm-child ;

: create-wm-child ( id -- <wm-child> )
  >r dpy get r> <window> <wm-child>		! <window> <wm-child>
  [ set-delegate ] keep
  [ add-to-window-table ] keep ;

M: wm-child handle-property-event ( child event -- )
  "A <wm-child> received a property event" print drop drop ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

TUPLE: wm-frame child ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: create-wm-frame ( child -- <wm-frame> )
  >r create-window-object r>			! <window> child
  <wm-frame>					! <window> <wm-frame>
  [ set-delegate ] keep				! <wm-frame>
  [ add-to-window-table ] keep			! <wm-frame>
  
  [ SubstructureRedirectMask
    SubstructureNotifyMask
    ExposureMask
    ButtonPressMask
    ButtonReleaseMask
    EnterWindowMask ] 0 [ execute bitor ] reduce	! <wm-frame> mask

  over select-input% ;				! <wm-frame>

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: manage-window ( window -- )
  grab-server

  create-wm-child				! child
  create-wm-frame				! frame

  dup "cornflowerblue" lookup-color swap set-window-background%

  dup wm-frame-child add-to-save-set%		! frame

  dup wm-frame-child window-position%		! frame position
  over						! frame position frame
  move-window%
  
  dup wm-frame-child 0 swap set-window-border-width%
  dup dup wm-frame-child			! frame frame child
  reparent-window%

  dup wm-frame-child window-size%		! frame child-size
  { 20 20 } v+					! frame child-size+
  over						! frame child-size+ frame
  resize-window%

  dup wm-frame-child { 10 10 } swap move-window%

  dup map-window%
  dup map-subwindows%

  dup wm-frame-child PropertyChangeMask swap select-input%
  
  flush-dpy 0 sync-dpy ungrab-server ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: destroy-window-event-match? ( event <wm-frame> -- ? )
  window-id swap XDestroyWindowEvent-window = ;

M: wm-frame handle-destroy-window-event ( event <wm-frame> -- )
  2dup destroy-window-event-match?
  [ destroy-window% drop ] [ drop drop ] if ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: map-request-event-match? ( event <wm-frame> -- ? )
  window-id swap XMapRequestEvent-window = ;

M: wm-frame handle-map-request-event ( event <wm-frame> -- )
  2dup map-request-event-match?				! event frame ?
  [ dup wm-frame-child map-window% map-window% drop ] [ drop drop ] if ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: map-event-match? ( event <wm-frame> -- ? )
  window-id swap XMapEvent-window = ;

M: wm-frame handle-map-event ( event <wm-frame> -- )
  2dup map-event-match?
  [ dup map-window% raise-window% drop ] [ drop drop ] if ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! M: wm-frame handle-configure-request-event ( event frame )
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

M: wm-frame move-request-x ( event frame -- x )
  over move-request-x?
  [ drop XConfigureRequestEvent-x ]
  [ nip window-x% ]
  if ;

M: wm-frame move-request-y ( event frame -- y )
  over move-request-y?
  [ drop XConfigureRequestEvent-y ]
  [ nip window-y% ]
  if ;

M: wm-frame move-request-position ( event frame -- { x y } )
  2dup move-request-x -rot move-request-y 2array ;

M: wm-frame execute-move-request ( event frame )
  dup -rot move-request-position swap move-window% ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

M: wm-frame size-request-width ( event frame -- width )
  over size-request-width?
  [ drop XConfigureRequestEvent-width ]
  [ nip wm-frame-child window-width% ]
  if ;

M: wm-frame size-request-height ( event frame -- height )
  over size-request-height?
  [ drop XConfigureRequestEvent-height ]
  [ nip wm-frame-child window-height% ]
  if ;

M: wm-frame size-request-size ( event frame -- size )
  2dup size-request-width -rot size-request-height 2array ;

: execute-size-request/child ( event frame )
  dup wm-frame-child -rot size-request-size swap resize-window% ;

: execute-size-request/frame ( event frame )
  dup -rot size-request-size { 20 20 } v+ swap resize-window% ;

M: wm-frame execute-size-request ( event frame )
  2dup execute-size-request/child execute-size-request/frame ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

M: wm-frame handle-configure-request-event ( event frame )
  over move-request? [ 2dup execute-move-request ] when
  over size-request? [ 2dup execute-size-request ] when
  drop drop ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: unmap-event-match? ( event frame -- ? )
  wm-frame-child window-id swap XUnmapEvent-window = ;

M: wm-frame handle-unmap-event ( event frame )
  2dup unmap-event-match? [ unmap-window% drop ] [ drop drop ] if ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: drag-move-frame ( frame -- ) drag-move-window% ;

: drag-resize-frame ( frame -- ) dup drag-resize-window% layout-frame ;

M: wm-frame handle-button-press-event ( event frame )
  over XButtonEvent-button				! event frame button
  { { [ dup Button1 = ] [ drop nip drag-move-frame ] }
    { [ dup Button2 = ] [ drop nip drag-resize-frame ] }
    { [ dup Button3 = ] [ drop nip unmap-window% ] }
    { [ t ] [ drop drop drop ] } }
  cond ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

M: wm-frame handle-enter-window-event ( event frame )
  nip dup wm-frame-child valid-window?%
  [ wm-frame-child >r RevertToPointerRoot CurrentTime r> set-input-focus% ]
  [ destroy-window% ]
  if ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

M: wm-frame handle-property-event ( event frame )
  "Inside handle-property-event" print drop drop ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: layout-frame ( frame -- )
  dup wm-frame-child { 10 10 } swap move-window%
  dup wm-frame-child				! frame child
  over window-size%				! frame child size
  { 20 20 } v-					! frame child child-size
  swap resize-window%				! frame
  drop ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Workspaces
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

GENERIC: switch-to

SYMBOL: current-workspace

TUPLE: workspace windows ;

: create-workspace [ ] <workspace> ;

M: workspace switch-to ( workspace -- )
  mapped-windows dup current-workspace get set-workspace-windows
  [ unmap-window+ ] each
  dup workspace-windows [ map-window+ ] each
  current-workspace set ;

SYMBOL: workspace-1
SYMBOL: workspace-2
SYMBOL: workspace-3
SYMBOL: workspace-4

create-workspace workspace-1 set
create-workspace workspace-2 set
create-workspace workspace-3 set
create-workspace workspace-4 set

workspace-1 get current-workspace set

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

SYMBOL: workspace-menu

: setup-workspace-menu ( -- )
  create-menu workspace-menu set
  "black" lookup-color workspace-menu get set-window-background%
  "Workspace 1"
    [ workspace-1 get switch-to ] workspace-menu get add-popup-menu-item
  "Workspace 2"
    [ workspace-2 get switch-to ] workspace-menu get add-popup-menu-item
  "Workspace 3"
    [ workspace-3 get switch-to ] workspace-menu get add-popup-menu-item
  "Workspace 4"
    [ workspace-4 get switch-to ] workspace-menu get add-popup-menu-item ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! window-list
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

SYMBOL: window-list

: setup-window-list ( -- )
  create-menu window-list set
  "black" lookup-color window-list get set-window-background% ;

: not-transient? ( frame -- ? ) wm-frame-child get-transient-for-hint% not ;

: add-window-to-list ( window-list frame -- window-list )
  dup					! window-list frame frame
  wm-frame-child			! window-list frame child
  fetch-name%				! window-list frame name-or-f
  dup					! window-list frame name-or-f name-or-f
  [ ] [ drop "*untitled*" ] if	! window-list frame name
  swap					! window-list name frame
  [ map-window% ]			! window-list name frame [ map-window% ]
  cons					! window-list name action
  pick					! window-list name action window-list
  add-popup-menu-item ;

: refresh-window-list ( window-list -- )
  dup window-children% [ destroy-window+ ] each
  ! clean-window-table
  window-table get hash-values [ wm-frame? ] subset
  [ not-transient? ] subset
  [ add-window-to-list ] each
  drop ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: window-is-mapped? ( window -- ? ) window-map-state+ IsUnmapped = not ;

: mapped-windows ( -- [ a b c d ... ] )
  root get window-children+ [ window-is-mapped? ] subset ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: manage-existing-windows ( -- ) mapped-windows [ manage-window ] each ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: start-factory ( dpy-string -- )
  initialize-x
  SetSimpleErrorHandler
  root get create-wm-root
  setup-root-menu
  setup-window-list
  setup-workspace-menu
  manage-existing-windows
  [ concurrent-event-loop ] spawn ;