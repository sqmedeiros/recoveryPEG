local lpeg = require"lpeg"
local compile = require'peggrammar'
local FIRST
local FOLLOW
local empty = '' 
local calcf
local makelit = compile.makelit
local makeord = compile.makeord
local printfirst, calcfirst, calck


local function disjoint (s1, s2)
	for k, _ in pairs(s1) do
		if s2[k] then
			return false
		end
	end
	return true
end


local function equalSet (s1, s2)
  for k, _ in pairs(s1) do
    if not s2[k] then
      return false
    end
  end
  for k, _ in pairs(s2) do
    if not s1[k] then
      return false
    end
  end
  return true
end


local function union (s1, s2, notEmpty)
	local s3 = {}
  local eq = true
	for k, _ in pairs(s1) do
		s3[k] = true
    if not s2[k] then
      eq = false
    end
	end
	for k, _ in pairs(s2) do
		s3[k] = true
    if not s1[k] then
      eq = false
    end
	end
  if notEmpty then
		s3[empty] = nil
	end	
	return s3, eq
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
			p = makelit(v)
		else
			p = makeord(makelit(v), p)
		end
	end	
	return p
end


local function matchEmpty (g, p)
	if p.kind == 'empty' or p.kind == 'star' or
     p.kind == 'not' or p.kind == 'and' or p.kind == 'opt' then 
		return true
	elseif p.kind == 'char' or p.kind == 'plus' or p.kind == 'any' then
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
		return FIRST[p.v][empty]
  else
		error("Unknown kind " .. tostring(p.kind))
	end
end


local function writepeg (p, iscon)
	if p.kind == 'char' then
		return "'" .. p.v .. "'"
	elseif p.kind == 'empty' then
		return "''"
	elseif p.kind == 'any' then
		return "."
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
	elseif p.kind == 'not' then
		return '!(' .. writepeg(p.p1)	.. ')'
  elseif p.kind == 'opt' then
    return writepeg(p.p1) .. '?'
  elseif p.kind == 'star' then
    return writepeg(p.p1) .. '*'
  elseif p.kind == 'plus' then
    return writepeg(p.p1) .. '+'
	else
		error("Unknown kind: " .. p.kind)
	end
end


local function makepeg (p)
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
		local fst = calcfirst(v)
		for k, _ in pairs(FOLLOW[k]) do
			s = s .. ' ' .. k
		end
		print(s)
    print("FIRST")
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


function calcfirst (p)
	if p.kind == 'empty' then
		return { [empty] = true }
	elseif p.kind == 'char' then
    return { [p.v] = true }
	elseif p.kind == 'ord' then
		return union(calcfirst(p.p1), calcfirst(p.p2))
	elseif p.kind == 'con' then
		local s1 = calcfirst(p.p1)
    local s2 = calcfirst(p.p2)
		if s1[empty] then
      return union(s1, s2, not s2[empty])
		else
			return s1
		end
	elseif p.kind == 'var' then
		return FIRST[p.v]
	elseif p.kind == 'throw' then
		return { }
	elseif p.kind == 'any' then
		return { ["any"] = true }
	elseif p.kind == 'not' then
		return { [empty] = true }
  -- in case of a well-formed PEG, in a repetition p*, we know p does not match the empty string
	elseif p.kind == 'opt' or p.kind == 'star' then 
    --if p.kind == 'plus' and p.p1.v == 'recordfield' then
    --  print ('danado', p.p1.v)
    --end
		return union(calcfirst(p.p1), { [empty] = true})
  elseif p.kind == 'plus' then
		return calcfirst(p.p1)
	else
		error("Unknown kind: " .. p.kind)
	end
end


local function updateFollow (g, p, k)
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
		return { [p.v]=true }
	elseif p.kind == 'ord' then
		local k1 = calck(g, p.p1, k)
		local k2 = calck(g, p.p2, k)
		return union(k1, k2, true)
	elseif p.kind == 'con' then
		local k2 = calck(g, p.p2, k)
		return calck(g, p.p1, k2)
	elseif p.kind == 'var' then
    if matchEmpty(g, p) then
			return union(FIRST[p.v], k, true)
    else
		  return FIRST[p.v]
    end
	elseif p.kind == 'throw' then
		return k
	elseif p.kind == 'any' then
		return { ['.']=true }
	elseif p.kind == 'not' then
		return k 
	elseif p.kind == 'opt' then
		return union(calck(g, p.p1, k), k, true) 
  -- in case of a well-formed PEG a repetition does not match the empty string
	elseif p.kind == 'star' then
    updateFollow(g, p.p1, calcfirst(p, {}))
    --if p.p1.kind == 'var' then
    --  local v = p.p1.v
		--	FOLLOW[v] = union(FOLLOW[v], calcfirst(g, g[v], {}), true)
		--end
		return union(calck(g, p.p1, k), k, true)
	elseif p.kind == 'plus' then
    --return calck(g, p.p1, k)
    updateFollow(g, p.p1, calcfirst(p, {}))
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


local function initFst (g)
  FIRST = {}
  for k, v in pairs(g) do
    FIRST[k] = {}
  end
end


local function calcFst (g)
  local update = true
  local equal
  initFst(g)
	
  while update do
    update = false
    for k, v in pairs(g) do
      FIRST[k], equal = union(FIRST[k], calcfirst(v))
      if not equal then
        update = true
      end
    end
	end

	return FIRST
end


local function initFlw(g, init)
  FOLLOW = {}
  for k, v in pairs(g) do
    FOLLOW[k] = {}
  end
  FOLLOW[init] = { ['$'] = true }
end


local function calcFlwAux (p, flw)
  --print('FlwAux', p.kind, flw[empty], p.v)
  if p.kind == 'var' then
    FOLLOW[p.v] = union(FOLLOW[p.v], flw)
  elseif p.kind == 'con' then
    calcFlwAux(p.p2, flw)
    local k = calcfirst(p.p2)
    --assert(not k[empty] == not matchEmpty({}, p.p2), tostring(k[empty]) .. ' ' .. tostring(matchEmpty({},p.p2)) .. ' ' .. writepeg(p.p2, p.p2.kind == 'con'))
    if matchEmpty({}, p.p2) then
    --TODO: matchEmpty retorna verdadeiro para !p1, o que implica que !p1 p2  casa a cadeia vazia (rever definicao)
    --if k[empty] then
      calcFlwAux(p.p1, union(k, flw, true))
    else
      calcFlwAux(p.p1, k)
		end
  elseif p.kind == 'star' or p.kind == 'plus' then
    calcFlwAux(p.p1, union(calcfirst(p.p1), flw, true))
  elseif p.kind == 'opt' then
    calcFlwAux(p.p1, flw)
  elseif p.kind == 'ord' then
    calcFlwAux(p.p1, flw)
    calcFlwAux(p.p2, flw)
	end
end


local function calcFlw (g, init)
  local update = true
  initFlw(g, init)

  while update do
    local tmp = {}
    for k, v in pairs(FOLLOW) do
      tmp[k] = v
    end

    for k, v in pairs(g) do
      calcFlwAux(v, FOLLOW[k]) 
    end

    update = false
    for k, v in pairs(g) do
      if not equalSet(FOLLOW[k], tmp[k]) then
			  update = true
      end
    end
  end

  return FOLLOW
end


return {
  calcFlw = calcFlw,
  calcFst = calcFst,
	calcfirst = calcfirst,
	printfollow = printfollow,
	disjoint = disjoint,
	set2choice = set2choice,
	calck = calck,
	matchEmpty = matchEmpty
}
