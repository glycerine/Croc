/******************************************************************************
This module contains the definition of all the classes which correspond to
Croc's grammar productions. These are used to represent the AST during
compilation.

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

module croc.compiler_ast;

import croc.base_alloc;
import croc.base_opcodes;
import croc.compiler_types;
import croc.types;

const char[][] AstTagNames =
[
	"Identifier",

	"ClassDef",
	"FuncDef",
	"NamespaceDef",

	"Module",
	"Decorator",

	"VarDecl",
	"FuncDecl",
	"ClassDecl",
	"NamespaceDecl",

	"AssertStmt",
	"ImportStmt",
	"BlockStmt",
	"ScopeStmt",
	"ExpressionStmt",
	"IfStmt",
	"WhileStmt",
	"DoWhileStmt",
	"ForStmt",
	"ForNumStmt",
	"ForeachStmt",
	"SwitchStmt",
	"CaseStmt",
	"DefaultStmt",
	"ContinueStmt",
	"BreakStmt",
	"ReturnStmt",
	"TryCatchStmt",
	"TryFinallyStmt",
	"ThrowStmt",
	"ScopeActionStmt",

	"AssignStmt",
	"AddAssignStmt",
	"SubAssignStmt",
	"CatAssignStmt",
	"MulAssignStmt",
	"DivAssignStmt",
	"ModAssignStmt",
	"OrAssignStmt",
	"XorAssignStmt",
	"AndAssignStmt",
	"ShlAssignStmt",
	"ShrAssignStmt",
	"UShrAssignStmt",
	"CondAssignStmt",
	"IncStmt",
	"DecStmt",
	"TypecheckStmt",

	"CondExp",
	"OrOrExp",
	"AndAndExp",
	"OrExp",
	"XorExp",
	"AndExp",
	"EqualExp",
	"NotEqualExp",
	"IsExp",
	"NotIsExp",
	"LTExp",
	"LEExp",
	"GTExp",
	"GEExp",
	"Cmp3Exp",
	"AsExp",
	"InExp",
	"NotInExp",
	"ShlExp",
	"ShrExp",
	"UShrExp",
	"AddExp",
	"SubExp",
	"CatExp",
	"MulExp",
	"DivExp",
	"ModExp",
	"NegExp",
	"NotExp",
	"ComExp",
	"LenExp",
	"VargLenExp",
	"DotExp",
	"DotSuperExp",
	"IndexExp",
	"VargIndexExp",
	"SliceExp",
	"VargSliceExp",
	"CallExp",
	"MethodCallExp",
	"IdentExp",
	"ThisExp",
	"NullExp",
	"BoolExp",
	"VarargExp",
	"IntExp",
	"FloatExp",
	"StringExp",
	"FuncLiteralExp",
	"ClassLiteralExp",
	"ParenExp",
	"TableCtorExp",
	"ArrayCtorExp",
	"NamespaceCtorExp",
	"YieldExp",

	"ForeachComprehension",
	"ForNumComprehension",
	"IfComprehension",
	"ArrayComprehension",
	"TableComprehension"
];

char[] genEnumMembers()
{
	char[] ret;

	foreach(tag; AstTagNames)
		ret ~= tag ~ ",";

	return ret;
}

mixin("enum AstTag {" ~ genEnumMembers() ~ "}");

const char[][] NiceAstTagNames =
[
	AstTag.Identifier:           "identifier",

	AstTag.ClassDef:             "class definition",
	AstTag.FuncDef:              "function definition",
	AstTag.NamespaceDef:         "namespace definition",

	AstTag.Module:               "module",
	AstTag.Decorator:            "decorator",

	AstTag.VarDecl:              "variable declaration",
	AstTag.FuncDecl:             "function declaration",
	AstTag.ClassDecl:            "class declaration",
	AstTag.NamespaceDecl:        "namespace declaration",

	AstTag.AssertStmt:           "assert statement",
	AstTag.ImportStmt:           "import statement",
	AstTag.BlockStmt:            "block statement",
	AstTag.ScopeStmt:            "scope statement",
	AstTag.ExpressionStmt:       "expression statement",
	AstTag.IfStmt:               "'if' statement",
	AstTag.WhileStmt:            "'while' statement",
	AstTag.DoWhileStmt:          "'do-while' statement",
	AstTag.ForStmt:              "'for' statement",
	AstTag.ForNumStmt:           "numeric 'for' statement",
	AstTag.ForeachStmt:          "'foreach' statement",
	AstTag.SwitchStmt:           "'switch' statement",
	AstTag.CaseStmt:             "'case' statement",
	AstTag.DefaultStmt:          "'default' statement",
	AstTag.ContinueStmt:         "'continue' statement",
	AstTag.BreakStmt:            "'break' statement",
	AstTag.ReturnStmt:           "'return' statement",
	AstTag.TryCatchStmt:         "'try-catch' statement",
	AstTag.TryFinallyStmt:       "'try-finally' statement",
	AstTag.ThrowStmt:            "'throw' statement",
	AstTag.ScopeActionStmt:      "'scope(...)' statement",

	AstTag.AssignStmt:           "assignment",
	AstTag.AddAssignStmt:        "addition assignment",
	AstTag.SubAssignStmt:        "subtraction assignment",
	AstTag.CatAssignStmt:        "concatenation assignment",
	AstTag.MulAssignStmt:        "multiplication assignment",
	AstTag.DivAssignStmt:        "division assignment",
	AstTag.ModAssignStmt:        "modulo assignment",
	AstTag.OrAssignStmt:         "bitwise 'or' assignment",
	AstTag.XorAssignStmt:        "bitwise 'xor' assignment",
	AstTag.AndAssignStmt:        "bitwise 'and' assignment",
	AstTag.ShlAssignStmt:        "left-shift assignment",
	AstTag.ShrAssignStmt:        "right-shift assignment",
	AstTag.UShrAssignStmt:       "unsigned right-shift assignment",
	AstTag.CondAssignStmt:       "conditional assignment",
	AstTag.IncStmt:              "increment",
	AstTag.DecStmt:              "decrement",
	AstTag.TypecheckStmt:        "typecheck statement",

	AstTag.CondExp:              "conditional expression",
	AstTag.OrOrExp:              "logical 'or' expression",
	AstTag.AndAndExp:            "logical 'and' expression",
	AstTag.OrExp:                "bitwise 'or' expression",
	AstTag.XorExp:               "bitwise 'xor' expression",
	AstTag.AndExp:               "bitwise 'and' expression",
	AstTag.EqualExp:             "equality expression",
	AstTag.NotEqualExp:          "inequality expression",
	AstTag.IsExp:                "identity expression",
	AstTag.NotIsExp:             "non-identity expression",
	AstTag.LTExp:                "less-than expression",
	AstTag.LEExp:                "less-or-equals expression",
	AstTag.GTExp:                "greater-than expression",
	AstTag.GEExp:                "greater-or-equals expression",
	AstTag.Cmp3Exp:              "three-way comparison expression",
	AstTag.AsExp:                "'as' expression",
	AstTag.InExp:                "'in' expression",
	AstTag.NotInExp:             "'!in' expression",
	AstTag.ShlExp:               "left-shift expression",
	AstTag.ShrExp:               "right-shift expression",
	AstTag.UShrExp:              "unsigned right-shift expression",
	AstTag.AddExp:               "addition expression",
	AstTag.SubExp:               "subtraction expression",
	AstTag.CatExp:               "concatenation expression",
	AstTag.MulExp:               "multiplication expression",
	AstTag.DivExp:               "division expression",
	AstTag.ModExp:               "modulo expression",
	AstTag.NegExp:               "negation expression",
	AstTag.NotExp:               "logical 'not' expression",
	AstTag.ComExp:               "bitwise complement expression",
	AstTag.LenExp:               "length expression",
	AstTag.VargLenExp:           "vararg length expression",
	AstTag.DotExp:               "dot expression",
	AstTag.DotSuperExp:          "dot-super expression",
	AstTag.IndexExp:             "index expression",
	AstTag.VargIndexExp:         "vararg index expression",
	AstTag.SliceExp:             "slice expression",
	AstTag.VargSliceExp:         "vararg slice expression",
	AstTag.CallExp:              "call expression",
	AstTag.MethodCallExp:        "method call expression",
	AstTag.IdentExp:             "identifier expression",
	AstTag.ThisExp:              "'this' expression",
	AstTag.NullExp:              "'null' expression",
	AstTag.BoolExp:              "boolean constant expression",
	AstTag.VarargExp:            "'vararg' expression",
	AstTag.IntExp:               "integer constant expression",
	AstTag.FloatExp:             "float constant expression",
	AstTag.StringExp:            "string constant expression",
	AstTag.FuncLiteralExp:       "function literal expression",
	AstTag.ClassLiteralExp:      "class literal expression",
	AstTag.ParenExp:             "parenthesized expression",
	AstTag.TableCtorExp:         "table constructor expression",
	AstTag.ArrayCtorExp:         "array constructor expression",
	AstTag.NamespaceCtorExp:     "namespace constructor expression",
	AstTag.YieldExp:             "yield expression",

	AstTag.ForeachComprehension: "'foreach' comprehension",
	AstTag.ForNumComprehension:  "numeric 'for' comprehension",
	AstTag.IfComprehension:      "'if' comprehension",
	AstTag.ArrayComprehension:   "array comprehension",
	AstTag.TableComprehension:   "table comprehension"
];

abstract class AstNode
{
	CompileLoc location;
	CompileLoc endLocation;
	AstTag type;

	new(uword size, ICompiler c)
	{
		return c.allocNode(size);
	}

	this(CompileLoc location, CompileLoc endLocation, AstTag type)
	{
		this.location = location;
		this.endLocation = endLocation;
		this.type = type;
	}

	char[] toString()
	{
		return AstTagNames[type];
	}

	char[] niceString()
	{
		return NiceAstTagNames[type];
	}

	T as(T)()
	{
		if(type == mixin("AstTag." ~ T.stringof))
			return cast(T)cast(void*)this;

		return null;
	}
}

class Identifier : AstNode
{
	char[] name;

	this(CompileLoc location, char[] name)
	{
		super(location, location, AstTag.Identifier);
		this.name = name;
	}
}

class ClassDef : AstNode
{
	struct Field
	{
		char[] name;
		Expression initializer;
		ubyte privacy;
		bool isMethod;
		char[] docs;
		CompileLoc docsLoc;
	}

	Identifier name;
	Expression baseClass;
	Field[] fields;
	char[] docs;
	CompileLoc docsLoc;

	this(CompileLoc location, CompileLoc endLocation, Identifier name, Expression baseClass, Field[] fields)
	{
		super(location, endLocation, AstTag.ClassDef);
		this.name = name;
		this.baseClass = baseClass;
		this.fields = fields;
	}
}

class FuncDef : AstNode
{
	enum TypeMask : uint
	{
		Null =      (1 << cast(uint)CrocValue.Type.Null),
		Bool =      (1 << cast(uint)CrocValue.Type.Bool),
		Int =       (1 << cast(uint)CrocValue.Type.Int),
		Float =     (1 << cast(uint)CrocValue.Type.Float),

		String =    (1 << cast(uint)CrocValue.Type.String),
		Table =     (1 << cast(uint)CrocValue.Type.Table),
		Array =     (1 << cast(uint)CrocValue.Type.Array),
		Memblock =  (1 << cast(uint)CrocValue.Type.Memblock),
		Function =  (1 << cast(uint)CrocValue.Type.Function),
		Class =     (1 << cast(uint)CrocValue.Type.Class),
		Instance =  (1 << cast(uint)CrocValue.Type.Instance),
		Namespace = (1 << cast(uint)CrocValue.Type.Namespace),
		Thread =    (1 << cast(uint)CrocValue.Type.Thread),
		NativeObj = (1 << cast(uint)CrocValue.Type.NativeObj),
		WeakRef =   (1 << cast(uint)CrocValue.Type.WeakRef),
		FuncDef =   (1 << cast(uint)CrocValue.Type.FuncDef),

		NotNull = Bool | Int | Float | String | Table | Array | Memblock | Function | Class | Instance | Namespace |
			Thread | NativeObj | WeakRef | FuncDef,
		Any = Null | NotNull
	}

	struct Param
	{
		Identifier name;
		uint typeMask = TypeMask.Any;
		Expression[] classTypes;
		Expression customConstraint;
		Expression defValue;
		char[] typeString;
		char[] valueString;
	}

	Identifier name;
	Param[] params;
	bool isVararg;
	Statement code;
	char[] docs;
	CompileLoc docsLoc;

	this(CompileLoc location, Identifier name, Param[] params, bool isVararg, Statement code)
	{
		assert(code.as!(ReturnStmt) || code.as!(BlockStmt));

		super(location, code.endLocation, AstTag.FuncDef);

		assert(params.length > 0 && params[0].name.name == "this");

		this.params = params;
		this.isVararg = isVararg;
		this.code = code;
		this.name = name;
	}
}

class NamespaceDef : AstNode
{
	struct Field
	{
		char[] name;
		Expression initializer;
		char[] docs;
		CompileLoc docsLoc;
	}

	Identifier name;
	Expression parent;
	Field[] fields;
	char[] docs;
	CompileLoc docsLoc;

	this(CompileLoc location, CompileLoc endLocation, Identifier name, Expression parent, Field[] fields)
	{
		super(location, endLocation, AstTag.NamespaceDef);
		this.name = name;
		this.parent = parent;
		this.fields = fields;
	}
}

class Module : AstNode
{
	char[][] names;
	Statement statements;
	Decorator decorator;
	char[] docs;
	CompileLoc docsLoc;

	this(CompileLoc location, CompileLoc endLocation, char[][] names, Statement statements, Decorator decorator)
	{
		super(location, endLocation, AstTag.Module);
		this.names = names;
		this.statements = statements;
		this.decorator = decorator;
	}
}

abstract class Statement : AstNode
{
	this(CompileLoc location, CompileLoc endLocation, AstTag type)
	{
		super(location, endLocation, type);
	}
}

enum Protection
{
	Default,
	Local,
	Global
}

class VarDecl : Statement
{
	Protection protection;
	Identifier[] names;
	Expression[] initializer;
	char[] docs;
	CompileLoc docsLoc;

	this(CompileLoc location, CompileLoc endLocation, Protection protection, Identifier[] names, Expression[] initializer)
	{
		super(location, endLocation, AstTag.VarDecl);
		this.protection = protection;
		this.names = names;
		this.initializer = initializer;
	}
}

class Decorator : AstNode
{
	Expression func;
	Expression context;
	Expression[] args;
	Decorator nextDec;

	this(CompileLoc location, CompileLoc endLocation, Expression func, Expression context, Expression[] args, Decorator nextDec)
	{
		super(location, endLocation, AstTag.Decorator);
		this.func = func;
		this.context = context;
		this.args = args;
		this.nextDec = nextDec;
	}
}

class FuncDecl : Statement
{
	Protection protection;
	FuncDef def;
	Decorator decorator;

	this(CompileLoc location, Protection protection, FuncDef def, Decorator decorator)
	{
		super(location, def.endLocation, AstTag.FuncDecl);
		this.protection = protection;
		this.def = def;
		this.decorator = decorator;
	}
}

class ClassDecl : Statement
{
	Protection protection;
	ClassDef def;
	Decorator decorator;

	this(CompileLoc location, Protection protection, ClassDef def, Decorator decorator)
	{
		super(location, def.endLocation, AstTag.ClassDecl);
		this.protection = protection;
		this.def = def;
		this.decorator = decorator;
	}
}

class NamespaceDecl : Statement
{
	Protection protection;
	NamespaceDef def;
	Decorator decorator;

	this(CompileLoc location, Protection protection, NamespaceDef def, Decorator decorator)
	{
		super(location, def.endLocation, AstTag.NamespaceDecl);
		this.protection = protection;
		this.def = def;
		this.decorator = decorator;
	}
}

class AssertStmt : Statement
{
	Expression cond;
	Expression msg;

	this(CompileLoc location, CompileLoc endLocation, Expression cond, Expression msg = null)
	{
		super(location, endLocation, AstTag.AssertStmt);
		this.cond = cond;
		this.msg = msg;
	}
}

class ImportStmt : Statement
{
	Identifier importName;
	Expression expr;
	Identifier[] symbols;
	Identifier[] symbolNames;

	this(CompileLoc location, CompileLoc endLocation, Identifier importName, Expression expr, Identifier[] symbols, Identifier[] symbolNames)
	{
		super(location, endLocation, AstTag.ImportStmt);
		this.importName = importName;
		this.expr = expr;
		this.symbols = symbols;
		this.symbolNames = symbolNames;
	}
}

class BlockStmt : Statement
{
	Statement[] statements;

	this(CompileLoc location, CompileLoc endLocation, Statement[] statements)
	{
		super(location, endLocation, AstTag.BlockStmt);
		this.statements = statements;
	}
}

class ScopeStmt : Statement
{
	Statement statement;

	this(Statement statement)
	{
		super(statement.location, statement.endLocation, AstTag.ScopeStmt);
		this.statement = statement;
	}
}

class ExpressionStmt : Statement
{
	Expression expr;

	this(CompileLoc location, CompileLoc endLocation, Expression expr)
	{
		super(location, endLocation, AstTag.ExpressionStmt);
		this.expr = expr;
	}

	this(Expression expr)
	{
		super(expr.location, expr.endLocation, AstTag.ExpressionStmt);
		this.expr = expr;
	}
}

class IfStmt : Statement
{
	IdentExp condVar;
	Expression condition;
	Statement ifBody;
	Statement elseBody;

	this(CompileLoc location, CompileLoc endLocation, IdentExp condVar, Expression condition, Statement ifBody, Statement elseBody)
	{
		super(location, endLocation, AstTag.IfStmt);

		this.condVar = condVar;
		this.condition = condition;
		this.ifBody = ifBody;
		this.elseBody = elseBody;
	}
}

class WhileStmt : Statement
{
	char[] name;
	IdentExp condVar;
	Expression condition;
	Statement code;

	this(CompileLoc location, char[] name, IdentExp condVar, Expression condition, Statement code)
	{
		super(location, code.endLocation, AstTag.WhileStmt);

		this.name = name;
		this.condVar = condVar;
		this.condition = condition;
		this.code = code;
	}
}

class DoWhileStmt : Statement
{
	char[] name;
	Statement code;
	Expression condition;

	this(CompileLoc location, CompileLoc endLocation, char[] name, Statement code, Expression condition)
	{
		super(location, endLocation, AstTag.DoWhileStmt);

		this.name = name;
		this.code = code;
		this.condition = condition;
	}
}

class ForStmt : Statement
{
	struct Init
	{
		bool isDecl = false;

		union
		{
			Statement stmt;
			VarDecl decl;
		}
	}

	char[] name;
	Init[] init;
	Expression condition;
	Statement[] increment;
	Statement code;

	this(CompileLoc location, char[] name, Init[] init, Expression cond, Statement[] inc, Statement code)
	{
		super(location, endLocation, AstTag.ForStmt);

		this.name = name;
		this.init = init;
		this.condition = cond;
		this.increment = inc;
		this.code = code;
	}
}

class ForNumStmt : Statement
{
	char[] name;
	Identifier index;
	Expression lo;
	Expression hi;
	Expression step;
	Statement code;

	this(CompileLoc location, char[] name, Identifier index, Expression lo, Expression hi, Expression step, Statement code)
	{
		super(location, code.endLocation, AstTag.ForNumStmt);

		this.name = name;
		this.index = index;
		this.lo = lo;
		this.hi = hi;
		this.step = step;
		this.code = code;
	}
}

class ForeachStmt : Statement
{
	char[] name;
	Identifier[] indices;
	Expression[] container;
	Statement code;

	this(CompileLoc location, char[] name, Identifier[] indices, Expression[] container, Statement code)
	{
		super(location, code.endLocation, AstTag.ForeachStmt);

		this.name = name;
		this.indices = indices;
		this.container = container;
		this.code = code;
	}
}

class SwitchStmt : Statement
{
	char[] name;
	Expression condition;
	CaseStmt[] cases;
	DefaultStmt caseDefault;

	this(CompileLoc location, CompileLoc endLocation, char[] name, Expression condition, CaseStmt[] cases, DefaultStmt caseDefault)
	{
		super(location, endLocation, AstTag.SwitchStmt);
		this.name = name;
		this.condition = condition;
		this.cases = cases;
		this.caseDefault = caseDefault;
	}
}

class CaseStmt : Statement
{
	struct CaseCond
	{
		Expression exp;
		uint dynJump;
	}

	CaseCond[] conditions;
	Expression highRange;
	Statement code;

	this(CompileLoc location, CompileLoc endLocation, CaseCond[] conditions, Expression highRange, Statement code)
	{
		super(location, endLocation, AstTag.CaseStmt);
		this.conditions = conditions;
		this.highRange = highRange;
		this.code = code;
	}
}

class DefaultStmt : Statement
{
	Statement code;

	this(CompileLoc location, CompileLoc endLocation, Statement code)
	{
		super(location, endLocation, AstTag.DefaultStmt);
		this.code = code;
	}
}

class ContinueStmt : Statement
{
	char[] name;

	this(CompileLoc location, char[] name)
	{
		super(location, location, AstTag.ContinueStmt);
		this.name = name;
	}
}

class BreakStmt : Statement
{
	char[] name;

	this(CompileLoc location, char[] name)
	{
		super(location, location, AstTag.BreakStmt);
		this.name = name;
	}
}

class ReturnStmt : Statement
{
	Expression[] exprs;

	this(CompileLoc location, CompileLoc endLocation, Expression[] exprs)
	{
		super(location, endLocation, AstTag.ReturnStmt);
		this.exprs = exprs;
	}
}

class TryCatchStmt : Statement
{
	struct CatchClause
	{
		Identifier catchVar;
		Expression[] exTypes;
		Statement catchBody;
	}

	Statement tryBody;
	CatchClause[] catches;
	Identifier hiddenCatchVar;
	Statement transformedCatch;

	this(CompileLoc location, CompileLoc endLocation, Statement tryBody, CatchClause[] catches)
	{
		super(location, endLocation, AstTag.TryCatchStmt);

		this.tryBody = tryBody;
		this.catches = catches;
	}
}

class TryFinallyStmt : Statement
{
	Statement tryBody;
	Statement finallyBody;

	this(CompileLoc location, CompileLoc endLocation, Statement tryBody, Statement finallyBody)
	{
		super(location, endLocation, AstTag.TryFinallyStmt);

		this.tryBody = tryBody;
		this.finallyBody = finallyBody;
	}
}

class ThrowStmt : Statement
{
	Expression exp;
	bool rethrowing;

	this(CompileLoc location, Expression exp, bool rethrowing = false)
	{
		super(location, exp.endLocation, AstTag.ThrowStmt);
		this.exp = exp;
		this.rethrowing = rethrowing;
	}
}

class ScopeActionStmt : Statement
{
	enum
	{
		Exit,
		Success,
		Failure
	}

	ubyte type;
	Statement stmt;

	this(CompileLoc location, ubyte type, Statement stmt)
	{
		super(location, stmt.endLocation, AstTag.ScopeActionStmt);
		this.type = type;
		this.stmt = stmt;
	}
}

class AssignStmt : Statement
{
	Expression[] lhs;
	Expression[] rhs;

	this(CompileLoc location, CompileLoc endLocation, Expression[] lhs, Expression[] rhs)
	{
		super(location, endLocation, AstTag.AssignStmt);
		this.lhs = lhs;
		this.rhs = rhs;
	}
}

abstract class OpAssignStmt : Statement
{
	Expression lhs;
	Expression rhs;

	this(CompileLoc location, CompileLoc endLocation, AstTag type, Expression lhs, Expression rhs)
	{
		super(location, endLocation, type);
		this.lhs = lhs;
		this.rhs = rhs;
	}
}

class AddAssignStmt : OpAssignStmt
{
	this(CompileLoc location, CompileLoc endLocation, Expression lhs, Expression rhs)
	{
		super(location, endLocation, AstTag.AddAssignStmt, lhs, rhs);
	}
}

class SubAssignStmt : OpAssignStmt
{
	this(CompileLoc location, CompileLoc endLocation, Expression lhs, Expression rhs)
	{
		super(location, endLocation, AstTag.SubAssignStmt, lhs, rhs);
	}
}

class CatAssignStmt : Statement
{
	Expression lhs;
	Expression rhs;
	Expression[] operands;
	bool collapsed = false;

	this(CompileLoc location, CompileLoc endLocation, Expression lhs, Expression rhs)
	{
		super(location, endLocation, AstTag.CatAssignStmt);
		this.lhs = lhs;
		this.rhs = rhs;
	}
}

class MulAssignStmt : OpAssignStmt
{
	this(CompileLoc location, CompileLoc endLocation, Expression lhs, Expression rhs)
	{
		super(location, endLocation, AstTag.MulAssignStmt, lhs, rhs);
	}
}

class DivAssignStmt : OpAssignStmt
{
	this(CompileLoc location, CompileLoc endLocation, Expression lhs, Expression rhs)
	{
		super(location, endLocation, AstTag.DivAssignStmt, lhs, rhs);
	}
}

class ModAssignStmt : OpAssignStmt
{
	this(CompileLoc location, CompileLoc endLocation, Expression lhs, Expression rhs)
	{
		super(location, endLocation, AstTag.ModAssignStmt, lhs, rhs);
	}
}

class OrAssignStmt : OpAssignStmt
{
	this(CompileLoc location, CompileLoc endLocation, Expression lhs, Expression rhs)
	{
		super(location, endLocation, AstTag.OrAssignStmt, lhs, rhs);
	}
}

class XorAssignStmt : OpAssignStmt
{
	this(CompileLoc location, CompileLoc endLocation, Expression lhs, Expression rhs)
	{
		super(location, endLocation, AstTag.XorAssignStmt, lhs, rhs);
	}
}

class AndAssignStmt : OpAssignStmt
{
	this(CompileLoc location, CompileLoc endLocation, Expression lhs, Expression rhs)
	{
		super(location, endLocation, AstTag.AndAssignStmt, lhs, rhs);
	}
}

class ShlAssignStmt : OpAssignStmt
{
	this(CompileLoc location, CompileLoc endLocation, Expression lhs, Expression rhs)
	{
		super(location, endLocation, AstTag.ShlAssignStmt, lhs, rhs);
	}
}

class ShrAssignStmt : OpAssignStmt
{
	this(CompileLoc location, CompileLoc endLocation, Expression lhs, Expression rhs)
	{
		super(location, endLocation, AstTag.ShrAssignStmt, lhs, rhs);
	}
}

class UShrAssignStmt : OpAssignStmt
{
	this(CompileLoc location, CompileLoc endLocation, Expression lhs, Expression rhs)
	{
		super(location, endLocation, AstTag.UShrAssignStmt, lhs, rhs);
	}
}

class CondAssignStmt : OpAssignStmt
{
	this(CompileLoc location, CompileLoc endLocation, Expression lhs, Expression rhs)
	{
		super(location, endLocation, AstTag.CondAssignStmt, lhs, rhs);
	}
}

class IncStmt : Statement
{
	Expression exp;

	this(CompileLoc location, CompileLoc endLocation, Expression exp)
	{
		super(location, endLocation, AstTag.IncStmt);
		this.exp = exp;
	}
}

class DecStmt : Statement
{
	Expression exp;

	this(CompileLoc location, CompileLoc endLocation, Expression exp)
	{
		super(location, endLocation, AstTag.DecStmt);
		this.exp = exp;
	}
}

class TypecheckStmt : Statement
{
	FuncDef def;

	this(CompileLoc location, FuncDef def)
	{
		super(location, location, AstTag.TypecheckStmt);
		this.def = def;
	}
}

abstract class Expression : AstNode
{
	char[] sourceStr;

	this(CompileLoc location, CompileLoc endLocation, AstTag type)
	{
		super(location, endLocation, type);
	}

	void checkToNothing(ICompiler c)
	{
		if(!hasSideEffects())
			c.loneStmtException(location, "{} cannot exist on its own", niceString());
	}

	bool hasSideEffects()
	{
		return false;
	}

	void checkMultRet(ICompiler c)
	{
		if(!isMultRet())
			c.semException(location, "{} cannot be the source of a multi-target assignment", niceString());
	}

	bool isMultRet()
	{
		return false;
	}

	void checkLHS(ICompiler c)
	{
		if(!isLHS())
			c.semException(location, "{} cannot be the target of an assignment", niceString());
	}

	bool isLHS()
	{
		return false;
	}

	bool isConstant()
	{
		return false;
	}

	bool isNull()
	{
		return false;
	}

	bool isBool()
	{
		return false;
	}

	bool asBool()
	{
		assert(false);
	}

	bool isInt()
	{
		return false;
	}

	crocint asInt()
	{
		assert(false);
	}

	bool isFloat()
	{
		return false;
	}

	crocfloat asFloat()
	{
		assert(false);
	}

	bool isString()
	{
		return false;
	}

	char[] asString()
	{
		assert(false);
	}

	bool isTrue()
	{
		return false;
	}
}

class CondExp : Expression
{
	Expression cond;
	Expression op1;
	Expression op2;

	this(CompileLoc location, CompileLoc endLocation, Expression cond, Expression op1, Expression op2)
	{
		super(location, endLocation, AstTag.CondExp);
		this.cond = cond;
		this.op1 = op1;
		this.op2 = op2;
	}

	override bool hasSideEffects()
	{
		return cond.hasSideEffects() || op1.hasSideEffects() || op2.hasSideEffects();
	}
}

abstract class BinaryExp : Expression
{
	Expression op1;
	Expression op2;

	this(CompileLoc location, CompileLoc endLocation, AstTag type, Expression op1, Expression op2)
	{
		super(location, endLocation, type);
		this.op1 = op1;
		this.op2 = op2;
	}
}

const BinExpMixin =
"public this(CompileLoc location, CompileLoc endLocation, Expression left, Expression right)"
"{"
	"super(location, endLocation, mixin(\"AstTag.\" ~ typeof(this).stringof), left, right);"
"}";

class OrOrExp : BinaryExp
{
	mixin(BinExpMixin);

	override bool hasSideEffects()
	{
		return op1.hasSideEffects() || op2.hasSideEffects();
	}
}

class AndAndExp : BinaryExp
{
	mixin(BinExpMixin);

	override bool hasSideEffects()
	{
		return op1.hasSideEffects() || op2.hasSideEffects();
	}
}

class OrExp : BinaryExp
{
	mixin(BinExpMixin);
}

class XorExp : BinaryExp
{
	mixin(BinExpMixin);
}

class AndExp : BinaryExp
{
	mixin(BinExpMixin);
}

abstract class BaseEqualExp : BinaryExp
{
	this(CompileLoc location, CompileLoc endLocation, AstTag type, Expression left, Expression right)
	{
		super(location, endLocation, type, left, right);
	}
}

class EqualExp : BaseEqualExp
{
	mixin(BinExpMixin);
}

class NotEqualExp : BaseEqualExp
{
	mixin(BinExpMixin);
}

class IsExp : BaseEqualExp
{
	mixin(BinExpMixin);
}

class NotIsExp : BaseEqualExp
{
	mixin(BinExpMixin);
}

class InExp : BaseEqualExp
{
	mixin(BinExpMixin);
}

class NotInExp : BaseEqualExp
{
	mixin(BinExpMixin);
}

abstract class BaseCmpExp : BinaryExp
{
	this(CompileLoc location, CompileLoc endLocation, AstTag type, Expression left, Expression right)
	{
		super(location, endLocation, type, left, right);
	}
}

class LTExp : BaseCmpExp
{
	mixin(BinExpMixin);
}

class LEExp : BaseCmpExp
{
	mixin(BinExpMixin);
}

class GTExp : BaseCmpExp
{
	mixin(BinExpMixin);
}

class GEExp : BaseCmpExp
{
	mixin(BinExpMixin);
}

class Cmp3Exp : BinaryExp
{
	mixin(BinExpMixin);
}

class AsExp : BinaryExp
{
	mixin(BinExpMixin);
}

class ShlExp : BinaryExp
{
	mixin(BinExpMixin);
}

class ShrExp : BinaryExp
{
	mixin(BinExpMixin);
}

class UShrExp : BinaryExp
{
	mixin(BinExpMixin);
}

class AddExp : BinaryExp
{
	mixin(BinExpMixin);
}

class SubExp : BinaryExp
{
	mixin(BinExpMixin);
}

class CatExp : BinaryExp
{
	Expression[] operands;
	bool collapsed = false;

	mixin(BinExpMixin);
}

class MulExp : BinaryExp
{
	mixin(BinExpMixin);
}

class DivExp : BinaryExp
{
	mixin(BinExpMixin);
}

class ModExp : BinaryExp
{
	mixin(BinExpMixin);
}

abstract class UnExp : Expression
{
	Expression op;

	this(CompileLoc location, CompileLoc endLocation, AstTag type, Expression operand)
	{
		super(location, endLocation, type);
		op = operand;
	}
}

const UnExpMixin =
"public this(CompileLoc location, Expression operand)"
"{"
	"super(location, operand.endLocation, mixin(\"AstTag.\" ~ typeof(this).stringof), operand);"
"}";

class NegExp : UnExp
{
	mixin(UnExpMixin);
}

class NotExp : UnExp
{
	mixin(UnExpMixin);
}

class ComExp : UnExp
{
	mixin(UnExpMixin);
}

class LenExp : UnExp
{
	mixin(UnExpMixin);

	override bool isLHS()
	{
		return true;
	}
}

abstract class PostfixExp : UnExp
{
	this(CompileLoc location, CompileLoc endLocation, AstTag type, Expression operand)
	{
		super(location, endLocation, type, operand);
	}
}

class DotExp : PostfixExp
{
	Expression name;

	this(Expression operand, Expression name)
	{
		super(operand.location, name.endLocation, AstTag.DotExp, operand);
		this.name = name;
	}

	override bool isLHS()
	{
		return true;
	}
}

class DotSuperExp : PostfixExp
{
	this(CompileLoc endLocation, Expression operand)
	{
		super(operand.location, endLocation, AstTag.DotSuperExp, operand);
	}
}

class IndexExp : PostfixExp
{
	Expression index;

	this(CompileLoc endLocation, Expression operand, Expression index)
	{
		super(operand.location, endLocation, AstTag.IndexExp, operand);
		this.index = index;
	}

	override bool isLHS()
	{
		return true;
	}
}

class SliceExp : PostfixExp
{
	Expression loIndex;
	Expression hiIndex;

	this(CompileLoc endLocation, Expression operand, Expression loIndex, Expression hiIndex)
	{
		super(operand.location, endLocation, AstTag.SliceExp, operand);
		this.loIndex = loIndex;
		this.hiIndex = hiIndex;
	}

	override bool isLHS()
	{
		return true;
	}
}

class CallExp : PostfixExp
{
	Expression context;
	Expression[] args;

	this(CompileLoc endLocation, Expression operand, Expression context, Expression[] args)
	{
		super(operand.location, endLocation, AstTag.CallExp, operand);
		this.context = context;
		this.args = args;
	}

	override bool hasSideEffects()
	{
		return true;
	}

	override bool isMultRet()
	{
		return true;
	}
}

class MethodCallExp : PostfixExp
{
	Expression method;
	Expression[] args;
	bool isSuperCall;

	this(CompileLoc location, CompileLoc endLocation, Expression operand, Expression method, Expression[] args, bool isSuperCall)
	{
		super(location, endLocation, AstTag.MethodCallExp, operand);
		this.method = method;
		this.args = args;
		this.isSuperCall = isSuperCall;
	}

	override bool hasSideEffects()
	{
		return true;
	}

	override bool isMultRet()
	{
		return true;
	}
}

class PrimaryExp : Expression
{
	this(CompileLoc location, AstTag type)
	{
		super(location, location, type);
	}

	this(CompileLoc location, CompileLoc endLocation, AstTag type)
	{
		super(location, endLocation, type);
	}
}

class IdentExp : PrimaryExp
{
	Identifier name;

	this(Identifier i)
	{
		super(i.location, AstTag.IdentExp);
		this.name = i;
	}

	override bool isLHS()
	{
		return true;
	}
}

class ThisExp : PrimaryExp
{
	this(CompileLoc location)
	{
		super(location, AstTag.ThisExp);
	}
}

class NullExp : PrimaryExp
{
	this(CompileLoc location)
	{
		super(location, AstTag.NullExp);
	}

	override bool isConstant()
	{
		return true;
	}

	override bool isTrue()
	{
		return false;
	}

	override bool isNull()
	{
		return true;
	}
}

class BoolExp : PrimaryExp
{
	bool value;

	this(CompileLoc location, bool value)
	{
		super(location, AstTag.BoolExp);
		this.value = value;
	}

	override bool isConstant()
	{
		return true;
	}

	override bool isTrue()
	{
		return value;
	}

	override bool isBool()
	{
		return true;
	}

	override bool asBool()
	{
		return value;
	}
}

class VarargExp : PrimaryExp
{
	this(CompileLoc location)
	{
		super(location, AstTag.VarargExp);
	}

	bool isMultRet()
	{
		return true;
	}
}

class VargLenExp : PrimaryExp
{
	this(CompileLoc location, CompileLoc endLocation)
	{
		super(location, endLocation, AstTag.VargLenExp);
	}
}

class VargIndexExp : PrimaryExp
{
	Expression index;

	this(CompileLoc location, CompileLoc endLocation, Expression index)
	{
		super(location, endLocation, AstTag.VargIndexExp);
		this.index = index;
	}

	override bool isLHS()
	{
		return true;
	}
}

class VargSliceExp : PrimaryExp
{
	Expression loIndex;
	Expression hiIndex;

	this(CompileLoc location, CompileLoc endLocation, Expression loIndex, Expression hiIndex)
	{
		super(location, endLocation, AstTag.VargSliceExp);
		this.loIndex = loIndex;
		this.hiIndex = hiIndex;
	}

	override bool isMultRet()
	{
		return true;
	}
}

class IntExp : PrimaryExp
{
	crocint value;

	this(CompileLoc location, crocint value)
	{
		super(location, AstTag.IntExp);
		this.value = value;
	}

	override bool isConstant()
	{
		return true;
	}

	override bool isTrue()
	{
		return (value != 0);
	}

	override bool isInt()
	{
		return true;
	}

	override crocint asInt()
	{
		return value;
	}

	override crocfloat asFloat()
	{
		return cast(crocfloat)value;
	}
}

class FloatExp : PrimaryExp
{
	crocfloat value;

	this(CompileLoc location, crocfloat value)
	{
		super(location, AstTag.FloatExp);
		this.value = value;
	}

	override bool isConstant()
	{
		return true;
	}

	override bool isTrue()
	{
		return (value != 0.0);
	}

	override bool isFloat()
	{
		return true;
	}

	override crocfloat asFloat()
	{
		return value;
	}
}

class StringExp : PrimaryExp
{
	char[] value;

	this(CompileLoc location, char[] value)
	{
		super(location, AstTag.StringExp);
		this.value = value;
	}

	override bool isConstant()
	{
		return true;
	}

	override bool isTrue()
	{
		return true;
	}

	override bool isString()
	{
		return true;
	}

	override char[] asString()
	{
		return value;
	}
}

class FuncLiteralExp : PrimaryExp
{
	FuncDef def;

	this(CompileLoc location, FuncDef def)
	{
		super(location, def.endLocation, AstTag.FuncLiteralExp);
		this.def = def;
	}
}

class ClassLiteralExp : PrimaryExp
{
	ClassDef def;

	this(CompileLoc location, ClassDef def)
	{
		super(location, def.endLocation, AstTag.ClassLiteralExp);
		this.def = def;
	}
}

class ParenExp : PrimaryExp
{
	Expression exp;

	this(CompileLoc location, CompileLoc endLocation, Expression exp)
	{
		super(location, endLocation, AstTag.ParenExp);
		this.exp = exp;
	}
}

class TableCtorExp : PrimaryExp
{
	struct Field
	{
		Expression key;
		Expression value;
	}

	Field[] fields;

	this(CompileLoc location, CompileLoc endLocation, Field[] fields)
	{
		super(location, endLocation, AstTag.TableCtorExp);
		this.fields = fields;
	}
}

class ArrayCtorExp : PrimaryExp
{
	Expression[] values;

	protected const uint maxFields = Instruction.MaxArrayFields;

	this(CompileLoc location, CompileLoc endLocation, Expression[] values)
	{
		super(location, endLocation, AstTag.ArrayCtorExp);
		this.values = values;
	}
}

class NamespaceCtorExp : PrimaryExp
{
	NamespaceDef def;

	this(CompileLoc location, NamespaceDef def)
	{
		super(location, def.endLocation, AstTag.NamespaceCtorExp);
		this.def = def;
	}
}

class YieldExp : PrimaryExp
{
	Expression[] args;

	this(CompileLoc location, CompileLoc endLocation, Expression[] args)
	{
		super(location, endLocation, AstTag.YieldExp);
		this.args = args;
	}

	bool hasSideEffects()
	{
		return true;
	}

	bool isMultRet()
	{
		return true;
	}
}

abstract class ForComprehension : AstNode
{
	IfComprehension ifComp;
	ForComprehension forComp;

	this(CompileLoc location, CompileLoc endLocation, AstTag tag)
	{
		super(location, endLocation, tag);
	}
}

class ForeachComprehension : ForComprehension
{
	Identifier[] indices;
	Expression[] container;

	this(CompileLoc location, Identifier[] indices, Expression[] container, IfComprehension ifComp, ForComprehension forComp)
	{
		if(ifComp)
		{
			if(forComp)
				super(location, forComp.endLocation, AstTag.ForeachComprehension);
			else
				super(location, ifComp.endLocation, AstTag.ForeachComprehension);
		}
		else if(forComp)
			super(location, forComp.endLocation, AstTag.ForeachComprehension);
		else
			super(location, container[$ - 1].endLocation, AstTag.ForeachComprehension);

		this.indices = indices;
		this.container = container;
		this.ifComp = ifComp;
		this.forComp = forComp;
	}
}

class ForNumComprehension : ForComprehension
{
	Identifier index;
	Expression lo;
	Expression hi;
	Expression step;

	this(CompileLoc location, Identifier index, Expression lo, Expression hi, Expression step, IfComprehension ifComp, ForComprehension forComp)
	{
		if(ifComp)
		{
			if(forComp)
				super(location, forComp.endLocation, AstTag.ForNumComprehension);
			else
				super(location, ifComp.endLocation, AstTag.ForNumComprehension);
		}
		else if(forComp)
			super(location, forComp.endLocation, AstTag.ForNumComprehension);
		else if(step)
			super(location, step.endLocation, AstTag.ForNumComprehension);
		else
			super(location, hi.endLocation, AstTag.ForNumComprehension); // NOT REACHABLE

		this.index = index;
		this.lo = lo;
		this.hi = hi;
		this.step = step;

		this.ifComp = ifComp;
		this.forComp = forComp;
	}
}

class IfComprehension : AstNode
{
	Expression condition;

	this(CompileLoc location, Expression condition)
	{
		super(location, condition.endLocation, AstTag.IfComprehension);
		this.condition = condition;
	}
}

class ArrayComprehension : PrimaryExp
{
	Expression exp;
	ForComprehension forComp;

	this(CompileLoc location, CompileLoc endLocation, Expression exp, ForComprehension forComp)
	{
		super(location, endLocation, AstTag.ArrayComprehension);

		this.exp = exp;
		this.forComp = forComp;
	}
}

class TableComprehension : PrimaryExp
{
	Expression key;
	Expression value;
	ForComprehension forComp;

	this(CompileLoc location, CompileLoc endLocation, Expression key, Expression value, ForComprehension forComp)
	{
		super(location, endLocation, AstTag.TableComprehension);

		this.key = key;
		this.value = value;
		this.forComp = forComp;
	}
}