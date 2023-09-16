g_blink_timer = 0
g_self_has_radar = nil

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

function get_has_radar(vehicle)
    local attachment_count = vehicle:get_attachment_count()

    for i = 0, attachment_count - 1 do
        local attachment = vehicle:get_attachment(i)

        if attachment:get() then
            local attachment_def = attachment:get_definition_index()
            if attachment_def == e_game_object_type.attachment_radar_awacs then
                return true
            elseif attachment_def == e_game_object_type.attachment_radar_golfball then
                return true
            elseif attachment_def == e_game_object_type.attachment_turret_carrier_missile then
                return true
            end
        end
    end
    return false
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

function eta_distance_to_text(dist, eta)
    if dist > 8000 then
        return string.format("%3dkm %s", math.floor(dist/1000), eta)
    elseif dist > 2000 then
        return string.format("%1.1fkm %s", dist/1000, eta)
    end
    return string.format("%4dm %s", math.floor(dist), eta)
end

function get_eta_text(dist, spd)
    local eta = ""
    if dist > 500 then
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
    return eta
end

function aircraft_display_navigation_bar(vehicle, ticks)
    local waypoint_count = vehicle:get_waypoint_count()
    puts(0, "nav", color_green)

    if waypoint_count == 0 then
        g_dest_ranges = {}
    else
        local total_wpt_dist = 0.0

        -- next wpt dist if not a loop
        local has_repeat = false
        local prev_pos = nil
        for j = 0, waypoint_count - 1, 1 do
            local waypoint = vehicle:get_waypoint(j)
            if waypoint:get_repeat_index() >= 0 then
                has_repeat = true
            else
                if j > 0 then
                    local next_pos = waypoint:get_position_xz()
                    local next_dist = math.floor(vec2_dist(next_pos, prev_pos))
                    total_wpt_dist = total_wpt_dist + next_dist
                end
                prev_pos = waypoint:get_position_xz()
            end
        end
        puts(0, string.format("%d wpts", waypoint_count), color_green)

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
            local spd = (moved / tick_range) * 33  -- m/sec

            if dist > 500 then
                eta = get_eta_text(dist, spd)
            end

            puts(0, eta_distance_to_text(dist, eta), bra_color)

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

            if total_wpt_dist > 0 then
                local all_dist = total_wpt_dist + dist
                local all_eta = get_eta_text(all_dist, spd)
                puts(0, eta_distance_to_text(all_dist, all_eta), bra_color)
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

function aircraft_display_info_petrel(vehicle)
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

function aircraft_display_info_razorbill(vehicle)
    update_set_screen_background_type(9)

    update_set_screen_camera_attach_vehicle(vehicle:get_id(), 0)
    update_set_screen_camera_render_attached_vehicle(false)
    update_set_screen_camera_cull_distance(5000)

    update_set_screen_camera_lod_level(0)
    update_set_screen_camera_is_render_map_vehicles(true)
    update_set_screen_camera_is_render_ocean(true)
end

function render_circle(x, y, radius, col)
    local steps = math.max(math.floor(radius), 8)
    local step = math.pi * 2 / steps

    for i = 0, steps - 1 do
        local angle = i * step
        local angle_next = angle + step
        update_ui_line(
            math.ceil(x + math.cos(angle) * radius),
            math.ceil(y + math.sin(angle) * radius),
            math.ceil(x + math.cos(angle_next) * radius),
            math.ceil(y + math.sin(angle_next) * radius),
            col
        )
    end
end

function rotate_xy(x, y, a)
    local s = math.sin(a)
    local c = math.cos(a)
    return x * c - y * s, x * s + y * c
end

function render_box(x, y, w, col)
    local left = x - math.floor(w / 2)
    local right = left + w
    local top = y - math.floor(w / 2)
    local bot = top + w

    update_ui_line(left, top, right, top, col)
    update_ui_line(right, top + 1, right, bot, col)
    update_ui_line(right, bot, left, bot, col)
    update_ui_line(left, bot + 1, left, top, col)

    -- diamond
    --update_ui_line(left, y, x, top, col)
    --update_ui_line(x, top, right, y, col)
    --update_ui_line(right, y, x, bot, col)
    --update_ui_line(x, bot, left, y, col)
end

function aircraft_display_info_radar(current_vehicle, screen_w, screen_h)
    -- chop off 20px from right and bottom
    local color_radar_ring = color8(0, 100, 0, 32)
    update_ui_push_offset(6, 6)

    screen_h = 63
    screen_w = screen_h

    -- find every friendly air unit within 10km
    -- find every visible hostile air unit within 10km
    if not current_vehicle:get() then
        return
    end
    local radar_range = 10000
    render_circle(
            screen_w/2, screen_h/2, screen_w/2, color_radar_ring
    )
    render_circle(
            screen_w/2, screen_h/2, screen_w/4, color_radar_ring
    )

    local current_pos = current_vehicle:get_position_xz()
    local current_team = current_vehicle:get_team()
    local current_hdg = current_vehicle:get_direction()
    local self_hdg_rad = math.atan(current_hdg:x(), current_hdg:y())


    local vehicle_count = update_get_map_vehicle_count()

    for i = 0, vehicle_count - 1, 1 do
        local vehicle = update_get_map_vehicle_by_index(i)
        if vehicle:get() then
            local vehicle_definition_index = vehicle:get_definition_index()
            if vehicle_definition_index ~= e_game_object_type.chassis_spaceship and vehicle_definition_index ~= e_game_object_type.drydock then
                local vehicle_team = vehicle:get_team()
                local vehicle_attached_parent_id = vehicle:get_attached_parent_id()
                local vehicle_color = color_green
                if vehicle_team ~= current_team then
                    vehicle_color = color_red
                end

                if vehicle_attached_parent_id == 0 and vehicle:get_is_visible() and vehicle:get_is_observation_revealed() then
                    local vehicle_pos_xz = vehicle:get_position_xz()
                    local dist = vec2_dist(vehicle_pos_xz, current_pos)
                    if dist < radar_range then
                        local size = 0
                        local render_vehicle = false
                        if get_is_vehicle_air(vehicle_definition_index) then
                            render_vehicle = true
                            size = 1
                        elseif vehicle_definition_index == e_game_object_type.chassis_carrier then
                            render_vehicle = true
                            size = 4
                        end
                        if render_vehicle then
                            local screen_pos_x, screen_pos_y = get_screen_from_world(vehicle_pos_xz:x(), vehicle_pos_xz:y(), current_pos:x(), current_pos:y(), 2 * radar_range, screen_w, screen_h)

                            if g_self_has_radar then
                                -- show vectors
                                local vehicle_dir = vehicle:get_direction()
                                local xm = screen_pos_x + vehicle_dir:x() * 8
                                local ym = screen_pos_y + vehicle_dir:y() * -8
                                update_ui_line(screen_pos_x, screen_pos_y, xm, ym, vehicle_color)
                            end

                            render_box(screen_pos_x, screen_pos_y, size, vehicle_color)
                        end
                    end
                end
            end
        end
    end
    update_ui_pop_offset()
end

-- square display
function aircraft_display_info(vehicle, screen_w, screen_h)
    local vdef = vehicle:get_definition_index()
    if vdef == e_game_object_type.chassis_air_rotor_heavy then
        aircraft_display_info_petrel(vehicle)
    elseif vdef == e_game_object_type.chassis_air_rotor_light then
        aircraft_display_info_razorbill(vehicle)
    else
        aircraft_display_info_radar(vehicle, screen_w, screen_h)
    end
end


function update_aircraft_attached(vehicle, screen_w, screen_h, ticks)
    local st, ret = pcall(function()
        mfd_text_line = 11

        local vdef = vehicle:get_definition_index()
        if get_is_vehicle_air(vdef) then
            if g_self_has_radar == nil then
                g_self_has_radar = get_has_radar(vehicle)
            end

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
                aircraft_display_info(vehicle, screen_w, screen_h)
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