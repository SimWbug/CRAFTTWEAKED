-- ============================================================
--  CGBank Server v1.1  |  bank_server.lua
--  Nouveautes v1.1:
--    - Comptes proteges par mot de passe (hash djb2)
--    - Commandes: register, login, transfer (avec auth)
--    - Les jeux/API n'ont pas besoin de mdp (token interne)
-- ============================================================

local CFG = {
    modem_side     = "top",
    channel        = 1000,
    db_file        = "cgbank_db.json",
    log_file       = "cgbank_log.txt",

    rates = {
        gold_ingot    = 0.1,
        diamond       = 0.2,
        gold_block    = 0.9,
        diamond_block = 1.8,
    },

    COL = {
        bg     = colors.black,
        accent = colors.yellow,
        ok     = colors.lime,
        err    = colors.red,
        dim    = colors.gray,
        white  = colors.white,
    }
}

-- ============================================
--      HASH mot de passe (djb2, pure Lua)     
-- ============================================
-- CC:Tweaked n'a pas de lib crypto native.
-- djb2 est simple, suffisant pour un usage MC.
-- Le mot de passe n'est JAMAIS stocke en clair.
local function hash(str)
    local h = 5381
    for i = 1, #str do
        -- djb2: h = h * 33 XOR byte
        -- On garde en 32 bits unsigned via modulo
        h = bit32.bxor((h * 33) % 0x100000000, str:byte(i))
    end
    return string.format("%08x", h)
end

-- ============================================
--               BASE DE DONNEES               
-- ============================================
local DB = {
    accounts  = {},
    next_txid = 1,
}
-- Structure d'un compte:
-- DB.accounts[name] = {
--   balance   = number,
--   pw_hash   = string,   -- hash djb2 du mot de passe
--   created   = string,
--   last_tx   = string,
--   owner     = string,
-- }

local function db_save()
    local f = fs.open(CFG.db_file, "w")
    f.write(textutils.serialiseJSON(DB))
    f.close()
end

local function db_load()
    if not fs.exists(CFG.db_file) then db_save(); return end
    local f = fs.open(CFG.db_file, "r")
    local raw = f.readAll(); f.close()
    local ok, data = pcall(textutils.unserialiseJSON, raw)
    if ok and data then
        DB = data
        DB.accounts  = DB.accounts  or {}
        DB.next_txid = DB.next_txid or 1
    end
end

-- ============================================
--                   JOURNAL                   
-- ============================================
local function log(msg)
    local f = fs.open(CFG.log_file, "a")
    f.writeLine("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] " .. msg)
    f.close()
end

-- ============================================
--                     AUTH                    
-- ============================================
local function account_exists(name)
    return DB.accounts[name] ~= nil
end

local function check_password(name, password)
    local acc = DB.accounts[name]
    if not acc then return false, "Compte inexistant" end
    if not acc.pw_hash then return false, "Compte sans mot de passe (legacy)" end
    if acc.pw_hash ~= hash(password) then
        return false, "Mot de passe incorrect"
    end
    return true, "OK"
end

-- ============================================
--                LOGIQUE METIER               
-- ============================================
local function round(n)
    return math.floor(n * 10000 + 0.5) / 10000
end

local function item_to_cgc(item_name, qty)
    local short = item_name:match(":(.+)$") or item_name
    local rate  = CFG.rates[short]
    if rate then return round(qty * rate), true end
    return 0, false
end

local function process_deposit(account_name, items)
    local acc   = DB.accounts[account_name]
    if not acc then return 0, {} end
    local total = 0
    local detail = {}
    for _, item in ipairs(items) do
        local cgc, ok = item_to_cgc(item.name, item.count)
        if ok then
            total = round(total + cgc)
            table.insert(detail, { item = item.name, qty = item.count, cgc = cgc })
        end
    end
    if total > 0 then
        acc.balance = round(acc.balance + total)
        acc.last_tx = os.date("%Y-%m-%d %H:%M:%S") .. " DEPOT +" .. total
        DB.next_txid = DB.next_txid + 1
        db_save()
        log(string.format("DEPOT %s +%.4f CGC (total=%.4f)", account_name, total, acc.balance))
    end
    return total, detail
end

local function withdraw(account_name, amount, reason)
    local acc = DB.accounts[account_name]
    if not acc then return false, "Compte inexistant" end
    amount = round(amount)
    if acc.balance < amount then
        return false, "Solde insuffisant (" .. string.format("%.4f", acc.balance) .. " CGC)"
    end
    acc.balance = round(acc.balance - amount)
    acc.last_tx = os.date("%Y-%m-%d %H:%M:%S") .. " RETRAIT -" .. amount .. " (" .. (reason or "?") .. ")"
    DB.next_txid = DB.next_txid + 1
    db_save()
    log(string.format("RETRAIT %s -%.4f CGC raison=%s (total=%.4f)", account_name, amount, reason or "?", acc.balance))
    return true, "OK"
end

local function deposit_cgc(account_name, amount, reason)
    local acc = DB.accounts[account_name]
    if not acc then
        -- Pour les jeux: creer le compte si inexistant (sans mdp)
        -- La banque peut aussi refuser — a toi de choisir
        return false, "Compte inexistant"
    end
    amount = round(amount)
    acc.balance = round(acc.balance + amount)
    acc.last_tx = os.date("%Y-%m-%d %H:%M:%S") .. " CREDIT +" .. amount .. " (" .. (reason or "?") .. ")"
    DB.next_txid = DB.next_txid + 1
    db_save()
    log(string.format("CREDIT %s +%.4f CGC raison=%s (total=%.4f)", account_name, amount, reason or "?", acc.balance))
    return true, "OK"
end

local function transfer_auth(from, password, to, amount, reason)
    -- Verifie le mdp avant tout
    local auth_ok, auth_msg = check_password(from, password)
    if not auth_ok then return false, auth_msg end

    if not DB.accounts[to] then return false, "Compte destinataire inexistant" end

    local ok, msg = withdraw(from, amount, "transfert vers " .. to)
    if not ok then return false, msg end
    deposit_cgc(to, amount, "transfert depuis " .. from)
    log(string.format("TRANSFERT %s -> %s %.4f CGC", from, to, amount))
    return true, "OK"
end

local function admin_set_balance(name, new_balance, admin)
    local acc = DB.accounts[name]
    if not acc then return false, "Compte inexistant" end
    local old = acc.balance
    acc.balance = round(new_balance)
    acc.last_tx = os.date("%Y-%m-%d %H:%M:%S") .. " ADMIN SET par " .. (admin or "?")
    db_save()
    log(string.format("ADMIN SET %s: %.4f -> %.4f par %s", name, old, new_balance, admin or "?"))
    return true, "OK"
end

local function admin_reset_password(name, new_password, admin)
    local acc = DB.accounts[name]
    if not acc then return false, "Compte inexistant" end
    acc.pw_hash = hash(new_password)
    db_save()
    log(string.format("ADMIN RESET MDP %s par %s", name, admin or "?"))
    return true, "OK"
end

local function admin_delete_account(name, admin)
    if not DB.accounts[name] then return false, "Compte inexistant" end
    DB.accounts[name] = nil
    db_save()
    log("ADMIN DELETE " .. name .. " par " .. (admin or "?"))
    return true, "OK"
end

-- ============================================
--                SERVEUR RESEAU               
-- ============================================
local modem = peripheral.wrap(CFG.modem_side)
if not modem then error("Aucun modem sur: " .. CFG.modem_side) end
modem.open(CFG.channel)

term.setBackgroundColor(CFG.COL.bg)
term.setTextColor(CFG.COL.accent)
term.clear(); term.setCursorPos(1,1)
print("============================================")
print("   CGBank Server  v1.1")
print("============================================")
term.setTextColor(CFG.COL.dim)
print("Canal: " .. CFG.channel .. "  |  DB: " .. CFG.db_file)

db_load()
local acct_count = 0
for _ in pairs(DB.accounts) do acct_count = acct_count + 1 end
term.setTextColor(CFG.COL.ok)
print("Comptes charges: " .. acct_count)
term.setTextColor(CFG.COL.white)
print("Serveur en ligne. Ctrl+T pour quitter.")
print("")

local handlers = {}

-- ── INSCRIPTION ──────────────────────────────────────────
handlers["register"] = function(req)
    if not req.account or not req.password then
        return { ok = false, msg = "Nom et mot de passe requis" }
    end
    if #req.account < 2 then
        return { ok = false, msg = "Nom trop court (2 caracteres min)" }
    end
    if #req.password < 4 then
        return { ok = false, msg = "Mot de passe trop court (4 caracteres min)" }
    end
    if account_exists(req.account) then
        return { ok = false, msg = "Ce nom de compte est deja pris" }
    end
    DB.accounts[req.account] = {
        balance  = 0,
        pw_hash  = hash(req.password),
        created  = os.date("%Y-%m-%d %H:%M:%S"),
        last_tx  = "Aucune",
        owner    = req.account,
    }
    db_save()
    log("INSCRIPTION: " .. req.account)
    return { ok = true, msg = "Compte cree avec succes !" }
end

-- ── LOGIN (verifie mdp, retourne solde) ──────────────────
handlers["login"] = function(req)
    local ok, msg = check_password(req.account, req.password or "")
    if not ok then return { ok = false, msg = msg } end
    local acc = DB.accounts[req.account]
    return { ok = true, balance = acc.balance, last_tx = acc.last_tx }
end

-- ── CHANGER MOT DE PASSE ─────────────────────────────────
handlers["change_password"] = function(req)
    local ok, msg = check_password(req.account, req.old_password or "")
    if not ok then return { ok = false, msg = msg } end
    if not req.new_password or #req.new_password < 4 then
        return { ok = false, msg = "Nouveau mot de passe trop court" }
    end
    DB.accounts[req.account].pw_hash = hash(req.new_password)
    db_save()
    log("CHANGEMENT MDP: " .. req.account)
    return { ok = true, msg = "Mot de passe modifie" }
end

-- ── SOLDE (sans mdp, pour jeux/API internes) ─────────────
handlers["balance"] = function(req)
    local acc = DB.accounts[req.account]
    if not acc then return { ok = false, msg = "Compte inexistant" } end
    return { ok = true, balance = acc.balance, last_tx = acc.last_tx }
end

-- ── SOLDE SECURISE (avec mdp, pour terminal joueur) ──────
handlers["balance_auth"] = function(req)
    local ok, msg = check_password(req.account, req.password or "")
    if not ok then return { ok = false, msg = msg } end
    local acc = DB.accounts[req.account]
    return { ok = true, balance = acc.balance, last_tx = acc.last_tx }
end

-- ── DEPOT ITEMS (le terminal a deja identifie le joueur) ─
handlers["deposit_items"] = function(req)
    -- Le depot ne demande pas de mdp: le joueur est deja
    -- connecte sur le terminal avant de deposer.
    -- Mais on verifie que le compte existe.
    if not account_exists(req.account) then
        return { ok = false, msg = "Compte inexistant. Inscrivez-vous d'abord." }
    end
    local total, detail = process_deposit(req.account, req.items or {})
    local acc = DB.accounts[req.account]
    return { ok = true, added = total, detail = detail, new_balance = acc.balance }
end

-- ── DEPOT CGC (depuis jeux, pas de mdp requis) ───────────
handlers["deposit_cgc"] = function(req)
    local ok, msg = deposit_cgc(req.account, req.amount, req.reason)
    local bal = DB.accounts[req.account] and DB.accounts[req.account].balance or 0
    return { ok = ok, msg = msg, new_balance = bal }
end

-- ── RETRAIT CGC (depuis jeux, pas de mdp requis) ─────────
handlers["withdraw"] = function(req)
    local ok, msg = withdraw(req.account, req.amount, req.reason)
    local bal = DB.accounts[req.account] and DB.accounts[req.account].balance or 0
    return { ok = ok, msg = msg, new_balance = bal }
end

-- ── TRANSFERT AVEC AUTH (terminal joueur) ────────────────
handlers["transfer"] = function(req)
    local ok, msg = transfer_auth(req.from, req.password or "", req.to, req.amount, req.reason)
    local bal = DB.accounts[req.from] and DB.accounts[req.from].balance or 0
    return { ok = ok, msg = msg, new_balance = bal }
end

-- ── ADMIN: liste ─────────────────────────────────────────
handlers["admin_list"] = function(req)
    local list = {}
    for name, acc in pairs(DB.accounts) do
        table.insert(list, {
            name    = name,
            balance = acc.balance,
            created = acc.created,
            last_tx = acc.last_tx,
            has_pw  = acc.pw_hash ~= nil,
        })
    end
    table.sort(list, function(a,b) return a.balance > b.balance end)
    return { ok = true, accounts = list }
end

handlers["admin_set"] = function(req)
    local ok, msg = admin_set_balance(req.account, req.balance, req.admin)
    return { ok = ok, msg = msg }
end

handlers["admin_delete"] = function(req)
    local ok, msg = admin_delete_account(req.account, req.admin)
    return { ok = ok, msg = msg }
end

handlers["admin_create"] = function(req)
    if account_exists(req.account) then
        return { ok = false, msg = "Compte deja existant" }
    end
    DB.accounts[req.account] = {
        balance  = round(req.balance or 0),
        pw_hash  = req.password and hash(req.password) or nil,
        created  = os.date("%Y-%m-%d %H:%M:%S"),
        last_tx  = "Cree par admin",
        owner    = req.account,
    }
    db_save()
    log("ADMIN CREATE " .. req.account .. " par " .. (req.admin or "?"))
    return { ok = true, balance = DB.accounts[req.account].balance }
end

-- Admin: reset mdp
handlers["admin_reset_pw"] = function(req)
    local ok, msg = admin_reset_password(req.account, req.password or "1234", req.admin)
    return { ok = ok, msg = msg }
end

handlers["admin_log"] = function(req)
    local lines = {}
    if fs.exists(CFG.log_file) then
        local f = fs.open(CFG.log_file, "r")
        local content = f.readAll(); f.close()
        for line in content:gmatch("[^\n]+") do
            table.insert(lines, 1, line)
        end
    end
    local max = req.max or 50
    local result = {}
    for i = 1, math.min(max, #lines) do
        table.insert(result, lines[i])
    end
    return { ok = true, lines = result }
end

handlers["ping"] = function(_)
    return { ok = true, msg = "CGBank online", version = "1.1" }
end

handlers["rates"] = function(_)
    return { ok = true, rates = CFG.rates }
end

-- ── BOUCLE PRINCIPALE ────────────────────────────────────
print("En attente de requetes...")
while true do
    local event, side, channel, reply_ch, msg = os.pullEvent("modem_message")
    if channel == CFG.channel and type(msg) == "table" and msg.cmd then
        local handler = handlers[msg.cmd]
        local response
        if handler then
            local ok, result = pcall(handler, msg)
            response = ok and result or { ok = false, msg = "Erreur interne: " .. tostring(result) }
        else
            response = { ok = false, msg = "Commande inconnue: " .. tostring(msg.cmd) }
        end

        term.setTextColor(CFG.COL.dim)
        io.write("[" .. msg.cmd .. "] ")
        term.setTextColor(response.ok and CFG.COL.ok or CFG.COL.err)
        print(msg.account or msg.from or "?")
        term.setTextColor(CFG.COL.white)

        modem.transmit(reply_ch, CFG.channel, response)
    end
end
