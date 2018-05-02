local m = require 'lpeg'

local Sp = m.S" \t"^0
local Id = m.R("az", "AZ", "09")^1
local Endline = m.P'\n'
local EOF = -m.P(1)
local V = m.V
local P = m.P

local ARROW = Sp * (m.P"->" + m.P"<-")
local SLASH = Sp * m.P"/"
local AND = Sp * m.P"&"
local NOT = Sp * m.P"!"
local STAR = Sp * m.P"*"
local PLUS = Sp * m.P"+"
local QUEST = Sp * m.P"?"
local GT = Sp * m.P">"
local LT = Sp * m.P"<"

local fail = "fail"

local g
local res
local rules

local function parse (s)
	res = {}
  rules = {}
	g:match(s)
	return res
end

local function makerule (v, p)
	res[v] = p
  rules[#rules+1] = v
end

local function makeexp (kind, p1, p2, f)
	return { kind=kind, p1=p1, p2=p2, f=f }
end

local function makev (kind, v)
	return { kind=kind, v=v }
end

local function makeord (p1, p2)
	return makeexp("ord", p1, p2)
end

local function makeordlab (p1, f, p2)
	--print("makeord ", p1, f, p2)
	return makeexp("ord", p1, p2, f)
end

local function makecon (p1, p2)
	return makeexp("con", p1, p2)
end

local function makeand (p1)
	return makeexp("and", p1)
end

local function makenot (p1)
	return makeexp("not", p1)
end

local function makestar (p1)
	return makeexp("star", p1)
end

local function makeplus (p1)
	return makeexp("plus", p1)
end

local function makeopt (p1)
	return makeexp("opt", p1)
end

local function makecon (p1, p2)
	return makeexp("con", p1, p2)
end

local function makeand (p1)
	return makeexp("and", p1)
end

local function makenot (p1)
	return makeexp("not", p1)
end

local function makestar (p1)
	return makeexp("star", p1)
end

local function makeplus (p1)
	return makeexp("plus", p1)
end

local function makelit (v)
	return makev("char", v)
end

local function makeany ()
	return makev("any", nil)
end

local function makevar (v)
	return makev("var", v)
end

local function makethrow (v)
	return makev("throw", v)
end

local function makeempty ()
	return makev("empty")
end

g = m.P{
	"Grammar",
	Grammar = Sp * V"Rule"^1,
	Rule = Sp * (m.C(Id) * ARROW * V"Exp") / makerule * Sp * (Endline + EOF),
	Exp = (V"Con" * SLASH * V"Label" *  V"Exp") / makeordlab  +  V"Con",
	Label = Sp * "{" * Sp * m.C(Id) * Sp * "}"  +  m.P""/"fail",
	Con = (V"Pred" * V"Con") / makecon  +  V"Pred",
	Pred = NOT * V"Rep" / makenot  +  AND * V"Rep" / makeand  +  V"Rep",
	Rep = (V"Elem" * STAR) / makestar  +  (V"Elem" * PLUS) / makeplus  + (V"Elem" * QUEST) / makeopt  +  V"Elem",
	Elem = V"Lit"  +  V"Var"  +  V"Throw"  +  V"Any" + V"Empty" + V"ExpPar",
	Lit = Sp * "'" * m.C((m.P(1) - "'")^1) / makelit * "'" * Sp,
	Var = Sp * LT * m.C(Id) / makevar * GT,
	Throw = Sp * "%" * Sp * m.C(Id) / makethrow, 
	Any = Sp * "." / makeany,
	Empty = Sp * m.C(m.P"'" * m.P"'") / makeempty,
	ExpPar = Sp * "(" * V"Exp" * Sp * ")",
}

--[=[local s = [[
S -> 'abc'*  /  !'ab' &'c'
A -> !'s'* / '' <x>]]

print(parse(s))
]=]


local function turnleft_aux (left, right, f)
	if right.kind == "ord" then
		local p1 = makeordlab(left, f, right.p1)
		return turnleft_aux(p1, right.p2, right.f)
	else
		return makeordlab(left, f, right)
	end
end


local function turnleft_first (p)
	if p.kind == "ord" then
		return turnleft_aux(p.p1, p.p2, p.f)
	else -- does look inside p (does not work for p1 (p2 / p3 / p4)
		return p
	end
end

local function turnleft (g)
	local g2 = {}
	for k, v in pairs(g) do
		g2[k] = turnleft_first(v)
	end
	return g2
end

local function getrules (g)
	return rules
end


return {
	parse = parse,
	getrules = getrules,
	makeord = makeord,
	makecon = makecon,
	makeand = makeand,
	makenot = makenot,
	makestar = makestar,
	makeplus = makeplus,
	makeopt = makeopt,
	makelit = makelit,
	makeany = makeany,
	makevar = makevar,
	makeempty = makeempty,
	makethrow = makethrow,
	turnleft = turnleft,
	fail = fail,
}
