extends RefCounted
## The tiny condition language used by data files (see docs/data-model.md).
##
##   missing(id)  placed(id)  carried(id)  state(id) == "x"  done(id)
##   hint_level(id) >= n  photos(id) >= n  revealed(id)  flag(name)  presence() >= 0.5
##
## Combined with and / or / not and parentheses. No arithmetic, no side effects.

const COMPARE := ["==", "!=", ">=", "<=", ">", "<"]

var _t: Array = []
var _i := 0


## Returns true for an empty expression.
static func check(expr: String) -> bool:
	if expr.strip_edges().is_empty():
		return true
	var c = load("res://scripts/core/conditions.gd").new()
	c._t = c._tokenize(expr)
	c._i = 0
	var v = c._or()
	if c._i < c._t.size():
		push_error("Condition has trailing tokens: " + expr)
	return _truthy(v)


static func _truthy(v) -> bool:
	if typeof(v) == TYPE_BOOL:
		return v
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return v != 0
	if typeof(v) == TYPE_STRING:
		return not v.is_empty()
	return false


func _tokenize(s: String) -> Array:
	var out := []
	var i := 0
	while i < s.length():
		var ch := s[i]
		if ch == " " or ch == "\t" or ch == "\n":
			i += 1
		elif ch == "(" or ch == ")" or ch == ",":
			out.append(ch)
			i += 1
		elif ch == "=" or ch == "!" or ch == "<" or ch == ">":
			if i + 1 < s.length() and s[i + 1] == "=":
				out.append(s.substr(i, 2))
				i += 2
			else:
				out.append(ch)
				i += 1
		elif ch == "\"" or ch == "'":
			var j := s.find(ch, i + 1)
			if j < 0:
				j = s.length()
			out.append({"str": s.substr(i + 1, j - i - 1)})
			i = j + 1
		else:
			var j := i
			while j < s.length() and not (s[j] in " \t\n(),=!<>"):
				j += 1
			out.append(s.substr(i, j - i))
			i = j
	return out


func _peek():
	return _t[_i] if _i < _t.size() else null


func _is(tok, text: String) -> bool:
	return typeof(tok) == TYPE_STRING and tok == text


func _next():
	var v = _peek()
	_i += 1
	return v


func _or():
	var v = _and()
	while _is(_peek(), "or"):
		_next()
		var r = _and()
		v = _truthy(v) or _truthy(r)
	return v


func _and():
	var v = _unary()
	while _is(_peek(), "and"):
		_next()
		var r = _unary()
		v = _truthy(v) and _truthy(r)
	return v


func _unary():
	if _is(_peek(), "not"):
		_next()
		return not _truthy(_unary())
	return _compare()


func _compare():
	var a = _primary()
	var p = _peek()
	if typeof(p) == TYPE_STRING and p in COMPARE:
		_next()
		var b = _primary()
		if typeof(a) == TYPE_STRING or typeof(b) == TYPE_STRING:
			var sa := str(a)
			var sb := str(b)
			match p:
				"==": return sa == sb
				"!=": return sa != sb
				_: return false
		var fa := float(a)
		var fb := float(b)
		match p:
			"==": return is_equal_approx(fa, fb)
			"!=": return not is_equal_approx(fa, fb)
			">=": return fa >= fb
			"<=": return fa <= fb
			">": return fa > fb
			"<": return fa < fb
	return a


func _primary():
	var tok = _next()
	if tok == null:
		return false
	if typeof(tok) == TYPE_DICTIONARY:
		return tok["str"]
	if tok == "(":
		var v = _or()
		_next()
		return v
	if tok == "true":
		return true
	if tok == "false":
		return false
	if tok.is_valid_float():
		return float(tok)
	# function call
	var args := []
	if _is(_peek(), "("):
		_next()
		while _peek() != null and not _is(_peek(), ")"):
			var a = _next()
			args.append(a["str"] if typeof(a) == TYPE_DICTIONARY else a)
			if _is(_peek(), ","):
				_next()
		_next()
	return _call(tok, args)


func _call(name: String, args: Array):
	var a0: String = args[0] if args.size() > 0 else ""
	var st = Engine.get_main_loop().root.get_node("State")
	match name:
		"missing": return st.get_object_state(a0) == "missing"
		"placed": return st.get_object_state(a0) == "placed"
		"carried": return st.get_object_state(a0) == "carried"
		"state": return st.get_object_state(a0)
		"done": return st.done.has(a0)
		"hint_level": return float(st.hint_level(a0))
		"photos": return float(st.photo_counts.get(a0, 0))
		"revealed": return st.revealed.has(a0)
		"flag": return st.has_flag(a0)
		"presence": return st.presence
	push_error("Unknown condition function: " + name)
	return false
