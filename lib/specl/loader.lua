-- Load Specl spec-files into native Lua tables.
--
-- Copyright (c) 2013 Free Software Foundation, Inc.
-- Written by Gary V. Vaughan, 2013
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3, or (at your option)
-- any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; see the file COPYING.  If not, write to the
-- Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
-- MA 02111-1301, USA.


local util = require "specl.util"
local yaml = require "yaml"


local TAG_PREFIX = "tag:yaml.org,2002:"
local null       = { type = "LYAML null" }


-- Metatable for Parser objects.
local parser_mt = {
  __index = {
    -- Return the type of the current event.
    type = function (self)
      return tostring (self.event.type)
    end,

    -- Raise a parse error.
    error = function (self, errmsg)
      return error (self.filename .. ":" .. self.mark.line .. ":" ..
                    self.mark.column .. ": " .. errmsg, 0)
    end,

    -- Save node in the anchor table for reference in future ALIASes.
    add_anchor = function (self, node)
      if self.event.anchor ~= nil then
        self.anchors[self.event.anchor] = node
      end
    end,

    -- Fetch the next event.
    parse = function (self)
      self.event = self.next ()
      self.mark  = {
        line   = tostring (self.event.start_mark.line + 1),
	column = tostring (self.event.start_mark.column + 1),
      }
      -- TODO: report parser problems here
      return self:type ()
    end,

    -- Construct a Lua hash table from following events.
    load_map = function (self)
      local map = {}
      self:add_anchor (map)
      -- Inject the preamble into before node of the outermost map.
      if self.preamble then
        map.before, self.preamble = self.preamble, nil
      end
      while true do
        local key = self:load_node ()
        if key == nil then break end
        local value = self:load_node ()
        if value == nil then
          return self:error ("unexpected " .. self:type () .. " event")
        end
        -- Be careful not to overwrite injected preamble.
	if key == "before" then
	  map.before = table.concat {map.before or "", value}
	else
          map[key] = value
	end
      end
      return map
    end,

    -- Construct a Lua array table from following events.
    load_sequence = function (self)
      local sequence = {}
      self:add_anchor (sequence)
      while true do
        local node = self:load_node ()
        if node == nil then break end
        sequence[#sequence + 1] = node
      end
      return sequence
    end,

    -- Construct a primitive type from the current event.
    load_scalar = function (self)
      local value = self.event.value
      local tag   = self.event.tag
      if tag then
        tag = tag:match ("^" .. TAG_PREFIX .. "(.*)$")
        if tag == "str" then
          -- value is already a string
        elseif tag == "int" or tag == "float" then
          value = tonumber (value)
        elseif tag == "bool" then
          value = (value == "true" or value == "yes")
        end
      elseif self.event.style == "PLAIN" then
        if value == "~" then
          value = null
        elseif value == "true" or value == "yes" then
          value = true
        elseif value == "false" or value == "no" then
          value = false
        else
          local number = tonumber (value)
          if number then value = number end
        end
      end
      self:add_anchor (value)
      return value
    end,

    load_alias = function (self)
      local anchor = self.event.anchor
      if self.anchors[anchor] == nil then
        return self:error ("invalid reference: " .. tostring (anchor))
      end
      return self.anchors[anchor]
    end,

    load_node = function (self)
      local dispatch  = {
        SCALAR         = self.load_scalar,
        ALIAS          = self.load_alias,
        MAPPING_START  = self.load_map,
        SEQUENCE_START = self.load_sequence,
        MAPPING_END    = util.nop,
        SEQUENCE_END   = util.nop,
        DOCUMENT_END   = util.nop,
      }

      local event = self:parse ()
      if dispatch[event] == nil then
        return self:error ("invalid event: " .. self:type ())
      end
     return dispatch[event] (self)
    end,
  },
}


-- Parser object constructor.
local function Parser (filename, s)
  local object = {
    anchors  = {},
    filename = filename:gsub ("^%./", ""),
    mark     = { line = "0", column = "0" },
    next     = yaml.parser (s),

    -- Used to simplify requiring from the spec file directory.
    preamble = "package.path = \"" ..
               filename:gsub ("[^/]+$", "?.lua;") ..
               "\" .. package.path\n",
  }
  return setmetatable (object, parser_mt)
end


local function load (filename, s)
  local documents = {}
  local parser    = Parser (filename, s)

  if parser:parse () ~= "STREAM_START" then
    return parser:error ("expecting STREAM_START event, but got " ..
                         parser:type ())
  end

  while parser:parse () ~= "STREAM_END" do
    local document = parser:load_node ()
    if document == nil then
      return parser:error ("unexpected " .. parser:type () .. " event")
    end

    if parser:parse () ~= "DOCUMENT_END" then
      return parser:error ("expecting DOCUMENT_END event, but got " ..
                           parser:type ())
    end

    -- save document
    documents[#documents + 1] = document

    -- reset anchor table
    parser.anchors = {}
  end

  return documents
end


--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--

local M = {
  load = load,
  null = null,
}

return M