-- Implementa a nova semântica de labels onde uma falha
-- é um par (label, restoDaEntrada)

local m = require "lpeg"
local compile = require 'peggrammar'
local first = require'first'

local makeord = compile.makeord
local makethrow = compile.makethrow
local makecon = compile.makecon
local makenot = compile.makenot
local makestar = compile.makestar
local makeopt = compile.makeopt
local makeplus = compile.makeplus
local makeany = compile.makeany
local makevar = compile.makevar
local fail = compile.fail
local calcfirst = first.calcfirst
local disjoint = first.disjoint
local set2choice = first.set2choice
local matchEmpty = first.matchEmpty
local ierr
local gerr

local function adderror (p, flw)
  local s = 'Err_' .. string.format("%03d", ierr)
	local pred = makenot(set2choice(flw))
  gerr[s] = makestar(makecon(pred, makeany()))
	ierr = ierr + 1
	return makeord(p, makethrow(s))
end

local function makeFailure (f, s)
	return { f = f, s = s }
end

local function isSimple (p)
	return p.kind == 'empty' or p.kind == 'char' or
         p.kind == 'any' or p.kind == 'var' or
				 p.kind == 'throw'
end

local function rep_symb (p)
	if p.kind == 'star' then
		return '*'
	elseif p.kind == 'plus' then
		return '+'
	else
		return '?'
	end
end

function addlab_aux (g, p, seq, flw)
  --io.write(p.kind .. " add_lab_aux: ")
  --for k, v in pairs(flw) do
  --  io.write(k .. ' ')
  --end
  --if flw[''] then io.write('empty') end
  --io.write('\n')
	if (p.kind == 'var' or p.kind == 'char' or p.kind == 'any') and seq then
    if p.kind == 'var' and matchEmpty(g, p) then
			return p
		else
			return adderror(p, flw)
		end
	elseif p.kind == 'con' then
		if seq then
			if p.p1.kind == 'ord' then
				local k = calck(g, p.p1.p2, calck(g, p.p2, flw))
				if disjoint(calcfirst(p.p1.p1), k) then
				--if disjoint(calcfirst(g, p.p1.p1), calcfirst(g, p.p1.p2)) then
					return makecon(addlab_aux(g, p.p1, seq, k), addlab_aux(g, p.p2, seq, flw))
				else
					return makecon(adderror(p.p1, flw), addlab_aux(g, p.p2, seq, flw)) --TODO: flw ou k em adderror?
				end
			else
        --local tmp = calck(g, p.p2, flw)
        --print("con else seq", p.p1.kind, p.p2.kind, tmp[')'], tmp['X'])
				return makecon(addlab_aux(g, p.p1, seq, calck(g, p.p2, flw)), addlab_aux(g, p.p2, seq, flw))
			end
    elseif p.p1.kind == 'star' then
			return makecon(addlab_aux(g, p.p1, seq, calck(g, p.p2, flw)), addlab_aux(g, p.p2, seq, flw))
		elseif matchEmpty(g, p.p1) then
			return makecon(p.p1, addlab_aux(g, p.p2, false, flw))
		else
			return makecon(p.p1, addlab_aux(g, p.p2, true, flw))
		end
	elseif p.kind == 'ord' then
		local p1 = addlab_aux(g, p.p1, false, flw)
		local p2 = addlab_aux(g, p.p2, false, flw)		
		if seq then --and p.p2.kind ~= 'empty' then -- FIRST(p1) \cap FIRST(p2) = \empty
			return adderror(makeord(p1, p2), flw)	
		--elseif not seq and disjoint(calcfirst(g, p.p1), calcfirst(g, p.p2)) then
		elseif disjoint(calcfirst(p.p1), calck(g, p.p2, flw)) then
			return makeord(p1, p2)
		else
			return p
		end
	--elseif (p.kind == 'star' or p.kind == 'opt') and seq and disjoint(calcfirst(g, p.p1), flw) then
	elseif (p.kind == 'star' or p.kind == 'opt' or p.kind == 'plus') and disjoint(calcfirst(p.p1), flw) then
		local newp
    --if seq then
    if true then
      local p1 = addlab_aux(g, p.p1, false, flw)
      local s = 'Err_' .. string.format("%03d", ierr) .. '_Flw'
      gerr[s] = set2choice(flw)
      newp = makecon(makenot(makevar(s)), adderror(p1, flw))
    else
      newp = addlab_aux(g, p.p1, false, flw)
    end
    if p.kind == 'star' then
			return makestar(newp)
		elseif p.kind == 'opt' then
			return makeopt(newp)
    else --plus
      if seq then
				return adderror(makeplus(newp), flw)
			else
				return makeplus(newp)
			end
		end
	else
		return p
	end
end

function addlab (g, flw, rules)
	local newg = {}
	ierr = 1
	for i, v in ipairs(rules) do
		newg[v] = addlab_aux(g, g[v], false, flw[v])
	end
	return newg
end

function printg_aux (p)
	if p.kind == 'empty' then
		return "''"       -- empty.1
	elseif p.kind == "char" then
		return "'" .. p.v .. "'"
	elseif p.kind == 'any' then
		return '.'
	elseif p.kind == "con" then
		local s1 = printg_aux(p.p1)
		local s2 = printg_aux(p.p2)
		local s = s1
		if p.p1.kind == 'ord' and (p.p1.p2.kind ~= 'throw') then
			s = '(' .. s .. ')'
		end
		if p.p2.kind == 'ord' and (p.p2.p2.kind ~= 'throw') then
			s = s .. ' (' .. s2 .. ')'
		else
			s = s .. ' ' .. s2
		end
		return s 
	elseif p.kind == "ord" then
		local s1 = printg_aux(p.p1)
		local s2 = printg_aux(p.p2)
		if p.p2.kind == 'throw' then
			return '[' .. s1 .. ']^' .. string.sub(s2, 2)
		else 
			return  s1 .. '  /  ' .. s2
		end
	elseif p.kind == "star" or p.kind == 'plus' or p.kind == 'opt' then
		local s = printg_aux(p.p1)
		if isSimple(p.p1) then
			return s .. rep_symb(p)
		else
			return '(' .. s .. ')' .. rep_symb(p)
		end
	elseif p.kind == "not" then
		local s = printg_aux(p.p1)
		if isSimple(p.p1) then
			return '!' ..	s
		else
			return '!(' .. s .. ')'
		end
  elseif p.kind == "var" then
		return p.v	
	elseif p.kind == "throw" then
		return '%' .. p.v
	else
		print(p, p.kind)
		error ("Regra desconhecida: " .. tostring(p))	
	end
end

function printg (g, rules)
	if rules then
		for i, v in ipairs(rules) do
			print(v, "<-", printg_aux(g[v]))
		end
	else
		local t = {}
		for k, _ in pairs(g) do
			table.insert(t, k)
		end
		table.sort(t)
		for i, v in ipairs(t) do
			print(v, "<-", printg_aux(g[v]))
		end
	end
end

function match(g, p, s, i)
	--print("kind = ", p.kind)
	if p.kind == 'empty' then
		return i       -- empty.1
	elseif p.kind == "char" then
		local n = #p.v
		if string.sub(s, i, i + n - 1) == p.v then
			return i + n   -- ch.1
		else
			return nil, makeFailure(fail, s)  -- ch.2, ch.3
		end
	elseif p.kind == 'any' then
		if i <= #s then
			return i + 1
		else
			return nil, makeFailure(fail, s)
		end
	elseif p.kind == "con" then
		local j, f = match(g, p.p1, s, i)
		if j == nil then 
			return nil, f     -- con.3
		end
		return match(g, p.p2, s, j) -- con.1, con.2
	elseif p.kind == "ord" then
		local j, f = match(g, p.p1, s, i)
		--print("ord ", j, f, p.f, f == p.f)
		--if f ~= nil then print("f.f = ", f.f, f.f == p.f) end
		if j ~= nil then
			return j  -- ord.1
		elseif p.f ~= f.f then --ord.2
			return nil, f
		else
			return match(g, p.p2, s, i)  -- ord.3
		end
	elseif p.kind == "star" then
		local j, f = match(g, p.p1, s, i)
		if j == nil then
			if f.f == fail then -- rep.1
				return i
			else  -- rep.3
				return nil, f
			end
		elseif j == i then -- rep.??
			return i
		else
			local k, f = match(g, p, s, j)
			-- could be just  "return match(g, p, s, j)"
			if k == nil then --rep.4
				return k, f
			else
				return k, f--rep.2
			end
		end
	elseif p.kind == "and" then
		local j, f = match(g, p.p1, s, i)
		if j == nil then
			return nil, f  -- and.1(?)
		end
		return i      -- and.2(?)
	elseif p.kind == "not" then
		local j, f = match(g, p.p1, s, i)
		if j == nil then
			if f.f == fail then
				return i         -- not.1
			else
				return nil, f  -- not.3
			end
		end
		return nil, makeFailure(fail, s) -- not.2
	elseif p.kind == "var" then
		local v = g[p.v] 
		if v == nil then
			error ("Gramática não possui regra " .. p.v)
		end
		return match(g, v, s, i)
	elseif p.kind == "throw" then
		--print("throw", p.v)
		return nil, makeFailure(p.v, s)
	else
		print(p, p.kind)
		error ("Regra desconhecida: " .. tostring(p))	
	end
end

local t = {}
function entry(e) 
	table.insert(t, e)	
end

local input = ({...})[1] or "grammars.lua"
local f, e = loadfile(input)

if f then f () else error(e) end

-- for every grammar in table t
for _, e in ipairs(t) do
	
	local g = compile.parse(e.g)
  local rules = compile.getrules()
  gerr = {}
	--printg(g)
	printg(compile.turnleft(g), rules)

  local fst = first.calcFst(g)
	local flw = first.calcFlw(g, e.s)
	print("\nFOLLOW")
	first.printfollow(g)	
	
	local newg = addlab(g, flw, rules)
	print("NewG -----------")
	printg(compile.turnleft(newg), rules)
  printg(compile.turnleft(gerr))
	--printg(newg)
	g = compile.turnleft(g) -- makes "/"left associative
  

	-- let's try to match several inputs
	for _, v in ipairs(e.input) do
		local inp = v[1]  -- the subject 
		local res = v[2]  -- the expected result
	
		local n, f = match(g, compile.makevar(e.s), inp, 1) 
		print (inp, n)
			if f ~= nil then
			print("Label: " .. f.f, "Input: " .. f.s)
		end
	
		if n == nil then n = 0 end	
		assert(n == res, 
					"For input " .. inp .. " the expected result was " .. res .. " but we got " .. tostring(n))
	end
	print()
end

