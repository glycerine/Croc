/******************************************************************************
License:
Copyright (c) 2007 Jarrett Billingsley

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

module minid.arraylib;

import tango.core.Array;
import tango.core.Tuple;
import tango.math.Math;

import minid.array;
import minid.ex;
import minid.interpreter;
import minid.types;

struct ArrayLib
{
static:
	public void init(MDThread* t)
	{
		pushGlobal(t, "modules");
		field(t, -1, "customLoaders");

		newFunction(t, function uword(MDThread* t, uword numParams)
		{
			newFunction(t, &array_new, "new");
			newGlobal(t, "new");
			newFunction(t, &range, "range");
			newGlobal(t, "range");

			newNamespace(t, "array");
				newFunction(t, &sort, "sort"); fielda(t, -2, "sort");
				newFunction(t, &reverse, "reverse"); fielda(t, -2, "reverse");
				newFunction(t, &array_dup, "dup"); fielda(t, -2, "dup");

					newFunction(t, &iterator, "iterator");
					newFunction(t, &iteratorReverse, "iteratorReverse");
				newFunction(t, &opApply, "opApply", 2);
				fielda(t, -2, "opApply");

				newFunction(t, &expand, "expand"); fielda(t, -2, "expand");
				newFunction(t, &toString, "toString"); fielda(t, -2, "toString");
				newFunction(t, &apply, "apply"); fielda(t, -2, "apply");
				newFunction(t, &map, "map"); fielda(t, -2, "map");
				newFunction(t, &reduce, "reduce"); fielda(t, -2, "reduce");
				newFunction(t, &each, "each"); fielda(t, -2, "each");
				newFunction(t, &filter, "filter"); fielda(t, -2, "filter");
				newFunction(t, &find, "find"); fielda(t, -2, "find");
				newFunction(t, &findIf, "findIf"); fielda(t, -2, "findIf");
				newFunction(t, &bsearch, "bsearch"); fielda(t, -2, "bsearch");
				newFunction(t, &array_pop, "pop"); fielda(t, -2, "pop");
				newFunction(t, &set, "set"); fielda(t, -2, "set");
				newFunction(t, &min, "min"); fielda(t, -2, "min");
				newFunction(t, &max, "max"); fielda(t, -2, "max");
				newFunction(t, &extreme, "extreme"); fielda(t, -2, "extreme");
				newFunction(t, &any, "any"); fielda(t, -2, "any");
				newFunction(t, &all, "all"); fielda(t, -2, "all");
				newFunction(t, &fill, "fill"); fielda(t, -2, "fill");
				newFunction(t, &append, "append"); fielda(t, -2, "append");
// 				newFunction(t, &flatten, "flatten"); fielda(t, -2, "flatten");
// 				newFunction(t, &makeHeap, "makeHeap"); fielda(t, -2, "makeHeap");
// 				newFunction(t, &pushHeap, "pushHeap"); fielda(t, -2, "pushHeap");
// 				newFunction(t, &popHeap, "popHeap"); fielda(t, -2, "popHeap");
// 				newFunction(t, &sortHeap, "sortHeap"); fielda(t, -2, "sortHeap");
// 				newFunction(t, &count, "count"); fielda(t, -2, "count");
// 				newFunction(t, &countIf, "countIf"); fielda(t, -2, "countIf");
			setTypeMT(t, MDValue.Type.Array);

			return 0;
		}, "array");

		fielda(t, -2, "array");

		importModule(t, "array");
	}

	uword array_new(MDThread* t, uword numParams)
	{
		auto length = checkIntParam(t, 1);

		if(length < 0)
			throwException(t, "Invalid length: {}", length);

		newArray(t, length);

		if(numParams > 1)
		{
			dup(t, 2);
			fillArray(t, -2);
		}

		return 1;
	}

	uword range(MDThread* t, uword numParams)
	{
		auto v1 = checkIntParam(t, 1);
		mdint v2;
		mdint step = 1;

		if(numParams == 1)
		{
			v2 = v1;
			v1 = 0;
		}
		else if(numParams == 2)
			v2 = checkIntParam(t, 2);
		else
		{
			v2 = checkIntParam(t, 2);
			step = checkIntParam(t, 3);
		}

		if(step <= 0)
			throwException(t, "Step may not be negative or 0");

		mdint range = abs(v2 - v1);
		mdint size = range / step;

		if((range % step) != 0)
			size++;

		newArray(t, size);
		auto a = getArray(t, -1);

		auto val = v1;

		if(v2 < v1)
		{
			for(mdint i = 0; val > v2; i++, val -= step)
				a.slice[i] = val;
		}
		else
		{
			for(mdint i = 0; val < v2; i++, val += step)
				a.slice[i] = val;
		}

		return 1;
	}

	uword sort(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);

		bool delegate(MDValue, MDValue) pred;

		if(numParams > 0)
		{
			if(isString(t, 1) && getString(t, 1) == "reverse"d)
			{
				pred = (MDValue v1, MDValue v2)
				{
					push(t, v1);
					push(t, v2);
					auto v = cmp(t, -2, -1);
					pop(t, 2);
					return v > 0;
				};
			}
			else
			{
				checkParam(t, 1, MDValue.Type.Function);
				dup(t);

				pred = (MDValue v1, MDValue v2)
				{
					auto reg = dup(t);
					pushNull(t);
					push(t, v1);
					push(t, v2);
					rawCall(t, reg, 1);
					
					if(!isInt(t, -1))
					{
						pushTypeString(t, -1);
						throwException(t, "comparison function expected to return 'int', not '{}'", getString(t, -1));
					}
					
					auto v = getInt(t, -1);
					pop(t);
					return v < 0;
				};
			}
		}
		else
		{
			pred = (MDValue v1, MDValue v2)
			{
				push(t, v1);
				push(t, v2);
				auto v = cmp(t, -2, -1);
				pop(t, 2);
				return v < 0;
			};
		}
		
		.sort(getArray(t, 0).slice, pred);
		dup(t, 0);
		return 1;
	}

	uword reverse(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);
		getArray(t, 0).slice.reverse;
		dup(t, 0);
		return 1;
	}

	uword array_dup(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);
		newArray(t, len(t, 0));
		getArray(t, -1).slice[] = getArray(t, 0).slice[];
		return 1;
	}

	uword iterator(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);
		auto index = checkIntParam(t, 1) + 1;

		if(index >= len(t, 0))
			return 0;

		pushInt(t, index);
		dup(t);
		idx(t, 0);

		return 2;
	}

	uword iteratorReverse(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);
		auto index = checkIntParam(t, 1) - 1;

		if(index < 0)
			return 0;

		pushInt(t, index);
		dup(t);
		idx(t, 0);

		return 2;
	}

	uword opApply(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);

		if(isString(t, 1) && getString(t, 1) == "reverse")
		{
			getUpval(t, 1);
			dup(t, 0);
			pushInt(t, len(t, 0));
		}
		else
		{
			getUpval(t, 0);
			dup(t, 0);
			pushInt(t, -1);
		}

		return 3;
	}

	uword expand(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);
		auto a = getArray(t, 0);

		foreach(ref val; a.slice)
			push(t, val);

		return a.slice.length;
	}

	uword toString(MDThread* t, uword numParams)
	{
		auto buf = StrBuffer(t);
		buf.addChar('[');
	
		auto length = len(t, 0);
	
		for(uword i = 0; i < length; i++)
		{
			pushInt(t, i);
			idx(t, 0);
	
			if(isString(t, -1))
			{
				// this is GC-safe since the string is stored in the array
				auto s = getString(t, -1);
				pop(t);
				buf.addChar('"');
				buf.addString(s);
				buf.addChar('"');
			}
			else if(isChar(t, -1))
			{
				auto c = getChar(t, -1);
				pop(t);
				buf.addChar('\'');
				buf.addChar(c);
				buf.addChar('\'');
			}
			else
			{
				pushToString(t, -1, true);
				insert(t, -2);
				pop(t);
				buf.addTop();
			}
	
			if(i < length - 1)
				buf.addString(", ");
		}
	
		buf.addChar(']');
		buf.finish();
	
		return 1;
	}

	uword apply(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);
		checkParam(t, 1, MDValue.Type.Function);
		
		auto data = getArray(t, 0).slice;

		foreach(i, ref v; data)
		{
			auto reg = dup(t, 1);
			dup(t, 0);
			push(t, v);
			rawCall(t, reg, 1);
			idxai(t, -2, i, true);
			pop(t);
		}

		dup(t, 0);
		return 1;
	}

	uword map(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);
		checkParam(t, 1, MDValue.Type.Function);
		newArray(t, len(t, 0));
		auto data = getArray(t, -1).slice;

		foreach(i, ref v; getArray(t, 0).slice)
		{
			auto reg = dup(t, 1);
			dup(t, 0);
			push(t, v);
			rawCall(t, reg, 1);
			idxai(t, -2, i, true);
			pop(t);
		}

		return 1;
	}

	uword reduce(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);
		checkParam(t, 1, MDValue.Type.Function);
		uword length = len(t, 0);

		if(length == 0)
		{
			pushNull(t);
			return 1;
		}

		idxi(t, 0, 0, true);

		for(uword i = 1; i < length; i++)
		{
			dup(t, 1);
			insert(t, -2);
			pushNull(t);
			insert(t, -2);
			idxi(t, 0, i, true);
			rawCall(t, -4, 1);
		}

		return 1;
	}

	uword each(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);
		checkParam(t, 1, MDValue.Type.Function);

		foreach(i, ref v; getArray(t, 0).slice)
		{
			dup(t, 1);
			dup(t, 0);
			pushInt(t, i);
			push(t, v);
			rawCall(t, -4, 1);
			
			if(isBool(t, -1) && getBool(t, -1) == false)
				break;
		}
		
		dup(t, 0);
		return 1;
	}

	uword filter(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);
		checkParam(t, 1, MDValue.Type.Function);

		auto newLen = len(t, 0) / 2;
		auto retArray = newArray(t, newLen);
		uword retIdx = 0;

		foreach(i, ref v; getArray(t, 0).slice)
		{
			dup(t, 1);
			dup(t, 0);
			pushInt(t, i);
			push(t, v);
			rawCall(t, -4, 1);
			
			if(!isBool(t, -1))
			{
				pushTypeString(t, -1);
				throwException(t, "filter function expected to return 'bool', not '{}'", getString(t, -1));
			}

			if(getBool(t, -1))
			{
				if(retIdx >= newLen)
				{
					pushInt(t, newLen + 10);
					lena(t, retArray);
				}

				push(t, v);
				idxai(t, retArray, retIdx, true);
				retIdx++;
			}
			
			pop(t);
		}
  
		pushInt(t, retIdx);
		lena(t, retArray);
		dup(t, retArray);
		return 1;
	}

	uword find(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);
		checkAnyParam(t, 1);

		foreach(i, ref v; getArray(t, 0).slice)
		{
			push(t, v);

			if(type(t, 1) == v.type && cmp(t, 1, -1) == 0)
			{
				pushInt(t, i);
				return 1;
			}
		}

		pushLen(t, 0);
		return 1;
	}

	uword findIf(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);
		checkParam(t, 1, MDValue.Type.Function);
		
		foreach(i, ref v; getArray(t, 0).slice)
		{
			auto reg = dup(t, 1);
			pushNull(t);
			push(t, v);
			rawCall(t, reg, 1);
			
			if(!isBool(t, -1))
			{
				pushTypeString(t, -1);
				throwException(t, "find function expected to return 'bool', not '{}'", getString(t, -1));
			}
			
			if(getBool(t, -1))
			{
				pushInt(t, i);
				return 1;
			}

			pop(t);
		}
		
		pushLen(t, 0);
		return 1;
	}

	uword bsearch(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);
		checkAnyParam(t, 1);

		uword lo = 0;
		uword hi = len(t, 0) - 1;
		uword mid = (lo + hi) >> 1;

		while((hi - lo) > 8)
		{
			idxi(t, 0, mid, true);
			auto cmp = cmp(t, 1, -1);
			pop(t);

			if(cmp == 0)
			{
				pushInt(t, mid);
				return 1;
			}
			else if(cmp < 0)
				hi = mid;
			else
				lo = mid;

			mid = (lo + hi) >> 1;
		}

		for(auto i = lo; i <= hi; i++)
		{
			idxi(t, 0, i, true);

			if(cmp(t, 1, -1) == 0)
			{
				pushInt(t, i);
				return 1;
			}
			
			pop(t);
		}

		pushLen(t, 0);
		return 1;
	}

	uword array_pop(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);
		word index = -1;
		auto data = getArray(t, 0).slice;

		if(data.length == 0)
			throwException(t, "Array is empty");

		if(numParams > 0)
			index = checkIntParam(t, 1);

		if(index < 0)
			index += data.length;

		if(index < 0 || index >= data.length)
			throwException(t, "Invalid array index: {}", index);

		idxi(t, 0, index, true);

		for(uword i = index; i < data.length - 1; i++)
			data[i] = data[i + 1];
			
		getArray(t, 0).slice.length = data.length - 1;
		return 1;
	}

	uword set(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);
		auto a = getArray(t, 0);

		array.resize(t.vm.alloc, a, numParams);

		for(uword i = 0; i < numParams; i++)
			a.slice[i] = *getValue(t, i + 1);

		dup(t, 0);
		return 1;
	}

	uword minMaxImpl(MDThread* t, uword numParams, bool max)
	{
		checkParam(t, 0, MDValue.Type.Array);
		auto data = getArray(t, 0).slice;

		if(data.length == 0)
			throwException(t, "Array is empty");

		auto extreme = data[0];

		if(numParams > 0)
		{
			for(uword i = 1; i < data.length; i++)
			{
				dup(t, 1);
				pushNull(t);
				idxi(t, 0, i, true);
				push(t, extreme);
				rawCall(t, -4, 1);
				
				if(!isBool(t, -1))
				{
					pushTypeString(t, -1);
					throwException(t, "extrema function should return 'bool', not '{}'", getString(t, -1));
				}
				
				if(getBool(t, -1))
					extreme = data[i];
					
				pop(t);
			}
			
			push(t, extreme);
		}
		else
		{
			idxi(t, 0, 0, true);

			if(max)
			{
				for(uword i = 1; i < data.length; i++)
				{
					idxi(t, 0, i, true);

					if(cmp(t, -1, -2) > 0)
						insert(t, -2);

					pop(t);
				}
			}
			else
			{
				for(uword i = 1; i < data.length; i++)
				{
					idxi(t, 0, i, true);

					if(cmp(t, -1, -2) < 0)
						insert(t, -2);

					pop(t);
				}
			}
		}

		return 1;
	}

	uword min(MDThread* t, uword numParams)
	{
		return minMaxImpl(t, 0, false);
	}

	uword max(MDThread* t, uword numParams)
	{
		return minMaxImpl(t, 0, true);
	}

	uword extreme(MDThread* t, uword numParams)
	{
		checkParam(t, 1, MDValue.Type.Function);
		return minMaxImpl(t, numParams, false);
	}

	uword all(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);

		if(numParams > 0)
		{
			checkParam(t, 1, MDValue.Type.Function);
			
			foreach(ref v; getArray(t, 0).slice)
			{
				dup(t, 1);
				pushNull(t);
				push(t, v);
				rawCall(t, -3, 1);

				if(!isTrue(t, -1))
				{
					pushBool(t, false);
					return 1;
				}

				pop(t);
			}
		}
		else
		{
			foreach(ref v; getArray(t, 0).slice)
			{
				if(v.isFalse())
				{
					pushBool(t, false);
					return 1;
				}
			}
		}

		pushBool(t, true);
		return 1;
	}
	
	uword any(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);

		if(numParams > 0)
		{
			checkParam(t, 1, MDValue.Type.Function);
			
			foreach(ref v; getArray(t, 0).slice)
			{
				dup(t, 1);
				pushNull(t);
				push(t, v);
				rawCall(t, -3, 1);

				if(isTrue(t, -1))
				{
					pushBool(t, true);
					return 1;
				}

				pop(t);
			}
		}
		else
		{
			foreach(ref v; getArray(t, 0).slice)
			{
				if(!v.isFalse())
				{
					pushBool(t, true);
					return 1;
				}
			}
		}

		pushBool(t, false);
		return 1;
	}

	uword fill(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);
		checkAnyParam(t, 1);
		dup(t, 1);
		fillArray(t, 0);
		return 0;
	}

	uword append(MDThread* t, uword numParams)
	{
		checkParam(t, 0, MDValue.Type.Array);

		for(uint i = 0; i < numParams; i++)
			self ~= s.getParam(i);

		return 0;
	}
/+
	uword flatten(MDThread* t, uword numParams)
	{
		bool[MDArray] flattening;
		auto ret = new MDArray(0);

		void flatten(MDArray a)
		{
			if(a in flattening)
				s.throwRuntimeException("Attempting to flatten a self-referencing array");

			flattening[a] = true;
			
			foreach(ref val; a)
			{
				if(val.isArray)
					flatten(val.as!(MDArray));
				else
					ret ~= val;
			}

			flattening.remove(a);
		}
		
		flatten(s.getContext!(MDArray)());
		s.push(ret);
		return 1;
	}
	
	uword makeHeap(MDThread* t, uword numParams)
	{
		auto self = s.getContext!(MDArray)();
		.makeHeap(self.mData, (ref MDValue a, ref MDValue b) { return s.cmp(a, b) < 0; });
		s.push(self);
		return 1;
	}

	uword pushHeap(MDThread* t, uword numParams)
	{
		auto self = s.getContext!(MDArray)();
		auto val = s.getParam(0u);
		.pushHeap(self.mData, val, (ref MDValue a, ref MDValue b) { return s.cmp(a, b) < 0; });
		s.push(self);
		return 1;
	}

	uword popHeap(MDThread* t, uword numParams)
	{
		auto self = s.getContext!(MDArray)();

		if(self.length == 0)
			s.throwRuntimeException("Array is empty");

		s.push(self[0]);
		.popHeap(self.mData, (ref MDValue a, ref MDValue b) { return s.cmp(a, b) < 0; });
		return 1;
	}

	uword sortHeap(MDThread* t, uword numParams)
	{
		auto self = s.getContext!(MDArray)();
		.sortHeap(self.mData, (ref MDValue a, ref MDValue b) { return s.cmp(a, b) < 0; });
		s.push(self);
		return 1;
	}
	
	uword count(MDThread* t, uword numParams)
	{
		auto self = s.getContext!(MDArray)();
		auto val = s.getParam(0u);

		bool delegate(MDValue, MDValue) pred;

		if(numParams > 1)
		{
			auto cl = s.getParam!(MDClosure)(1);
			pred = (MDValue a, MDValue b)
			{
				s.call(cl, 1, a, b);
				return s.pop!(bool)();
			};
		}
		else
			pred = (MDValue a, MDValue b) { return s.cmp(a, b) == 0; };

		s.push(.count(self.mData, val, pred));
		return 1;
	}

	uword countIf(MDThread* t, uword numParams)
	{
		auto self = s.getContext!(MDArray)();
		auto cl = s.getParam!(MDClosure)(0);

		s.push(.countIf(self.mData, (MDValue a)
		{
			s.call(cl, 1, a);
			return s.pop!(bool)();
		}));
		
		return 1;
	}
+/
}