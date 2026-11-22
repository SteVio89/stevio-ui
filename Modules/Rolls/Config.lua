local _, ns = ...

ns.config.rolls = {
	enabled = true,

	-- Our cards take the place of Blizzard's Need/Greed/Pass popup. Turn this
	-- off (and /reload) to get Blizzard's popup back, e.g. if it ever causes
	-- taint; the cards then still show the rolls and winners once you rolled.
	replaceBlizzardRolls = true,

	-- Cards hang below the notch (below its island while that is open),
	-- stacked downwards: open rolls first, answered ones below them.
	width = 320,
	fontSize = 14,
	iconSize = 20,
	padding = 6,
	-- Gap below the notch and between two cards.
	notchGap = 6,
	cardGap = 4,
	-- The stripe on the left and the timer bar, in the item's quality color.
	stripeWidth = 2,
	timerHeight = 3,
	-- The stack glides to its new place in this many seconds.
	slideTime = 0.2,

	-- Answered cards list this many rolls of other players plus your own.
	topRolls = 3,
	-- Once the winner is known a card stays this many seconds (longer while
	-- the cursor is over it), then fades out.
	holdAfterWinner = 15,
	fadeOutTime = 1,
	-- Opacity of a card you passed on.
	passedAlpha = 0.6,
	-- An answered roll without a result stays at most this many seconds
	-- after its timer ran out (e.g. after leaving the group).
	resultTimeout = 60,

	-- The history window takes the loot ticker's place at the bottom left,
	-- with the ticker's width and height.
	history = {
		fontSize = 14,
		iconSize = 20,
		rowHeight = 23,
		headerHeight = 22,
		rollHeight = 18,
	},
}
