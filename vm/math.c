#include "factor.h"

/* Fixnums */

F_FIXNUM to_fixnum(CELL tagged)
{
	F_RATIO* r;
	F_ARRAY* x;
	F_ARRAY* y;
	F_FLOAT* f;

	switch(TAG(tagged))
	{
	case FIXNUM_TYPE:
		return untag_fixnum_fast(tagged);
	case BIGNUM_TYPE:
		return (F_FIXNUM)s48_bignum_to_fixnum((F_ARRAY*)UNTAG(tagged));
	case RATIO_TYPE:
		r = (F_RATIO*)UNTAG(tagged);
		x = to_bignum(r->numerator);
		y = to_bignum(r->denominator);
		return to_fixnum(tag_bignum(s48_bignum_quotient(x,y)));
	case FLOAT_TYPE:
		f = (F_FLOAT*)UNTAG(tagged);
		return (F_FIXNUM)f->n;
	default:
		type_error(FIXNUM_TYPE,tagged);
		return -1; /* can't happen */
	}
}

void primitive_to_fixnum(void)
{
	drepl(tag_fixnum(to_fixnum(dpeek())));
}

#define POP_FIXNUMS(x,y) \
	F_FIXNUM x, y; \
	y = untag_fixnum_fast(dpop()); \
	x = untag_fixnum_fast(dpop());
	
/* The fixnum arithmetic operations defined in C are relatively slow.
The Factor compiler has optimized assembly intrinsics for all these
operations. */
void primitive_fixnum_add(void)
{
	POP_FIXNUMS(x,y)
	box_signed_cell(x + y);
}

void primitive_fixnum_add_fast(void)
{
	POP_FIXNUMS(x,y)
	dpush(tag_fixnum(x + y));
}

void primitive_fixnum_subtract(void)
{
	POP_FIXNUMS(x,y)
	box_signed_cell(x - y);
}

void primitive_fixnum_subtract_fast(void)
{
	POP_FIXNUMS(x,y)
	dpush(tag_fixnum(x - y));
}

/**
 * Multiply two integers, and trap overflow.
 * Thanks to David Blaikie (The_Vulture from freenode #java) for the hint.
 */
void primitive_fixnum_multiply(void)
{
	POP_FIXNUMS(x,y)

	if(x == 0 || y == 0)
		dpush(tag_fixnum(0));
	else
	{
		F_FIXNUM prod = x * y;
		/* if this is not equal, we have overflow */
		if(prod / x == y)
			box_signed_cell(prod);
		else
		{
			dpush(tag_bignum(
				s48_bignum_multiply(
					s48_fixnum_to_bignum(x),
					s48_fixnum_to_bignum(y))));
		}
	}
}

void primitive_fixnum_divint(void)
{
	POP_FIXNUMS(x,y)
	box_signed_cell(x / y);
}

void primitive_fixnum_divfloat(void)
{
	POP_FIXNUMS(x,y)
	dpush(tag_float((double)x / (double)y));
}

void primitive_fixnum_divmod(void)
{
	POP_FIXNUMS(x,y)
	box_signed_cell(x / y);
	box_signed_cell(x % y);
}

void primitive_fixnum_mod(void)
{
	POP_FIXNUMS(x,y)
	dpush(tag_fixnum(x % y));
}

void primitive_fixnum_and(void)
{
	POP_FIXNUMS(x,y)
	dpush(tag_fixnum(x & y));
}

void primitive_fixnum_or(void)
{
	POP_FIXNUMS(x,y)
	dpush(tag_fixnum(x | y));
}

void primitive_fixnum_xor(void)
{
	POP_FIXNUMS(x,y)
	dpush(tag_fixnum(x ^ y));
}

/*
 * Note the hairy overflow check.
 * If we're shifting right by n bits, we won't overflow as long as none of the
 * high WORD_SIZE-TAG_BITS-n bits are set.
 */
void primitive_fixnum_shift(void)
{
	POP_FIXNUMS(x,y)

	if(x == 0 || y == 0)
	{
		dpush(tag_fixnum(x));
		return;
	}
	else if(y < 0)
	{
		if(y <= -WORD_SIZE)
			dpush(x < 0 ? tag_fixnum(-1) : tag_fixnum(0));
		else
			dpush(tag_fixnum(x >> -y));
		return;
	}
	else if(y < WORD_SIZE - TAG_BITS)
	{
		F_FIXNUM mask = -(1 << (WORD_SIZE - 1 - TAG_BITS - y));
		if((x > 0 && (x & mask) == 0) || (x & mask) == mask)
		{
			dpush(tag_fixnum(x << y));
			return;
		}
	}

	dpush(tag_bignum(s48_bignum_arithmetic_shift(
		s48_fixnum_to_bignum(x),y)));
}

void primitive_fixnum_less(void)
{
	POP_FIXNUMS(x,y)
	box_boolean(x < y);
}

void primitive_fixnum_lesseq(void)
{
	POP_FIXNUMS(x,y)
	box_boolean(x <= y);
}

void primitive_fixnum_greater(void)
{
	POP_FIXNUMS(x,y)
	box_boolean(x > y);
}

void primitive_fixnum_greatereq(void)
{
	POP_FIXNUMS(x,y)
	box_boolean(x >= y);
}

void primitive_fixnum_not(void)
{
	drepl(tag_fixnum(~untag_fixnum_fast(dpeek())));
}

#define INT_DEFBOX(name,type) \
void name (type integer)                                                       \
{                                                                              \
	dpush(tag_integer(integer));                                           \
}

#define INT_DEFUNBOX(name,type) \
type name(void)                                                                \
{                                                                              \
	return to_fixnum(dpop());                                              \
}

INT_DEFBOX(box_signed_1, signed char)
INT_DEFBOX(box_signed_2, signed short)
INT_DEFBOX(box_unsigned_1, unsigned char)
INT_DEFBOX(box_unsigned_2, unsigned short)
INT_DEFUNBOX(unbox_signed_1, signed char)
INT_DEFUNBOX(unbox_signed_2, signed short)
INT_DEFUNBOX(unbox_unsigned_1, unsigned char)
INT_DEFUNBOX(unbox_unsigned_2, unsigned short) 

/* Bignums */

CELL to_cell(CELL x)
{
	switch(type_of(x))
	{
	case FIXNUM_TYPE:
		return untag_fixnum_fast(x);
	case BIGNUM_TYPE:
		return s48_bignum_to_fixnum(untag_bignum_fast(x));
	default:
		type_error(BIGNUM_TYPE,x);
		return 0;
	}
}

F_ARRAY* to_bignum(CELL tagged)
{
	F_RATIO* r;
	F_ARRAY* x;
	F_ARRAY* y;
	F_FLOAT* f;

	switch(type_of(tagged))
	{
	case FIXNUM_TYPE:
		return s48_fixnum_to_bignum(untag_fixnum_fast(tagged));
	case BIGNUM_TYPE:
		return (F_ARRAY*)UNTAG(tagged);
	case RATIO_TYPE:
		r = (F_RATIO*)UNTAG(tagged);
		x = to_bignum(r->numerator);
		y = to_bignum(r->denominator);
		return s48_bignum_quotient(x,y);
	case FLOAT_TYPE:
		f = (F_FLOAT*)UNTAG(tagged);
		return s48_double_to_bignum(f->n);
	default:
		type_error(BIGNUM_TYPE,tagged);
		return NULL; /* can't happen */
	}
}

void primitive_to_bignum(void)
{
	maybe_gc(0);
	drepl(tag_bignum(to_bignum(dpeek())));
}

#define GC_AND_POP_BIGNUMS(x,y) \
	F_ARRAY *x, *y; \
	maybe_gc(0); \
	y = untag_bignum_fast(dpop()); \
	x = untag_bignum_fast(dpop());

void primitive_bignum_eq(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	box_boolean(s48_bignum_equal_p(x,y));
}

void primitive_bignum_add(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_bignum(s48_bignum_add(x,y)));
}

void primitive_bignum_subtract(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_bignum(s48_bignum_subtract(x,y)));
}

void primitive_bignum_multiply(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_bignum(s48_bignum_multiply(x,y)));
}

void primitive_bignum_divint(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_bignum(s48_bignum_quotient(x,y)));
}

void primitive_bignum_divfloat(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_float(
		s48_bignum_to_double(x) /
		s48_bignum_to_double(y)));
}

void primitive_bignum_divmod(void)
{
	F_ARRAY *q, *r;
	GC_AND_POP_BIGNUMS(x,y);
	s48_bignum_divide(x,y,&q,&r);
	dpush(tag_bignum(q));
	dpush(tag_bignum(r));
}

void primitive_bignum_mod(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_bignum(s48_bignum_remainder(x,y)));
}

void primitive_bignum_and(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_bignum(s48_bignum_bitwise_and(x,y)));
}

void primitive_bignum_or(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_bignum(s48_bignum_bitwise_ior(x,y)));
}

void primitive_bignum_xor(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	dpush(tag_bignum(s48_bignum_bitwise_xor(x,y)));
}

void primitive_bignum_shift(void)
{
	F_FIXNUM y;
        F_ARRAY* x;
	maybe_gc(0);
	y = to_fixnum(dpop());
	x = to_bignum(dpop());
	dpush(tag_bignum(s48_bignum_arithmetic_shift(x,y)));
}

void primitive_bignum_less(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	box_boolean(s48_bignum_compare(x,y) == bignum_comparison_less);
}

void primitive_bignum_lesseq(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	switch(s48_bignum_compare(x,y))
	{
	case bignum_comparison_less:
	case bignum_comparison_equal:
		dpush(T);
		break;
	case bignum_comparison_greater:
		dpush(F);
		break;
	default:
		critical_error("s48_bignum_compare returns bogus value",0);
		break;
	}
}

void primitive_bignum_greater(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	box_boolean(s48_bignum_compare(x,y) == bignum_comparison_greater);
}

void primitive_bignum_greatereq(void)
{
	GC_AND_POP_BIGNUMS(x,y);
	switch(s48_bignum_compare(x,y))
	{
	case bignum_comparison_less:
		dpush(F);
		break;
	case bignum_comparison_equal:
	case bignum_comparison_greater:
		dpush(T);
		break;
	default:
		critical_error("s48_bignum_compare returns bogus value",0);
		break;
	}
}

void primitive_bignum_not(void)
{
	maybe_gc(0);
	drepl(tag_bignum(s48_bignum_bitwise_not(
		untag_bignum_fast(dpeek()))));
}

void box_signed_cell(F_FIXNUM integer)
{
	dpush(tag_integer(integer));
}

F_FIXNUM unbox_signed_cell(void)
{
	return to_fixnum(dpop());
}

void box_unsigned_cell(CELL cell)
{
	dpush(tag_cell(cell));
}

F_FIXNUM unbox_unsigned_cell(void)
{
	return to_cell(dpop());
}

void box_signed_4(s32 n)
{
	dpush(tag_bignum(s48_long_to_bignum(n)));
}

s32 unbox_signed_4(void)
{
	return to_fixnum(dpop());
}

void box_unsigned_4(u32 n)
{
	dpush(tag_bignum(s48_ulong_to_bignum(n)));
}

u32 unbox_unsigned_4(void)
{
	return to_cell(dpop());
}

void box_signed_8(s64 n)
{
	dpush(tag_bignum(s48_long_long_to_bignum(n)));
}

s64 unbox_signed_8(void)
{
	return s48_bignum_to_long_long(to_bignum(dpop()));
}

void box_unsigned_8(u64 n)
{
	dpush(tag_bignum(s48_ulong_long_to_bignum(n)));
}

u64 unbox_unsigned_8(void)
{
	return s48_bignum_to_ulong_long(to_bignum(dpop()));
}

/* Ratios */

/* Does not reduce to lowest terms, so should only be used by math
library implementation, to avoid breaking invariants. */
void primitive_from_fraction(void)
{
	CELL numerator, denominator;
	F_RATIO* ratio;

	maybe_gc(0);

	denominator = dpop();
	numerator = dpop();
	ratio = allot_object(RATIO_TYPE,sizeof(F_RATIO));
	ratio->numerator = numerator;
	ratio->denominator = denominator;
	dpush(RETAG(ratio,RATIO_TYPE));
}

void fixup_ratio(F_RATIO* ratio)
{
	data_fixup(&ratio->numerator);
	data_fixup(&ratio->denominator);
}

void collect_ratio(F_RATIO* ratio)
{
	copy_handle(&ratio->numerator);
	copy_handle(&ratio->denominator);
}

/* Floats */

double to_float(CELL tagged)
{
	F_RATIO* r;
	double x;
	double y;

	switch(TAG(tagged))
	{
	case FIXNUM_TYPE:
		return (double)untag_fixnum_fast(tagged);
	case BIGNUM_TYPE:
		return s48_bignum_to_double((F_ARRAY*)UNTAG(tagged));
	case RATIO_TYPE:
		r = (F_RATIO*)UNTAG(tagged);
		x = to_float(r->numerator);
		y = to_float(r->denominator);
		return x / y;
	case FLOAT_TYPE:
		return ((F_FLOAT*)UNTAG(tagged))->n;
	default:
		type_error(FLOAT_TYPE,tagged);
		return 0.0; /* can't happen */
	}
}

void primitive_to_float(void)
{
	maybe_gc(sizeof(F_FLOAT));
	drepl(tag_float(to_float(dpeek())));
}

void primitive_str_to_float(void)
{
	F_STRING* str;
	char *c_str, *end;
	double f;

	maybe_gc(sizeof(F_FLOAT));

	str = untag_string(dpeek());
	c_str = to_char_string(str,true);
	end = c_str;
	f = strtod(c_str,&end);
	if(end != c_str + string_capacity(str))
		drepl(F);
	else
		drepl(tag_float(f));
}

void primitive_float_to_str(void)
{
	char tmp[33];

	maybe_gc(sizeof(F_FLOAT));

	snprintf(tmp,32,"%.16g",to_float(dpop()));
	tmp[32] = '\0';
	box_char_string(tmp);
}

#define GC_AND_POP_FLOATS(x,y) \
	double x, y; \
	maybe_gc(sizeof(F_FLOAT)); \
	y = untag_float_fast(dpop()); \
	x = untag_float_fast(dpop());

void primitive_float_add(void)
{
	GC_AND_POP_FLOATS(x,y);
	dpush(tag_float(x + y));
}

void primitive_float_subtract(void)
{
	GC_AND_POP_FLOATS(x,y);
	dpush(tag_float(x - y));
}

void primitive_float_multiply(void)
{
	GC_AND_POP_FLOATS(x,y);
	dpush(tag_float(x * y));
}

void primitive_float_divfloat(void)
{
	GC_AND_POP_FLOATS(x,y);
	dpush(tag_float(x / y));
}

void primitive_float_mod(void)
{
	GC_AND_POP_FLOATS(x,y);
	dpush(tag_float(fmod(x,y)));
}

void primitive_float_less(void)
{
	GC_AND_POP_FLOATS(x,y);
	box_boolean(x < y);
}

void primitive_float_lesseq(void)
{
	GC_AND_POP_FLOATS(x,y);
	box_boolean(x <= y);
}

void primitive_float_greater(void)
{
	GC_AND_POP_FLOATS(x,y);
	box_boolean(x > y);
}

void primitive_float_greatereq(void)
{
	GC_AND_POP_FLOATS(x,y);
	box_boolean(x >= y);
}

void primitive_facos(void)
{
	maybe_gc(sizeof(F_FLOAT));
	drepl(tag_float(acos(to_float(dpeek()))));
}

void primitive_fasin(void)
{
	maybe_gc(sizeof(F_FLOAT));
	drepl(tag_float(asin(to_float(dpeek()))));
}

void primitive_fatan(void)
{
	maybe_gc(sizeof(F_FLOAT));
	drepl(tag_float(atan(to_float(dpeek()))));
}

void primitive_fatan2(void)
{
	double x, y;
	maybe_gc(sizeof(F_FLOAT));
	y = to_float(dpop());
	x = to_float(dpop());
	dpush(tag_float(atan2(x,y)));
}

void primitive_fcos(void)
{
	maybe_gc(sizeof(F_FLOAT));
	drepl(tag_float(cos(to_float(dpeek()))));
}

void primitive_fexp(void)
{
	maybe_gc(sizeof(F_FLOAT));
	drepl(tag_float(exp(to_float(dpeek()))));
}

void primitive_fcosh(void)
{
	maybe_gc(sizeof(F_FLOAT));
	drepl(tag_float(cosh(to_float(dpeek()))));
}

void primitive_flog(void)
{
	maybe_gc(sizeof(F_FLOAT));
	drepl(tag_float(log(to_float(dpeek()))));
}

void primitive_fpow(void)
{
	double x, y;
	maybe_gc(sizeof(F_FLOAT));
	y = to_float(dpop());
	x = to_float(dpop());
	dpush(tag_float(pow(x,y)));
}

void primitive_fsin(void)
{
	maybe_gc(sizeof(F_FLOAT));
	drepl(tag_float(sin(to_float(dpeek()))));
}

void primitive_fsinh(void)
{
	maybe_gc(sizeof(F_FLOAT));
	drepl(tag_float(sinh(to_float(dpeek()))));
}

void primitive_fsqrt(void)
{
	maybe_gc(sizeof(F_FLOAT));
	drepl(tag_float(sqrt(to_float(dpeek()))));
}

void primitive_float_bits(void)
{
	FLOAT_BITS b;
	b.x = (float)to_float(dpeek());
	drepl(tag_cell(b.y));
}

void primitive_bits_float(void)
{
	FLOAT_BITS b;
	b.y = unbox_unsigned_4();
	dpush(tag_float(b.x));
}

void primitive_double_bits(void)
{
	DOUBLE_BITS b;
	b.x = to_float(dpop());
	box_unsigned_8(b.y);
}

void primitive_bits_double(void)
{
	DOUBLE_BITS b;
	b.y = unbox_unsigned_8();
	dpush(tag_float(b.x));
}

#define FLO_DEFBOX(name,type) \
void name (type flo)                                                       \
{                                                                              \
	dpush(tag_float(flo));                                               \
}

#define FLO_DEFUNBOX(name,type) \
type name(void)                                                                \
{                                                                              \
	return to_float(dpop());                                                  \
}

FLO_DEFBOX(box_float,float)
FLO_DEFUNBOX(unbox_float,float)  
FLO_DEFBOX(box_double,double)
FLO_DEFUNBOX(unbox_double,double)

/* Complex numbers */

void primitive_from_rect(void)
{
	CELL real, imaginary;
	F_COMPLEX* complex;

	maybe_gc(sizeof(F_COMPLEX));

	imaginary = dpop();
	real = dpop();
	complex = allot_object(COMPLEX_TYPE,sizeof(F_COMPLEX));
	complex->real = real;
	complex->imaginary = imaginary;
	dpush(RETAG(complex,COMPLEX_TYPE));
}

void fixup_complex(F_COMPLEX* complex)
{
	data_fixup(&complex->real);
	data_fixup(&complex->imaginary);
}

void collect_complex(F_COMPLEX* complex)
{
	copy_handle(&complex->real);
	copy_handle(&complex->imaginary);
}