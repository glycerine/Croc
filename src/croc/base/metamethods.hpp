#ifndef CROC_BASE_METAMETHODS_HPP
#define CROC_BASE_METAMETHODS_HPP

#include "croc/base/sanity.hpp"

namespace croc
{
	// The first several values of this enumeration are the same as the opcodes for
	// their corresponding instructions, so that the metamethods can be looked up
	// quickly without needing an opcode-to-MM translation table.
	// LAST_OPCODE_MM is the last metamethod type which is like this.

#define METAMETHOD_LIST(X)\
	X(MM_Cat,          "opCat"         ),\
	X(MM_CatEq,        "opCatAssign"   ),\
	X(MM_Cat_r,        "opCat_r"       ),\
	X(MM_Index,        "opIndex"       ),\
	X(MM_IndexAssign,  "opIndexAssign" ),\
	X(MM_Slice,        "opSlice"       ),\
	X(MM_SliceAssign,  "opSliceAssign" ),\
	X(MM_Field,        "opField"       ),\
	X(MM_FieldAssign,  "opFieldAssign" ),\
	X(MM_Length,       "opLength"      ),\
	X(MM_LengthAssign, "opLengthAssign"),\
	X(MM_Cmp,          "opCmp"         ),\
	X(MM_Equals,       "opEquals"      ),\
	X(MM_Call,         "opCall"        ),\
	X(MM_Method,       "opMethod"      ),\
	X(MM_Apply,        "opApply"       ),\
	X(MM_In,           "opIn"          ),\
	X(MM_ToString,     "toString"      )

#define POOP(x, _) x
	typedef enum Metamethod
	{
		METAMETHOD_LIST(POOP)
	} Metamethod;
#undef POOP

	extern const char* MetaNames[];
}
#endif
