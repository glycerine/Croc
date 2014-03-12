#ifndef CROC_STDLIB_HELPERS_REGISTER_HPP
#define CROC_STDLIB_HELPERS_REGISTER_HPP

#include "croc/api.h"
#include "croc/types/base.hpp"

namespace croc
{
#define DModule CROC_DOC_MODULE
#define DFunc CROC_DOC_FUNC
#define DClass CROC_DOC_CLASS
#define DNs CROC_DOC_NS
#define DField CROC_DOC_FIELD
#define DFieldV CROC_DOC_FIELDV
#define DVar CROC_DOC_VAR
#define DVarV CROC_DOC_VARV
#define DBase CROC_DOC_BASE
#define DParamAny CROC_DOC_PARAMANY
#define DParamAnyD CROC_DOC_PARAMANYD
#define DParam CROC_DOC_PARAM
#define DParamD CROC_DOC_PARAMD
#define DVararg CROC_DOC_VARARG

#define DBeginList(name) const StdlibRegister name[] = {{
#define DListSep() },{
#define DEndList() },{nullptr, nullptr, 0, nullptr}};

	constexpr const char* Docstr(const char* s)
	{
#ifdef CROC_BUILTIN_DOCS
		return s;
#else
		return s - s; // teehee sneaky way to return nullptr AND use s
#endif
	}

	struct StdlibRegister
	{
		const char* docs;
		const char* name;
		word maxParams;
		CrocNativeFunc func;
	};

	void registerGlobals(CrocThread* t, const StdlibRegister* funcs);
	void registerFields(CrocThread* t, const StdlibRegister* funcs);
	void registerMethods(CrocThread* t, const StdlibRegister* funcs);
#ifdef CROC_BUILTIN_DOCS
	void docGlobals(CrocDoc* d, const StdlibRegister* funcs);
	void docFields(CrocDoc* d, const StdlibRegister* funcs);
#endif
}

#endif