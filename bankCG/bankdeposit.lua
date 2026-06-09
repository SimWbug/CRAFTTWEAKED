-- ============================================================
--  CGBank Terminal Depot v1.0  |  bank_deposit.lua
--  Installez sur un Advanced Computer a cote d'un coffre
--  et d'un modem reseau. Le joueur pose ses items dans le
--  coffre, entre son nom, et le systeme converti en CGC.
-- ============================================================

local CFG = {
    modem_side   = "top",
    server_ch    = 1000,
    my_ch        = 1001,      -- canal de reponse de CE terminal
    chest_side   = "front",   -- cote du coffre de depot
    timeout      = 5,

    COL = {
        bg      = colors.black,
        frame   = colors.cyan,
        accent  = colors.yellow,
        ok      = colors.lime,
        err     = colors.red,
        dim     = colors.gray,
        white   = colors.white,
        input   = colors.lightBlue,
    }
}

local modem = peripheral.wrap(CFG.modem_side)
local chest = peripheral.wrap(CFG.chest_side)
if not modem then error("Modem introuvable: " .. CFG.modem_side) end
if not chest then error("Coffre introuvable: " .. CFG.chest_side) end
modem.open(CFG.my_ch)

local W, H = term.getSize()

-- ╔══════════════════════════════════════════╗
-- ║         UTILITAIRES UI                   ║
-- ╚══════════════════════════════════════════╝
local function cls()
    term.setBackgroundColor(CFG.COL.bg)
    term.clear()
    term.setCursorPos(1, 1)
end

local function center(y, text, col)
    term.setCursorPos(math.floor((W - #text) / 2) + 1, y)
    if col then term.setTextColor(col) end
    term.write(text)
end

local function hline(y, col)
    term.setTextColor(col or CFG.COL.frame)
    term.setCursorPos(1, y)
    term.write(string.rep("\140", W))   -- demi-bloc horizontal
end

local function draw_header()
    cls()
    term.setBackgroundColor(CFG.COL.bg)
    hline(1, CFG.COL.frame)
    center(2, "  CGBank  |  Terminal de Depot  ", CFG.COL.accent)
    hline(3, CFG.COL.frame)
end

local function draw_box(x, y, w, h, col)
    col = col or CFG.COL.frame
    term.setTextColor(col)
    -- coins et bords ASCII safe
    term.setCursorPos(x, y); term.write("+" .. string.rep("-", w-2) .. "+")
    for i = y+1, y+h-2 do
        term.setCursorPos(x, i); term.write("|")
        term.setCursorPos(x+w-1, i); term.write("|")
    end
    term.setCursorPos(x, y+h-1); term.write("+" .. string.rep("-", w-2) .. "+")
end

local function input_field(x, y, label, max)
    term.setTextColor(CFG.COL.dim)
    term.setCursorPos(x, y)
    term.write(label)
    term.setTextColor(CFG.COL.input)
    term.setCursorPos(x + #label, y)
    local result = ""
    term.setCursorBlink(true)
    while true do
        local e, char = os.pullEvent("char")
        if char == "\n" or char == "\r" then break end
        local ev, key = os.pullEvent("key")
        if key == keys.enter then break
        elseif key == keys.backspace then
            result = result:sub(1, -2)
        elseif #result < (max or 32) then
            result = result .. (char or "")
        end
        term.setCursorPos(x + #label, y)
        term.write(string.rep(" ", max or 32))
        term.setCursorPos(x + #label, y)
        term.setTextColor(CFG.COL.input)
        term.write(result)
    end
    term.setCursorBlink(false)
    return result
end

-- Version input plus fiable
local function ask(prompt, max)
    term.setTextColor(CFG.COL.dim)
    term.write(prompt)
    term.setTextColor(CFG.COL.input)
    local result = read(nil, nil, nil, string.rep(" ", max or 24))
    return result
end

-- ╔══════════════════════════════════════════╗
-- ║         COMMUNICATION RESEAU             ║
-- ╚══════════════════════════════════════════╝
local function send(cmd_table)
    cmd_table.reply_ch = CFG.my_ch
    modem.transmit(CFG.server_ch, CFG.my_ch, cmd_table)
    local timer = os.startTimer(CFG.timeout)
    while true do
        local e, s, ch, rch, msg = os.pullEvent()
        if e == "modem_message" and ch == CFG.my_ch and type(msg) == "table" then
            return msg
        elseif e == "timer" and s == timer then
            return { ok = false, msg = "Timeout - serveur non repond" }
        end
    end
end

-- ╔══════════════════════════════════════════╗
-- ║         SCAN DU COFFRE                   ║
-- ╚══════════════════════════════════════════╝
local function scan_chest()
    local items = {}
    local inv = chest.list()
    for slot, item in pairs(inv) do
        -- Cherche si cet item est deja dans la liste
        local found = false
        for _, entry in ipairs(items) do
            if entry.name == item.name then
                entry.count = entry.count + item.count
                found = true; break
            end
        end
        if not found then
            table.insert(items, { name = item.name, count = item.count, slot = slot })
        end
    end
    return items
end

local function empty_chest()
    -- Vide le coffre (les items sont "consommes" par la banque)
    local inv = chest.list()
    for slot, _ in pairs(inv) do
        chest.pushItems(CFG.chest_side, slot)  -- pousse vers lui-meme pour vider
    end
    -- Note: en vrai vous pouvez rediriger vers un coffre "coffre-fort banque"
    -- via chest.pushItems("nomDuCoffreCible", slot)
end

-- ╔══════════════════════════════════════════╗
-- ║         ECRANS                           ║
-- ╚══════════════════════════════════════════╝
local function screen_main()
    draw_header()

    center(5,  "Bienvenue a la CGBank !", CFG.COL.white)
    center(7,  "Deposez vos items dans le coffre,", CFG.COL.dim)
    center(8,  "puis choisissez une option.", CFG.COL.dim)

    hline(10, CFG.COL.frame)

    term.setTextColor(CFG.COL.accent)
    term.setCursorPos(3, 12); term.write("[1]")
    term.setTextColor(CFG.COL.white)
    term.write("  Deposer des items (or/diamants)")

    term.setTextColor(CFG.COL.accent)
    term.setCursorPos(3, 14); term.write("[2]")
    term.setTextColor(CFG.COL.white)
    term.write("  Consulter mon solde")

    term.setTextColor(CFG.COL.accent)
    term.setCursorPos(3, 16); term.write("[3]")
    term.setTextColor(CFG.COL.white)
    term.write("  Transferer des CGC")

    term.setTextColor(CFG.COL.accent)
    term.setCursorPos(3, 18); term.write("[4]")
    term.setTextColor(CFG.COL.white)
    term.write("  Voir les taux de change")

    hline(H-1, CFG.COL.frame)
    center(H, "Choix: ", CFG.COL.dim)
    term.setCursorPos(9, H)
    term.setTextColor(CFG.COL.input)
    local key = read()
    return key
end

local function screen_deposit()
    draw_header()
    center(5, "-- DEPOT D'ITEMS --", CFG.COL.accent)

    term.setCursorPos(2, 7)
    term.setTextColor(CFG.COL.dim)
    term.write("Nom de compte: ")
    term.setTextColor(CFG.COL.input)
    local name = read()
    if name == "" then return end

    -- Scan coffre
    term.setCursorPos(2, 9)
    term.setTextColor(CFG.COL.dim)
    term.write("Analyse du coffre...")
    local items = scan_chest()

    if #items == 0 then
        term.setCursorPos(2, 11)
        term.setTextColor(CFG.COL.err)
        term.write("Coffre vide ! Aucun item detecte.")
        os.sleep(2.5)
        return
    end

    -- Afficher preview
    term.setCursorPos(2, 10)
    term.setTextColor(CFG.COL.white)
    term.write("Items detectes:")
    local row = 11
    for _, item in ipairs(items) do
        if row < H - 4 then
            term.setCursorPos(4, row)
            term.setTextColor(CFG.COL.accent)
            term.write(item.count .. "x ")
            term.setTextColor(CFG.COL.dim)
            local short = item.name:match(":(.+)$") or item.name
            term.write(short)
            row = row + 1
        end
    end

    hline(H-3, CFG.COL.frame)
    center(H-2, "Confirmer le depot ? (o/n)", CFG.COL.white)
    term.setCursorPos(math.floor(W/2)+2, H-2)
    local confirm = read()

    if confirm:lower() ~= "o" then
        center(H-1, "Depot annule.", CFG.COL.err)
        os.sleep(1.5)
        return
    end

    -- Envoi au serveur
    center(H-1, "Envoi au serveur...", CFG.COL.dim)
    local res = send({ cmd = "deposit_items", account = name, items = items })

    cls()
    draw_header()
    if res.ok then
        center(6,  "DEPOT CONFIRME !", CFG.COL.ok)
        center(8,  "+" .. string.format("%.4f", res.added) .. " CGC credites", CFG.COL.accent)
        center(9,  "Nouveau solde: " .. string.format("%.4f", res.new_balance) .. " CGC", CFG.COL.white)

        if res.detail then
            local row2 = 11
            for _, d in ipairs(res.detail) do
                if row2 < H - 3 then
                    term.setCursorPos(4, row2)
                    term.setTextColor(CFG.COL.dim)
                    local short = d.item:match(":(.+)$") or d.item
                    term.write(d.qty .. "x " .. short .. " = ")
                    term.setTextColor(CFG.COL.accent)
                    term.write(string.format("%.4f", d.cgc) .. " CGC")
                    row2 = row2 + 1
                end
            end
        end
    else
        center(7, "ERREUR: " .. (res.msg or "?"), CFG.COL.err)
    end

    hline(H-1, CFG.COL.frame)
    center(H, "Appuyez sur entree...", CFG.COL.dim)
    read()
end

local function screen_balance()
    draw_header()
    center(5, "-- CONSULTER SOLDE --", CFG.COL.accent)

    term.setCursorPos(2, 7)
    term.setTextColor(CFG.COL.dim)
    term.write("Nom de compte: ")
    term.setTextColor(CFG.COL.input)
    local name = read()
    if name == "" then return end

    center(9, "Chargement...", CFG.COL.dim)
    local res = send({ cmd = "balance", account = name })

    cls(); draw_header()
    if res.ok then
        center(6, "Compte: " .. name, CFG.COL.white)
        center(8, string.format("%.4f CGC", res.balance), CFG.COL.accent)
        center(10, "Derniere transaction:", CFG.COL.dim)
        center(11, tostring(res.last_tx), CFG.COL.dim)
    else
        center(7, "Erreur: " .. (res.msg or "?"), CFG.COL.err)
    end

    hline(H-1, CFG.COL.frame)
    center(H, "Appuyez sur entree...", CFG.COL.dim)
    read()
end

local function screen_transfer()
    draw_header()
    center(5, "-- TRANSFERT CGC --", CFG.COL.accent)

    term.setCursorPos(2, 7)
    term.setTextColor(CFG.COL.dim)
    term.write("Votre compte:    ")
    term.setTextColor(CFG.COL.input)
    local from = read()

    term.setCursorPos(2, 9)
    term.setTextColor(CFG.COL.dim)
    term.write("Compte destinataire: ")
    term.setTextColor(CFG.COL.input)
    local to = read()

    term.setCursorPos(2, 11)
    term.setTextColor(CFG.COL.dim)
    term.write("Montant CGC: ")
    term.setTextColor(CFG.COL.input)
    local amt_str = read()
    local amount = tonumber(amt_str)

    if not amount or amount <= 0 or from == "" or to == "" then
        center(13, "Donnees invalides.", CFG.COL.err)
        os.sleep(2); return
    end

    center(13, "Envoi...", CFG.COL.dim)
    local res = send({ cmd = "transfer", from = from, to = to, amount = amount, reason = "transfert joueur" })

    cls(); draw_header()
    if res.ok then
        center(6, "Transfert effectue !", CFG.COL.ok)
        center(8, string.format("%.4f CGC envoyes a %s", amount, to), CFG.COL.accent)
        center(9, string.format("Nouveau solde: %.4f CGC", res.new_balance), CFG.COL.white)
    else
        center(7, "ECHEC: " .. (res.msg or "?"), CFG.COL.err)
    end

    hline(H-1, CFG.COL.frame)
    center(H, "Appuyez sur entree...", CFG.COL.dim)
    read()
end

local function screen_rates()
    draw_header()
    center(5, "-- TAUX DE CHANGE --", CFG.COL.accent)
    local res = send({ cmd = "rates" })

    if res.ok and res.rates then
        local row = 7
        for item, rate in pairs(res.rates) do
            local per = math.floor(1 / rate + 0.5)
            term.setCursorPos(4, row)
            term.setTextColor(CFG.COL.white)
            term.write(item .. ": ")
            term.setTextColor(CFG.COL.accent)
            term.write(per .. "x = 1 CGC   (" .. string.format("%.4f", rate) .. " CGC/item)")
            row = row + 2
        end
    else
        center(7, "Impossible de charger les taux.", CFG.COL.err)
    end

    hline(H-1, CFG.COL.frame)
    center(H, "Appuyez sur entree...", CFG.COL.dim)
    read()
end

-- ╔══════════════════════════════════════════╗
-- ║         BOUCLE PRINCIPALE                ║
-- ╚══════════════════════════════════════════╝
while true do
    local choice = screen_main()
    if     choice == "1" then screen_deposit()
    elseif choice == "2" then screen_balance()
    elseif choice == "3" then screen_transfer()
    elseif choice == "4" then screen_rates()
    end
end