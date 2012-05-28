/******************************************************************************
This module contains the 'text' standard library.

License:
Copyright (c) 2012 Jarrett Billingsley

This software is provided 'as-is', without any express or implied warranty.
In no event will the authors be held liable for any damages arising from the
use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it freely,
subject to the following restrictions:

    1. The origin of this software must not be misrepresented; you must not
	claim that you wrote the original software. If you use this software in a
	product, an acknowledgment in the product documentation would be
	appreciated but is not required.

    2. Altered source versions must be plainly marked as such, and must not
	be misrepresented as being the original software.

    3. This notice may not be removed or altered from any source distribution.
******************************************************************************/

module croc.stdlib_text;

import croc.api_interpreter;
import croc.api_stack;
import croc.ex;
import croc.stdlib_utils;
import croc.types;

alias CrocDoc.Docs Docs;
alias CrocDoc.Param Param;
alias CrocDoc.Extra Extra;

// ================================================================================================================================================
// Public
// ================================================================================================================================================

public:

void initTextLib(CrocThread* t)
{
	makeModule(t, "text", function uword(CrocThread* t)
	{
		registerGlobals(t, _globalFuncs);
		return 0;
	});

	importModule(t, "text");

	version(CrocBuiltinDocs)
	{
		scope doc = new CrocDoc(t, __FILE__);
		doc.push(Docs("module", "text",
		`This library contains utilities for performing text encoding and formatting.
		
		Note that this is somewhat different from the purpose of the \tt{string} library, which concerns itself with simple
		algorithmic operations on string objects. This module instead deals with the more "linguistic" aspects of handling text,
		including encoding strings into and decoding strings from raw character encodings, and formatting program objects into
		human-readable forms.
		
		This module exposes flexible interfaces, and the hope is that more text encodings and formatting options will be made
		available by second- and third-party libraries.`));

		docFields(t, doc, _globalFuncDocs);

		doc.pop(-1);
	}

	pop(t);
}

// ================================================================================================================================================
// Private
// ================================================================================================================================================

private:

const RegisterFunc[] _globalFuncs =
[
	{"toRawUnicode",   &_toRawUnicode,   maxParams: 3},
	{"toRawAscii",     &_toRawAscii,     maxParams: 2},
	{"fromRawUnicode", &_fromRawUnicode, maxParams: 3},
	{"fromRawAscii",   &_fromRawAscii,   maxParams: 3}
];

uword _toRawUnicode(CrocThread* t)
{
	checkStringParam(t, 1);
	auto str = getStringObj(t, 1);
	auto bitSize = optIntParam(t, 2, 8);

	char[] typeCode;

	switch(bitSize)
	{
		case 8:  typeCode = "u8"; break;
		case 16: typeCode = "u16"; break;
		case 32: typeCode = "u32"; break;
		default: throwStdException(t, "ValueException", "Invalid encoding size of {} bits", bitSize);
	}

	CrocMemblock* ret;

	if(optParam(t, 3, CrocValue.Type.Memblock))
	{
		ret = getMemblock(t, 3);
		// round off to a multiple of 4 so the re-type always works
		lenai(t, 3, len(t, 3) & ~3);
		dup(t, 3);
		pushNull(t);
		pushString(t, typeCode);
		methodCall(t, -3, "type", 0);
		lenai(t, 3, str.length);
	}
	else
	{
		newMemblock(t, typeCode, str.length);
		ret = getMemblock(t, -1);
	}

	uword len = 0;
	auto src = str.toString();

	switch(bitSize)
	{
		case 8:
			(cast(char*)ret.data.ptr)[0 .. str.length] = src[];
			len = str.length;
			break;

		case 16:
			auto dest = (cast(wchar*)ret.data.ptr)[0 .. str.length];

			auto temp = allocArray!(dchar)(t, str.length);
			scope(exit) freeArray(t, temp);

			uint ate = 0;
			auto tempData = safeCode(t, "exceptions.UnicodeException", Utf.toString32(src, temp, &ate));
			len = safeCode(t, "exceptions.UnicodeException", Utf.toString16(temp, dest, &ate)).length;
			break;

		case 32:
			auto dest = (cast(dchar*)ret.data.ptr)[0 .. str.length];
			uint ate = 0;
			len = safeCode(t, "exceptions.UnicodeException", Utf.toString32(src, dest, &ate)).length;
			break;

		default: assert(false);
	}

	push(t, CrocValue(ret));
	lenai(t, -1, len);
	return 1;
}

uword _toRawAscii(CrocThread* t)
{
	checkStringParam(t, 1);
	auto str = getStringObj(t, 1);

	// Take advantage of the fact that in UTF-8, codepoint length == data length iff all codepoints <= 0x7f -- valid ASCII
	if(str.length != str.cpLength)
		throwStdException(t, "ValueException", "Cannot convert string with codepoints higher than U+0007F to ASCII");

	CrocMemblock* ret;

	if(optParam(t, 2, CrocValue.Type.Memblock))
	{
		ret = getMemblock(t, 2);
		dup(t, 2);
		pushNull(t);
		pushString(t, "u8");
		methodCall(t, -3, "type", 0);
		lenai(t, 2, str.length);
	}
	else
	{
		newMemblock(t, "u8", str.length);
		ret = getMemblock(t, -1);
	}

	(cast(char*)ret.data.ptr)[0 .. str.length] = str.toString()[];
	push(t, CrocValue(ret));
	return 1;
}

uword _fromRawUnicode(CrocThread* t)
{
	checkParam(t, 1, CrocValue.Type.Memblock);
	auto mb = getMemblock(t, 1);
	auto lo = optIntParam(t, 2, 0);
	auto hi = optIntParam(t, 3, mb.itemLength);

	if(lo < 0)
		lo += mb.itemLength;

	if(hi < 0)
		hi += mb.itemLength;

	if(lo < 0 || lo > hi || hi > mb.itemLength)
		throwStdException(t, "BoundsException", "Invalid memblock slice indices {} .. {} (memblock length: {})", lo, hi, mb.itemLength);

	switch(mb.kind.code)
	{
		case CrocMemblock.TypeCode.u8:  pushFormat(t, "{}", (cast(char[])mb.data)[cast(uword)lo .. cast(uword)hi]); break;
		case CrocMemblock.TypeCode.u16: pushFormat(t, "{}", (cast(wchar[])mb.data)[cast(uword)lo .. cast(uword)hi]); break;
		case CrocMemblock.TypeCode.u32: pushFormat(t, "{}", (cast(dchar[])mb.data)[cast(uword)lo .. cast(uword)hi]); break;
		default: throwStdException(t, "ValueException", "Memblock must be of type 'u8', 'u16', or 'u32', not '{}'", mb.kind.name);
	}

	return 1;
}

uword _fromRawAscii(CrocThread* t)
{
	checkParam(t, 1, CrocValue.Type.Memblock);
	auto mb = getMemblock(t, 1);
	auto lo = optIntParam(t, 2, 0);
	auto hi = optIntParam(t, 3, mb.itemLength);

	if(lo < 0)
		lo += mb.itemLength;

	if(hi < 0)
		hi += mb.itemLength;
		
	if(lo < 0 || lo > hi || hi > mb.itemLength)
		throwStdException(t, "BoundsException", "Invalid memblock slice indices {} .. {} (memblock length: {})", lo, hi, mb.itemLength);

	if(mb.kind.code != CrocMemblock.TypeCode.u8)
		throwStdException(t, "ValueException", "Memblock must be of type 'u8', not '{}'", mb.kind.name);

	auto src = (cast(char[])mb.data)[cast(uword)lo .. cast(uword)hi];
	auto dest = allocArray!(char)(t, src.length);

	scope(exit)
		freeArray(t, dest);

	foreach(i, char c; src)
	{
		if(c <= 0x7f)
			dest[i] = c;
		else
			dest[i] = '\u001a';
	}

	pushString(t, dest);
	return 1;
}

version(CrocBuiltinDocs) const Docs[] _globalFuncDocs =
[
	{kind: "function", name: "fromRawUnicode", docs:
	`Converts data stored in a memblock into a string. The given memblock must be of type \tt{u8}, \tt{u16}, or \tt{u32}.
	If it's \tt{u8}, it must contain UTF-8 data; if it's \tt{u16}, it must contain UTF-16 data; and if it's \tt{u32}, it
	must contain UTF-32 data. You can specify only a slice of the memblock to convert into a string with the \tt{lo}
	and \tt{hi} parameters; the default behavior is to convert the entire memblock. If the data is invalid Unicode,
	an exception will be thrown. Returns the converted string.

	\throws[exceptions.BoundsException] if the given slice indices are invalid.
	\throws[exceptions.ValueException] if the given memblock is not one of the three valid types.`,
	params: [Param("mb", "memblock"), Param("lo", "int", "0"), Param("hi", "int", "#mb")]},

	{kind: "function", name: "fromRawAscii", docs:
	`Similar to \link{fromRawUnicode}, except converts a memblock containing ASCII data into a string. The memblock
	must be of type \tt{u8}. Any bytes above U+0007F are turned into the Unicode replacement character, U+0001A.
	Returns the converted string.

	\throws[exceptions.BoundsException] if the given slice indices are invalid.
	\throws[exceptions.ValueException] if the given memblock is not of type \tt{u8}.`,
	params: [Param("mb", "memblock"), Param("lo", "int", "0"), Param("hi", "int", "#mb")]},

	{kind: "function", name: "toRawUnicode", docs:
	`Converts a string into a memblock containing Unicode-encoded data. The \tt{bits} parameter determines which
	encoding to use. It defaults to 8, which means the resulting memblock will be filled with a UTF-8 encoding of
	\tt{s}, and its type will be \tt{u8}. The other two valid values are 16, which will encode UTF-16 data in a memblock
	of type \tt{u16}, and 32, which will encode UTF-32 data in a memblock of type \tt{u32}.

	You may optionally pass a memblock as the second parameter to be used as the destination memblock. This way you
	can reuse a memblock as a conversion buffer to avoid memory allocations. The memblock's type will be set
	appropriately and its data will be replaced by the encoded string data.

	\returns the memblock containing the encoded string data, either a new memblock if \tt{mb} is \tt{null}, or \tt{mb}
	otherwise.

	\throws[exceptions.ValueException] if \tt{bits} is not one of the valid values.
	\throws[exceptions.UnicodeException] if, somehow, the Unicode transcoding fails (but this shouldn't happen unless something
	else is broken..)`,
	params: [Param("bits", "int", "8"), Param("mb", "memblock", "null")]},

	{kind: "function", name: "toRawAscii", docs:
	`Similar to \link{toRawUnicode}, except encodes \tt{s} as ASCII. \tt{s} must not contain any codepoints above U+0007F;
	that is, \tt{s.isAscii()} must return true for this method to work.

	Just like \link{toRawUnicode} you can pass a memblock as a destination buffer. Its type will be set to \tt{u8}.

	\returns the memblock containing the encoded string data, either a new memblock if \tt{mb} is \tt{null}, or \tt{mb}
	otherwise.

	\throws[exceptions.ValueException] if the given string is not an ASCII string.`,
	params: [Param("mb", "memblock", "null")]},
];
