/******************************************************************************
This module contains the 'hash' standard library.

License:
Copyright (c) 2008 Jarrett Billingsley

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

module croc.stdlib_hash;

import croc.api_interpreter;
import croc.api_stack;
import croc.compiler;
import croc.ex;
import croc.ex_library;
import croc.types;
import croc.types_namespace;
import croc.types_table;

alias CrocDoc.Docs Docs;
alias CrocDoc.Param Param;
alias CrocDoc.Extra Extra;

// =========================================================================================================================================
// Public
// =========================================================================================================================================

public:

void initHashLib(CrocThread* t)
{
	makeModule(t, "hash", function uword(CrocThread* t)
	{
		registerGlobals(t, _globalFuncs);

		newNamespace(t, "table");
			registerFields(t, _tableMetamethods);
		setTypeMT(t, CrocValue.Type.Table);

		newNamespace(t, "namespace");
			registerFields(t, _namespaceMetamethods);
		setTypeMT(t, CrocValue.Type.Namespace);

		version(CrocBuiltinDocs)
			scope c = new Compiler(t, Compiler.getDefaultFlags(t) | Compiler.DocTable);
		else
			scope c = new Compiler(t);

		c.compileStatements(WeakTableCode, "hash.croc");
		newFunction(t, -1);
		pushNull(t);
		call(t, -2, 0);
		pop(t);

		version(CrocBuiltinDocs)
			newGlobal(t, "_subdocs"); // store the sub-doctable in a global temporarily

		return 0;
	});

	auto hash = importModule(t, "hash");

	version(CrocBuiltinDocs)
	{
		scope doc = new CrocDoc(t, __FILE__);
		doc.push(Docs("module", "hash",
		`This library contains functionality common to both tables and namespaces, which are two similar kinds of hash
		tables. It also defines the metatables for tables and namespaces.`));

		// docFields(t, doc, _globalFuncDocs);

		field(t, hash, "_subdocs");
		doc.mergeModuleDocs();
		pop(t);

		doc.pop(-1);

		pushString(t, "_subdocs");
		removeKey(t, hash);
	}

	pop(t);
}

// =========================================================================================================================================
// Private
// =========================================================================================================================================

private:

// =========================================================================================================================================
// Helpers

uword keysImpl(CrocThread* t, word slot)
{
	if(isTable(t, slot))
	{
		auto tab = getTable(t, slot);

		newArray(t, table.length(tab));
		word idx = 0;

		foreach(ref k, ref _; tab.data)
		{
			push(t, k);
			idxai(t, -2, idx++);
		}
	}
	else if(isNamespace(t, slot))
	{
		auto ns = getNamespace(t, slot);

		newArray(t, namespace.length(ns));
		word idx = 0;

		foreach(ref k, ref _; ns.data)
		{
			push(t, CrocValue(k));
			idxai(t, -2, idx++);
		}
	}
	else
		paramTypeError(t, slot, "table|namespace");

	return 1;
}

uword tableIterator(CrocThread* t)
{
	getUpval(t, 0);
	auto tab = getTable(t, -1);
	getUpval(t, 1);
	uword idx = cast(uword)getInt(t, -1);

	CrocValue* k = void, v = void;

	if(table.next(tab, idx, k, v))
	{
		pushInt(t, idx);
		setUpval(t, 1);
		push(t, *k);
		push(t, *v);
		return 2;
	}

	return 0;
}

uword modTableIterator(CrocThread* t)
{
	getUpval(t, 0);
	auto tab = getTable(t, -1);
	getUpval(t, 1);
	auto keys = getArray(t, -1).toArray();
	getUpval(t, 2);
	uword idx = cast(uword)getInt(t, -1) + 1;

	pop(t, 3);

	for(; idx < keys.length; idx++)
	{
		if(auto v = table.get(tab, keys[idx].value))
		{
			pushInt(t, idx);
			setUpval(t, 2);
			push(t, keys[idx].value);
			push(t, *v);
			return 2;
		}
	}

	return 0;
}

uword namespaceIterator(CrocThread* t)
{
	getUpval(t, 0);
	auto ns = getNamespace(t, -1);
	getUpval(t, 1);
	uword idx = cast(uword)getInt(t, -1);
	CrocString** k = void;
	CrocValue* v = void;

	if(ns.data.next(idx, k, v))
	{
		pushInt(t, idx);
		setUpval(t, 1);
		push(t, CrocValue(*k));
		push(t, *v);
		return 2;
	}

	return 0;
}

uword modNamespaceIterator(CrocThread* t)
{
	getUpval(t, 0);
	auto ns = getNamespace(t, -1);
	getUpval(t, 1);
	auto keys = getArray(t, -1).toArray();
	getUpval(t, 2);
	uword idx = cast(uword)getInt(t, -1) + 1;

	pop(t, 3);

	for(; idx < keys.length; idx++)
	{
		if(auto v = namespace.get(ns, keys[idx].value.mString))
		{
			pushInt(t, idx);
			setUpval(t, 2);
			push(t, keys[idx].value);
			push(t, *v);
			return 2;
		}
	}

	return 0;
}

uword opApplyImpl(CrocThread* t, word slot)
{
	// in case it was called as a method with no params
	setStackSize(t, slot + 2);

	if(isTable(t, slot))
	{
		dup(t, slot);

		if(optStringParam(t, slot + 1, "") == "modify")
		{
			keysImpl(t, slot);
			pushInt(t, -1);
			newFunction(t, &modTableIterator, "iterator", 3);
		}
		else
		{
			pushInt(t, 0);
			newFunction(t, &tableIterator, "iterator", 2);
		}
	}
	else if(isNamespace(t, slot))
	{
		dup(t, slot);

		if(optStringParam(t, slot + 1, "") == "modify")
		{
			keysImpl(t, slot);
			pushInt(t, -1);
			newFunction(t, &modNamespaceIterator, "iterator", 3);
		}
		else
		{
			pushInt(t, 0);
			newFunction(t, &namespaceIterator, "iterator", 2);
		}
	}
	else
		paramTypeError(t, slot, "table|namespace");

	return 1;
}

uword takeImpl(bool remove)(CrocThread* t)
{
	uword idx = 0;
	CrocValue* v = void;

	if(isTable(t, 1))
	{
		auto tab = getTable(t, 1);
		CrocValue* k = void;

		if(table.next(tab, idx, k, v))
		{
			push(t, *k);
			push(t, *v);

			static if(remove)
				table.idxa(t.vm.alloc, tab, *k, CrocValue.nullValue);
		}
		else
			throwStdException(t, "ValueError", "Attempting to take from an empty table");
	}
	else if(isNamespace(t, 1))
	{
		auto ns = getNamespace(t, 1);
		CrocString** s = void;

		if(ns.data.next(idx, s, v))
		{
			push(t, CrocValue(*s));
			push(t, *v);

			static if(remove)
				namespace.remove(t.vm.alloc, ns, *s);
		}
		else
			throwStdException(t, "ValueError", "Attempting to take from an empty namespace");
	}
	else
		paramTypeError(t, 1, "table|namespace");

	return 2;
}

// =========================================================================================================================================
// Implementations

const RegisterFunc[] _globalFuncs =
[
	{"dup",    &_dup,    maxParams: 1},
	{"keys",   &_keys,   maxParams: 1},
	{"values", &_values, maxParams: 1},
	{"apply",  &_apply,  maxParams: 2},
	{"map",    &_map,    maxParams: 2},
	{"reduce", &_reduce, maxParams: 3},
	{"each",   &_each,   maxParams: 2},
	{"filter", &_filter, maxParams: 2},
	{"take",   &_take,   maxParams: 1},
	{"pop",    &_pop,    maxParams: 1},
	{"clear",  &_clear,  maxParams: 1},
	{"remove", &_remove, maxParams: 2},
];

const RegisterFunc[] _tableMetamethods =
[
	{"opApply", &_tableOpApply, maxParams: 1},
];

const RegisterFunc[] _namespaceMetamethods =
[
	{"opApply", &_namespaceOpApply, maxParams: 1},
];

uword _dup(CrocThread* t)
{
	checkParam(t, 1, CrocValue.Type.Table);
	push(t, CrocValue(table.dup(t.vm.alloc, getTable(t, 1))));
	return 1;
}

uword _keys(CrocThread* t)
{
	checkAnyParam(t, 1);
	return keysImpl(t, 1);
}

uword _values(CrocThread* t)
{
	checkAnyParam(t, 1);

	if(isTable(t, 1))
	{
		auto tab = getTable(t, 1);

		newArray(t, table.length(tab));
		word idx = 0;

		foreach(ref _, ref v; tab.data)
		{
			push(t, v);
			idxai(t, -2, idx++);
		}
	}
	else if(isNamespace(t, 1))
	{
		auto ns = getNamespace(t, 1);

		newArray(t, namespace.length(ns));
		word idx = 0;

		foreach(ref _, ref v; ns.data)
		{
			push(t, v);
			idxai(t, -2, idx++);
		}
	}
	else
		paramTypeError(t, 1, "table|namespace");

	return 1;
}

uword _tableOpApply(CrocThread* t)
{
	checkParam(t, 0, CrocValue.Type.Table);
	return opApplyImpl(t, 0);
}

uword _namespaceOpApply(CrocThread* t)
{
	checkParam(t, 0, CrocValue.Type.Namespace);
	return opApplyImpl(t, 0);
}

uword _apply(CrocThread* t)
{
	checkParam(t, 1, CrocValue.Type.Table);
	checkParam(t, 2, CrocValue.Type.Function);

	auto tab = getTable(t, 1);

	foreach(ref k, ref v; tab.data)
	{
		dup(t, 2);
		pushNull(t);
		push(t, v);
		call(t, -3, 1);

		if(isNull(t, -1))
			throwStdException(t, "TypeError", "Callback function returned null");

		table.idxa(t.vm.alloc, tab, k, *getValue(t, -1));
		pop(t);
	}

	dup(t, 1);
	return 1;
}

uword _map(CrocThread* t)
{
	checkParam(t, 1, CrocValue.Type.Table);
	checkParam(t, 2, CrocValue.Type.Function);

	newTable(t);

	auto newTab = getTable(t, -1);

	foreach(ref k, ref v; getTable(t, 1).data)
	{
		dup(t, 2);
		pushNull(t);
		push(t, v);
		call(t, -3, 1);
		table.idxa(t.vm.alloc, newTab, k, *getValue(t, -1));
		pop(t);
	}

	return 1;
}

uword _reduce(CrocThread* t)
{
	auto numParams = stackSize(t) - 1;
	checkParam(t, 1, CrocValue.Type.Table);
	checkParam(t, 2, CrocValue.Type.Function);

	uword length = cast(uword)len(t, 1);

	if(length == 0)
	{
		if(numParams == 2)
			throwStdException(t, "ParamError", "Attempting to reduce an empty table without an initial value");
		else
		{
			dup(t, 3);
			return 1;
		}
	}

	bool haveInitial = numParams > 2;

	foreach(ref k, ref v; getTable(t, 1).data)
	{
		if(!haveInitial)
		{
			push(t, v);
			haveInitial = true;
		}
		else
		{
			dup(t, 2);
			pushNull(t);
			dup(t, -3);
			push(t, v);
			call(t, -4, 1);
			insertAndPop(t, -2);
		}
	}

	return 1;
}

uword _filter(CrocThread* t)
{
	checkParam(t, 1, CrocValue.Type.Table);
	checkParam(t, 2, CrocValue.Type.Function);

	newTable(t);

	auto newTab = getTable(t, -1);

	foreach(ref k, ref v; getTable(t, 1).data)
	{
		dup(t, 2);
		pushNull(t);
		push(t, k);
		push(t, v);
		call(t, -4, 1);

		if(!isBool(t, -1))
		{
			pushTypeString(t, -1);
			throwStdException(t, "TypeError", "Callback function did not return a bool, it returned '{}'", getString(t, -1));
		}

		if(getBool(t, -1))
			table.idxa(t.vm.alloc, newTab, k, v);

		pop(t);
	}

	return 1;
}

uword _each(CrocThread* t)
{
	checkParam(t, 2, CrocValue.Type.Function);

	CrocValue* k = void, v = void;

	bool guts()
	{
		auto reg = dup(t, 2);
		dup(t, 1);
		push(t, *k);
		push(t, *v);

		call(t, reg, 1);

		if(!isNull(t, -1))
		{
			if(!isBool(t, -1))
			{
				pushTypeString(t, -1);
				throwStdException(t, "TypeError", "'each' function expected to return 'bool', not '{}'", getString(t, -1));
			}

			if(getBool(t, -1) == false)
			{
				pop(t);
				return false;
			}
		}

		pop(t);
		return true;
	}

	if(isTable(t, 1))
	{
		auto tab = getTable(t, 1);
		uword idx = 0;

		while(table.next(tab, idx, k, v))
			if(!guts())
				break;
	}
	else if(isNamespace(t, 1))
	{
		auto ns = getNamespace(t, 1);
		uword idx = 0;
		CrocString** s = void;
		CrocValue key = void;
		k = &key;

		while(ns.data.next(idx, s, v))
		{
			key = *s;

			if(!guts())
				break;
		}
	}
	else
		paramTypeError(t, 1, "table|namespace");

	dup(t, 1);
	return 1;
}

uword _take(CrocThread* t)
{
	checkAnyParam(t, 1);
	return takeImpl!(false)(t);
}

uword _pop(CrocThread* t)
{
	checkAnyParam(t, 1);
	return takeImpl!(true)(t);
}

uword _clear(CrocThread* t)
{
	checkAnyParam(t, 1);

	if(isTable(t, 1))
		clearTable(t, 1);
	else if(isNamespace(t, 1))
		clearNamespace(t, 1);
	else
		paramTypeError(t, 1, "table|namespace");

	return 0;
}

uword _remove(CrocThread* t)
{
	checkAnyParam(t, 1);

	if(isTable(t, 1))
		checkAnyParam(t, 2);
	else if(isNamespace(t, 1))
		checkStringParam(t, 2);
	else
		paramTypeError(t, 1, "table|namespace");

	removeKey(t, 1);
	return 0;
}

private const char[] WeakTableCode =
`local weakref, deref = weakref, deref
local allWeakTables = {}

gc.postCallback$ function postGC()
{
	foreach(k, _; allWeakTables, "modify")
	{
		local tab = deref(k)

		if(tab is null)
			allWeakTables[k] = null
		else
			tab.normalize()
	}
}

local class WeakTableBase
{
	this()
	{
		allWeakTables[weakref(this)] = true
	}
}

class WeakKeyTable : WeakTableBase
{
	_data

	this()
	{
		:_data = {}
		super()
	}

	function opIn(k) = weakref(k) in :_data
	function opIndex(k) = :_data[weakref(k)]
	function opIndexAssign(k, v) :_data[weakref(k)] = v
	function opLength() = #:_data

	function opApply(_) // can modify with this implementation too
	{
		local keys = hash.keys(:_data)
		local idx = -1

		function iterator(_)
		{
			for(idx++; idx < #keys; idx++)
			{
				local v = :_data[keys[idx]]

				if(v !is null)
					return deref(keys[idx]), v
			}
		}

		return iterator, this, null
	}

	function keys() = [deref(k) foreach k, _; :_data if deref(k) !is null]
	function values() = hash.values(:_data)

	function normalize()
	{
		foreach(k, _; :_data, "modify")
		{
			if(deref(k) is null)
				:_data[k] = null
		}
	}
}

class WeakValTable : WeakTableBase
{
	_data

	this()
	{
		:_data = {}
		super()
	}

	function opIn(k) = k in :_data
	function opIndex(k) = deref(:_data[k])
	function opIndexAssign(k, v) :_data[k] = weakref(v)
	function opLength() = #:_data

	function opApply(_) // can modify with this implementation too
	{
		local keys = hash.keys(:_data)
		local idx = -1

		function iterator(_)
		{
			for(idx++; idx < #keys; idx++)
			{
				local v = deref(:_data[keys[idx]])

				if(v !is null)
					return keys[idx], v
			}
		}

		return iterator, this, null
	}

	function keys() = hash.keys(:_data)
	function values() = [deref(v) foreach _, v; :_data if deref(v) !is null]

	function normalize()
	{
		foreach(k, v; :_data, "modify")
		{
			if(deref(v) is null)
				:_data[k] = null
		}
	}
}

class WeakKeyValTable : WeakTableBase
{
	_data

	this()
	{
		:_data = {}
		super()
	}

	function opIn(k) = weakref(k) in :_data
	function opIndex(k) = deref(:_data[weakref(k)])
	function opIndexAssign(k, v) :_data[weakref(k)] = weakref(v)
	function opLength() = #:_data

	function opApply(_) // can modify with this implementation too
	{
		local keys = hash.keys(:_data)
		local idx = -1

		function iterator(_)
		{
			for(idx++; idx < #keys; idx++)
			{
				local v = deref(:_data[keys[idx]])

				if(v !is null)
					return deref(keys[idx]), v
			}
		}

		return iterator, this, null
	}

	function keys() = [deref(k) foreach k, _; :_data if deref(k) !is null]
	function values() = [deref(v) foreach _, v; :_data if deref(v) !is null]

	function normalize()
	{
		foreach(k, v; :_data, "modify")
			if(deref(k) is null || deref(v) is null)
				:_data[k] = null
	}
}`;