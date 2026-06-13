local api, CHILDS, CONTENTS = ...

local json = require "json"
local helper = require "helper"
local anims = require(api.localized "anims")

local font_clock
local font_day
local font_room
local font_talk
local font_text
local font_track
local white = resource.create_colored_texture(1,1,1)
local fallback_track_background = resource.create_colored_texture(.5,.5,.5,1)
local optout = resource.load_image{
    file = api.localized("camera-video-off.png");
    mipmap = true;
    nearest = true;
}

local schedule = {}
local rooms = {}
local all_next_talks = {}
local room_next_talks = {}
local current_room
local text_a
local text_b
local image_a
local image_b
local day = 0
local time = 0
local clock = "??"
local show_language = true
local show_track = true
local hide_talks_older_than_minutes = 25

local M = {}

local function rgba(base, a)
    return base[1], base[2], base[3], a
end

local function log(what)
    return print("[pretalx] " .. what)
end

function M.data_trigger(path, data)
    log("received data '" .. data .. "' on " .. path)
    if path == "day" then
        day = tonumber(data)
    elseif path == "clock" then
        clock = data
    elseif path == "time" then
        time = tonumber(data)
    end
end

function M.updated_config_json(config)
    log("running on device ".. tostring(sys.get_env "SERIAL"))
    show_language = config.show_language
    show_track = config.show_track
    hide_talks_older_than_minutes = config.hide_talks_older_than_minutes

    font_clock = resource.load_font(api.localized(config.font_clock.asset_name))
    font_day = resource.load_font(api.localized(config.font_day.asset_name))
    font_room = resource.load_font(api.localized(config.font_room.asset_name))
    font_talk = resource.load_font(api.localized(config.font_talk.asset_name))
    font_text = resource.load_font(api.localized(config.font_text.asset_name))
    font_track = resource.load_font(api.localized(config.font_track.asset_name))

    current_room = nil
    for idx, room in ipairs(config.rooms) do
        log(tostring(room.serial) .. " room '" .. room.name .. "'")
        if room.serial == sys.get_env "SERIAL" then
            log("found my room: " .. room.name)
            pp(room)
            current_room = room.name
            text_a = room.text_a
            text_b = room.text_b
            image_a = resource.load_image{
                file = api.localized(room.image_a.asset_name);
                mipmap = true;
                nearest = true;
            }
            image_b = resource.load_image{
                file = api.localized(room.image_b.asset_name);
                mipmap = true;
                nearest = true;
            }
        end
    end
end

function M.updated_schedule_json(new_schedule)
    log("new schedule")
    schedule = new_schedule.talks
end

function M.updated_uuid_json(new_uuids)
    log("new room uuid mapping")
    rooms = new_uuids
end

local function wrap(str, font, size, max_w)
    local lines = {}
    local space_w = font:width(" ", size)

    local remaining = max_w
    local line = {}
    for non_space in str:gmatch("%S+") do
        local w = font:width(non_space, size)
        if remaining - w < 0 then
            lines[#lines+1] = table.concat(line, "")
            line = {}
            remaining = max_w
        end
        line[#line+1] = non_space
        line[#line+1] = " "
        remaining = remaining - w - space_w
    end
    if #line > 0 then
        lines[#lines+1] = table.concat(line, "")
    end
    return lines
end

local function has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end


local function check_next_talks()
    log("time is now " .. time)
    if time == 0 then
        log("No time info yet, cannot check for next talks")
        return
    end

    room_next_talks = {}
    all_next_talks = {}

    local min_start = time - hide_talks_older_than_minutes * 60

    if current_room then
        log("my room is '" .. current_room .. "'")
    else
        log("running without room selection!")
    end

    for idx = 1, #schedule do
        local talk = schedule[idx]

        -- Ignore all talks that have already ended here. We don't want
        -- to announce these.
        if talk.end_ts > time and talk.start_ts > min_start then
            -- is this in *this* room, or somewhere else?
            if current_room and (talk.room == current_room or talk.room_uuid == current_room) then
                room_next_talks[#room_next_talks+1] = talk
            end
            all_next_talks[#all_next_talks+1] = talk
        end
    end

    log(tostring(#all_next_talks) .. " talks to come")
    log(tostring(#room_next_talks) .. " in this room")
end

local function view_next_talk(starts, ends, config, x1, y1, x2, y2)
    local font_size = config.font_size or 70
    local show_abstract = config.next_abstract
    local track_text = config.next_track_text
    local default_color = {helper.parse_rgb(config.color or "#ffffff")}

    local a = anims.Area(x2 - x1, y2 - y1)

    local S = starts
    local E = ends

    local function text(...)
        return a.add(anims.moving_font(S, E, ...))
    end

    local x, y = 0, 0

    local time_size = font_size
    local title_size = font_size
    local abstract_size = math.floor(font_size * 0.8)
    local speaker_size = math.floor(font_size * 0.8)
    local track_size = math.floor(font_size * 0.6)

    local current_talk = room_next_talks[1]

    local col1 = 0
    local col2 = 35 + font_text:width("in XXX min", time_size)

    if #schedule == 0 then
        text(font_text, col2, y, "Fetching talks...", time_size, rgba(default_color,1))
    elseif not current_talk then
        text(font_text, col2, y, "Nope. That's it.", time_size, rgba(default_color,1))
    else
        -- Time
        text(font_text, col1, y, current_talk.start_str, time_size, rgba(default_color,1))

        -- Delta
        local delta = current_talk.start_ts - time
        local talk_time
        if delta > 180*60 then
            talk_time = string.format("in %d h", math.floor(delta/3600))
        elseif delta > 0 then
            talk_time = string.format("in %d min", math.floor(delta/60)+1)
        else
            talk_time = "Now"
        end

        local y_time = y+time_size
        text(font_text, col1, y_time, talk_time, time_size, rgba(default_color,1))

        -- show optout icon for talks that are optout
        if current_talk.do_not_record and a.height > (time_size * 3) then
            a.add(anims.moving_image(
                S, E, optout,
                col1, y + time_size * 2,
                col1 + time_size, y + time_size * 3,
                1
            ))
        end

        -- Title
        local y_start = y

        local title = current_talk.title
        if show_language and current_talk.locale ~= json.null then
            title = title .. " (" .. current_talk.locale .. ")"
        end

        local lines = wrap(title, font_talk, title_size, a.width - col2)
        for idx = 1, math.min(5, #lines) do
            text(font_talk, col2, y, lines[idx], title_size, rgba(default_color,1))
            y = y + title_size
        end
        y = y + 20

        -- Show abstract only if it fits into the drawing area completely
        local lines = wrap(current_talk.abstract, font_text, abstract_size, a.width - col2)
        if show_abstract and a.height > (y + #lines*abstract_size + 20) then
            for idx = 1, #lines do
                text(font_text, col2, y, lines[idx], abstract_size, rgba(default_color,1))
                y = y + abstract_size
            end
            y = y + 20
        end

        -- Show speakers only if all of them do fit into the drawing area
        if a.height > (y + #current_talk.persons*speaker_size + 20) then
            for idx = 1, #current_talk.persons do
                text(font_text, col2, y, current_talk.persons[idx], speaker_size, rgba(default_color,.8))
                y = y + speaker_size
            end
        end

        if show_track and current_talk.track ~= json.null and current_talk.track.color ~= json.null then
            local r,g,b = helper.parse_rgb(current_talk.track["color"])

            if track_text then
                if a.height > y + 30 + track_size then
                    local brightness = math.max(r,g,b)
                    local track_width = font_track:width(current_talk.track.name, track_size)

                    a.add(anims.moving_image_raw(
                        S, E, resource.create_colored_texture(r,g,b,1),
                        col2, y + 20,
                        col2 + track_width + 10, y + track_size + 30
                    ))
                    if brightness > 0.6 then
                        text(font_track, col2+5, y+25, current_talk.track.name, track_size, 0,0,0,1)
                    else
                        text(font_track, col2+5, y+25, current_talk.track.name, track_size, 1,1,1,1)
                    end
                end
            else
                a.add(anims.moving_image_raw(
                    S, E, resource.create_colored_texture(r,g,b,1),
                    col2 - 25, 0,
                    col2 - 10, y
                ))
            end
        end
    end

    for now in api.frame_between(starts, ends) do
        a.draw(now, x1, y1, x2, y2)
    end
end

local function view_all_talks(starts, ends, config, x1, y1, x2, y2)
    local title_size = config.font_size or 70
    local default_color = {helper.parse_rgb(config.color or "#ffffff")}
    local show_speakers = config.all_speakers or true
    local proposal_type_filter = config.proposal_type_filter or ""
    local proposal_types = {}

    if proposal_type_filter ~= "" then
        log("filtering for proposals with type: ")
        for i in string.gmatch(proposal_type_filter, "([^;]+)") do
            table.insert(proposal_types, i)
            log("  - '" .. i .. "'")
        end
    end

    local a = anims.Area(x2 - x1, y2 - y1)

    local S = starts
    local E = ends

    local time_size = title_size
    local info_size = math.floor(title_size * 0.8)

    -- always leave room for 15px of track bar
    local col1 = 0
    local col2 = 35 + font_text:width("XXX min ago", time_size)

    local x, y = 0, 0

    local function text(...)
        return a.add(anims.moving_font(S, E, ...))
    end

    if #schedule == 0 then
        text(font_text, col2, y, "Fetching talks...", title_size, rgba(default_color,1))
    elseif #all_next_talks == 0 and #schedule > 0 and sys.now() > 30 then
        text(font_text, col2, y, "Nope. That's it.", title_size, rgba(default_color,1))
    end

    for idx = 1, #all_next_talks do
        local talk = all_next_talks[idx]

        local show_this_talk = true
        if talk.type ~= json.null and proposal_type_filter ~= "" then
            show_this_talk = has_value(proposal_types, talk.type)
        end

        if show_this_talk then
            local title = talk.title
            if show_language and talk.locale ~= json.null then
                title = title .. " (" .. talk.locale .. ")"
            end

            local title_lines = wrap(
                title,
                font_talk, title_size, a.width - col2
            )

            local info_line = talk.room

            if show_speakers and #talk.persons > 0 then
                local joiner = ({
                    de = "mit",
                })[talk.locale or ""] or "with"
                info_line = info_line .. " " .. joiner .. " " .. table.concat(talk.persons, ", ")
            end

            local info_lines = wrap(
                info_line,
                font_text, info_size, a.width - col2
            )

            if y + #title_lines * title_size + 3 + #info_lines * info_size > a.height then
                break
            end

            -- time
            local talk_time
            local delta = talk.start_ts - time
            if delta > -60 and delta < 60 then
                talk_time = "Now"
            elseif delta > 30*60 then
                talk_time = talk.start_str
            elseif delta > 0 then
                talk_time = string.format("in %d min", math.floor(delta/60)+1)
            else
                talk_time = string.format("%d min ago", math.ceil(-delta/60))
            end
            local time_width = font_text:width(talk_time, time_size)
            text(font_text, col2 - 35 - time_width, y, talk_time, time_size, rgba(default_color, 1))

            -- show optout icon for talks that are optout
            if talk.do_not_record then
                a.add(anims.moving_image(
                    S, E, optout,
                    col2 - 35 - info_size, y + time_size,
                    col2 - 35, y + time_size + info_size,
                    1
                ))
            end

            -- track
            if show_track and talk.track ~= json.null and talk.track.color ~= json.null then
                local r,g,b = helper.parse_rgb(talk.track.color)
                a.add(anims.moving_image_raw(
                    S, E, resource.create_colored_texture(r,g,b,1),
                    col2 - 25, y,
                    col2 - 10, y + #title_lines*title_size + 3 + #info_lines*info_size
                ))
            end

            -- title
            for idx = 1, #title_lines do
                text(font_talk, col2, y, title_lines[idx], title_size, rgba(default_color,1))
                y = y + title_size
            end
            y = y + 3

            -- info
            for idx = 1, #info_lines do
                text(font_text, col2, y, info_lines[idx], info_size, rgba(default_color,.8))
                y = y + info_size
            end
            y = y + 20
        end
    end

    for now in api.frame_between(starts, ends) do
        a.draw(now, x1, y1, x2, y2)
    end
end

local function view_room(starts, ends, config, x1, y1, x2, y2)
    local font_size = config.font_size or 70
    local align = config.room_align or "left"
    local animate = config.room_animate or true
    local default_color = {helper.parse_rgb(config.color or "#ffffff")}
    local r,g,b = helper.parse_rgb(config.color or "#ffffff")

    local a = anims.Area(x2 - x1, y2 - y1)

    local S = starts
    local E = ends

    local function text(...)
        return a.add(anims.moving_font(S, E, ...))
    end

    local room_name = current_room;
    if rooms[current_room] ~= nil then
        room_name = rooms[current_room]
    end

    local x = 0
    local w = font_room:width(room_name, font_size)
    if align == "right" then
        x = a.width - w
    elseif align == "center" then
        x = (a.width - w) / 2
    end
    text(font_room, x, 0, room_name, font_size, rgba(default_color,1))

    for now in api.frame_between(starts, ends) do
        if animate then
            a.draw(now, x1, y1, x2, y2)
        else
            font_room:write(x1+x, y1, room_name, font_size, r,g,b,1)
        end
    end
end

local function view_clock(starts, ends, config, x1, y1, x2, y2)
    local font_size = config.font_size or 70
    local align = config.clock_align or "left"
    local animate = config.clock_animate or false
    local default_color = {helper.parse_rgb(config.color or "#ffffff")}
    local r,g,b = helper.parse_rgb(config.color or "#ffffff")

    local a = anims.Area(x2 - x1, y2 - y1)

    local S = starts
    local E = ends

    local function text(...)
        return a.add(anims.moving_font(S, E, ...))
    end

    local x = 0
    local w = font_clock:width(clock, font_size)
    if align == "right" then
        x = a.width - w
    elseif align == "center" then
        x = (a.width - w) / 2
    end
    text(font_clock, x, 0, clock, font_size, rgba(default_color,1))

    for now in api.frame_between(starts, ends) do
        if animate then
            a.draw(now, x1, y1, x2, y2)
        else
            x = 0
            w = font_clock:width(clock, font_size)
            if align == "right" then
                x = a.width - w
            elseif align == "center" then
                x = (a.width - w) / 2
            end
            font_clock:write(x1+x, y1, clock, font_size, r,g,b,1)
        end
    end
end

local function view_day(starts, ends, config, x1, y1, x2, y2)
    local font_size = config.font_size or 70
    local align = config.day_align or "left"
    local template = config.day_template or "Day %d"
    local animate = config.day_animate
    local default_color = {helper.parse_rgb(config.color or "#ffffff")}
    local r,g,b = helper.parse_rgb(config.color or "#ffffff")

    local a = anims.Area(x2 - x1, y2 - y1)

    local S = starts
    local E = ends

    local function text(...)
        return a.add(anims.moving_font(S, E, ...))
    end

    local x = 0
    local line = string.format(template, day)
    local w = font_day:width(line, font_size)
    if align == "right" then
        x = a.width - w
    elseif align == "center" then
        x = (a.width - w) / 2
    end
    text(font_day, x, 0, line, font_size, rgba(default_color,1))

    for now in api.frame_between(starts, ends) do
        if animate then
            a.draw(now, x1, y1, x2, y2)
        else
            x = 0
            line = string.format(template, day)
            w = font_day:width(line, font_size)
            if align == "right" then
                x = a.width - w
            elseif align == "center" then
                x = (a.width - w) / 2
            end
            font_day:write(x1+x, y1, line, font_size, r,g,b,1)
        end
    end
end

local function view_info(starts, ends, config, x1, y1, x2, y2)
    local font_size = config.font_size or 70
    local align = config.info_align or "left"
    local animate = config.info_animate or true
    local default_color = {helper.parse_rgb(config.color or "#ffffff")}
    local r,g,b = helper.parse_rgb(config.color or "#ffffff")
    -- keep this as "info_text_source" to not break existing setups
    local info_source = config.info_text_source or "a"

    local a = anims.Area(x2 - x1, y2 - y1)

    local S = starts
    local E = ends

    local function text(...)
        return a.add(anims.moving_font(S, E, ...))
    end

    local info_mode = "text"
    local info_content = text_a
    if info_source == "b" then
        info_content = text_b
    elseif info_source == "image_a" then
        info_mode = "image"
        info_content = image_a
    elseif info_source == "image_b" then
        info_mode = "image"
        info_content = image_b
    end

    if info_mode == "text" then
        local y = 0
        for line in string.gmatch(info_content.."\n", "([^\n]*)\n") do
            if line ~= "" then
                local lines = wrap(
                    line,
                    font_text, font_size, a.width
                )

                for idx = 1, #lines do
                    local x = 0
                    local w = font_text:width(lines[idx], font_size)

                    if align == "right" then
                        x = a.width - w
                    elseif align == "center" then
                        x = (a.width - w) / 2
                    end

                    text(font_text, x, y, lines[idx], font_size, rgba(default_color,.8))
                    y = y + font_size
                end
            else
                y = y + font_size*0.5
            end
        end

        for now in api.frame_between(starts, ends) do
            if animate then
                a.draw(now, x1, y1, x2, y2)
            else
                local y = 0
                for line in string.gmatch(info_content.."\n", "([^\n]*)\n") do
                    local lines = wrap(
                        line,
                        font_text, font_size, a.width
                    )

                    for idx = 1, #lines do
                        local x = 0
                        local w = font_text:width(lines[idx], font_size)

                        if align == "right" then
                            x = a.width - w
                        elseif align == "center" then
                            x = (a.width - w) / 2
                        end

                        font_text:write(x, y, lines[idx], font_size, r,g,b,1)
                        y = y + font_size
                    end
                end
            end
        end
    else
        local w = x2 - x1
        local h = y2 - y1
        a.add(anims.moving_image(
            S, E, info_content,
            0, 0,
            w, h,
            1
        ))
        for now in api.frame_between(starts, ends) do
            if animate then
                a.draw(now, x1, y1, x2, y2)
            else
                util.draw_correct(info_content, 0, 0, w, h)
            end
        end
    end
end

function M.task(starts, ends, config, x1, y1, x2, y2)
    check_next_talks()
    return ({
        next_talk = view_next_talk,
        all_talks = view_all_talks,

        room = view_room,
        day = view_day,
        clock = view_clock,
        info = view_info,
    })[config.mode or 'all_talks'](starts, ends, config, x1, y1, x2, y2)
end

function M.can_show(config)
    local mode = config.mode or 'all_talks'
    -- these can always play
    if mode == "day" or
       mode == "all_talks" or
       mode == "clock"
    then
        return true
    end
    return not not current_room
end

return M
