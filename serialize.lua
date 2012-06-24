--[[
Save Table to File
Load Table from File
v 1.0

Lua 5.2 compatible

Only Saves Tables, Numbers and Strings
Insides Table References are saved
Does not save Userdata, Metatables, Functions and indices of these
----------------------------------------------------
table.save( table , filename )

on failure: returns an error msg

----------------------------------------------------
table.load( filename or stringtable )

Loads a table that has been saved via the table.save functio`n

on success: returns a previously saved table
on failure: returns as second argument an error msg
----------------------------------------------------

Licensed under the same terms as Lua itself.
]]--
-- declare local variables
--// exportstring( string )
--// returns a "Lua" portable version of the string
local function exportstring( s )
   return string.format("%q", s)
end

local charE = "\n"

local saveTableUnsafe

local function saveTable(tbl, file, level,name)
   local status, err = pcall(saveTableUnsafe,tbl,file,level)
   if status == false then
      print(name .. " is a bad table")
      error(err)
   end
   return err
end      

function saveTableUnsafe(tbl, file, level) 
   if tbl == nil then -- ???
      file:write("{}"); 
      return
   end
   local spaces = ''
   if level then
      spaces = string.rep('  ',level)
   end
   file:write("{")
   local first = true
   for n,v in pairs( tbl ) do
      if first == true then
         first = false
      else
         file:write(',')
      end
      file:write(charE..spaces.."[")
      if type(n) == "number" then
         file:write(n)
      else
         file:write(exportstring(n))
      end
      file:write("] = ")
      local stype = type( v )
      if stype == "table" then
         saveTable(v,file,level+1,n)
      elseif stype == "string" then
         file:write(exportstring( v ))
      elseif stype == "number" then
         file:write(tostring( v ))
      elseif v.to_table ~= nil then
         print("found to_table for "..n..charE)
         saveTable(v:to_table(),file,level+1,n)
      else
         print("blerh for "..n..charE)
         local mt = getmetatable(v)
         if mt then
            print("metatable of "..v..charE)
            for n,v in mt do
               print("\t"..n..charE)
            end
         end
         error("what is "..stype)
         file:write(stype)
      end
   end
   if(first == false) then
      file:write(charE..spaces)
   end
   file:write("}")
end

local function saveTo(tbl,file)
   file:write("local userdata = nil"..charE) -- sigh...
   file:write("return ")
   saveTable(tbl,file,1,"<top>")
end

--// The Save Function
local function save(tbl,filename )
   local file,err = io.open( filename, "wb" )
   if err then return err end
   saveTo(tbl,file)
   file:close()
end

--// The Load Function
local function load(filename)
   f,err = loadfile(filename)
   if f == nil then
      print("load error! "..err)
      return {}
   end
   return f()
end
-- ChillCode
-- refactored by Cy

return {save=save,load=load}