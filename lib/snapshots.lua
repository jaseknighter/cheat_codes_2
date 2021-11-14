local snap = {}

local restorable_params = {"rate","offset","level","fifth","start_point","end_point","loop","mode","clip","global_level","pan","tilt"}
local level_envelope_params = {"active","rise_stage_active","fall_stage_active","rise_stage_time","rise_time_index","fall_stage_time","fall_time_index","loop"}

snap.init = function()
  for i = 1,3 do
    bank[i].snapshot = {{},{},{},{},{},{},{},{}}
    bank[i].snapshot_fnl_active = false
    bank[i].snapshot_fnl_canceled = false
    bank[i].active_snapshot = 0
    bank[i].restore_mod = false
    bank[i].snapshot_mod = false
    bank[i].restore_mod_index = 1
    bank[i].snapshot_mod_index = 1
    bank[i].snapshot_saver_active = false
    bank[i].snapshot_saver_clock = nil
    for j = 1,16 do
      bank[i].snapshot[j] = {["pad"]= {},["saved"] = false,["rate_ramp"] = true,["rate_scaling"] = "linear",["partial_restore"] = false} -- maybe want rate_ramp to be bank-level????
      bank[i].snapshot[j].restore =
        {
          ["rate"] = true,
          ["offset"] = true,
          ["level"] = true,
          ["fifth"] = true,
          ["start_point"] = true,
          ["end_point"] = true,
          ["loop"] = true,
          ["mode"] = true,
          ["clip"] = true,
          ["global_level"] = true,
          ["pan"] = true,
          ["filter"] = true
        }
      for k = 1,16 do
        bank[i].snapshot[j].pad[k] = {}
      end
      bank[i].snapshot[j].restore_times = {["beats"] = {1,2,4,8,16,32,64,128}, ["time"] = {1,2,4,8,16,32,64,128}, ["mode"] = "beats"}
    end
  end
end

snap.capture = function(b,slot)
  local shot = bank[b].snapshot[slot]
  local src = bank[b]
  for i = 1,16 do
    shot.pad[i].rate = src[i].rate
    shot.pad[i].offset = src[i].offset
    shot.pad[i].fifth = src[i].fifth
    shot.pad[i].start_point = src[i].start_point
    shot.pad[i].end_point = src[i].end_point
    shot.pad[i].loop = src[i].loop
    shot.pad[i].mode = src[i].mode
    shot.pad[i].clip = src[i].clip
    shot.pad[i].level = src[i].level
    shot.pad[i].global_level = src.global_level

    shot.pad[i].enveloped = src[i].enveloped
    shot.pad[i].envelope_mode = src[i].envelope_mode
    shot.pad[i].level_envelope = {}
    for j = 1,#level_envelope_params do
      shot.pad[i].level_envelope[level_envelope_params[j]] = src[i].level_envelope[level_envelope_params[j]]
    end

    shot.pad[i].pan = src[i].pan
    shot.pad[i].tilt = params:get("filter "..b.." dj tilt")
    shot.pad[i].filter =
    {
      ["style"] = params:get("filter "..b.." style"),
      ["dj tilt"] = params:get("filter "..b.." dj tilt"),
      ["cutoff"] = params:get("filter "..b.." cutoff"),
      ["q"] = params:get("filter "..b.." q"),
      ["lp"] = params:get("filter "..b.." lp"),
      ["hp"] = params:get("filter "..b.." hp"),
      ["bp"] = params:get("filter "..b.." bp"),
      ["dry"] = params:get("filter "..b.." dry"),
      ["lp mute"] = params:get("filter "..b.." lp mute"),
      ["hp mute"] = params:get("filter "..b.." hp mute"),
      ["bp mute"] = params:get("filter "..b.." bp mute"),
      ["dry mute"] = params:get("filter "..b.." dry mute")
    }
  end
  shot.saved = true
  bank[b].active_snapshot = slot
end

snap.clear = function(b,slot)
  local shot = bank[b].snapshot[slot]
  shot.saved = false
  if bank[b].active_snapshot == slot then
    bank[b].active_snapshot = 0
  end
end

snap.save_to_slot = function(b,slot)
  clock.sleep(0.25)
  bank[b].snapshot_saver_active = true
  if bank[b].snapshot_saver_active then
    if not grid_alt then
      print("saved snap",b,slot)
      snap.capture(b,slot)
    else
      snap.clear(b,slot)
    end
    grid_dirty = true
  end
  bank[b].snapshot_saver_active = false
end

snap.toggle_mod = function(b,slot,prm)
  local shot = bank[b].snapshot[slot]
  shot.restore[prm] = not shot.restore[prm]
end

snap.check_restore = function(b,slot,prm)
  
end

snap.restore = function(b,slot,sec,style)
  if bank[b].snapshot[slot].saved then
  -- print("trying to get from "..bank[b].active_snapshot.." to "..slot, bank[b].snapshot_fnl_canceled,bank[b].snapshot.fnl_active, bank[b].restore_mod )
    if (bank[b].active_snapshot == slot and bank[b].snapshot_fnl_canceled and bank[b].snapshot.fnl_active and bank[b].restore_mod) then
      -- print("nahhh")

    elseif (bank[b].active_snapshot ~= slot and not bank[b].snapshot_fnl_canceled)
    or (bank[b].active_snapshot == slot and bank[b].snapshot_fnl_canceled)
    or (bank[b].active_snapshot == slot and bank[b].snapshot.partial_restore)
    or (bank[b].active_snapshot ~= slot and bank[b].snapshot_fnl_canceled and not bank[b].snapshot.fnl_active)
    or (bank[b].active_snapshot ~= slot and bank[b].snapshot_fnl_canceled and bank[b].snapshot.fnl_active) then
      -- print("restoring snap",b,slot)
      bank[b].active_snapshot = slot
      local shot = bank[b].snapshot[slot]
      local src = bank[b]
      local original_srcs = {}
      for i = 1,16 do
        original_srcs[i] = {}
        for j = 1,#restorable_params do
          -- print(src[i][restorable_params[j]])
          original_srcs[i][restorable_params[j]] = src[i][restorable_params[j]]
        end
        original_srcs[i].global_level = src.global_level
        original_srcs[i].filter =
          {
            ["style"] = params:get("filter "..b.." style"),
            ["dj tilt"] = params:get("filter "..b.." dj tilt"),
            ["cutoff"] = params:get("filter "..b.." cutoff"),
            ["q"] = params:get("filter "..b.." q"),
            ["lp"] = params:get("filter "..b.." lp"),
            ["hp"] = params:get("filter "..b.." hp"),
            ["bp"] = params:get("filter "..b.." bp"),
            ["dry"] = params:get("filter "..b.." dry"),
            ["lp mute"] = params:get("filter "..b.." lp mute"),
            ["hp mute"] = params:get("filter "..b.." hp mute"),
            ["bp mute"] = params:get("filter "..b.." bp mute"),
            ["dry mute"] = params:get("filter "..b.." dry mute")
          }

        original_srcs[i].enveloped = src[i].enveloped
        original_srcs[i].envelope_mode = src[i].envelope_mode
        original_srcs[i].level_envelope = {}
        for j = 1,#level_envelope_params do
          original_srcs[i].level_envelope[level_envelope_params[j]] = src[i].level_envelope[level_envelope_params[j]]
        end

      end
      for i = 1,16 do
        -- src[i].loop = shot.pad[i].loop
        -- if i == src.id then
        --   softcut.loop(b+1,src[i].loop and 1 or 0)
        -- end
        if shot.restore.level then
          src[i].enveloped = shot.pad[i].enveloped
          src[i].envelope_mode = shot.pad[i].envelope_mode
          -- src[i].level_envelope = {}
          for j = 1,#level_envelope_params do
            src[i].level_envelope[level_envelope_params[j]] = shot.pad[i].level_envelope[level_envelope_params[j]]
          end
        end
      end
      if not bank[b].snapshot.fnl_active and (sec ~= nil and sec > 0.1) then
        
        if style ~= nil then
          if style == "beats" then
            sec = clock.get_beat_sec()*sec
          elseif style == "time" then
            sec = sec
          end
        end

        print(sec,style)

        bank[b].snapshot.fnl_active = true
        bank[b].snapshot.fnl = snap.fnl(
          function(r_val)
            bank[b].snapshot.current_value = r_val
            src.global_level = util.linlin(0,1,original_srcs[1].global_level,shot.pad[1].global_level,r_val)
            if shot.restore.filter then
              if original_srcs[1].filter.style == 1 then
                if shot.pad[1].filter.style ~= 1 then
                  params:set("filter "..b.." style",2)
                else
                  params:set("filter "..b.." dj tilt",util.linlin(0,1,original_srcs[1].tilt,shot.pad[1].tilt,r_val))
                end
              elseif original_srcs[1].filter.style == 2 then
                if shot.pad[1].filter.style ~= 2 then
                  params:set("filter "..b.." style",1)
                  params:set("filter "..b.." dj tilt",util.linlin(0,1,original_srcs[1].tilt,shot.pad[1].tilt,r_val))
                  params:set("filter "..b.." q",util.linlin(0,1,original_srcs[1].filter["q"],shot.pad[1].filter["q"],r_val))
                else
                  params:set("filter "..b.." cutoff",util.linlin(0,1,original_srcs[1].filter["cutoff"],shot.pad[1].filter["cutoff"],r_val))
                  params:set("filter "..b.." q",util.linlin(0,1,original_srcs[1].filter["q"],shot.pad[1].filter["q"],r_val))
                  params:set("filter "..b.." lp",util.linlin(0,1,original_srcs[1].filter["lp"],shot.pad[1].filter["lp"],r_val))
                  params:set("filter "..b.." hp",util.linlin(0,1,original_srcs[1].filter["hp"],shot.pad[1].filter["hp"],r_val))
                  params:set("filter "..b.." bp",util.linlin(0,1,original_srcs[1].filter["bp"],shot.pad[1].filter["bp"],r_val))
                  params:set("filter "..b.." dry",util.linlin(0,1,original_srcs[1].filter["dry"],shot.pad[1].filter["dry"],r_val))
                end
              end
            end
            for i = 1,16 do
              if shot.restore.start_point then
                src[i].start_point = util.linlin(0,1,original_srcs[i].start_point,shot.pad[i].start_point,r_val)
              end
              if shot.restore.end_point then
                src[i].end_point = util.linlin(0,1,original_srcs[i].end_point,shot.pad[i].end_point,r_val)
              end
              if shot.restore.level then
                src[i].level = util.linlin(0,1,original_srcs[i].level,shot.pad[i].level,r_val)
              end
              if shot.restore.rate then
                if shot.rate_ramp then
                  src[i].rate = util.linlin(0,1,original_srcs[i].rate,shot.pad[i].rate,easingFunctions[shot.rate_scaling](r_val,0,1,1))
                end
              end
              if i == src.id then
                bank[b].snapshot_mute_while_running = true
                if src[i].loop then
                  softcut.loop_start(b+1,src[i].start_point)
                  softcut.loop_end(b+1,src[i].end_point)
                end
                if shot.restore.level then
                  if not src[i].enveloped then
                    softcut.level(b+1,src[i].level*src.global_level)
                  end
                end
                if shot.rate_ramp then
                  softcut.rate(b+1,src[i].rate*_loops.get_total_pitch_offset(b,i))
                end
                bank[b].snapshot_mute_while_running = false
              end
            end
            if bank[b].snapshot.current_value ~= nil and util.round(bank[b].snapshot.current_value,0.001) == 1 then
              snap.snapshot_funnel_done_action(b,slot)
            end
          end,
          0,
          {{1,sec}},
          60
        )
      elseif not bank[b].snapshot.fnl_active and (sec == nil or sec == 0) then
        src.global_level = shot.pad[1].global_level
        if shot.restore.filter then
          if original_srcs[1].filter.style == 1 then
            if shot.pad[1].filter.style ~= 1 then
              params:set("filter "..b.." style",2)
            else
              params:set("filter "..b.." dj tilt",shot.pad[1].tilt)
            end
          elseif original_srcs[1].filter.style == 2 then
            if shot.pad[1].filter.style ~= 2 then
              params:set("filter "..b.." style",1)
              params:set("filter "..b.." dj tilt",shot.pad[1].tilt)
              params:set("filter "..b.." q",shot.pad[1].filter["q"])
            else
              params:set("filter "..b.." cutoff",shot.pad[1].filter["cutoff"])
              params:set("filter "..b.." q",shot.pad[1].filter["q"])
              params:set("filter "..b.." lp",shot.pad[1].filter["lp"])
              params:set("filter "..b.." hp",shot.pad[1].filter["hp"])
              params:set("filter "..b.." bp",shot.pad[1].filter["bp"])
              params:set("filter "..b.." dry",shot.pad[1].filter["dry"])
            end
          end
        end
        for i = 1,16 do
          if shot.restore.start_point then
            src[i].start_point = shot.pad[i].start_point
          end
          if shot.restore.end_point then
            src[i].end_point = shot.pad[i].end_point
          end
          if shot.restore.level then
            src[i].level = shot.pad[i].level
          end
          -- if shot.restore.filter then
          --   params:set("filter "..b.." dj tilt",shot.pad[i].tilt)
          -- end
          if i == src.id then
            softcut.loop_start(b+1,src[i].start_point)
            softcut.loop_end(b+1,src[i].end_point)
            if shot.restore.level and not shot.enveloped then
              softcut.level(b+1,src[i].level*src.global_level)
            end
          end
        end
        snap.snapshot_funnel_done_action(b,slot)
        bank[b].snapshot_fnl_canceled = false
      else
        -- print("already running!!!") -- this ends up restoring from current in duration... 
        print('canceling current funnel')
        clock.cancel(bank[b].snapshot.fnl)
        bank[b].snapshot_fnl_canceled = true
        bank[b].snapshot.fnl_active = false
        snap.restore(b,slot,sec,style)
      end
    elseif (bank[b].active_snapshot == slot and bank[b].snapshot.fnl_active) then
    -- or (bank[b].active_snapshot ~= slot and bank[b].snapshot_fnl_canceled and bank[b].snapshot.fnl_active) then
      print('canceling current funnel 2')
      local shot = bank[b].snapshot[slot]
      local src = bank[b]
      clock.cancel(bank[b].snapshot.fnl)
      bank[b].snapshot_fnl_canceled = true
      bank[b].snapshot.fnl_active = false
      src.global_level = shot.pad[1].global_level
      for i = 1,16 do
        src[i].start_point = shot.pad[i].start_point
        src[i].end_point = shot.pad[i].end_point
        params:set("filter "..b.." dj tilt",shot.pad[i].tilt)
        if i == src.id then
          softcut.loop_start(b+1,src[i].start_point)
          softcut.loop_end(b+1,src[i].end_point)
          softcut.level(b+1,src[i].level*src.global_level)
        end
      end
      bank[b].active_snapshot = slot
      -- bank[b].snapshot.fnl_active = false
      snap.snapshot_funnel_done_action(b,slot)
    end
  end
end

snap.snapshot_funnel_done_action = function(b,slot,args)
  print("snapshot funnel done")
  local shot = bank[b].snapshot[slot]
  local src = bank[b]
  bank[b].snapshot.fnl_active = false
  for i = 1,16 do
    if shot.restore.rate then
      src[i].rate = shot.pad[i].rate
    end
    src[i].offset = shot.pad[i].offset
    if i == src.id then
      softcut.rate(b+1,src[i].rate*_loops.get_total_pitch_offset(b,i))
      if shot.restore.filter then
        params:set("filter "..b.." dj tilt",shot.pad[i].tilt)
      end
    end
  end
  if src.snapshot.partial_restore then
    bank[b].snapshot.partial_restore = false
  end
end

-- we do need to keep the clips inside of the limits of the clip...

snap.crossfade = function(b,scene_a,scene_b,val)
  local min_fade = bank[b].snapshot[scene_a].pad
  local max_fade = bank[b].snapshot[scene_b].pad
  local dest = bank[b]
  local shot = bank[b].snapshot[scene_b]
  dest.global_level = util.linlin(0,127,min_fade[1].global_level,max_fade[1].global_level,val)
  for i = 1,16 do
    -- new_val[i].rate = util.linlin(0,127,min_fade[i].rate,max_fade[i].rate,val)
    -- new_val[i].fifth = util.linlin(0,127,min_fade[i].fifth,max_fade[i].fifth,val)
    dest[i].start_point = util.linlin(0,127,min_fade[i].start_point,max_fade[i].start_point,val)
    dest[i].end_point = util.linlin(0,127,min_fade[i].end_point,max_fade[i].end_point,val)
    dest[i].level = util.linlin(0,2,min_fade[i].level,max_fade[i].level,val)
    if shot.rate_ramp then
      dest[i].rate = util.linlin(0,127,min_fade[i].rate,max_fade[i].rate,easingFunctions[shot.rate_scaling](val,0,127,127))
    end
    dest[i].pan = util.linlin(0,127,min_fade[i].pan,max_fade[i].pan,val)
    dest[i].tilt = util.linlin(0,127,min_fade[i].tilt,max_fade[i].tilt,val)
    if i == dest.id then
      bank[b].snapshot_mute_while_running = true
      if dest[i].loop then
        softcut.loop_start(b+1,dest[i].start_point)
        softcut.loop_end(b+1,dest[i].end_point)
      end
      softcut.level(b+1,dest[i].level*dest.global_level)
      if shot.rate_ramp then
        softcut.rate(b+1,dest[i].rate*_loops.get_total_pitch_offset(b,i))
      end
      bank[b].snapshot_mute_while_running = false
      -- softcut.loop_start(b+1,dest[i].start_point)
      -- softcut.loop_end(b+1,dest[i].end_point)
      params:set("filter "..b.." dj tilt",dest[i].tilt)
    end
  end
  if val > 0 and val < 127 then
    bank[b].snapshot.partial_restore = true
  else
    bank[b].snapshot.partial_restore = false
  end
end

snap.fnl_crossfade = function(b,scene_a,scene_b,sec)
  local filter_current = params:get("filter "..b.." dj tilt")
  bank[b].snapshot.crossfade_fnl = snap.fnl(
    function(r_val)
      snap.crossfade(b,scene_a,scene_b,r_val)
    end,
    0,
    {{127,sec}}
  )
  -- TODO should still work this out:
  -- snap.fnl(
  --   function(r_val)
  --     params:set("filter tilt "..b,r_val)
  --   end,
  --   filter_current,
  --   {{bank[b].snapshot[scene_b].pad[bank[b].id].tilt,0.3}}
  -- )
end

snap.fnl = function(fn, origin, dest_ms, fps)
  return clock.run(function()
    fps = fps or 15 -- default
    local spf = 1 / fps -- seconds per frame
    fn(origin)
    for _,v in ipairs(dest_ms) do
      local count = math.floor(v[2] * fps) -- number of iterations
      local stepsize = (v[1]-origin) / count -- how much to increment by each iteration
      while count > 0 do
        clock.sleep(spf)
        origin = origin + stepsize -- move toward destination
        count = count - 1 -- count iteration
        fn(origin)
      end
    end
  end)
end

return snap