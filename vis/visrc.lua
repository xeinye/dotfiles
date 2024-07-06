-- load standard vis module, providing parts of the Lua API
require('vis')
vis.events.subscribe(vis.events.INIT, function()
	-- Your global configuration options
	vis:command('set theme custom')
	vis:command('set autoindent on')
	vis:command('set ic on')
	vis:command('set change-256colors off')
	end)

vis:map(vis.modes.NORMAL, '<C-p>', '"+p')
vis:map(vis.modes.INSERT, '<C-p>', '<Escape>"+pa')
vis:map(vis.modes.VISUAL_LINE, '<C-y>', function() vis:feedkeys(':>vis-clipboard --copy<Enter>') end)
vis:map(vis.modes.VISUAL, '<C-y>', function() vis:feedkeys(':>vis-clipboard --copy<Enter>') end)

vis.events.subscribe(vis.events.WIN_OPEN, function(win)
	-- Your per window configuration options e.g.
	vis:command('set show-eof off')
end)
