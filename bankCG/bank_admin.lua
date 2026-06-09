-- ============================================================
--  CGBank Admin Panel v1.0  |  bank_admin.lua
--  Interface complete pour le banquier.
--  Installez sur un Advanced Computer prive (banquier).
-- ============================================================

local CFG = {
    modem_side = "top",
    server_ch  = 1000,
    my_ch      = 1002,     -- canal de reponse de l'admin
    timeout    = 6,
    admin_name = "Banquier",   -- nom affiche dans les logs

    COL = {
        bg      = colors.black,
        frame   = colors.orange,
        accent  = colors.yellow,
        ok      = colors.lime,
        err     = colors.red,
        dim     = colors.gray,
        white   = colors.white,
        input   = colors.lightBlue,
        header  = colors.orange,
        sel     = colors.cyan,
    }
}

local modem = peripheral.wrap(CFG.modem_side)
if not modem then error("Modem introuvable: " .. CFG.modem_side) end
modem.open(CFG.my_ch)

local W, H = term.getSize()

-- ╔══════════════════════════════════════════╗
-- ║         UTILITAIRES UI                   ║
-- ╚══════════════════════════════════════════╝
local function cls()
    term.setBackgroundColor(CFG.COL.bg)
    term.clear(); term.setCursorPos(1,1)
end

local function center(y, text, col)
    term.setCursorPos(math.floor((W - #text) / 2) + 1, y)
    if col then term.setTextColor(col) end
    term.write(text)
end

local function hline(y, col, char)
    term.setTextColor(col or CFG.COL.frame)
    term.setCursorPos(1, y)
    term.write(string.rep(char or "-", W))
end

local function print_at(x, y, text, col)
    term.setCursorPos(x, y)
    if col then term.setTextColor(col) end
    term.write(text)
end

local function draw_header(title)
    cls()
    hline(1, CFG.COL.frame, "=")
    center(2, "  CGBank ADMIN  |  " .. (title or "Menu Principal") .. "  ", CFG.COL.accent)
    hline(3, CFG.COL.frame, "=")
end

local function prompt(y, label)
    print_at(2, y, label, CFG.COL.dim)
    term.setCursorPos(2 + #label, y)
    term.setTextColor(CFG.COL.input)
    return read()
end

local function confirm(y, msg)
    print_at(2, y, msg .. " (o/n): ", CFG.COL.err)
    term.setCursorPos(2 + #msg + 8, y)
    term.setTextColor(CFG.COL.input)
    return read():lower() == "o"
end

local function wait_key(y)
    hline(y or H, CFG.COL.frame)
    print_at(2, y and y+1 or H, "[ Entree pour continuer ]", CFG.COL.dim)
    read()
end

-- ╔══════════════════════════════════════════╗
-- ║         RESEAU                           ║
-- ╚══════════════════════════════════════════╝
local function send(cmd_table)
    cmd_table.reply_ch = CFG.my_ch
    cmd_table.admin    = CFG.admin_name
    modem.transmit(CFG.server_ch, CFG.my_ch, cmd_table)
    local timer = os.startTimer(CFG.timeout)
    while true do
        local e, s, ch, rch, msg = os.pullEvent()
        if e == "modem_message" and ch == CFG.my_ch and type(msg) == "table" then
            return msg
        elseif e == "timer" and s == timer then
            return { ok = false, msg = "Timeout serveur" }
        end
    end
end

-- ╔══════════════════════════════════════════╗
-- ║         MODULE: LISTE DES COMPTES        ║
-- ╚══════════════════════════════════════════╝
local function screen_list()
    draw_header("Liste des Comptes")
    print_at(2, 5, "Chargement...", CFG.COL.dim)
    local res = send({ cmd = "admin_list" })

    if not res.ok then
        print_at(2, 5, "ERREUR: " .. (res.msg or "?"), CFG.COL.err)
        wait_key(); return
    end

    local accounts = res.accounts
    local page = 1
    local per_page = H - 8
    local total_pages = math.max(1, math.ceil(#accounts / per_page))

    while true do
        cls()
        hline(1, CFG.COL.frame, "=")
        center(2, "Liste des Comptes (" .. #accounts .. " total)", CFG.COL.accent)
        hline(3, CFG.COL.frame, "=")

        -- En-tetes colonnes
        print_at(2,  4, "NOM", CFG.COL.header)
        print_at(20, 4, "SOLDE (CGC)", CFG.COL.header)
        print_at(35, 4, "DERNIERE TX", CFG.COL.header)
        hline(5, CFG.COL.dim)

        local start_idx = (page - 1) * per_page + 1
        local row = 6
        for i = start_idx, math.min(start_idx + per_page - 1, #accounts) do
            local a = accounts[i]
            local balance_str = string.format("%.4f", a.balance)
            local col = (a.balance > 0) and CFG.COL.ok or CFG.COL.dim

            print_at(2,  row, (a.name or "?"):sub(1, 17), CFG.COL.white)
            print_at(20, row, balance_str, col)
            -- Tronque la derniere tx pour tenir dans l'ecran
            local tx_short = (a.last_tx or "?"):sub(1, W - 36)
            print_at(35, row, tx_short, CFG.COL.dim)
            row = row + 1
        end

        hline(H-2, CFG.COL.frame)
        print_at(2, H-1, "Page " .. page .. "/" .. total_pages .. "  [<][>] Nav  [q] Retour", CFG.COL.dim)
        term.setCursorPos(W, H-1)

        local _, key = os.pullEvent("key")
        if key == keys.right and page < total_pages then page = page + 1
        elseif key == keys.left and page > 1 then page = page - 1
        elseif key == keys.q then return
        end
    end
end

-- ╔══════════════════════════════════════════╗
-- ║         MODULE: RECHERCHER UN COMPTE     ║
-- ╚══════════════════════════════════════════╝
local function screen_search()
    draw_header("Rechercher / Modifier Compte")
    local name = prompt(5, "Nom du compte: ")
    if name == "" then return end

    print_at(2, 7, "Recherche...", CFG.COL.dim)
    local res = send({ cmd = "balance", account = name })

    if not res.ok then
        print_at(2, 7, "ERREUR: " .. (res.msg or "?"), CFG.COL.err)
        wait_key(); return
    end

    while true do
        cls()
        hline(1, CFG.COL.frame, "=")
        center(2, "Compte: " .. name, CFG.COL.accent)
        hline(3, CFG.COL.frame, "=")

        print_at(2, 5, "Solde actuel:", CFG.COL.dim)
        print_at(16, 5, string.format("%.4f CGC", res.balance), CFG.COL.ok)
        print_at(2, 6, "Derniere TX:", CFG.COL.dim)
        print_at(15, 6, tostring(res.last_tx):sub(1, W-16), CFG.COL.dim)

        hline(8, CFG.COL.dim)

        print_at(2, 10, "[1] Crediter des CGC", CFG.COL.white)
        print_at(2, 11, "[2] Debiter des CGC", CFG.COL.white)
        print_at(2, 12, "[3] Definir solde exact", CFG.COL.white)
        print_at(2, 13, "[4] Supprimer ce compte", CFG.COL.err)
        print_at(2, 14, "[q] Retour", CFG.COL.dim)

        hline(H-1, CFG.COL.frame)
        print_at(2, H, "Choix: ", CFG.COL.dim)
        term.setCursorPos(9, H)
        term.setTextColor(CFG.COL.input)
        local choice = read()

        if choice == "1" then
            local amt_str = prompt(16, "Montant a crediter: ")
            local amt = tonumber(amt_str)
            if amt and amt > 0 then
                local r = send({ cmd = "deposit_cgc", account = name, amount = amt, reason = "Admin credit" })
                if r.ok then
                    res.balance = r.new_balance
                    print_at(2, 17, "Credit OK! Nouveau solde: " .. string.format("%.4f", r.new_balance), CFG.COL.ok)
                    os.sleep(1.5)
                else
                    print_at(2, 17, "Erreur: " .. (r.msg or "?"), CFG.COL.err)
                    os.sleep(1.5)
                end
            end

        elseif choice == "2" then
            local amt_str = prompt(16, "Montant a debiter: ")
            local amt = tonumber(amt_str)
            if amt and amt > 0 then
                local r = send({ cmd = "withdraw", account = name, amount = amt, reason = "Admin debit" })
                if r.ok then
                    res.balance = r.new_balance
                    print_at(2, 17, "Debit OK! Nouveau solde: " .. string.format("%.4f", r.new_balance), CFG.COL.ok)
                    os.sleep(1.5)
                else
                    print_at(2, 17, "Erreur: " .. (r.msg or "?"), CFG.COL.err)
                    os.sleep(1.5)
                end
            end

        elseif choice == "3" then
            local bal_str = prompt(16, "Nouveau solde exact: ")
            local bal = tonumber(bal_str)
            if bal and bal >= 0 then
                if confirm(17, "Definir " .. name .. " a " .. bal .. " CGC ?") then
                    local r = send({ cmd = "admin_set", account = name, balance = bal })
                    if r.ok then
                        res.balance = bal
                        print_at(2, 18, "Solde modifie !", CFG.COL.ok)
                        os.sleep(1.5)
                    end
                end
            end

        elseif choice == "4" then
            if confirm(16, "SUPPRIMER " .. name .. " DEFINITIVEMENT ?") then
                local r = send({ cmd = "admin_delete", account = name })
                if r.ok then
                    print_at(2, 17, "Compte supprime.", CFG.COL.ok)
                    os.sleep(1.5)
                    return
                else
                    print_at(2, 17, "Erreur: " .. (r.msg or "?"), CFG.COL.err)
                    os.sleep(1.5)
                end
            end

        elseif choice:lower() == "q" then
            return
        end
    end
end

-- ╔══════════════════════════════════════════╗
-- ║         MODULE: CREER UN COMPTE          ║
-- ╚══════════════════════════════════════════╝
local function screen_create()
    draw_header("Creer un Compte")
    local name = prompt(5, "Nom du nouveau compte: ")
    if name == "" then return end

    local bal_str = prompt(7, "Solde initial (0 si vide): ")
    local bal = tonumber(bal_str) or 0

    local r = send({ cmd = "admin_create", account = name, balance = bal })
    if r.ok then
        print_at(2, 9, "Compte cree ! Solde: " .. string.format("%.4f", r.balance) .. " CGC", CFG.COL.ok)
    else
        print_at(2, 9, "Erreur: " .. (r.msg or "?"), CFG.COL.err)
    end
    wait_key()
end

-- ╔══════════════════════════════════════════╗
-- ║         MODULE: JOURNAL                  ║
-- ╚══════════════════════════════════════════╝
local function screen_log()
    draw_header("Journal des Transactions")
    print_at(2, 5, "Chargement...", CFG.COL.dim)
    local res = send({ cmd = "admin_log", max = 100 })

    if not res.ok or not res.lines then
        print_at(2, 5, "Erreur chargement journal.", CFG.COL.err)
        wait_key(); return
    end

    local lines = res.lines
    local page = 1
    local per_page = H - 7
    local total_pages = math.max(1, math.ceil(#lines / per_page))

    while true do
        cls()
        hline(1, CFG.COL.frame, "=")
        center(2, "Journal (" .. #lines .. " entrees)", CFG.COL.accent)
        hline(3, CFG.COL.frame, "=")

        local start_idx = (page - 1) * per_page + 1
        local row = 4
        for i = start_idx, math.min(start_idx + per_page - 1, #lines) do
            local line = lines[i] or ""
            -- Colore selon le type
            local col = CFG.COL.dim
            if line:find("DEPOT") or line:find("CREDIT") then col = CFG.COL.ok
            elseif line:find("RETRAIT") or line:find("DELETE") then col = CFG.COL.err
            elseif line:find("ADMIN") then col = CFG.COL.accent
            elseif line:find("TRANSFERT") then col = CFG.COL.sel
            end
            print_at(2, row, line:sub(1, W-2), col)
            row = row + 1
        end

        hline(H-2, CFG.COL.frame)
        print_at(2, H-1, "Page " .. page .. "/" .. total_pages .. "  [<][>] Nav  [q] Retour", CFG.COL.dim)
        term.setCursorPos(W, H-1)

        local _, key = os.pullEvent("key")
        if key == keys.right and page < total_pages then page = page + 1
        elseif key == keys.left and page > 1 then page = page - 1
        elseif key == keys.q then return
        end
    end
end

-- ╔══════════════════════════════════════════╗
-- ║         MODULE: PING SERVEUR             ║
-- ╚══════════════════════════════════════════╝
local function screen_ping()
    draw_header("Statut Serveur")
    print_at(2, 5, "Ping en cours...", CFG.COL.dim)
    local start = os.clock()
    local res = send({ cmd = "ping" })
    local elapsed = math.floor((os.clock() - start) * 1000)

    if res.ok then
        print_at(2, 5, "Serveur en ligne !", CFG.COL.ok)
        print_at(2, 6, "Version: " .. (res.version or "?"), CFG.COL.accent)
        print_at(2, 7, "Latence: " .. elapsed .. "ms", CFG.COL.dim)
    else
        print_at(2, 5, "HORS LIGNE: " .. (res.msg or "?"), CFG.COL.err)
    end
    wait_key()
end

-- ╔══════════════════════════════════════════╗
-- ║         MENU PRINCIPAL                   ║
-- ╚══════════════════════════════════════════╝
local function main_menu()
    while true do
        draw_header("Menu Principal")

        print_at(2, 5, "GESTION DES COMPTES", CFG.COL.frame)
        print_at(4, 7,  "[1] Liste de tous les comptes", CFG.COL.white)
        print_at(4, 8,  "[2] Rechercher / Modifier un compte", CFG.COL.white)
        print_at(4, 9,  "[3] Creer un compte manuellement", CFG.COL.white)

        print_at(2, 11, "SUPERVISION", CFG.COL.frame)
        print_at(4, 13, "[4] Journal des transactions", CFG.COL.white)
        print_at(4, 14, "[5] Ping / Statut du serveur", CFG.COL.white)

        print_at(2, 16, "SYSTEME", CFG.COL.frame)
        print_at(4, 18, "[q] Quitter", CFG.COL.dim)

        hline(H-1, CFG.COL.frame)
        print_at(2, H, "Choix Admin: ", CFG.COL.dim)
        term.setCursorPos(15, H)
        term.setTextColor(CFG.COL.input)
        local c = read()

        if     c == "1" then screen_list()
        elseif c == "2" then screen_search()
        elseif c == "3" then screen_create()
        elseif c == "4" then screen_log()
        elseif c == "5" then screen_ping()
        elseif c:lower() == "q" then
            cls()
            center(H//2, "CGBank Admin ferme.", CFG.COL.dim)
            os.sleep(1)
            return
        end
    end
end

main_menu()
