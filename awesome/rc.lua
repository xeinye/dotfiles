
-- ~/.config/awesome/rc.lua
local gears         = require("gears")
local awful         = require("awful")
require("awful.autofocus")
local wibox         = require("wibox")
local beautiful     = require("beautiful")
local naughty       = require("naughty")
local hotkeys_popup = require("awful.hotkeys_popup")
require("awful.hotkeys_popup.keys")

-- ===========================================================================
-- Error handling
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Startup error!", text = awesome.startup_errors })
end

awesome.connect_signal("debug::error", function(err)
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Error!", text = tostring(err) })
end)

-- ===========================================================================
-- Paths & globals
beautiful.init(gears.filesystem.get_configuration_dir() .. "themes/default/theme.lua")
local assets_path  = os.getenv("HOME") .. "/.config/awesome/assets/"
local colors_path  = assets_path .. "colors/"
terminal           = "st"
browser            = "firefox"
editor             = os.getenv("EDITOR") or "nano"
editor_cmd         = terminal .. " -e " .. editor
modkey             = "Mod4"

-- Tag icons, wallpapers and house info
local tag_icons = {
    ["1"] = assets_path .. "targaryen.svg",
    ["2"] = assets_path .. "arryn.svg",
    ["3"] = assets_path .. "tyrell.svg",
}

local tag_wallpapers = {
    ["1"] = assets_path .. "wallpaper_targaryen.jpg",
    ["2"] = assets_path .. "wallpaper_arryn.jpg",
    ["3"] = assets_path .. "wallpaper_tyrell.jpg",
}

local tag_info = {
    ["1"] = { name = "TARGARYEN", color = "#c41e3a" },
    ["2"] = { name = "ARRYN",     color = "#4a90e2" },
    ["3"] = { name = "TYRELL",    color = "#2e8b57" },
}

local titlebar_colors = {
    ["1"] = "#c41e3a",
    ["2"] = "#4a90e2",
    ["3"] = "#2e8b57",
}

local tag_xresources = {
    ["1"] = colors_path .. "colors.targaryen",
    ["2"] = colors_path .. "colors.arryn",
    ["3"] = colors_path .. "colors.tyrell",
}

-- Pre-load icons
local icon_surfaces = {}
for tag, path in pairs(tag_icons) do
    if gears.filesystem.file_readable(path) then
        icon_surfaces[tag] = gears.surface.load_uncached(path)
    end
end

-- ===========================================================================
-- Main menu
local myawesomemenu = {
    { "Hotkeys",     function() hotkeys_popup.show_help(nil, awful.screen.focused()) end },
    { "Manual",      terminal .. " -e man awesome" },
    { "Edit config", editor_cmd .. " " .. awesome.conffile },
    { "Restart",     awesome.restart },
    { "Quit",        function() awesome.quit() end },
}

local mymainmenu = awful.menu({ items = {
    { "awesome", myawesomemenu, beautiful.awesome_icon },
    { "terminal", terminal },
}})

-- ===========================================================================
-- Titlebars
client.connect_signal("request::titlebars", function(c)
    awful.titlebar(c, { size = 28 }):setup {
        { -- Left
    left   = 8,
    right  = 4,
    widget = wibox.container.margin
},
        { -- Middle
            { align = "center", font = "Game of Thrones 11", widget = awful.titlebar.widget.titlewidget(c) },
            buttons = { awful.button({ }, 1, function() c:activate { context = "titlebar", action = "mouse_move" } end) },
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.minimizebutton(c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.closebutton(c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
end)

local calendar_widget = wibox.widget {
    date          = os.date('*t'),
    font          = "Cal Roman Capitals 12",
    spacing       = 3,
    week_numbers  = false,
    start_sunday  = false,
    long_weekdays = false,
    widget        = wibox.widget.calendar.month
}

local house_colors = {
    ["1"] = "#c41e3a",  -- Targaryen
    ["2"] = "#4a90e2",  -- Arryn
    ["3"] = "#2e8b57",  -- Tyrell
}

local function update_calendar_style()
    local tag = awful.screen.focused().selected_tag
    if not tag then return end
    local color = house_colors[tag.name] or "#ffffff"

    local function decorate_cell(widget, flag, date)
        
        if flag == "focus" then
            widget:set_markup("<b><span foreground='" .. color .. "'>" .. widget:get_text() .. "</span></b>")
        end
        return wibox.widget {
            widget,
            margins = 4,
            widget  = wibox.container.margin
        }
    end

    calendar_widget.fn_embed = decorate_cell
    calendar_widget.date = os.date('*t')  
end

tag.connect_signal("property::selected", function(t)
    if t.selected then update_calendar_style() end
end)

update_calendar_style()


-- ===========================================================================
-- Update titlebar colors
local function update_titlebar_colors()
    local tag = awful.screen.focused().selected_tag
    if not tag then return end
    local color = titlebar_colors[tag.name] or "#ffffff"

    for _, c in ipairs(tag:clients()) do
        if not c.requests_no_titlebar then
            beautiful.titlebar_bg = color
            c:emit_signal("request::titlebars")
        end
    end
    if client.focus and not client.focus.requests_no_titlebar then
        beautiful.titlebar_bg = color
        client.focus:emit_signal("request::titlebars")
    end
end

tag.connect_signal("property::selected", function(t) if t.selected then update_titlebar_colors() end end)
client.connect_signal("focus",     update_titlebar_colors)
client.connect_signal("tagged",    update_titlebar_colors)
client.connect_signal("untagged",  update_titlebar_colors)

-- Icon, name and wallpaper house
local function update_tag_visuals(tag, screen)
    local surf = icon_surfaces[tag.name] or icon_surfaces["1"]
    if surf then screen.big_icon_img:set_image(surf) end

    local info = tag_info[tag.name] or tag_info["1"]
    screen.house_name.markup = string.format(
        "<span foreground='%s' font_weight='bold'>%s</span>", info.color, info.name
    )

    local wp = tag_wallpapers[tag.name]
    if wp and gears.filesystem.file_readable(wp) then
        awful.spawn.with_shell("feh --bg-fill '" .. wp .. "'")
    end
end

-- ===========================================================================
--  Xresources per tag
local function apply_xresources_for_tag(tag)
    local file = tag_xresources[tag.name]
    if file and awful.util.file_readable(file) then
        awful.spawn.with_shell(
            "xrdb -merge '" .. file .. "' && kill -USR1 $(pidof st) 2>/dev/null || true"
        )
    end
end

tag.connect_signal("property::selected", function(t) if t.selected then apply_xresources_for_tag(t) end end)
client.connect_signal("tagged",   function(c) if c.first_tag then apply_xresources_for_tag(c.first_tag) end end)
client.connect_signal("untagged", function(c)
    local t = awful.screen.focused().selected_tag
    if t then apply_xresources_for_tag(t) end
end)

-- ===========================================================================
-- Screen & wibar 
awful.screen.connect_for_each_screen(function(s)
    s.big_icon_img = wibox.widget.imagebox()
    s.big_icon_img.resize = true
    s.big_icon_img.forced_width  = 240
    s.big_icon_img.forced_height = 240
    s.house_name = wibox.widget { font = "Game of Thrones 16", align = "center", widget = wibox.widget.textbox }

    local time_widget = wibox.widget { font = "Cal Roman Capitals 30", fg = "#ffffff", align = "center", widget = wibox.widget.textbox }
    local date_widget = wibox.widget { font = "Cal Roman Capitals 16", fg = "#ffffff", align = "center", widget = wibox.widget.textbox }
    local function update_clock()
        local t = os.date("*t")
        time_widget.text = string.format("%02d:%02d", t.hour, t.min)
        date_widget.text = os.date("%a %d %b")
    end
    update_clock()
    gears.timer { timeout = 10, autostart = true, callback = update_clock }

    local centered_icon = wibox.widget { s.big_icon_img, left = 30, right = 30, widget = wibox.container.margin }

    local content = wibox.widget {
        centered_icon,
        { s.house_name,      top = -25, left = 30, right = 30, widget = wibox.container.margin },
        { time_widget,       top =  23, left = 30, right = 30, widget = wibox.container.margin },
        { date_widget,       top =  -5, left = 30, right = 30, widget = wibox.container.margin },
        layout = wibox.layout.fixed.vertical
    }

    local big_block = wibox.widget { content, top = 60, widget = wibox.container.margin }
    big_block:buttons(gears.table.join(awful.button({}, 1, function() mymainmenu:toggle() end)))

    local systray = wibox.widget.systray()
    local layout = wibox.layout.fixed.vertical()
    layout:add(big_block)
    layout:add(systray)
    layout:add(calendar_widget)

    s.mywibar = awful.wibar({
        position = "right",
        width    = 240,
        bg       = "#0c0c0b",
        widget   = layout
    })

    tag.connect_signal("property::selected", function(t)
        if t.selected and t.screen == s then
            update_tag_visuals(t, s)
            update_titlebar_colors()
        end
    end)

    s:connect_signal("tag::history::update", function()
        if s.selected_tag then update_tag_visuals(s.selected_tag, s) end
    end)

    gears.timer.delayed_call(function()
        if s.selected_tag then
            update_tag_visuals(s.selected_tag, s)
            apply_xresources_for_tag(s.selected_tag)
            update_titlebar_colors()
        end
    end)
end)

-- ===========================================================================
-- Tags + Wall
awful.screen.connect_for_each_screen(function(s)
    awful.tag({ "1", "2", "3" }, s, awful.layout.layouts[1])
awful.spawn.once("feh --bg-fill " .. tag_wallpapers["1"])

awful.spawn.once("picom")

s.mypromptbox = awful.widget.prompt()

    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
                           awful.button({ }, 1, function () awful.layout.inc( 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(-1) end),
                           awful.button({ }, 4, function () awful.layout.inc( 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(-1) end)))
    s.mytaglist = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.all,
        buttons = taglist_buttons
    }

    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons
    }
end)

-- {{{ Mouse bindings
root.buttons(gears.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = gears.table.join(
    awful.key({ modkey,           }, "s",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore,
              {description = "go back", group = "tag"}),

    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
        end,
        {description = "focus next by index", group = "client"}
    ),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
        end,
        {description = "focus previous by index", group = "client"}
    ),
    awful.key({ modkey,           }, "w", function () mymainmenu:show() end,
              {description = "show main menu", group = "awesome"}),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous client by index", group = "client"}),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end,
              {description = "focus the previous screen", group = "screen"}),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end,
        {description = "go back", group = "client"}),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey,           }, "f", function () awful.spawn(browser) end,
              {description = "open the browser", group = "launcher"}),
    awful.key({ modkey, "Shift" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)          end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)          end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1, nil, true) end,
              {description = "increase the number of master clients", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "decrease the number of master clients", group = "layout"}),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1, nil, true)    end,
              {description = "increase the number of columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1, nil, true)    end,
              {description = "decrease the number of columns", group = "layout"}),
    awful.key({ modkey,           }, "space", function () awful.layout.inc( 1)                end,
              {description = "select next", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(-1)                end,
              {description = "select previous", group = "layout"}),

    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  -- Focus restored client
                  if c then
                    c:emit_signal(
                        "request::activate", "key.unminimize", {raise = true}
                    )
                  end
              end,
              {description = "restore minimized", group = "client"}),

    -- Prompt
    awful.key({ modkey },            "r",     function () awful.screen.focused().mypromptbox:run() end,
              {description = "run prompt", group = "launcher"}),

    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run {
                    prompt       = "Run Lua code: ",
                    textbox      = awful.screen.focused().mypromptbox.widget,
                    exe_callback = awful.util.eval,
                    history_path = awful.util.get_cache_dir() .. "/history_eval"
                  }
              end,
              {description = "lua execute prompt", group = "awesome"}),
    -- Menubar
    awful.key({ modkey }, "p", function() menubar.show() end,
              {description = "show the menubar", group = "launcher"})
)

clientkeys = gears.table.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ modkey,   }, "q",      function (c) c:kill()                         end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey,           }, "o",      function (c) c:move_to_screen()               end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey,           }, "n",
        function (c)
            c.minimized = true
        end ,
        {description = "minimize", group = "client"}),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized = not c.maximized
            c:raise()
        end ,
        {description = "(un)maximize", group = "client"}),
    awful.key({ modkey, "Control" }, "m",
        function (c)
            c.maximized_vertical = not c.maximized_vertical
            c:raise()
        end ,
        {description = "(un)maximize vertically", group = "client"}),
    awful.key({ modkey, "Shift"   }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c:raise()
        end ,
        {description = "(un)maximize horizontally", group = "client"})
)

-- Bind all key numbers to tags.
for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end,
                  {description = "view tag #"..i, group = "tag"}),
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end,
                  {description = "toggle tag #" .. i, group = "tag"}),
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end,
                  {description = "move focused client to tag #"..i, group = "tag"}),
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:toggle_tag(tag)
                          end
                      end
                  end,
                  {description = "toggle focused client on tag #" .. i, group = "tag"})
    )
end

clientbuttons = gears.table.join(
    awful.button({ }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
    end),
    awful.button({ modkey }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.resize(c)
    end)
)

-- Set keys
root.keys(globalkeys)


-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     raise = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     screen = awful.screen.preferred,
                     placement = awful.placement.no_overlap+awful.placement.no_offscreen
     }
    },

    -- Floating clients.
    { rule_any = {
        instance = {
          "mpv",  -- Firefox addon DownThemAll.
          "st",  -- Includes session name in class.
          "pinentry",
        },
        class = {
          "Arandr",
          "Blueman-manager",
          "Gpick",
          "Kruler",
          "MessageWin",  -- kalarm.
          "Sxiv",
          "Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size.
          "Wpa_gui",
          "veromix",
          "xtightvncviewer"},

        -- Note that the name property shown in xprop might be set slightly after creation of the client
        -- and the name shown there might not match defined rules here.
        name = {
          "Event Tester",  -- xev.
        },
        role = {
          "AlarmWindow",  -- Thunderbird's calendar.
          "ConfigManager",  -- Thunderbird's about:config.
          "pop-up",       -- e.g. Google Chrome's (detached) Developer Tools.
        }
      }, properties = { floating = true }},

    -- Add titlebars to normal clients and dialogs
    { rule_any = {type = { "normal", "dialog" }
      }, properties = { titlebars_enabled = true }
    },

    -- Set Firefox to always map on the tag named "2" on screen 1.
    -- { rule = { class = "Firefox" },
    --   properties = { screen = 1, tag = "2" } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
    -- buttons for the titlebar
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.resize(c)
        end)
    )

    awful.titlebar(c) : setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton (c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton   (c),
            awful.titlebar.widget.ontopbutton    (c),
            awful.titlebar.widget.closebutton    (c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", {raise = false})
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}
