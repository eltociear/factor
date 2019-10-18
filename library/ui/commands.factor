IN: gadgets-presentations
USING: compiler gadgets gadgets-buttons gadgets-listener
gadgets-menus gadgets-panes generic hashtables inference
inspector io jedit kernel lists namespaces parser prettyprint
sequences strings styles words ;

SYMBOL: commands

TUPLE: command name pred quot context default? ;

V{ } clone commands set-global

: forget-command ( name -- )
    global [
        commands [ [ command-name = not ] subset-with ] change
    ] bind ;

: (define-command) ( name pred quot context default? -- )
    <command> dup command-name forget-command commands get push ;

: define-command ( name pred quot context -- )
    f (define-command) ;

: define-default-command ( name pred quot context -- )
    t (define-command) ;

: applicable ( object -- seq )
    commands get [ command-pred call ] subset-with ;

: command>quot ( presented command -- quot )
    [ command-quot curry ] keep command-context unit curry ;

TUPLE: command-button object ;

: command-action ( command-button -- )
    #! Invoke the default action.
    command-button-object dup applicable
    [ command-default? ] find-last nip command>quot call ;

: <command-menu-item> ( presented command -- item )
    [ command>quot [ drop ] swap append ] keep
    command-name swons ;

: <command-menu> ( presented -- menu )
    dup applicable
    [ <command-menu-item> ] map-with <menu> ;

: command-menu ( command-button -- )
    dup button-update
    command-button-object <command-menu>
    show-hand-menu ;

: command-button-actions ( gadget -- )
    dup
    [ command-menu ] [ button-down 3 ] set-action
    [ button-update ] [ button-up 3 ] set-action ;

C: command-button ( gadget object -- button )
    [ set-command-button-object ] keep
    [
        >r [ command-action ] <roll-button> r>
        set-gadget-delegate
    ] keep
    dup command-button-actions ;

M: command-button gadget-help ( button -- string )
    command-button-object dup word? [ synopsis ] [ summary ] if ;

"Describe object" [ drop t ] [ describe ] \ in-browser define-default-command
"Inspect object" [ drop t ] [ inspect ] \ in-listener define-command
"Describe commands" [ drop t ] [ applicable describe ] \ in-browser define-command
"Prettyprint" [ drop t ] [ . ] \ in-listener define-command
"Push on data stack" [ drop t ] [ ] \ in-listener define-command

"Word call hierarchy" [ word? ] [ uses. ] \ in-browser define-command
"Word caller hierarchy" [ word? ] [ usage. ] \ in-browser define-command
"Open in jEdit" [ word? ] [ jedit ] \ call define-command
"Reload original source" [ word? ] [ reload ] \ in-listener define-command
"Infer stack effect" [ word? ] [ unit infer . ] \ in-listener define-command

"Use word vocabulary" [ word? ] [ word-vocabulary use+ ] \ in-listener define-command

"Display gadget" [ [ gadget? ] is? ] [ gadget. ] \ in-listener define-command

"Use as input" [ input? ] [ input-string pane get replace-input ] \ call define-default-command