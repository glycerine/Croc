/******************************************************************************

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

module croc.stdlib_text_ascii;

import tango.stdc.string;

import croc.api_interpreter;
import croc.api_stack;
import croc.ex;
import croc.ex_library;
import croc.stdlib_text_codec;
import croc.types;
import croc.utf;

// =====================================================================================================================
// Package
// =====================================================================================================================

package:

void initAsciiCodec(CrocThread* t)
{
	pushGlobal(t, "text");
	loadString(t, _code, true, "text_ascii.croc");
	pushNull(t);
	newTable(t);
		registerFields(t, _funcs);

	call(t, -3, 0);
}

// =====================================================================================================================
// Private
// =====================================================================================================================

private:

const RegisterFunc[] _funcs =
[
	{ "asciiEncodeInternal", &_asciiEncodeInternal, maxParams: 4 },
	{ "asciiDecodeInternal", &_asciiDecodeInternal, maxParams: 4 }
];

uword _asciiEncodeInternal(CrocThread* t)
{
	mixin(encodeIntoHeader);

	// Gonna need at most str.length characters, if all goes well
	lenai(t, 2, start + str.length);

	auto destBase = getMemblockData(t, 2).ptr;
	auto dest = destBase + start;
	auto src = str.ptr;

	if(str.length == strlen)
	{
		// It's definitely ASCII, just shortcut copying it over.
		memcpy(dest, src, strlen * char.sizeof);
		dup(t, 2);
		return 1;
	}

	auto end = src + str.length;
	auto last = src;

	// At least one of the characters is outside ASCII range, just let the slower loop figure out what to do
	while(src < end)
	{
		if(*src < 0x80)
			src++;
		else
		{
			if(src !is last)
			{
				memcpy(dest, last, (src - last) * char.sizeof);
				dest += src - last;
			}

			auto c = fastDecodeUtf8Char(src);
			last = src;

			if(errors == "strict")
				throwStdException(t, "UnicodeError", "Character U+{:X6} cannot be encoded as ASCII", cast(uint)c);
			else if(errors == "ignore")
				continue;
  			else if(errors == "replace")
				*(dest++) = '?';
			else
				throwStdException(t, "ValueError", "Invalid error handling type '{}'", errors);
		}
	}

	if(src !is last)
	{
		memcpy(dest, last, (src - last) * char.sizeof);
		dest += src - last;
	}

	// "ignore" may have resulted in fewer characters being encoded than we allocated for
	lenai(t, 2, dest - destBase);
	dup(t, 2);
	return 1;
}

uword _asciiDecodeInternal(CrocThread* t)
{
	mixin(decodeRangeHeader);

	auto src = mb.ptr;
	auto end = mb.ptr + mb.length;
	auto last = src;

	auto s = StrBuffer(t);

	while(src < end)
	{
		if(*src < 0x80)
			src++;
		else
		{
			if(src !is last)
				s.addString(cast(char[])last[0 .. src - last]);

			auto c = *src++;
			last = src;

			if(errors == "strict")
				throwStdException(t, "UnicodeError", "Character 0x{:X2} is invalid ASCII (above 0x7F)", c);
			else if(errors == "ignore")
				continue;
			else if(errors == "replace")
				s.addChar('\uFFFD');
			else
				throwStdException(t, "ValueError", "Invalid error handling type '{}'", errors);
		}
	}

	if(src !is last)
		s.addString(cast(char[])last[0 .. src - last]);

	s.finish();
	return 1;
}

const char[] _code =
`
local _internal = vararg
local _encodeInto, _decodeRange = _internal.asciiEncodeInternal, _internal.asciiDecodeInternal

local class AsciiIncrementalEncoder : IncrementalEncoder
{
	_errors

	this(errors: string = "strict")
		:_errors = errors

	function encodeInto(str: string, dest: memblock, start: int, final: bool = false) =
		_encodeInto(str, dest, start, :_errors)

	function reset() {}
}

local class AsciiIncrementalDecoder : IncrementalDecoder
{
	_errors

	this(errors: string = "strict")
		:_errors = errors

	function decodeRange(src: memblock, lo: int, hi: int, final: bool = false) =
		_decodeRange(src, lo, hi, :_errors)

	function reset() {}
}

class AsciiCodec : TextCodec
{
	name = "ascii"

	function incrementalEncoder(errors: string = "strict") =
		AsciiIncrementalEncoder(errors)

	function incrementalDecoder(errors: string = "strict") =
		AsciiIncrementalDecoder(errors)
}

object.addMethod(AsciiCodec, "encodeInto", _encodeInto)
object.addMethod(AsciiCodec, "decodeRange", _decodeRange)

registerCodec("ascii", AsciiCodec())
`;