local _, ns = ...

-- The /sui commands with what they do, for "Commands & help" on the start
-- page of the settings window. Kept free of WoW API calls;
-- tests/settings_help_test.lua checks that every registered command is here.

local Help = {}
ns.SettingsHelp = Help

-- { command, arguments, english, german } in the order shown.
Help.COMMANDS = {
	{ "config", "", "Opens this window (so does /sui alone).", "Öffnet dieses Fenster (auch /sui allein)." },
	{
		"test",
		"5|10|25|40",
		"Fills the group grid with test players; without a number it ends.",
		"Füllt das Gruppenraster mit Testspielern; ohne Zahl endet die Vorschau.",
	},
	{
		"bars",
		"[name|next|missing|forget]",
		"Lists or switches the action sets.",
		"Listet die Aktions-Sets oder wechselt sie.",
	},
	{
		"players",
		"[name|reset]",
		"Opens the player database, or one player's page.",
		"Öffnet die Spielerdatenbank oder die Seite eines Spielers.",
	},
	{
		"notes",
		"[item link]",
		"Opens the notes, or the note of an item.",
		"Öffnet die Notizen oder die Notiz eines Gegenstands.",
	},
	{
		"roll",
		"[1-5|history]",
		"Simulates loot rolls with items from your bags.",
		"Simuliert Beutewürfe mit Gegenständen aus deinen Taschen.",
	},
	{ "rolls", "", "Shows sample roll cards and history.", "Zeigt Beispiel-Würfelkarten und den Verlauf." },
	{ "loot", "", "Shows sample lines in the loot ticker.", "Zeigt Beispielzeilen im Beuteticker." },
	{
		"apply",
		"",
		"Applies the profile again (keys, game settings, action bars).",
		"Wendet das Profil erneut an (Tasten, Spieleinstellungen, Aktionsleisten).",
	},
	{
		"export",
		"",
		"Writes the current keys and game settings as a Profile.lua.",
		"Schreibt die aktuellen Tasten und Spieleinstellungen als Profile.lua.",
	},
	{
		"restore",
		"",
		"Brings back your settings from before stevio-ui and disables it.",
		"Stellt deine Einstellungen von vor stevio-ui wieder her und deaktiviert es.",
	},
	{
		"reset",
		"",
		"Resets every option to the defaults in code (asks first).",
		"Setzt alle Optionen auf die Vorgaben im Code zurück (mit Nachfrage).",
	},
	{
		"errors",
		"[clear]",
		"Shows stevio-ui's errors, also those of earlier sessions.",
		"Zeigt die Fehler von stevio-ui, auch aus früheren Sitzungen.",
	},
	{
		"chat",
		"",
		"Lists the chat channels and how many lines they hold.",
		"Listet die Chatkanäle und wie viele Zeilen sie haben.",
	},
	{
		"notch",
		"",
		"Writes the notch geometry for troubleshooting.",
		"Schreibt die Notch-Geometrie zur Fehlersuche.",
	},
}

-- "/sui test 5|10|25|40" and the explanation in the client's language.
function Help.Lines()
	local lines = {}
	for _, command in ipairs(Help.COMMANDS) do
		local text = "/sui " .. command[1]
		if command[2] ~= "" then
			text = text .. " " .. command[2]
		end
		lines[#lines + 1] = { command = text, text = ns.T(command[3], command[4]) }
	end
	return lines
end
