INLINE CELL tag_boolean(CELL untagged)
{
	return (untagged == false ? F : T);
}

DLLEXPORT void box_boolean(bool value);
DLLEXPORT bool unbox_boolean(void);

INLINE F_ARRAY* untag_array_fast(CELL tagged)
{
	return (F_ARRAY*)UNTAG(tagged);
}

INLINE F_ARRAY* untag_array(CELL tagged)
{
	type_check(ARRAY_TYPE,tagged);
	return untag_array_fast(tagged);
}

INLINE F_ARRAY* untag_byte_array_fast(CELL tagged)
{
	return (F_ARRAY*)UNTAG(tagged);
}

INLINE CELL array_size(CELL size)
{
	return align8(sizeof(F_ARRAY) + size * CELLS);
}

F_ARRAY *allot_array(CELL type, F_FIXNUM capacity);
F_ARRAY *array(CELL type, F_FIXNUM capacity, CELL fill);
F_ARRAY *byte_array(F_FIXNUM size);

CELL make_array_2(CELL v1, CELL v2);
CELL make_array_4(CELL v1, CELL v2, CELL v3, CELL v4);

void primitive_array(void);
void primitive_tuple(void);
void primitive_byte_array(void);
void primitive_quotation(void);

F_ARRAY *resize_array(F_ARRAY* array, F_FIXNUM capacity, CELL fill);
void primitive_resize_array(void);
void primitive_array_to_tuple(void);
void primitive_tuple_to_array(void);

#define AREF(array,index) ((CELL)(array) + sizeof(F_ARRAY) + (index) * CELLS)
#define UNAREF(array,ptr) (((CELL)(ptr)-(CELL)(array)-sizeof(F_ARRAY)) / CELLS)

INLINE CELL array_capacity(F_ARRAY* array)
{
	return untag_fixnum_fast(array->capacity);
}

void fixup_array(F_ARRAY* array);
void collect_array(F_ARRAY* array);

INLINE F_VECTOR* untag_vector(CELL tagged)
{
	type_check(VECTOR_TYPE,tagged);
	return (F_VECTOR*)UNTAG(tagged);
}

F_VECTOR* vector(F_FIXNUM capacity);

void primitive_vector(void);
void primitive_array_to_vector(void);
void fixup_vector(F_VECTOR* vector);
void collect_vector(F_VECTOR* vector);

#define SREF(string,index) ((CELL)string + sizeof(F_STRING) + index * CHARS)

INLINE F_STRING* untag_string_fast(CELL tagged)
{
	return (F_STRING*)UNTAG(tagged);
}

INLINE F_STRING* untag_string(CELL tagged)
{
	type_check(STRING_TYPE,tagged);
	return untag_string_fast(tagged);
}

INLINE CELL string_capacity(F_STRING* str)
{
	return untag_fixnum_fast(str->length);
}

INLINE CELL string_size(CELL size)
{
	return align8(sizeof(F_STRING) + (size + 1) * CHARS);
}

F_STRING* allot_string(F_FIXNUM capacity);
void rehash_string(F_STRING* str);
void primitive_rehash_string(void);
F_STRING* string(F_FIXNUM capacity, CELL fill);
void primitive_string(void);
F_STRING *resize_string(F_STRING *string, F_FIXNUM capacity, u16 fill);
void primitive_resize_string(void);

F_STRING *memory_to_char_string(const char *string, CELL length);
void primitive_memory_to_char_string(void);
F_STRING *from_char_string(const char *c_string);
DLLEXPORT void box_char_string(const char *c_string);
void primitive_alien_to_char_string(void);

F_STRING *memory_to_u16_string(const u16 *string, CELL length);
void primitive_memory_to_u16_string(void);
F_STRING *from_u16_string(const u16 *c_string);
DLLEXPORT void box_u16_string(const u16 *c_string);
void primitive_alien_to_u16_string(void);

void char_string_to_memory(F_STRING *s, char *string);
void primitive_char_string_to_memory(void);
F_ARRAY *string_to_char_alien(F_STRING *s, bool check);
char* to_char_string(F_STRING *s, bool check);
char *pop_char_string(void);
DLLEXPORT char *unbox_char_string(void);
void primitive_string_to_char_alien(void);

void u16_string_to_memory(F_STRING *s, u16 *string);
void primitive_u16_string_to_memory(void);
F_ARRAY *string_to_u16_alien(F_STRING *s, bool check);
u16* to_u16_string(F_STRING *s, bool check);
u16 *pop_u16_string(void);
DLLEXPORT u16 *unbox_u16_string(void);
void primitive_string_to_u16_alien(void);

/* untagged & unchecked */
INLINE CELL string_nth(F_STRING* string, CELL index)
{
	return cget(SREF(string,index));
}

/* untagged & unchecked */
INLINE void set_string_nth(F_STRING* string, CELL index, u16 value)
{
	cput(SREF(string,index),value);
}

void primitive_char_slot(void);
void primitive_set_char_slot(void);

F_SBUF* sbuf(F_FIXNUM capacity);
void primitive_sbuf(void);
void fixup_sbuf(F_SBUF* sbuf);
void collect_sbuf(F_SBUF* sbuf);

void primitive_hashtable(void);
void fixup_hashtable(F_HASHTABLE* hashtable);
void collect_hashtable(F_HASHTABLE* hashtable);

typedef void (*XT)(F_WORD *word);

INLINE F_WORD *untag_word_fast(CELL tagged)
{
	return (F_WORD*)UNTAG(tagged);
}

INLINE F_WORD *untag_word(CELL tagged)
{
	type_check(WORD_TYPE,tagged);
	return untag_word_fast(tagged);
}

INLINE CELL tag_word(F_WORD *word)
{
	return RETAG(word,WORD_TYPE);
}

void update_xt(F_WORD* word);
void primitive_word(void);
void primitive_update_xt(void);
void primitive_word_compiledp(void);
void fixup_word(F_WORD* word);
void collect_word(F_WORD* word);

INLINE F_WRAPPER *untag_wrapper_fast(CELL tagged)
{
	return (F_WRAPPER*)UNTAG(tagged);
}

INLINE CELL tag_wrapper(F_WRAPPER *wrapper)
{
	return RETAG(wrapper,WRAPPER_TYPE);
}

void primitive_wrapper(void);
void fixup_wrapper(F_WRAPPER *wrapper);
void collect_wrapper(F_WRAPPER *wrapper);