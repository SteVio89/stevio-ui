local addonName, ns = ...

-- The addon takes over keybindings, CVars, action bars and the Edit Mode layout
-- account-wide. It is all or nothing, so nothing loads until the player agrees,
-- and declining turns the addon off instead of leaving half a UI behind.

local DIALOG = "STEVIOUI_CONSENT"

local text
if GetLocale() == "deDE" then
	text = {
		body = "%s ist eine komplette UI und überschreibt account-weit deine Tastenbelegungen, Grafik- und Interface-Einstellungen, Aktionsleisten und das Edit-Mode-Layout.\n\nDeine bisherigen Einstellungen werden vorher gesichert. /sui restore stellt sie wieder her und deaktiviert das Addon.",
		accept = "Übernehmen",
		decline = "Addon deaktivieren",
	}
else
	text = {
		body = "%s is a complete UI and overwrites your keybindings, graphics and interface settings, action bars and Edit Mode layout account-wide.\n\nYour current settings are backed up first. /sui restore brings them back and disables the addon.",
		accept = "Take over",
		decline = "Disable addon",
	}
end

-- OnButton1/OnButton2 with selectCallbackByIndex only fire on a real click, so
-- Escape or another popup pushing this one away can't disable the addon.
StaticPopupDialogs[DIALOG] = {
	text = text.body,
	button1 = text.accept,
	button2 = text.decline,
	selectCallbackByIndex = true,
	OnButton1 = function()
		StevioUIState = { consented = true, backup = ns.CaptureBackup() }
		ReloadUI()
	end,
	OnButton2 = function()
		C_AddOns.DisableAddOn(addonName)
		ReloadUI()
	end,
	showAlert = true,
	timeout = 0,
	whileDead = true,
	hideOnEscape = false,
}

function ns.ShowConsent()
	StaticPopup_Show(DIALOG, addonName)
end
