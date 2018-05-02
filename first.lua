local lpeg = require"lpeg"
local compile = require'peggrammar'
local FOLLOW
local LR
local empty = '' 
local calcf
local makelit = compile.makelit
local makeord = compile.makeord
local printfirst
LOOKAHEAD = 1

math.randomseed(os.time())

local function newvar (p, k)
	return p.v .. sep .. k.v	
end

local function getvar ()
	local s
	repeat
		s = 'v' .. math.random(1, 1000)
	until FOLLOW[s] == nil
	return s
end

local function disjoint (s1, s2)
	for k, _ in pairs(s1) do
		if s2[k] then
			return false
		end
	end
	return true
end

local function union (s1, s2, notEmpty)
	local s3 = {}
	for k, _ in pairs(s1) do
		s3[k] = true
	end
	for k, _ in pairs(s2) do
		s3[k] = true
	end
  if notEmpty then
		s3[empty] = nil
	end	
	return s3
end

local function concatfirst (s1, s2)
	local k
	if next(s2) == nil then
		return s1
	end
	if next(s1) == nil then
		return s2
	end
	if LOOKAHEAD == nil then
		k = 1
	else
		k = LOOKAHEAD
	end
	local s3 = {}
	for x, _ in pairs(s1) do
		if #x >= k then
			s3[x] = true
		else 
			for y, _ in pairs(s2) do
				--local z = string.sub(x .. y, 1, k)
        local z = x .. y
				s3[z] = true
			end
		end
	end
	return s3
end	

local function string2concat (x)
	return makelit(x)
	--[[if #x == 1 then
		return makelit(x)
	else
		return makelit(string2concat(string.sub(x, 1, 1)), string2concat(string.sub(x, 2))) 
	end]]
end

local function set2string(s)
	local t = {}
	for k, _ in pairs(s) do
		t[#t+1] = k
	end
	table.sort(t)
	local x = ''
	for i, v in ipairs(t) do
		x = x .. ', ' .. v  
	end
	return '(' .. string.sub(x, 3) .. ')'
end

local function sortset(s)
  local r = {}
	for k, _ in pairs(s) do
		table.insert(r, k)
	end
	table.sort(r)
	return r
end

local function set2choice (s)
	local p
  local r = sortset(s)
	for i, v in ipairs(r) do
		if not p then
			p = string2concat(v)
		else
			p = makeord(string2concat(v), p)
		end
	end	
	return p
end

local function matchEmpty (g, p)
	if p.kind == 'empty' or p.kind == 'star' or
     p.kind == 'not' or p.kind == 'and' or p.kind == 'opt' then 
		return true
	elseif p.kind == 'char' or p.kind == 'plus' then
		return false
	elseif p.kind == 'ord' then
		return matchEmpty(g, p.p1) or matchEmpty(g, p.p2)
	elseif p.kind == 'con' then
		if matchEmpty(g, p.p1) then
			return matchEmpty(g, p.p2)
		else
			return false
		end
	elseif p.kind == 'var' then
		return matchEmpty(g, g[p.v])
  else
		error("Unknown kind " .. tostring(p.kind))
	end
end

-- returns true if A is a subset of B
local function issubset (A, B)
	for k, _ in pairs(A) do
		if B[k] == nil then
			return false
		end
	end
	return true
end

function writepeg (p, iscon)
	if p.kind == 'char' then
		return "'" .. p.v .. "'"
	elseif p.kind == 'empty' then
		return "''"
	elseif p.kind == 'var' then
		return p.v
	elseif p.kind == 'ord' then
		local s1 = writepeg(p.p1, false)
		local s2 = writepeg(p.p2, false)
		if iscon then
			return '(' .. s1 .. " / " .. s2 .. ')'
		else
			return s1 .. " / " .. s2
		end
	elseif p.kind == 'con' then
		return writepeg(p.p1, true) .. " " .. writepeg(p.p2, true)
	elseif p.kind == 'and' then
		return '&(' .. writepeg(p.p1)	.. ')'
	else
		error("Unknown kind: " .. p.kind)
	end
end

function makepeg (p)
	if p.kind == 'char' then
		return lpeg.P(p.v)
	elseif p.kind == 'empty' then
		return lpeg.P""
	elseif p.kind == 'ord' then
		return makepeg(p.p1) + makepeg(p.p2)
	elseif p.kind == 'con' then
		return makepeg(p.p1) * makepeg(p.p2)
	elseif p.kind == 'var' then
		return lpeg.V(p.v)
	elseif p.kind == 'and' then
		return #makepeg(p.p1)
	else
		error("Unknown kind: " .. p.kind)
	end
end

local function printfollow (g)
	for k, v in pairs(g) do
		local s = k .. ':'
		local fst = calcfirst(g, v)
		for k, _ in pairs(FOLLOW[k]) do
			s = s .. ' ' .. k
		end
		print(s)
		printfirst(fst) 
	end
end

function printfirst (t)
	local s = ''
	for k, _ in pairs(t) do
		s = s .. ' ' .. k
	end
	print(s) 
end

local function allhavesizek(s)
	if next(s) == nil then
		return false
	end
	for k, _ in pairs(s) do
		if #k < LOOKAHEAD then
			return false
		end
	end
	return true
end

function calcfirst (g, p, s)
  --print("calfirst", p.kind, p.v)
	if not s then
		s = {}
	end
	if p.kind == 'empty' then
		return { [empty] = true }
	elseif p.kind == 'char' then
		return concatfirst(s, { [p.v] = true})
	elseif p.kind == 'ord' then
		return union(calcfirst(g, p.p1, s), calcfirst(g, p.p2, s))
	elseif p.kind == 'con' then
		local s1 = calcfirst(g, p.p1, s)
		if allhavesizek(s1) then
			return s1
		else
			return calcfirst(g, p.p2, s1)
		end
	elseif p.kind == 'var' then
		return calcfirst(g, g[p.v], s)
	elseif p.kind == 'throw' then
		return s
	elseif p.kind == 'any' then
		return { ["any"] = true }
	elseif p.kind == 'not' then
		return s
  -- in case of a well-formed PEG, in a repetition p*, we know p does not match the empty string
	elseif p.kind == 'opt' or p.kind == 'star' then 
    --if p.kind == 'plus' and p.p1.v == 'recordfield' then
    --  print ('danado', p.p1.v)
    --end
		return union(calcfirst(g, p.p1, s), { [empty] = true})
  elseif p.kind == 'plus' then
		return calcfirst(g, p.p1, s)
	else
		error("Unknown kind: " .. p.kind)
	end
end

function updateFollow (g, p, k)
	if p.kind == 'var' then
    local v = p.v
    FOLLOW[v] = union(FOLLOW[v], k, true)
	elseif p.kind == 'con' then
		if p.p1.kind == 'var' and matchEmpty(g, p.p2) then
			updateFollow(g, p.p1, k)
		end
    updateFollow(g, p.p2, k)
	elseif p.kind == 'ord' then
		updateFollow(g, p.p1, k)
		updateFollow(g, p.p2, k)
	end
end


function calck (g, p, k)
	if p.kind == 'empty' then
		return k
	elseif p.kind == 'char' then
		return concatfirst({ [p.v]=true }, k)
	elseif p.kind == 'ord' then
		if not p.v then
			p.v = getvar()
			if p.p2.kind == 'ord' then
				p.p2.v = p.v
			end
			FOLLOW[p.v] = {}
		end
		FOLLOW[p.v] = union(FOLLOW[p.v], k, true)
		local k1 = calck(g, p.p1, k)
		local k2 = calck(g, p.p2, k)
		return union(k1, k2, true)
	elseif p.kind == 'con' then
		local k2 = calck(g, p.p2, k)
		return calck(g, p.p1, k2)
	elseif p.kind == 'var' then
		return calcf(g, p, k)
	elseif p.kind == 'throw' then
		return k
	elseif p.kind == 'any' then
		return concatfirst({ ['.']=true }, k)
	elseif p.kind == 'not' then
		return k 
	elseif p.kind == 'opt' then
		return union(calck(g, p.p1, k), k, true) 
  -- in case of a well-formed PEG a repetition does not match the empty string
	elseif p.kind == 'star' then
    updateFollow(g, p.p1, calcfirst(g, p, {}))
    --if p.p1.kind == 'var' then
    --  local v = p.p1.v
		--	FOLLOW[v] = union(FOLLOW[v], calcfirst(g, g[v], {}), true)
		--end
		return union(calck(g, p.p1, k), k, true)
	elseif p.kind == 'plus' then
    --return calck(g, p.p1, k)
    updateFollow(g, p.p1, calcfirst(g, p, {}))
    --[[if p.p1.kind == 'var' then
      local v = p.p1.v
			FOLLOW[v] = union(FOLLOW[v], calcfirst(g, g[v], {}), true)
		end]]
		--return union(calck(g, p.p1, k), k) 
		return union(calck(g, p.p1, k), k, true)
	else
		error("Unknown kind: " .. p.kind)
	end
end

function calcf (g, p, k)
	if p.kind == 'var' then
		local v = p.v
    --print('calcf ', p.v)
		if issubset(k, FOLLOW[v]) then
			local k2 = calcfirst(g, p, {})
			return concatfirst(k2, k)
		end
		FOLLOW[v] = union(FOLLOW[v], k, true)
		return calck(g, g[v], k)
	else
		error("Unknown kind: " .. p.kind)
	end
end

local function initfollow (g, init)
	FOLLOW = {}
	for k, v in pairs(g) do
		FOLLOW[k] = { }
	end
	FOLLOW[init] = { ['$'] = true }
end

function calcfollow (g, init)
	initfollow(g, init)
	calck(g, g[init], { [string.rep('$', LOOKAHEAD)] = true})
	return FOLLOW
end

return {
	calcfirst = calcfirst,
	calcfollow = calcfollow,
	printfollow = printfollow,
	disjoint = disjoint,
	set2choice = set2choice,
	calck = calck,
	matchEmpty = matchEmpty
}
