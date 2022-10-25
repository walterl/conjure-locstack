local _2afile_2a = "fnl/conjure-locstack/main.fnl"
local _2amodule_name_2a = "conjure-locstack.main"
local _2amodule_2a
do
  package.loaded[_2amodule_name_2a] = {}
  _2amodule_2a = package.loaded[_2amodule_name_2a]
end
local _2amodule_locals_2a
do
  _2amodule_2a["aniseed/locals"] = {}
  _2amodule_locals_2a = (_2amodule_2a)["aniseed/locals"]
end
local autoload = (require("conjure-locstack.aniseed.autoload")).autoload
local a, log, nrepl, nvim, server, str, text, view = autoload("conjure.aniseed.core"), autoload("conjure.log"), autoload("conjure.remote.nrepl"), autoload("conjure.aniseed.nvim"), autoload("conjure.client.clojure.nrepl.server"), autoload("conjure.aniseed.string"), autoload("conjure.text"), autoload("conjure.aniseed.view")
do end (_2amodule_locals_2a)["a"] = a
_2amodule_locals_2a["log"] = log
_2amodule_locals_2a["nrepl"] = nrepl
_2amodule_locals_2a["nvim"] = nvim
_2amodule_locals_2a["server"] = server
_2amodule_locals_2a["str"] = str
_2amodule_locals_2a["text"] = text
_2amodule_locals_2a["view"] = view
local debug_3f = false
local function toggle_debug()
  debug_3f = not debug_3f
  return debug_3f
end
_2amodule_2a["toggle-debug"] = toggle_debug
local function dlog(s)
  if debug_3f then
    local function _1_()
      if a["string?"](s) then
        return {s}
      else
        return s
      end
    end
    return log.append(_1_())
  else
    return nil
  end
end
_2amodule_locals_2a["dlog"] = dlog
local function send_op_msg(op, msg, cb)
  local function _3_(conn, ops)
    local _4_
    if a.get(ops, op) then
      _4_ = a.merge({op = op, session = conn.session}, msg)
    else
      _4_ = nil
    end
    local function _6_(msg0)
      dlog("; response: ", view.serialise(msg0))
      local function _7_()
        if not msg0.status["no-info"] then
          return ((msg0).info or msg0)
        else
          return nil
        end
      end
      return cb(_7_())
    end
    return server.send(_4_, _6_)
  end
  local function _8_()
    return log.append({"; [LocStack] Something went wrong \240\159\152\181"})
  end
  return server["with-conn-and-ops-or-warn"]({op}, _3_, {["else"] = _8_})
end
_2amodule_locals_2a["send-op-msg"] = send_op_msg
local function ns_sym_info(ns, sym)
  log.append({("; Looking up symbol " .. ns .. "/" .. sym .. " \240\159\148\142...")})
  local function _9_(msg)
    if msg then
      local _let_10_ = msg
      local ns0 = _let_10_["ns"]
      local name = _let_10_["name"]
      local arglists_str = _let_10_["arglists-str"]
      local doc = _let_10_["doc"]
      local file = _let_10_["file"]
      local line = _let_10_["line"]
      local column = _let_10_["column"]
      local function _11_()
        if column then
          return (":" .. column)
        else
          return ""
        end
      end
      return log.append({("; " .. ns0 .. "/" .. name .. " " .. arglists_str), ("; \"" .. doc .. "\""), ("; " .. file .. ":" .. (line or "?") .. _11_())})
    else
      return nil
    end
  end
  return send_op_msg("info", {ns = ns, sym = sym}, _9_)
end
_2amodule_2a["ns-sym-info"] = ns_sym_info
local function ns_path(ns)
  log.append({("; Looking up path for ns " .. ns .. " \240\159\148\142...")})
  local function _13_(msg)
    return log.append({("; " .. a.get(msg, "path", "\194\175\\_(\227\131\132)_/\194\175"))})
  end
  return send_op_msg("ns-path", {ns = ns}, _13_)
end
_2amodule_2a["ns-path"] = ns_path
local function ns_path_loc(ns, cb)
  local function _14_(msg)
    local function _15_()
      if msg then
        return a.get(msg, "path")
      else
        return nil
      end
    end
    return cb(_15_())
  end
  return send_op_msg("ns-path", {ns = ns}, _14_)
end
_2amodule_locals_2a["ns-path-loc"] = ns_path_loc
local function ns_sym_loc(ns, sym, cb)
  local function _16_(msg)
    return cb(a.get(msg, "file"))
  end
  return send_op_msg("info", {ns = ns, sym = sym}, _16_)
end
_2amodule_locals_2a["ns-sym-loc"] = ns_sym_loc
local function frame_loc(frame, cb)
  local _let_17_ = frame
  local fn_2a = _let_17_["fn"]
  local ns = _let_17_["ns"]
  local frame_type = _let_17_["type"]
  if ("java" == frame_type) then
    return cb(nil)
  elseif (("clj" == frame_type) and ns and fn_2a) then
    return ns_path_loc(ns, cb)
  else
    return nil
  end
end
_2amodule_locals_2a["frame-loc"] = frame_loc
local function frame_3d_3f(x, y)
  local id_keys = {"name", "line"}
  return (not a["nil?"](x) and not a["nil?"](y) and (a.get(x, "name") == a.get(y, "name")) and (a.get(x, "line") == a.get(y, "line")))
end
_2amodule_locals_2a["frame=?"] = frame_3d_3f
local function nrepl__3envim_path(path)
  if text["starts-with"](path, "jar:file:") then
    local function _19_(zip, file)
      if (tonumber(string.sub(nvim.g.loaded_zipPlugin, 2)) > 31) then
        return ("zipfile://" .. zip .. "::" .. file)
      else
        return ("zipfile:" .. zip .. "::" .. file)
      end
    end
    return string.gsub(path, "^jar:file:(.+)!/?(.+)$", _19_)
  elseif text["starts-with"](path, "file:") then
    local function _21_(file)
      return file
    end
    return string.gsub(path, "^file:(.+)$", _21_)
  else
    return path
  end
end
_2amodule_locals_2a["nrepl->nvim-path"] = nrepl__3envim_path
local function st_frames__3eloclist_items(frames)
  local tbl_15_auto = {}
  local i_16_auto = #tbl_15_auto
  for _, frame in ipairs(frames) do
    local val_17_auto
    do
      local _let_23_ = frame
      local file_url = _let_23_["file-url"]
      local ns = _let_23_["ns"]
      local line = _let_23_["line"]
      local name = _let_23_["name"]
      local file_url0 = nrepl__3envim_path(file_url)
      local _let_24_ = str.split(name, "/")
      local name_ns = _let_24_[1]
      local name_var = _let_24_[2]
      local name_var0
      do
        local _25_ = name
        if (nil ~= _25_) then
          local _26_ = str.split(_25_, "/")
          if (nil ~= _26_) then
            name_var0 = a.second(_26_)
          else
            name_var0 = _26_
          end
        else
          name_var0 = _25_
        end
      end
      local ns0
      if a["empty?"](ns) then
        ns0 = name_ns
      else
        ns0 = ns
      end
      val_17_auto = {filename = file_url0, module = ns0, lnum = line, text = name}
    end
    if (nil ~= val_17_auto) then
      i_16_auto = (i_16_auto + 1)
      do end (tbl_15_auto)[i_16_auto] = val_17_auto
    else
    end
  end
  return tbl_15_auto
end
_2amodule_2a["st-frames->loclist-items"] = st_frames__3eloclist_items
local function stacktrace__3eloclist()
  log.append({"; [LocStack] Loading last stracktrace... \226\143\179"})
  local function _31_(msg)
    local frames = a.get(msg, "stacktrace", {})
    local no_url_frames
    do
      local tbl_15_auto = {}
      local i_16_auto = #tbl_15_auto
      for _, st in ipairs(frames) do
        local val_17_auto
        if a["empty?"](a.get(st, "file-url")) then
          val_17_auto = st
        else
          val_17_auto = nil
        end
        if (nil ~= val_17_auto) then
          i_16_auto = (i_16_auto + 1)
          do end (tbl_15_auto)[i_16_auto] = val_17_auto
        else
        end
      end
      no_url_frames = tbl_15_auto
    end
    local log_results
    local function _34_()
      if a["empty?"](no_url_frames) then
        local items = st_frames__3eloclist_items(frames)
        dlog(("; loclist items: " .. view.serialise(items)))
        nvim.fn.setloclist(0, items, "r")
        nvim.ex.lopen()
        return log.append({"; [LocStack] Stacktrace loaded into location list \226\156\148\239\184\143"})
      else
        return dlog(("; Still waiting for info on " .. a.count(no_url_frames) .. " frames."))
      end
    end
    log_results = _34_
    for _, frm in ipairs(no_url_frames) do
      local function _36_(loc)
        local frm_2a = a.assoc(frm, "file-url", loc)
        local function _37_(_241)
          if frame_3d_3f(frm, _241) then
            return frm_2a
          else
            return _241
          end
        end
        frames = a.map(_37_, frames)
        local function _39_(_241)
          return not frame_3d_3f(_241, frm)
        end
        no_url_frames = a.filter(_39_, no_url_frames)
        return log_results()
      end
      frame_loc(frm, _36_)
    end
    return nil
  end
  return send_op_msg("stacktrace", nil, _31_)
end
_2amodule_2a["stacktrace->loclist"] = stacktrace__3eloclist
local function init()
  local function _40_()
    return stacktrace__3eloclist()
  end
  return nvim.create_user_command("LocStack", _40_, {})
end
_2amodule_2a["init"] = init
return _2amodule_2a