local _, ns = ...

-- stevio-ui's entry in Blizzard's Options -> AddOns: a short explanation and
-- a button that opens the settings window (Window.lua), where everything is
-- changed. The reset dialog lives here too, shared by the window and /sui reset.

local Window = ns.SettingsWindow
local T = ns.T

local RESET_DIALOG = "STEVIOUI_RESET_CONFIG"
ns.RESET_CONFIG_DIALOG = RESET_DIALOG

StaticPopupDialogs[RESET_DIALOG] = {
	text = T(
		"Reset all stevio-ui options, your own keys and game settings to the defaults in code and reload the UI? The backup is kept.",
		"Alle stevio-ui-Optionen, eigenen Tasten und Spieleinstellungen auf die Vorgaben im Code zurücksetzen und das UI neu laden? Die Sicherung bleibt erhalten."
	),
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		StevioUIConfig.values, StevioUIConfig.bindings, StevioUIConfig.cvars = {}, {}, {}
		ReloadUI()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local function CreateBlizzardPage()
	local page = CreateFrame("Frame")
	page:Hide()
	local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("stevio-ui")
	local text = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
	text:SetWidth(560)
	text:SetJustifyH("LEFT")
	text:SetSpacing(3)
	text:SetText(
		T(
			"stevio-ui has a settings window of its own: every option with an explanation, a search, keybindings, graphics and the profile with its backup. Open it with the button below, /sui config or the gear in the notch island.\n\nKeybindings and graphics you change in Blizzard's menus are kept as your own changes.",
			"stevio-ui hat ein eigenes Einstellungsfenster: jede Option mit Erklärung, eine Suche, Tastenbelegung, Grafik und das Profil mit seiner Sicherung. Öffnen über den Knopf unten, /sui config oder das Zahnrad in der Notch-Insel.\n\nTasten und Grafik, die du in Blizzards Menüs änderst, bleiben als eigene Änderungen erhalten."
		)
	)
	local open = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	open:SetSize(200, 26)
	open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -20)
	open:SetText(T("Open settings", "Einstellungen öffnen"))
	open:SetScript("OnClick", function()
		if SettingsPanel and SettingsPanel:IsShown() then
			HideUIPanel(SettingsPanel)
		end
		Window.Open()
	end)
	return page
end

-- Opens the settings window on a module's page (e.g. "players").
function ns.OpenOptionsPage(key)
	Window.Open("module", key)
end

function ns.SetupOptionsPanel()
	Window.Setup()
	ns.RegisterSlashCommand("reset", function()
		StaticPopup_Show(RESET_DIALOG)
	end)
	local category = Settings.RegisterCanvasLayoutCategory(CreateBlizzardPage(), "stevio-ui")
	Settings.RegisterAddOnCategory(category)
end
