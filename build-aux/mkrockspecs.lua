-- Generate rockspecs from a prototype with variants

require "std"

if select ("#", ...) < 2 then
  io.stderr:write "Usage: mkrockspecs PACKAGE VERSION TEMPLATE\n"
  os.exit ()
end

package_name = select (1, ...)
version = select (2, ...)
template = select (3, ...)

function format (x, indent)
  indent = indent or ""
  if type (x) == "table" then
    local s = "{\n"
    for i, v in pairs (x) do
      if type (i) ~= "number" then
        s = s..indent..i.." = "..format (v, indent.."  ")..",\n"
      end
    end
    for i, v in ipairs (x) do
      s = s..indent..format (v, indent.."  ")..",\n"
    end
    return s..indent:sub (1, -3).."}"
  elseif type (x) == "string" then
    return string.format ("%q", x)
  else
    return tostring (x)
  end
end

local settings = loadfile (template) ()
local qualified_version = settings.default.version
for f, spec in pairs (settings) do
  if f ~= "default" then
    local specfile = package_name.."-"..(f ~= "" and f:lower ().."-" or "")..qualified_version..".rockspec"
    h = io.open (specfile, "w")
    assert (h)
    flavour = f -- a global, visible in loadfile
    local specs = loadfile (template) () -- reload to get current flavour interpolated
    local spec = tree.merge (tree.new (specs.default), tree.new (specs[f]))
    local s = ""
    for i, v in pairs (spec) do
      s = s..i.." = "..format (v, "  ").."\n"
    end
    h:write (s)
    h:close ()
    os.execute ("luarocks lint " .. specfile)
  end
end
