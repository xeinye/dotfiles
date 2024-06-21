-- colors
local lexers = vis.lexers
local colors = {
	['base00'] = '#1c1c1c',
	['base01'] = '#dddddd',
}

lexers.colors = colors
local fg = ',fore:'..colors.base01..','
local bg = ',back:'..colors.base00..','
lexers.STYLE_DEFAULT = bg..fg
lexers.STYLE_NOTHING = bg
