local saver = dofile (minetest.get_modpath("multinode") .. "/serialize.lua")
local inspect = dofile (minetest.get_modpath("multinode") .. "/inspect.lua") -- don't judge me

MN1 = {}
MN2 = {}
MN1CACHE = {}
MN2CACHE = {}
COPY = {}
COPYREF = {}
PASTEREF ={}
REPLACE = {}
WITH = {}

ACTIONNODE = function(nodeid, nodename,onplace,ondig)
                local params = {
                   description = nodename,
                   tile_images = {"multinode_"..nodeid..".png"},
                   inventory_image = minetest.inventorycube("multinode_"..nodeid..".png"),
                   is_ground_content = true,
                   groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2,flammable=3},
                   sounds = default.node_sound_wood_defaults(),
                }
                if onplace ~= nil then params.after_place_node = onplace end
                if ondig ~= nil then params.after_dig_node = ondig end
                minetest.register_node("multinode:"..nodeid, params)
             end
ACTIONNODE('m1','Multinode Marker 1', function(pos,placer)
                                         local player = placer:get_player_name()-- or ""
                                         if player == '' then print('errorm1') end
                                         if MN1[player] == nil then MN1[player] = {} end
                                         table.insert(MN1[player], pos)
                                         minetest.chat_send_player(player, "marker 1 set")
                                      end)
ACTIONNODE('m2','Multinode Marker 2', function(pos,placer)
                                         local player = placer:get_player_name()-- or ""
                                         if player == '' then print('errorm2') end
                                         if MN2[player] == nil then MN2[player] = {} end
                                         table.insert(MN2[player], pos)
                                         minetest.chat_send_player(player, "marker 2 set")
                                      end)
ACTIONNODE('pasteref','Paste Reference Marker', function(pos,placer)
                                                   local player = placer:get_player_name()-- or ""
                                                   if player == '' then print('errorm2') end
                                                   PASTEREF[player] = pos
                                                   minetest.chat_send_player(player, "paste reference set")
                                                end)

-- ***********************************************************************************
--		FUNCTIONS							**************************************************
-- ***********************************************************************************
compare = function(p1,p2)
             result = {}
             if p1 > p2 then
		result.high = p1
		result.low = p2
		result.diff = p1 - p2
             elseif p2 > p1 then
		result.high = p2
		result.low = p1
		result.diff = p2 - p1
             else
		result.high = p2
		result.low = p1
		result.diff = 0
             end
             if result.diff < 0 then 
		result.diff = -result.diff
		result.mul = -1
             else result.mul = 1 end
             return result
          end

local fixlight = function(p)
                    local no = minetest.env:get_node(p)
                    no.param1 = 13
                    minetest.env:add_node(p, no)
                 end
local fillnode = function(pos,param)
                    if param == '-light' then
                       fixlight(pos)
                    else
                       minetest.env:add_node(pos,{type="node",name=param})
                    end
                 end
local removenode = function(pos,param)
                      if param == '-a' then
                         minetest.env:remove_node(pos)
                      else
                         local node = minetest.env:get_node_or_nil(pos)
                         if node and node.name == param then minetest.env:remove_node(pos) end	
                      end
                   end
local copynode = function(pos,param)
                    local node = minetest.env:get_node_or_nil(pos)
                    local meta = minetest.env:get_meta(pos):to_table()
                    if node then table.insert(COPY[param],{pos=pos,name=node.name,param1=node.param1,param2=node.param2,meta=meta}) end
                 end

local replacenode = function(pos,param)
                       local node = minetest.env:get_node_or_nil(pos)
                       if node and node.name == REPLACE[param] then
                          minetest.env:add_node(pos,{type="node",name=WITH[param]}) 
                       end
                    end

local multinode = function(p1,p2,mutation,param)
                     local xdif = compare(p1.x,p2.x)
                     local ydif = compare(p1.y,p2.y)
                     local zdif = compare(p1.z,p2.z)
                     if mutation == copynode then COPYREF[param] = p1 end

                     if xdif.diff > 0 then
                        for q =0,xdif.diff,1 do
                           mutation({x=xdif.high-q*xdif.mul,y=ydif.high,z=zdif.high},param)
                           if ydif.diff > 0 then
                              for m =0,ydif.diff,1 do
                                 mutation({x=xdif.high-q*xdif.mul,y=ydif.high-m*ydif.mul,z=zdif.high},param)
                                 if zdif.diff > 0 then
                                    for i =0,zdif.diff,1 do
                                       mutation({x=xdif.high-q*xdif.mul,y=ydif.high-m*ydif.mul,z=zdif.high-i*zdif.mul},param)
                                    end
                                 end
                              end
                           elseif zdif.diff > 0 then
                              for i =0,zdif.diff,1 do
                                 mutation({x=xdif.high-q*xdif.mul,y=ydif.high,z=zdif.high-i*zdif.mul},param)
                              end
                           end

                        end
                     elseif ydif.diff > 0 then
                        for m =0,ydif.diff,1 do
                           mutation({x=xdif.high,y=ydif.high-m*ydif.mul,z=zdif.high},param)
                           if zdif.diff > 0 then
                              for i =0,zdif.diff,1 do
                                 mutation({x=xdif.high,y=ydif.high-m*ydif.mul,z=zdif.high-i*zdif.mul},param)
                              end
                           end
                        end
                     elseif zdif.diff > 0 then
                        for i =0,zdif.diff,1 do
                           mutation({x=xdif.high,y=ydif.high,z=zdif.high-i*zdif.mul},param)
                        end
                     else
                        return false
                     end
                  end

-- ***********************************************************************************
--		CHATCOMMANDS						**************************************************
-- ***********************************************************************************
minetest.register_chatcommand("reload", {
                                 params = "<none>",
                                 description = "restore last multinode list",
                                 privs = {server=true},
                                 func = function(name, param)
                                           MN1[name] = MN1CACHE[name]
                                           MN2[name] = MN2CACHE[name]
                                        end,
                              })
minetest.register_chatcommand("clear", {
                                 params = "<none>",
                                 description = "clear",
                                 privs = {server=true},
                                 func = function(name, param)
                                           COPY[name] = {}
                                           COPYREF[name] = {}
                                           PASTEREF[name] = {}
                                           REPLACE[name] = {}
                                           WITH[name] = {}
                                           MN1[name] = {}
                                           MN2[name] = {}
                                        end,
                              })
minetest.register_chatcommand("p1", {
                                 params = "<X>,<Y>,<Z>",
                                 description = "first corner",
                                 privs = {server=true},
                                 func = function(name, param)
                                           if MN1[name] == nil then MN1[name] = {} end
                                           local p = {}
                                           p.x, p.y, p.z = string.match(param, "^([%d.-]+)[, ] *([%d.-]+)[, ] *([%d.-]+)$")
                                           if p.x and p.y and p.z then
                                              table.insert(MN1[name], p)
                                              minetest.chat_send_player(name, "p1 set")
                                              return
                                           else 
                                              local target = minetest.env:get_player_by_name(name)
                                              if target then
                                                 table.insert(MN1[name],target:getpos())
                                                 minetest.chat_send_player(name, "p1 set")
                                                 return
                                              end
                                           end
                                        end,
                              })
minetest.register_chatcommand("p2", {
                                 params = "<X>,<Y>,<Z>",
                                 description = "opposite corner",
                                 privs = {server=true},
                                 func = function(name, param)
                                           if MN2[name] == nil then MN2[name] = {} end
                                           local p = {}
                                           p.x, p.y, p.z = string.match(param, "^([%d.-]+)[, ] *([%d.-]+)[, ] *([%d.-]+)$")
                                           if p.x and p.y and p.z then
                                              table.insert(MN2[name], p)
                                              minetest.chat_send_player(name, "p2 set")
                                              return
                                           else 
                                              local target = minetest.env:get_player_by_name(name)
                                              if target then
                                                 table.insert(MN2[name], target:getpos())
                                                 minetest.chat_send_player(name, "p2 set")
                                                 return
                                              end
                                           end
                                        end,
                              })

minetest.register_chatcommand("fill", {
                                 params = "<nodename>",
                                 description = "fill with given node",
                                 privs = {server=true},
                                 func = function(name, param)
                                           if MN1[name] == nil or MN2[name] == nil then
                                              print('failed check 0')
                                              return end
                                           if table.getn(MN1[name]) == 0 or table.getn(MN2[name]) == 0 or param == nil then 
                                              print('failed check 1')
                                              return end
                                           MN1CACHE[name] = MN1[name]--LASTFILL1 = FILL1
                                           MN2CACHE[name] = MN2[name]--LASTFILL2 = FILL2
                                           MN1[name] = {}
                                           MN2[name] = {}
                                           for a = 1,table.getn(MN1CACHE[name]),1 do
                                              if MN1CACHE[name][a] == nil or MN2CACHE[name][a] == nil then print('failed check 2') return end
                                              if multinode(MN1CACHE[name][a],MN2CACHE[name][a],fillnode,param) == false then minetest.chat_send_player(name, "there is no fill only zuul") end
                                           end
                                        end,
                              })
minetest.register_chatcommand("remove", {
                                 params = "<nodename>",
                                 description = "to remove specific node or use flag '-a'",
                                 privs = {server=true},
                                 func = function(name, param)
                                           if table.getn(MN1[name]) == 0 or table.getn(MN2[name]) == 0 or param == nil then 
                                              print('failed check 1')
                                              return end
                                           MN1CACHE[name] = MN1[name]--LASTFILL1 = FILL1
                                           MN2CACHE[name] = MN2[name]--LASTFILL2 = FILL2
                                           MN1[name] = {}
                                           MN2[name] = {}
                                           for a = 1,table.getn(MN1CACHE[name]),1 do
                                              if MN1CACHE[name][a] == nil or MN2CACHE[name][a] == nil then print('failed check 2') return end
                                              if multinode(MN1CACHE[name][a],MN2CACHE[name][a],removenode,param) == false then minetest.chat_send_player(name, "there is no remove only zuul") end
                                           end
                                        end,
                              })
minetest.register_chatcommand("copy", {
                                 params = "<none>",
                                 description = "copy",
                                 privs = {server=true},
                                 func = function(name, param)
                                           if MN1[name] == nil or MN2[name] == nil then  minetest.chat_send_player(name, "a klingon that kills without showing his face, has no honor") return end
                                           if table.getn(MN1[name]) == 0 or table.getn(MN2[name]) == 0 or param == nil then 
                                              print('failed check 1')
                                              return end
                                           MN1CACHE[name] = MN1[name]
                                           MN2CACHE[name] = MN2[name]
                                           MN1[name] = {}
                                           MN2[name] = {}
                                           if COPY[name] == nil then COPY[name] = {} end
                                           if COPYREF[name] == nil then COPYREF[name] = {} end
                                           for a = 1,table.getn(MN1CACHE[name]),1 do
                                              if MN1CACHE[name][a] == nil or MN2CACHE[name][a] == nil then print('failed check 2') return end
                                              if multinode(MN1CACHE[name][a],MN2CACHE[name][a],copynode,name) == false then minetest.chat_send_player(name, "there is no copy only zuul") end
                                           end
                                        end,
                              })
minetest.register_chatcommand("paste", {
                                 params = "<none>",
                                 description = "paste",
                                 privs = {server=true},
                                 func = function(name, param)
                                           if PASTEREF[name] then
                                              newpos = PASTEREF[name]
                                           else
                                              local target = minetest.env:get_player_by_name(name)
                                              if target then 
                                                 newpos = target:getpos()
                                              end
                                           end
                                           
                                           status,err = pcall(
                                             function()
                                           difx = COPYREF[name].x - newpos.x
                                           dify = COPYREF[name].y - newpos.y
                                           difz = COPYREF[name].z - newpos.z
                                             end)
                                           if status == false then
                                              print("paste error "..err)
                                              print(inspect(COPYREF[name]))
                                              minetest.chat_send_player(name, "paste failed.")
                                              return
                                           end
                                              

                                           for a = 1,table.getn(COPY[name]),1 do
                                              local info = COPY[name][a]

                                              if param ~= '+90' and param ~= '-90' and param ~= '+180' then
                                                 pastepos = {x=info.pos.x-difx,y=info.pos.y-dify,z=info.pos.z-difz}
                                              else
                                                 local x = info.pos.x -COPYREF[name].x
                                                 local y = info.pos.y
                                                 local z = info.pos.z -COPYREF[name].z
                                                 local newx,newz = nil
                                                 if param == '+90' then 
                                                    newx = z
                                                    newz = -(x)
                                                 elseif param == '-90' then 
                                                    newx = -(z)
                                                    newz = x
                                                 elseif param == '+180' then 
                                                    newx = -(x)
                                                    newz = -(z)
                                                 else
                                                    return
                                                 end
                                                 x = newx + COPYREF[name].x
                                                 z = newz + COPYREF[name].z
                                                 pastepos = {x=x-difx,y=y-dify,z=z-difz}
                                              end
                                              minetest.env:add_node(pastepos,{type="node",
                                                                              name=info.name,
                                                                              param1 = info.param1,
                                                                              param2 = info.param2})
                                              minetest.env:get_meta(pastepos):from_table(info.meta)
                                           end
                                           PASTEREF[name] = nil
                                        end,
                              })
minetest.register_chatcommand("replace", {
                                 params = "<none>",
                                 description = "clear",
                                 privs = {server=true},
                                 func = function(name, param)
                                           REPLACE[name] = param
                                        end,
                              })
minetest.register_chatcommand("with", {
                                 params = "<none>",
                                 description = "clear",
                                 privs = {server=true},
                                 func = function(name, param)
                                           WITH[name] = param
                                        end,
                              })
minetest.register_chatcommand("doit", {
                                 params = "<none>",
                                 description = "clear",
                                 privs = {server=true},
                                 func = function(name, param)
                                           if MN1[name] == nil or MN2[name] == nil then
                                              print('set p1 or p2 first')
                                              return end
                                           if table.getn(MN1[name]) == 0 or table.getn(MN2[name]) == 0 then 
                                              print('failed check 1')
                                              return end
                                           MN1CACHE[name] = MN1[name]
                                           MN2CACHE[name] = MN2[name]
                                           MN1[name] = {}
                                           MN2[name] = {}
                                           for a = 1,table.getn(MN1CACHE[name]),1 do
                                              if MN1CACHE[name][a] == nil or MN2CACHE[name][a] == nil then print('failed check 2') return end
                                              if multinode(MN1CACHE[name][a],MN2CACHE[name][a],replacenode,name) == false then minetest.chat_send_player(name, "there is no replace only zuul") end
                                           end
                                           REPLACE[name] = nil
                                           WITH[name] = nil
                                        end,
                              })

minetest.register_chatcommand("saveas", {
                                 params = "<bldname>",
                                 description = "paste",
                                 privs = {server=true},
                                 func = function(name, param)
                                           if COPY[name] == nil then  minetest.chat_send_player(name, "a klingon that kills without showing his face, has no honor") return end

                                           local path = minetest.get_modpath('multinode')..'/buildings/'..param..'.bld'

                                           status,err = pcall(saver.save,{COPYREF[name],COPY[name]},path..".tmp")
                                           if status == false then
                                              print("save error "..err)
                                              print("derp "..inspect(COPY[name]))
                                              minetest.chat_send_player(name, param.." save failed")
                                              return
                                           end
                                           os.remove(path)
                                           os.rename(path..".tmp",path)
                                           minetest.chat_send_player(name, param.." saved")

                                        end,
                              })
minetest.register_chatcommand("load", {
                                 params = "<bldname>",
                                 description = "load from file",
                                 privs = {server=true},
                                 func = function(name, param)
                                           local status,err = pcall(
                                              function()
                                                 local path = minetest.get_modpath('multinode')..'/buildings/'..param..'.bld'
                                                 local derp = saver.load(path)
                                                 COPYREF[name] = derp[1]
                                                 COPY[name] = derp[2]
                                              end)
                                           if status == true then
                                              minetest.chat_send_player(name, "loaded.")
                                           else
                                              minetest.chat_send_player(name, "load failed.")
                                              print("load error "..err)
                                           end
                                        end,
                              })
