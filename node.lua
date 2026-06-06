local json = require "json"

local font_clock
local font_day
local font_room
local font_talk
local font_text
local font_track

local day = 0
local time = 0
local clock = "??"
local schedule = {}
local tracks = {}
local all_next_talks = {}
local show_language = true
local show_track = true
local is_single_day = false
local hide_talks_older_than_minutes = 25
local TOPBAR_FONT_SIZE = 70
local TALK_FONT_SIZE = 50
local PADDING = 20

local optout = resource.load_image{
    file = "camera-video-off.png";
    mipmap = true;
    nearest = true;
}

gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

local function log(what)
    return print("[pretalx] " .. what)
end

util.json_watch("schedule.json", function(new_schedule)
    log("new schedule")
    schedule = new_schedule.talks
    tracks = new_schedule.tracks
end)

util.file_watch("config.json", function(content)
    local config = json.decode(content)

    log("running on device ".. tostring(sys.get_env "SERIAL"))
    show_language = config.show_language
    show_track = config.show_track
    hide_talks_older_than_minutes = config.hide_talks_older_than_minutes

    TOPBAR_FONT_SIZE = config.standalone_topbar_size
    TALK_FONT_SIZE = config.standalone_talk_size
    PADDING = config.standalone_padding

    font_clock = resource.load_font(config.font_clock.asset_name)
    font_day = resource.load_font(config.font_day.asset_name)
    font_room = resource.load_font(config.font_room.asset_name)
    font_talk = resource.load_font(config.font_talk.asset_name)
    font_text = resource.load_font(config.font_text.asset_name)
    font_track = resource.load_font(config.font_track.asset_name)
end)

util.data_mapper{
    ["(.*)"] = function(path, data)
        log("received data '" .. data .. "' on " .. path)
        if path == "day" then
            day = tonumber(data)
        elseif path == "clock" then
            clock = data
        elseif path == "time" then
            time = tonumber(data)
        elseif path == "single_day" then
            if tostring(data) == "1" then
                is_single_day = true
            else
                is_single_day = false
            end
        end
    end,
}

local function parse_rgb(hex)
    hex = hex:gsub("#","")
    return tonumber("0x"..hex:sub(1,2))/255, tonumber("0x"..hex:sub(3,4))/255, tonumber("0x"..hex:sub(5,6))/255
end

local function check_next_talks()
    if time == 0 then
        log("No time info yet, cannot check for next talks")
        return
    end

    all_next_talks = {}

    local min_start = time - hide_talks_older_than_minutes * 60

    for idx = 1, #schedule do
        local talk = schedule[idx]

        -- Ignore all talks that have already ended here. We don't want
        -- to announce these.
        if talk.end_ts > time and talk.start_ts > min_start then
            all_next_talks[#all_next_talks+1] = talk
        end
    end
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

function node.render()
    gl.clear(0, 0, 0, 1)

    y = PADDING
    if not is_single_day then
        font_day:write(PADDING, y, string.format("Day %d", day), TOPBAR_FONT_SIZE, 1, 1, 1, 1)
    end

    local clock_width = font_clock:width(clock, TOPBAR_FONT_SIZE)
    font_clock:write(NATIVE_WIDTH-PADDING-clock_width, y, clock, TOPBAR_FONT_SIZE, 1, 1, 1, 1)

    y = y + TOPBAR_FONT_SIZE + PADDING*2
    check_next_talks()

    local time_size = TALK_FONT_SIZE
    local info_size = math.floor(TALK_FONT_SIZE * 0.8)

    local col1 = PADDING
    local col2 = PADDING*2 + 15 + font_text:width("XXX min ago", time_size)

    local track_x = 0
    local track_y = NATIVE_HEIGHT - PADDING*0.3
    local space_used_for_tracks = 0
    if show_track then
        for idx = 1, #tracks do
            track = tracks[idx]
            if track.color ~= json.null then
                r,g,b = parse_rgb(track.color)
                local track_width = font_track:width(track.name, info_size)
                local brightness = math.max(r, g, b)
                if track_x - track_width < PADDING then
                    track_x = NATIVE_WIDTH - PADDING
                    track_y = track_y - info_size - PADDING
                    space_used_for_tracks = space_used_for_tracks + 1
                end
                resource.create_colored_texture(r,g,b,1):draw(
                    track_x - track_width - PADDING*0.3,
                    track_y - PADDING*0.3,
                    track_x + PADDING*0.3,
                    track_y + info_size + PADDING*0.3
                )
                if brightness > 0.7 then
                    font_track:write(
                        track_x - track_width,
                        track_y,
                        track.name,
                        info_size,
                        0, 0, 0, 1
                    )
                else
                    font_track:write(
                        track_x - track_width,
                        track_y,
                        track.name,
                        info_size,
                        1, 1, 1, 1
                    )
                end
                track_x = track_x - track_width - PADDING
            end
        end
    end

    if #schedule == 0 then
        font_text:write(col2, y, "Fetching talks...", TALK_FONT_SIZE, 1, 1, 1, 1)
    elseif #all_next_talks == 0 and #schedule > 0 and sys.now() > 30 then
        font_text:write(col2, y, "Nope. That's it.", TALK_FONT_SIZE, 1, 1, 1, 1)
    end

    for idx = 1, #all_next_talks do
        local talk = all_next_talks[idx]

        local title = talk.title
        if show_language and talk.locale ~= json.null then
            title = title .. " (" .. talk.locale .. ")"
        end

        local title_lines = wrap(
            title,
            font_talk, TALK_FONT_SIZE, NATIVE_WIDTH - col2 - PADDING
        )

        local info_line = talk.room

        if #talk.persons > 0 then
            local joiner = ({
                de = "mit",
            })[talk.locale or ""] or "with"
            info_line = info_line .. " " .. joiner .. " " .. table.concat(talk.persons, ", ")
        end

        local info_lines = wrap(
            info_line,
            font_text, info_size, NATIVE_WIDTH - col2 - PADDING
        )

        if y + #title_lines * TALK_FONT_SIZE + 3 + #info_lines * info_size > NATIVE_HEIGHT - space_used_for_tracks*(info_size+PADDING) - PADDING then
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
        font_text:write(col2 - 15 - PADDING - time_width, y, talk_time, time_size, 1, 1, 1, 1)

        -- show optout icon for talks that are optout
        if talk.do_not_record then
            optout:draw(
                col2 - 35 - info_size, y + time_size,
                col2 - 35, y + time_size + info_size
            )
        end

        -- track
        if show_track and talk.track ~= json.null and talk.track.color ~= json.null then
            local r,g,b = parse_rgb(talk.track.color)
            resource.create_colored_texture(r,g,b,1):draw(col2 - 5 - PADDING, y, col2 - 10, y + #title_lines*TALK_FONT_SIZE + 3 + #info_lines*info_size)
        end

        -- title
        for idx = 1, #title_lines do
            font_talk:write(col2, y, title_lines[idx], TALK_FONT_SIZE, 1, 1, 1, 1)
            y = y + TALK_FONT_SIZE
        end
        y = y + 3

        -- info
        for idx = 1, #info_lines do
            font_text:write(col2, y, info_lines[idx], info_size, 1, 1, 1, .8)
            y = y + info_size
        end
        y = y + PADDING
    end
end
