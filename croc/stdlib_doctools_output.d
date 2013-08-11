/******************************************************************************
This module contains the 'doctools.output' module of the standard library.

License:
Copyright (c) 2013 Jarrett Billingsley

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

module croc.stdlib_doctools_output;

import croc.ex;
import croc.types;

// ================================================================================================================================================
// Public
// ================================================================================================================================================

public:

void initDoctoolsOutputLib(CrocThread* t)
{
	importModuleFromStringNoNS(t, "doctools.output", Code, __FILE__);
}

// ================================================================================================================================================
// Private
// ================================================================================================================================================

private:

const char[] Code =
`/**
This sub-module of the docs lib contains functionality for outputting docs in a human-readable form, as well as a small
framework which makes it easier to output docs to new formats.
*/
module doctools.output

import docs: DocVisitor, docsOf

import exceptions:
	StateException,
	ValueException,
	NotImplementedException,
	RangeException

/**
This class defines a default behavior for mapping documentation links (made with the \tt{\\link} command) to the things
they refer to. It uses a \link{LinkTranslator} which you define in order to turn the mapped links into outputtable link
text.

For URIs (such as with \tt{\\link{http://www.example.com}}), no attempt is made to ensure the correctness or well-
formedness of the link.

All other links are considered links to other documentable items. The way it does this is by taking a snapshot of the
global namespace and all currenly-loaded modules. This means that any modules imported after instantiating this class
are unknown to that instance, and links into them will not resolve. Most of the time this won't be a problem since
you'll likely have imported them beforehand so that you can output their docs!

Once a link has been processed, it is then passed to one of the methods that its \link{LinkTranslator} instance defines.
The results of those methods are returned from \link{resolveLink}.
*/
class LinkResolver
{
	// struct ItemDesc { string name, fqn; DocTable docTable; ItemDesc[string] children; }
	__modules // ItemDesc[string]
	__globals // ItemDesc[string]
	__module = null // ItemDesc
	__item = null // ItemDesc
	__trans

	/**
	Constructs a resolver with the given link translator.

	The constructor takes a snapshot of the global namespace and all loaded modules, so if there are any modules that
	you want links to resolve to, you must have imported them before instantiating this class.

	When you create a link resolver, any links will be evaluated within the global scope. You can change the scope in
	which links are resolved by using the \tt{enter/leaveItem/Module} methods.

	\param[trans] is the link translator object whose methods will be called by \link{resolveLink}.
	*/
	this(trans: LinkTranslator)
	{
		:__trans = trans

		// Setup modules
		:__modules = {}

		foreach(name, m; modules.loaded)
		{
			if(local dt = docsOf(m))
				:__modules[name] = :__makeMapRec(dt)
		}

		// Setup globals
		if(local dt = docsOf(_G))
			:__globals = :__makeMapRec(dt).children
		else
			:__globals = {}

		// Might be some globals added by user code that aren't in docsOf(_G).children
		foreach(name, val; _G)
		{
			if(name !is "_G" && name !in :__globals && name !in modules.loaded)
			{
				if(local dt = docsOf(val))
					:__globals[name] = :__makeMapRec(dt)
			}
		}
	}

	/**
	Returns a string saying what scope this resolver is currently operating in.

	\returns one of \tt{"global"} (the default), \tt{"module"} (when you have entered a module), or \tt{"item"} (when
	you have entered an item within a module).
	*/
	function currentScope()
	{
		if(:__item is null)
		{
			if(:__module is null)
				return "global"
			else
				return "module"
		}
		else
			return "item"
	}

	/**
	Switches from global scope to module scope, so that links will be resolved in the context of the given module.

	\throws[exceptions.StateException] if the current scope is not global scope.
	\throws[exceptions.ValueException] if there is no module of the given name.
	*/
	function enterModule(name: string)
	{
		if(:__item !is null || :__module !is null)
			throw StateException("Attempting to enter a module from {} scope".format(:currentScope()))

		if(local m = :__modules[name])
			:__module = m
		else
			throw ValueException("No module named '{}' (did you import it after creating this resolver?)".format(name))
	}

	/**
	Switches from module scope to item scope, so that links will be resolved in the context of the given item (class or
	namespace declaration).

	\throws[exceptions.StateException] if the current scope is not module scope.
	\throws[exceptions.ValueException] if there is no item of the given name in the current module.
	*/
	function enterItem(name: string)
	{
		if(:__item !is null || :__module is null)
			throw StateException("Attempting to enter an item from {} scope".format(:currentScope()))

		if(local i = :__module.children[name])
			:__item = i
		else
			throw ValueException("No item named '{}' in {}".format(name, __module.name))
	}

	/**
	Switches from the current scope to the owning scope.

	\throws[exceptions.StateException] if the current scope is global scope.
	*/
	function leave()
	{
		if(:__item !is null)
			:__item = null
		else if(:__module !is null)
			:__module = null
		else
			throw StateException("Attempting to leave at global scope")
	}

	/**
	Given a raw, unprocessed link, turns it into a link string suitable for output.

	It does this by analyzing the link, determining whether it's a URI or a code link, ensuring it's a valid link if
	it's a code link, and then calling one of \link{LinkTranslator}'s methods as appropriate to turn the raw link into
	something suitable for output. It does not process the outputs of those methods; whatever they return is what this
	method returns.
	*/
	function resolveLink(link: string)
	{
		if("/" in link)
		{
			// URI; no further processing necessary. If someone writes something like "www.example.com" it's ambiguous
			// and it's their fault when it doesn't resolve :P
			return :__trans.translateURI(link)
		}
		else
		{
			// Okay, so: names aren't really all that specific. Name lookup works more or less like in Croc itself, with
			// one exception: names can refer to other members within classes and namespaces.
			// In any case, a dotted name can resolve to one of two locations (qualified name within current module, or
			// fully-qualified name), and a name without dots can resolve to one of FOUR locations (those two, plus
			// global, or another name within the current class/NS).
			// Also, names shadow one another. If you write a link to \tt{toString} within a class that defines it, the
			// link will resolve to this class's method, rather than the function declared at global scope.

			local isDotted = "." in link

			if(!isDotted && :__inItem(link)) // not dotted, could be item name
				return :__trans.translateLink(:__module.name, :__item.name ~ "." ~ link)
			else if(:__inCurModule(link)) // maybe it's something in the current module
				return :__trans.translateLink(:__module.name, link)
			else
			{
				// tryyyy all the modules!
				local isFQN, modName, itemName = :__inModules(link)

				if(isFQN)
					return :__trans.translateLink(modName, itemName)

				// um. um. global?!
				// it might be a member of a global class or something, or just a plain old global
				if(:__inGlobalItem(link) || :__inGlobals(link))
					return :__trans.translateLink("", link)
			}
		}

		// noooooo nothing matched :(
		return :__trans.invalidLink(link)
	}

	// =================================================================================================================
	// Private

	function __inItem(link: string) =
		:__item !is null && link in :__item.children

	function __inCurModule(link: string) =
		:__module !is null && :__inModule(:__module, link)

	function __inModules(link: string)
	{
		if(link in :__modules)
			return true, link, ""

		// What we're doing here is trying every possible prefix as a module name. So for the name "a.b.c.d" we try
		// "a.b.c", "a.b", and "a" as module names, and see if the rest of the string is an item inside it.
		local lastDot

		for(local dot = link.rfind("."); dot != #link; dot = link.rfind(".", lastDot - 1))
		{
			lastDot = dot
			local modName = link[0 .. dot]

			if(local m = :__modules[modName])
			{
				// There can only be ONE match to the module name. Once you find it, there can't be any other modules
				// with names that are a prefix, since that's enforced by the module system. So if the item doesn't
				// exist in this module, it doesn't exist at all

				local itemName = link[dot + 1 ..]

				if(:__inModule(m, itemName))
					return true, modName, itemName
				else
					return false
			}
		}

		return false
	}

	function __inModule(mod: table, item: string)
	{
		local t = mod

		foreach(piece; item.split("."))
		{
			if(t.children is null)
				return false

			t = t.children[piece]

			if(t is null)
				return false
		}

		return true
	}

	function __inGlobalItem(link: string)
	{
		local dot = link.find(".")

		if(dot is #link)
			return false

		local n = link[0 .. dot]
		local f = link[dot + 1 ..]
		local i = :__globals[n]

		return i !is null && i.children && f in i.children
	}

	function __inGlobals(link: string) =
		link in :__globals

	function __makeMapRec(dt: table)
	{
		local ret = { name = dt.name }

		if(dt.children)
		{
			ret.children = {}

			foreach(child; dt.children)
			{
				local c = :__makeMapRec(child)
				ret.children[child.name] = c

				if(local dit = child.dittos)
				{
					foreach(d; dit)
						ret.children[d.name] = c
				}
			}
		}

		return ret
	}
}

/**
A link resolver that does absolutely nothing and resolves all links to whatever was passed in.

It never throws any errors or does anything. It's useful for when you don't want any link resolution behavior at all.
*/
class NullLinkResolver : LinkResolver
{
	this(_) {}
	function currentScope() = "global" /// Always returns "global".
	function enterModule(name: string) {}
	function enterItem(name: string) {}
	function leave() {}
	function resolveLink(link: string) = link /// Always returns \tt{link} unmodified.
}

/**
This class defines an interface for mapping links from their raw form to their outputtable form. Since the structure of
the output docs is unknown to the library, how this translation happens is left up to the user.

You create a subclass of this class, override the appropriate methods, and then pass an instance of it to the
constructor of \link{LinkResolver}.
*/
class LinkTranslator
{
	/**
	Given a module name and a sub-item name (which may or may not be dotted, since it might be something like a class
	field), translates them into a suitable link string.

	This, and \link{translateURI}, are the only methods you have to override in a subclass.

	Both the \tt{mod} and \tt{item} parameters may either be the empty string or a non-empty string, and the meanings of
	those combinations are as follows:

	\blist
		\li \tt{mod == "", item == ""}: the link points to the global namespace (i.e. the Croc baselib).
		\li \tt{mod == "", item != ""}: the link points to the global named \tt{item}.
		\li \tt{mod != "", item == ""}: the link points to the module named \tt{mod}.
		\li \tt{mod != "", item != ""}: the link points to the item named \tt{item} in the module named \tt{mod}.
	\endlist

	\param[mod] is the name of the module, as explained above.
	\param[item] is the name of the item, as explained above.
	\returns the link translated into a form that makes sense to whatever output format you're using.
	*/
	function translateLink(mod: string, item: string)
		throw NotImplementedException()

	/**
	Given a URI, translates it into a suitable link string.

	This, and \link{translateLink}, are the only methods you have to override in a subclass.

	\param[uri] is the URI to translate.

	\returns the link translated into a form that makes sense to whatever output format you're using.
	*/
	function translateURI(uri: string)
		throw NotImplementedException()

	/**
	This method is called when the given link fails to resolve.

	\link{LinkResolver.resolveLink} will call this method if it fails to find a valid target for the given link. This
	method can return a string which will then be returned by \link{LinkResolver.resolveLink}. By default, this method
	throws a \link{exceptions.ValueException} saying which link failed, but you can override it so that it does
	something else (such as returning a dummy link and logging the error to stderr).

	\param[link] is the link that failed to resolve.
	\returns a replacement string, optionally.
	\throws[exceptions.ValueException] by default as explained above.
	*/
	function invalidLink(link: string)
		throw ValueException("No target found for link '{}'".format(link))
}

/// Checks if a given name is a valid name for a doc section.
function validSectionName(name: string) =
	!(#name == 0 || (#name == 1 && name[0] == '_') || (name[0] != '_' && name !in stdSections))

/// Checks if a paragraph list is empty (has no actual text).
function isPlistEmpty(plist: array) =
	#plist == 1 && #plist[0] == 1 && plist[0][0] is ""

/// Checks if a given doctable's \tt{docs} member is an empty plist.
function isDocsEmpty(doctable: table) =
	isPlistEmpty(doctable.docs)

local UpperRomanNumTable =
[
	["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"],
	["", "X", "XX", "XXX", "XL", "L", "LX", "LXX", "LXXX", "XC"],
]

local LowerRomanNumTable =
[
	["", "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix"],
	["", "x", "xx", "xxx", "xl", "l", "lx", "lxx", "lxxx", "xc"],
]

/**
Converts a positive integer to a roman numeral. Only works for numbers in the range 1 to 99; numbers larger than this
are wrapped around (100 becomes 1, 101 becomes 2, etc.).

\param[n] is the number.
\param[lower] is whether or not the result should be lowercase.
\returns a string.
\throws[exceptions.RangeException] if \tt{n <= 0}.
*/
function numToRoman(n: int, lower: bool)
{
	if(n <= 0)
		throw RangeException("Invalid number")

	n = ((n - 1) % 99) + 1
	local table = lower ? LowerRomanNumTable : UpperRomanNumTable

	if(n < 10)
		return table[0][n]
	else
		return table[1][n / 10] ~ table[0][n % 10]
}

local UpperLetterTable =
	['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z']

local LowerLetterTable =
	['a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z']

/**
Converts a positive integer to a letter of the alphabet. Only works for numbers in the range 1 to 26; numbers larger
than this are wrapped around.

\param[n] is the number.
\param[lower] is whether or not the result should be lowercase.
\returns a string.
\throws[exceptions.RangeException] if \tt{n <= 0}.
*/
function numToLetter(n: int, lower: bool)
{
	if(n <= 0)
		throw RangeException("Invalid number")

	return (lower ? LowerLetterTable : UpperLetterTable)[(n - 1) % 26]
}

/**
Given a doctable, returns a string which would make a suitable documentation header for that item.

If the \tt{full} parameter is true (the default), you will get headers that look like this:

\blist
	\li For modules, it will be of the form \tt{"module name"}.
	\li For functions, it will be of the form \tt{"functionName(parameters)"}, where \tt{parameters} will be a listing
		of all parameter names, their types (if not trivial), and any default values. Some examples:
	\blist
		\li \tt{"this()"} (for any function named \tt{"constructor"})
		\li \tt{"someFunction()"}
		\li \tt{"anotherFunction(x: int)"}
		\li \tt{"staticMethod(this: class, param: string = 'hi')"}
		\li \tt{"variadicFunc(fmt: string, vararg)"}
	\endlist
	\li For classes and namespaces, it will look like the first line of the declaration, like \tt{"class Foo : Bar"} or
		\tt{"namespace N"}.
	\li For fields, it will be the name of the field, followed by the initializer if it has one. Examples: \tt{"__x"},
		\tt{"numThings = 0"}.
	\li For variables, it will look just like the variable declaration, like \tt{"local a = 4"} or \tt{"global y"}.
\endlist

If the \tt{full} parameter is false, then all you will get back is the name of the item as follows.

Regardless of the \tt{full} parameter, if the \tt{parentFQN} parameter is a non-empty string, the name of the item will
be prepended with \tt{parentFQN} followed by a period; that is, if \tt{parentFQN} is \tt{"some.mod"} and
\tt{doctable.name} is \tt{"foo"}, then this will result in the name \tt{"some.mod.foo"} in the result. If \tt{parentFQN}
is the empty string, then the name in the result will simply be \tt{"foo"}.

\param[doctable] is the item to get a header of.
\param[parentFQN] is the fully-qualified name of \tt{doctable}'s owner, or the empty string if you don't want the
	owner's name to be prepended to the item name.
\param[full] controls whether the header is full or just the name, as explained above.

\returns a string containing the header representation.

\throws[exceptions.ValueException] if \tt{doctable}'s kind is \tt{"parameter"} or some invalid kind.
*/
function toHeader(doctable: table, parentFQN: string, full: bool = true)
{
	local ret = string.StringBuffer()

	switch(doctable.kind)
	{
		case "module":
			if(full)
				ret.append("module ")

			ret.append(doctable.name)
			break

		case "function":
			if(parentFQN !is "")
				ret.append(parentFQN, ".")

			ret.append(doctable.name == "constructor" ? "this" : doctable.name)

			if(!full)
				break

			ret.append("(")

			foreach(i, p; doctable.params)
			{
				if(i > 0)
					ret.append(", ")

				ret.append(p.name)

				if(p.type != "any" && p.type != "vararg")
					ret.append(": ", p.type)

				if(p.value)
					ret.append(" = ", p.value)
			}

			ret.append(")")
			break

		case "class", "namespace":
			if(full)
				ret.append(doctable.kind, " ")

			if(parentFQN !is "")
				ret.append(parentFQN, ".")

			ret.append(doctable.name)

			if(!full)
				break

			if(doctable.base)
				ret.append(" : ", doctable.base)
			break

		case "field":
			if(parentFQN !is "")
				ret.append(parentFQN, ".")

			ret.append(doctable.name)

			if(!full)
				break

			if(doctable.value)
				ret.append(" = ", doctable.value)
			break

		case "variable":
			if(full)
				ret.append(doctable.protection, " ")

			if(parentFQN !is "")
				ret.append(parentFQN, ".")

			ret.append(doctable.name)

			if(!full)
				break

			if(doctable.value)
				ret.append(" = ", doctable.value)
			break

		case "parameter":
			throw ValueException("Cannot call toHeader on a parameter doctable")

		default:
			throw ValueException("Malformed documentation for {}".format(doctable.name))
	}

	return ret.toString()
}

/**
Defines the order of the standard sections that the \link{SectionOrder} class uses by default.

The order is:

\nlist
	\li \tt{deprecated}
	\li \tt{docs}
	\li \tt{examples}
	\li \tt{params}
	\li \tt{returns}
	\li \tt{throws}
	\li \tt{bugs}
	\li \tt{notes}
	\li \tt{todo}
	\li \tt{warnings}
	\li \tt{see}
	\li \tt{authors}
	\li \tt{date}
	\li \tt{history}
	\li \tt{since}
	\li \tt{version}
	\li \tt{copyright}
	\li \tt{license}
\endlist
*/
global stdSections =
[
	"deprecated"

	"docs"
	"examples"
	"params"
	"returns"
	"throws"

	"bugs"
	"notes"
	"todo"
	"warnings"

	"see"

	"authors"
	"date"
	"history"
	"since"
	"version"

	"copyright"
	"license"
]

/**
Defines an ordering of sections as used by documentation visitors.
*/
class SectionOrder
{
	__sectionOrder

	/**
	The new instance will have its order set to the same order as defined in \link{stdSections}.
	*/
	this()
	{
		:__sectionOrder = stdSections.dup()
	}

	/**
	Duplicates this order.
	\returns a new instance of this class.
	*/
	function dup()
	{
		local ret = SectionOrder()
		ret.setOrder(:__sectionOrder)
		return ret
	}

	/**
	\returns the current order as an array.
	*/
	function getOrder() =
		:__sectionOrder.dup()

	/**
	Sets the current order to the given array. It must satisfy all of the following conditions:

	\blist
		\li All elements of \tt{order} must be strings.
		\li All elements must be valid section names as defined by \link{validSectionName}.
		\li All of the standard sections must appear in the order.
		\li No section appears twice in the order.
	\endlist

	\param[order] order is the new order as described above.
	\throws[exceptions.ValueException] if any of the given constraints are not satisfied.
	*/
	function setOrder(order: array)
	{
		// Make sure it's an array of valid section names
		foreach(name; order)
		{
			if(!isString(name))
				throw ValueException("Order must be an array of nothing but strings")
			else if(!validSectionName(name))
				throw ValueException("Invalid section name '{}' in given order".format(name))
		}

		// Make sure all standard sections are accounted for
		foreach(sec; stdSections)
			if(sec !in order)
				throw ValueException("Standard section '{}' does not exist in the given order".format(sec))

		// Make sure there are no duplicates
		local temp = order.dup().sort()

		for(i: 0 .. #temp - 1)
		{
			if(temp[i] is temp[i + 1])
				throw ValueException("Section '{}' is repeated in the given order".format(temp[i]))
		}

		:__sectionOrder = order.dup()
	}

	/**
	Moves the section \tt{sec} before the existing section \tt{before}.

	\param[sec] is the name of the section to insert. It can be a section already in the order, in which case it will be
		moved; or a new section name.
	\param[before] is the name of the section before which \tt{sec} will be inserted.
	*/
	function insertSectionBefore(sec: string, before: string)
		:__insertSectionImpl(sec, before, false)

	/**
	Same as \link{insertSectionBefore}, but puts \tt{sec} after \tt{after} instead of before it.
	*/
	function insertSectionAfter(sec: string, after: string)
		:__insertSectionImpl(sec, after, true)

	function __insertSectionImpl(sec: string, target: string, after: bool)
	{
		if(!validSectionName(sec))
			throw ValueException("Invalid section name '{}'".format(sec))
		else if(!validSectionName(target))
			throw ValueException("Invalid section name '{}'".format(target))
		else if(sec == target)
			throw ValueException("Section names must be different")
		else if(target !in ord)
			throw ValueException("Section '{}' does not exist in the section order".format(target))

		local ord = :__sectionOrder

		// Check if this section is already in the order. It's possible for it not to be,
		// if it's a custom section.
		local idx = ord.find(sec)

		if(idx < #ord)
			ord.pop(idx)

		// Find where to insert and put it there.
		local targetIdx = ord.find(target)
		ord.insert(after ? targetIdx + 1 : targetIdx, sec)
	}
}

/**
This class defines an "outputter" interface which works in conjunction with the \link{OutputDocVisitor} class.

The general idea of this interface is that for each doc item, section, paragraph, and paragraph element, the owning
\tt{OutputDocVisitor} will call the \tt{begin} method for it, then process its contents, and then call the corresponding
\tt{end} method. For instance, when visiting a module, it calls \tt{beginModule}, then processes the module's
documentation and its children, and finally calls \tt{endModule}.

Note that there is no requirement to use either of these classes; you can simply write your own doc visitor if you wish.
However this interface tends to work well for many kinds of doc outputs, and saves you from having to rewrite some stuff
over and over.
*/
class DocOutputter
{
	// Item-level stuff

	/**
	Each of these pairs of methods is called when the visitor encounters a doc item of the given type.

	In the \tt{begin} methods, your implementation is expected to handle any dittos as well (which will be in the
	\tt{doctable} param if any exist).

	\param[doctable] is the doc table of the given item.
	*/
	function beginModule(doctable: table) throw NotImplementedException()
	function endModule() throw NotImplementedException() /// ditto
	function beginFunction(doctable: table) throw NotImplementedException() /// ditto
	function endFunction() throw NotImplementedException() /// ditto
	function beginClass(doctable: table) throw NotImplementedException() /// ditto
	function endClass() throw NotImplementedException() /// ditto
	function beginNamespace(doctable: table) throw NotImplementedException() /// ditto
	function endNamespace() throw NotImplementedException() /// ditto
	function beginField(doctable: table) throw NotImplementedException() /// ditto
	function endField() throw NotImplementedException() /// ditto
	function beginVariable(doctable: table) throw NotImplementedException() /// ditto
	function endVariable() throw NotImplementedException() /// ditto

	// Section-level stuff

	/**
	Called when a given section begins.

	The sections are output in whatever order is specified by the visitor, so you shouldn't depend on them being output
	in any specific order.

	Note that the \tt{"params"} and \tt{"throws"} sections will call some additional methods between their begin and
	end calls, listed below

	\param[name] is the name of the section, completely unmodified (so it will be lowercase and, if it's a custom
		section, will still have the underscore at the beginning).
	*/
	function beginSection(name: string) throw NotImplementedException()

	/// Called when a section ends.
	function endSection() throw NotImplementedException()

	/**
	When outputting a \tt{"params"} section, this is called for each parameter.

	This method is passed the parameter's doctable, so that it can output the name/type/default value/whatever it wants.
	The docs, however, will be output by the \tt{OutputDocVisitor} after this method returns, so you don't have to
	output those yourself.

	\param[doctable] is the doctable of the parameter being begun.
	*/
	function beginParameter(doctable: table) throw NotImplementedException()

	/// Called when a parameter ends.
	function endParameter() throw NotImplementedException()

	/**
	When outputting a \tt{"throws"} section, this is called for each exception.

	This is similar to the \tt{beginParameter} method in that this will be called, and after it returns, the docs for
	the exception will be output.

	\param[name] is the exception name.
	*/
	function beginException(name: string) throw NotImplementedException()

	/// Called when an exception ends.
	function endException() throw NotImplementedException()

	// Paragraph-level stuff

	/**
	Output raw text.

	This is called to output raw text snippets in paragraphs, among other things.

	\param[vararg] are all strings to be output.
	*/
	function outputText(vararg) throw NotImplementedException()

	/**
	Begin and end a single paragraph as defined by the doc comment spec.

	Between these calls, you'll get calls to output the paragraph's contents.
	*/
	function beginParagraph() throw NotImplementedException()
	function endParagraph() throw NotImplementedException() /// ditto

	/**
	Begin and end code and verbatim sections.

	The \tt{language} parameter of \tt{beginCode} is what programming language the code snippet is in.

	Within these sections, only \link{outputText} will be called.
	*/
	function beginCode(language: string) throw NotImplementedException()
	function endCode() throw NotImplementedException() /// ditto
	function beginVerbatim() throw NotImplementedException() /// ditto
	function endVerbatim() throw NotImplementedException() /// ditto

	/**
	Begin and end bulleted and numbered lists.

	The \tt{type} parameter of \tt{beginNumList} specifies the type of list (one of \tt{"1", "a", "A", "i",} and
	\tt{"I"}).
	*/
	function beginBulletList() throw NotImplementedException()
	function endBulletList() throw NotImplementedException() /// ditto
	function beginNumList(type: string) throw NotImplementedException() /// ditto
	function endNumList() throw NotImplementedException() /// ditto

	/**
	Begin and end list items in bulleted and numbered lists.

	Each list item will be bracketed by these two calls. Sub-lists are not treated as their own list items.
	*/
	function beginListItem() throw NotImplementedException()
	function endListItem() throw NotImplementedException() /// ditto

	/**
	Begin and end definition lists.

	Each item will consist of a definition term followed by a definition ... definition. Hey, you come up with a better
	name!
	*/
	function beginDefList() throw NotImplementedException()
	function endDefList() throw NotImplementedException() /// ditto

	/**
	Begin and end definition list items.

	For each item, you will get a \tt{beginDefTerm}, then some paragraph elements for the term, then \tt{endDefTerm};
	then comes \tt{beginDefDef}, then the contents of the definition, and finally \tt{endDefDef}.
	*/
	function beginDefTerm() throw NotImplementedException()
	function endDefTerm() throw NotImplementedException() /// ditto
	function beginDefDef() throw NotImplementedException() /// ditto
	function endDefDef() throw NotImplementedException() /// ditto

	/**
	Begin and end tables, their rows, and their cells.

	Each row is bracketed by \tt{beginRow/endRow} calls; each cell in each row is bracketed by \tt{beginCell/endCell}
	calls. It's simple.
	*/
	function beginTable() throw NotImplementedException()
	function endTable() throw NotImplementedException() /// ditto
	function beginRow() throw NotImplementedException() /// ditto
	function endRow() throw NotImplementedException() /// ditto
	function beginCell() throw NotImplementedException() /// ditto
	function endCell() throw NotImplementedException() /// ditto

	/// Begin and end text spans.
	function beginBold() throw NotImplementedException()
	function endBold() throw NotImplementedException() /// ditto
	function beginEmphasis() throw NotImplementedException() /// ditto
	function endEmphasis() throw NotImplementedException() /// ditto
	function beginSubscript() throw NotImplementedException() /// ditto
	function endSubscript() throw NotImplementedException() /// ditto
	function beginSuperscript() throw NotImplementedException() /// ditto
	function endSuperscript() throw NotImplementedException() /// ditto
	function beginMonospace() throw NotImplementedException() /// ditto
	function endMonospace() throw NotImplementedException() /// ditto
	function beginUnderline() throw NotImplementedException() /// ditto
	function endUnderline() throw NotImplementedException() /// ditto

	/**
	Begin and end link text spans.

	\param[link] is the link target, and if you want the link to work, you'll have to use a \link{LinkResolver} with
	an implementation of \link{LinkTranslator} to do so.
	*/
	function beginLink(link: string) throw NotImplementedException()
	function endLink() throw NotImplementedException() /// ditto
}

/**
A kind of doc visitor which uses an instance of a class derived from \link{DocOutputter} to output documentation.

If you want to handle sections with custom formatting and custom spans in your documentation when using this little
framework, you can derive from this class and override the appropriate methods.
*/
class OutputDocVisitor : DocVisitor
{
	_order
	_output

	/**
	\param[so] is the order in which the sections should be visited for each documentation item.
	\param[o] is an instance of a class derived from \link{DocOutputter} which implements its interface.
	*/
	this(so: SectionOrder, o: DocOutputter)
	{
		:_order = so.getOrder()
		:_output = o
	}

	/**
	Each of these visits a documentation item of the given type.

	By default, they call the appropriate \tt{begin} method on the outputter, then output any docs for the item, then
	(if applicable) it recursively visits its children, and finally calls the appropriate \tt{end} method. You can
	override a method if you want to do something different.

	\param[doctable] is the item's doc table.
	*/
	function visitModule(doctable: table)
	{
		:_output.beginModule(doctable)
		:_doDocSections(doctable)
		:visitChildren(doctable)
		:_output.endModule()
	}

	/// ditto
	function visitFunction(doctable: table)
	{
		:_output.beginFunction(doctable)
		:_doDocSections(doctable)
		:_output.endFunction()
	}

	/// ditto
	function visitClass(doctable: table)
	{
		:_output.beginClass(doctable)
		:_doDocSections(doctable)
		:visitChildren(doctable)
		:_output.endClass()
	}

	/// ditto
	function visitNamespace(doctable: table)
	{
		:_output.beginNamespace(doctable)
		:_doDocSections(doctable)
		:visitChildren(doctable)
		:_output.endNamespace()
	}

	/// ditto
	function visitField(doctable: table)
	{
		:_output.beginField(doctable)
		:_doDocSections(doctable)
		:_output.endField()
	}

	/// ditto
	function visitVariable(doctable: table)
	{
		:_output.beginVariable(doctable)
		:_doDocSections(doctable)
		:_output.endVariable()
	}

	/**
	Visits one section of an item's docs, outputting them if necessary.

	For \tt{"docs"} sections, no \tt{begin/endSection} methods will be called if the section is empty.

	For \tt{"params"} sections, no \tt{begin/endSection} methods will be called if all of the parameters' docs are
	empty.

	For \tt{"params"} and \tt{"throws"} sections, calls the \tt{begin/endParameter} and \tt{begin/endException} methods
	as defined in \link{DocOutputter}.

	For all other kinds of sections, simply calls the \tt{beginSection} method, then outputs its contents as a list of
	paragraphs, and then calls the \tt{endSection} method.

	This handles "regular" custom sections as well, but if you have a custom section which expects specific formatting,
	you can override this method and handle that section appropriately.

	\param[name] is the name of the section, unmodified from the doctables.
	\param[contents] is a plist as defined by the doc comment spec.
	*/
	function visitSection(name: string, contents: array)
	{
		if(name is "params")
		{
			if(#contents == 0 || contents.all(isDocsEmpty))
				return

			:_output.beginSection(name)

			foreach(param; contents)
			{
				:_output.beginParameter(param)
				:visitPlist(param.docs)
				:_output.endParameter()
			}
		}
		else if(name is "throws")
		{
			:_output.beginSection(name)

			foreach(ex; contents)
			{
				:_output.beginException(ex[0])
				:visitPlist(ex[1..])
				:_output.endException()
			}
		}
		else
		{
			if(name is "docs" && isPlistEmpty(contents))
				return

			:_output.beginSection(name)
			:visitPlist(contents)
		}

		:_output.endSection()
	}

	/**
	Override of \link{DocVisitor.visitParagraph} which simply calls the \tt{begin/endParagraph} methods around the
	paragraph's contents.
	*/
	function visitParagraph(par: array)
	{
		:_output.beginParagraph()
		super.visitParagraph(par)
		:_output.endParagraph()
	}

	/// Simply calls the outputter's \tt{outputText} with its input as the parameter.
	function visitText(elem: string)
		:_output.outputText(elem)

	/// Implmentations of the methods which output text structures and spans.
	function visitCode(language: string, contents: string)
	{
		:_output.beginCode(language)
		:_output.outputText(contents)
		:_output.endCode()
	}

	/// ditto
	function visitVerbatim(contents: string)
	{
		:_output.beginVerbatim()
		:_output.outputText(contents)
		:_output.endVerbatim()
	}

	/// ditto
	function visitBlist(items: array)
	{
		:_output.beginBulletList()

		foreach(item; items)
		{
			:_output.beginListItem()
			:visitPlist(item)
			:_output.endListItem()
		}

		:_output.endBulletList()
	}

	/// ditto
	function visitNlist(type: string, items: array)
	{
		:_output.beginNumList(type)

		foreach(item; items)
		{
			:_output.beginListItem()
			:visitPlist(item)
			:_output.endListItem()
		}

		:_output.endNumList()
	}

	/// ditto
	function visitDlist(items: array)
	{
		:_output.beginDefList()

		foreach(item; items)
		{
			:_output.beginDefTerm()
			:visitParagraphElements(item[0])
			:_output.endDefTerm()

			:_output.beginDefDef()
			:visitPlist(item[1..])
			:_output.endDefDef()
		}

		:_output.endDefList()
	}

	/// ditto
	function visitTable(rows: array)
	{
		:_output.beginTable()

		foreach(row; rows)
		{
			:_output.beginRow()

			foreach(cell; row)
			{
				:_output.beginCell()
				:visitPlist(cell)
				:_output.endCell()
			}

			:_output.endRow()
		}

		:_output.endTable()
	}

	/// ditto
	function visitBold(contents: array)
	{
		:_output.beginBold()
		:visitParagraphElements(contents)
		:_output.endBold()
	}

	/// ditto
	function visitEmphasis(contents: array)
	{
		:_output.beginEmphasis()
		:visitParagraphElements(contents)
		:_output.endEmphasis()
	}

	/// ditto
	function visitLink(link: string, contents: array)
	{
		:_output.beginLink(link)
		:visitParagraphElements(contents)
		:_output.endLink()
	}

	/// ditto
	function visitSubscript(contents: array)
	{
		:_output.beginSubscript()
		:visitParagraphElements(contents)
		:_output.endSubscript()
	}

	/// ditto
	function visitSuperscript(contents: array)
	{
		:_output.beginSuperscript()
		:visitParagraphElements(contents)
		:_output.endSuperscript()
	}

	/// ditto
	function visitMonospace(contents: array)
	{
		:_output.beginMonospace()
		:visitParagraphElements(contents)
		:_output.endMonospace()
	}

	/// ditto
	function visitUnderline(contents: array)
	{
		:_output.beginUnderline()
		:visitParagraphElements(contents)
		:_output.endUnderline()
	}

	/// ditto
	function visitCustomSpan(type: string, contents: array)
	{
		:visitParagraphElements(contents)
	}

	/**
	Protected method which implements the section visiting.

	This is called from the item visit methods, and calls the \link{visitSection} method for any section that exists
	in the given doctable. You can override this if you need different handling.

	\param[doctable] is the doctable of the item that's being visited.
	*/
	function _doDocSections(doctable: table)
	{
		foreach(section; :_order)
		{
			local contents = null

			if(section[0] == '_')
			{
				if(hasField(doctable, "custom"))
					contents = doctable.custom[section[1 ..]]
			}
			else
				contents = doctable[section]

			if(contents)
				:visitSection(section, contents)
		}
	}
}
`;