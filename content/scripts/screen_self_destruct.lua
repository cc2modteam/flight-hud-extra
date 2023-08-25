g_blink_timer = 0

function begin()
    begin_load()
end

function update(screen_w, screen_h, ticks) 

    if update_screen_overrides(screen_w, screen_h, ticks)  then return end

    local this_vehicle = update_get_screen_vehicle()
    if this_vehicle:get() == false then return end

    local this_vehicle_object = update_get_vehicle_by_id(this_vehicle:get_id())
    if this_vehicle_object:get() == false then return end

    g_blink_timer = g_blink_timer + 1
    if(g_blink_timer > 30)
    then 
        g_blink_timer = 0 
    end

    if update_aircraft_attached(this_vehicle, screen_w, screen_h, ticks) then return end

    local active_mode = this_vehicle_object:get_self_destruct_mode()
    local countdown = this_vehicle_object:get_self_destruct_countdown()

    update_ui_rectangle_outline((screen_w/2)-20, (screen_h/2)-2, 40, 12, color_white)

    if active_mode == g_self_destruct_modes.locked then
        update_ui_text(0, screen_h/2, update_get_loc(e_loc.upp_lck), 128, 1, color_white, 0)
    elseif active_mode == g_self_destruct_modes.input then
        if g_blink_timer > 5 then
          update_ui_text(0, screen_h/2, string.format("%.2f", countdown / 30), 128, 1, color_white, 0)
        end
    elseif active_mode == g_self_destruct_modes.ready then
        col = color_status_warning
        update_ui_text(0, screen_h/2-12, update_get_loc(e_loc.upp_armed), 128, 1, color_white, 0)
        update_ui_text(0, screen_h/2, string.format("%.2f", countdown / 30), 128, 1, color_white, 0)
    end 
end

function input_event(event, action)
    if action == e_input_action.release then
        if event == e_input.back then
            update_set_screen_state_exit()
        end
    end
end


mfd_text_alpha = 48
color_green = color8(0, 255, 0, mfd_text_alpha)
color_green_hud = color8(0, 255, 0, 128)
color_red = color8(255, 0, 0, mfd_text_alpha)
color_yellow = color8(255, 255, 0, mfd_text_alpha)
color_warn = color8(255, 0, 0, mfd_text_alpha)

g_dest_ranges = {}
g_dest_range_samples = 12

function update_dest_range(distance, ticks)
    local sample = {d=distance, t=ticks}
    table.insert(g_dest_ranges, sample)
    if #g_dest_ranges > g_dest_range_samples then
        table.remove(g_dest_ranges, 1)
    end
    if #g_dest_ranges == g_dest_range_samples then
        local tick_time = 0
        -- get time spent
        for i = 1, #g_dest_ranges do
            tick_time = tick_time + g_dest_ranges[i].t
        end
        return g_dest_ranges[1].d, tick_time
    end

    return 0, 0
end

function putxy(x, y, txt, color)
    update_ui_text(x, y, txt, 255, 1, color, 0)
end

function puts(col, txt, color)
    update_ui_text(9 + 8 * col, mfd_text_line, txt, 255, 0, color, 0)
    mfd_text_line = mfd_text_line + 11
end

function get_vehicle_weapon(vehicle)
    local attachment_count = vehicle:get_attachment_count()

    for i = 0, attachment_count - 1 do
        local attachment = vehicle:get_attachment(i)

        if attachment:get() then
            local attachment_def = attachment:get_definition_index()

            if attachment_def == e_game_object_type.attachment_turret_15mm
            then
                return "GUN 15mm"
            elseif attachment_def == e_game_object_type.attachment_turret_30mm
            then
                return "GUN 30mm"
            elseif attachment_def == e_game_object_type.attachment_turret_40mm
            then
                return "GUN 40mm"
            elseif attachment_def == e_game_object_type.attachment_turret_heavy_cannon
            then
                return "GUN HEAVY"
            elseif attachment_def == e_game_object_type.attachment_turret_battle_cannon
            then
                return "GUN BATTLE"
            elseif attachment_def == e_game_object_type.attachment_turret_artillery
            then
                return "GND ART"
            elseif attachment_def == e_game_object_type.attachment_turret_robot_dog_capsule
            then
                return "VIRUS"
            end
        end
    end
    return ""
end

function aircraft_display_navigation_bar(vehicle, ticks)
    local waypoint_count = vehicle:get_waypoint_count()
    puts(0, "nav", color_green)

    if waypoint_count == 0 then
        g_dest_ranges = {}
    else
        puts(0, string.format("%d wpts", waypoint_count), color_green)
        -- next wpt dist if not a loop
        local has_repeat = false


        for j = 0, waypoint_count - 1, 1 do
            local waypoint = vehicle:get_waypoint(j)
            if waypoint:get_repeat_index() >= 0 then
                has_repeat = true
            end
        end

        if has_repeat then
            puts(0, "racetrack", color_green)
            g_last_dist = 0
        else
            local child_vehicle_id = vehicle:get_attached_vehicle_id(0)
            local vpos = vehicle:get_position_xz()
            local waypoint = vehicle:get_waypoint(0)
            local waypoint_pos = waypoint:get_position_xz(0)
            local dist = math.floor(vec2_dist(waypoint_pos, vpos))

            local bra_color = color_green_hud
            if dist < 10 then
                bra_color = color_yellow
            end
            local angle = math.atan(waypoint_pos:x() - vpos:x(), waypoint_pos:y() - vpos:y())
            local bearing = math.floor((angle / math.pi * 180)) % 360

            local waypoint_type = waypoint:get_type()
            if waypoint_type == e_waypoint_type.deploy then
                if child_vehicle_id >= 0 then
                    -- get the unit type
                    local child = update_get_map_vehicle_by_id(child_vehicle_id)
                    if child:get() then
                        local vehicle_definition_index = child:get_definition_index()
                        local vehicle_definition_name, vehicle_definition_region = get_chassis_data_by_definition_index(vehicle_definition_index)
                        puts(0, string.format("DEPLOY %s", vehicle_definition_name), color_green)
                    end
                end
            end

            local attack_target_type = vehicle:get_attack_target_type()


            if attack_target_type ~= e_attack_type.none then
                local attack_target_pos = vehicle:get_attack_target_position_xz()
                local attack_target_attack_type = vehicle:get_attack_target_type()
                dist = vec2_dist(vpos, attack_target_pos)
                local target_angle = math.atan(attack_target_pos:x() - vpos:x(), attack_target_pos:y() - vpos:y())
                bearing = math.floor((target_angle / math.pi * 180)) % 360

                if attack_target_attack_type == e_attack_type.airlift then
                    -- pickup
                    bra_color = color_green
                    if dist < 10 then
                        bra_color = color_yellow
                    end
                    puts(0, string.format("LIFT", math.floor(dist)), bra_color)
                else
                    -- attack
                    if dist > 0 then
                        bra_color = color_red
                        puts(0, string.format("TGT", math.floor(dist)), color_red)
                    end
                end

            end


            local hdg = math.floor((vehicle:get_rotation_y() * 360 / (math.pi * 2) % 360))
            local diff = math.floor(bearing - hdg)
            local abs_diff = math.abs(diff)
            if abs_diff > 180 then
                if diff > 0 then
                    diff = diff - 180
                else
                    diff = diff + 180
                end
            end
            if abs_diff < 170 then
                putxy(math.floor(diff / 3), 9, "v", bra_color)
            end
            putxy(1, 36, string.format("%03d", bearing), bra_color)

            -- calc ETA
            local eta = ""
            local first_range, tick_range = update_dest_range(dist, ticks)
            local moved = first_range - dist

            if dist > 500 then
                local spd = (moved / tick_range) * 33  -- m/sec
                if spd > 1 then
                    local eta_secs = math.floor(dist / spd)
                    if eta_secs > 100 then
                        local eta_mins = math.floor(eta_secs / 60)
                        eta = string.format("ETA %d min", eta_mins)
                    else
                        eta = string.format("ETA %d sec", eta_secs)
                    end

                end
            end

            if dist > 8000 then
                puts(0, string.format("%3dkm %s", math.floor(dist/1000), eta), bra_color)
            elseif dist > 2000 then
                puts(0, string.format("%1.1fkm %s", dist/1000, eta), bra_color)
            else
                puts(0, string.format("%4dm %s", math.floor(dist), eta), bra_color)
            end

            local is_group_a = waypoint:get_is_wait_group(0)
            local is_group_b = waypoint:get_is_wait_group(1)
            local is_group_c = waypoint:get_is_wait_group(2)
            local is_group_d = waypoint:get_is_wait_group(3)
            if is_group_a or is_group_b or is_group_c or is_group_d then
                local group_text = ""
                if is_group_a then group_text = group_text..update_get_loc(e_loc.upp_acronym_alpha) end
                if is_group_b then group_text = group_text..update_get_loc(e_loc.upp_acronym_beta) end
                if is_group_c then group_text = group_text..update_get_loc(e_loc.upp_acronym_charlie) end
                if is_group_d then group_text = group_text..update_get_loc(e_loc.upp_acronym_delta) end
                puts(0, "HOLD "..group_text, color_red)
            end

        end
    end
end

function aircraft_display_warning_box(vehicle)
    if vehicle:get_is_visible_by_enemy() then
        if g_blink_timer % 2 == 0 then
            puts(0, "WARN!", color_warn)
        end
    end
end

function aircraft_display_info(vehicle)
    local child_vehicle_id = vehicle:get_attached_vehicle_id(0)
    if child_vehicle_id >= 0 then
        local child = update_get_map_vehicle_by_id(child_vehicle_id)
        if child:get() then
            puts(0, "cargo:", color_green)
            local vehicle_definition_index = child:get_definition_index()
            local vehicle_definition_name, vehicle_definition_region = get_chassis_data_by_definition_index(vehicle_definition_index)
            puts(0, string.format("%s ID%d", vehicle_definition_name, child_vehicle_id), color_green)
            puts(0, get_vehicle_weapon(child), color_green)
        end
    end
end


function update_aircraft_attached(vehicle, screen_w, screen_h, ticks)
    local st, ret = pcall(function()
        mfd_text_line = 11

        local vdef = vehicle:get_definition_index()
        if get_is_vehicle_air(vdef) then
            update_set_screen_background_type(0)
            -- render aircraft displays
            -- 128 = type 0
            -- 256 = type 4
            --  64 = type 5

            if screen_w == 256 then
                aircraft_display_navigation_bar(vehicle, ticks)
            end

            if screen_w == 64 then
                aircraft_display_warning_box(vehicle)
            end

            if screen_w == 128 then
                aircraft_display_info(vehicle)
            end
            return true
        end

    end)
    if st then
        return ret
    else
        print(ret)
    end

    return false
end