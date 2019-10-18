! Copyright (C) 2005 Slava Pestov.
! See http://factor.sf.net/license.txt for BSD license.
IN: assembler

! AMD64 registers
SYMBOL: RAX \ RAX 0  64 define-register
SYMBOL: RCX \ RCX 1  64 define-register
SYMBOL: RDX \ RDX 2  64 define-register
SYMBOL: RBX \ RBX 3  64 define-register
SYMBOL: RSP \ RSP 4  64 define-register
SYMBOL: RBP \ RBP 5  64 define-register
SYMBOL: RSI \ RSI 6  64 define-register
SYMBOL: RDI \ RDI 7  64 define-register
SYMBOL: R8  \ R8  8  64 define-register
SYMBOL: R9  \ R9  9  64 define-register
SYMBOL: R10 \ R10 10 64 define-register
SYMBOL: R11 \ R11 11 64 define-register
SYMBOL: R12 \ R12 12 64 define-register
SYMBOL: R13 \ R13 13 64 define-register
SYMBOL: R14 \ R14 14 64 define-register
SYMBOL: R15 \ R15 15 64 define-register

SYMBOL: XMM8 \ XMM8 8 128 define-register
SYMBOL: XMM9 \ XMM9 9 128 define-register
SYMBOL: XMM10 \ XMM10 10 128 define-register
SYMBOL: XMM11 \ XMM11 11 128 define-register
SYMBOL: XMM12 \ XMM12 12 128 define-register
SYMBOL: XMM13 \ XMM13 13 128 define-register
SYMBOL: XMM14 \ XMM14 14 128 define-register
SYMBOL: XMM15 \ XMM15 15 128 define-register