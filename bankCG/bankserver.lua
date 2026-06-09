-- ============================================================
--  CGBank Server v1.0  |  bank_server.lua
--  Installez sur le computer "serveur" connecte au modem
--  reseau et aux coffres de depot.
-- ============================================================

-- ╔══════════════════════════════════════════╗
-- ║         CONFIGURATION                    ║
-- ╚══════════════════════════════════════════╝
local CFG = {
    modem_side     = "top",      -- cote du modem reseau
    channel        = 1000,       -- canal principal banque
    db_file        = "cgbank_db.json",
    log_file       = "cgbank_log.txt",

    -- Taux de conversion vers CGCoin
    rates = {
        gold_ingot    = 0.1,     -- 10 or    = 1 CGC
        diamond       = 0.2,     -- 5 diamants = 1 CGC
        gold_block     = 0.9,    -- 1 bloc or  = 0.9 CGC (9 lingots)
        diamond_block  = 1.8,    -- 1 bloc diamant = 1.8 CGC
    },

    -- Couleurs palette
    COL = {
        bg      = colors.black,
        accent  = colors.yellow,
        ok      = colors.lime,
        err     = colors.red,
        dim     = colors.gray,
        white   = colors.white,
    }
}

-- ╔══════════════════════════════════════════╗
-- ║         BASE DE DONNEES                  ║
-- ╚══════════════════════════════════════════╝
local DB = {
    accounts  = {},   -- [name] = { balance, created, last_tx }
    pending   = {},   -- transactions en attente (non utilise ici mais extensible)
    next_txid = 1,
}

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

-- ╔══════════════════════════════════════════╗
-- ║         JOURNAL                          ║
-- ╚══════════════════════════════════════════╝
local function log(msg)
    local f = fs.open(CFG.log_file, "a")
    f.writeLine("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] " .. msg)
    f.close()
end

-- ╔══════════════════════════════════════════╗
-- ║         LOGIQUE METIER                   ║
-- ╚══════════════════════════════════════════╝

-- Cree ou retourne un compte
local function get_or_create(name)
    if not DB.accounts[name] then
        DB.accounts[name] = {
            balance  = 0,
            created  = os.date("%Y-%m-%d %H:%M:%S"),
            last_tx  = "Aucune",
            owner    = name,
        }
        db_save()
        log("NOUVEAU COMPTE: " .. name)
    end
    return DB.accounts[name]
end

-- Arrondi a 4 decimales pour eviter les flottants sales
local function round(n)
    return math.floor(n * 10000 + 0.5) / 10000
end

-- Calcule la valeur CGC d'un item
local function item_to_cgc(item_name, qty)
    -- Normalise le nom (enleve le namespace si present)
    local short = item_name:match(":(.+)$") or item_name
    local rate  = CFG.rates[short]
    if rate then
        return round(qty * rate), true
    end
    return 0, false
end

-- Depot physique : table d'items [{name, count}]
local function process_deposit(account_name, items)
    local acc   = get_or_create(account_name)
    local total = 0
    local detail = {}

    for _, item in ipairs(items) do
        local cgc, ok = item_to_cgc(item.name, item.count)
        if ok then
            total = round(total + cgc)
            table.insert(detail, {
                item = item.name,
                qty  = item.count,
                cgc  = cgc,
            })
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

-- Retrait logique (pour jeux, envois, etc.)
local function withdraw(account_name, amount, reason)
    local acc = get_or_create(account_name)
    amount = round(amount)
    if acc.balance < amount then
        return false, "Solde insuffisant (" .. acc.balance .. " CGC)"
    end
    acc.balance = round(acc.balance - amount)
    acc.last_tx = os.date("%Y-%m-%d %H:%M:%S") .. " RETRAIT -" .. amount .. " (" .. (reason or "?") .. ")"
    DB.next_txid = DB.next_txid + 1
    db_save()
    log(string.format("RETRAIT %s -%.4f CGC raison=%s (total=%.4f)", account_name, amount, reason or "?", acc.balance))
    return true, "OK"
end

-- Depot logique (gains jeux, reception, etc.)
local function deposit_cgc(account_name, amount, reason)
    local acc = get_or_create(account_name)
    amount = round(amount)
    acc.balance = round(acc.balance + amount)
    acc.last_tx = os.date("%Y-%m-%d %H:%M:%S") .. " CREDIT +" .. amount .. " (" .. (reason or "?") .. ")"
    DB.next_txid = DB.next_txid + 1
    db_save()
    log(string.format("CREDIT %s +%.4f CGC raison=%s (total=%.4f)", account_name, amount, reason or "?", acc.balance))
    return true, "OK"
end

-- Transfert entre comptes
local function transfer(from, to, amount, reason)
    local ok, msg = withdraw(from, amount, "transfert vers " .. to)
    if not ok then return false, msg end
    deposit_cgc(to, amount, "transfert depuis " .. from)
    log(string.format("TRANSFERT %s -> %s %.4f CGC", from, to, amount))
    return true, "OK"
end

-- Modification admin directe
local function admin_set_balance(name, new_balance, admin)
    local acc = get_or_create(name)
    local old = acc.balance
    acc.balance = round(new_balance)
    acc.last_tx = os.date("%Y-%m-%d %H:%M:%S") .. " ADMIN SET par " .. (admin or "?")
    db_save()
    log(string.format("ADMIN SET %s: %.4f -> %.4f par %s", name, old, new_balance, admin or "?"))
    return true
end

local function admin_delete_account(name, admin)
    if not DB.accounts[name] then return false, "Compte inexistant" end
    DB.accounts[name] = nil
    db_save()
    log("ADMIN DELETE " .. name .. " par " .. (admin or "?"))
    return true, "OK"
end

-- ╔══════════════════════════════════════════╗
-- ║         SERVEUR RESEAU                   ║
-- ╚══════════════════════════════════════════╝
local modem = peripheral.wrap(CFG.modem_side)
if not modem then
    error("Aucun modem detecte sur le cote: " .. CFG.modem_side)
end
modem.open(CFG.channel)

-- Affichage serveur minimal
term.setBackgroundColor(CFG.COL.bg)
term.setTextColor(CFG.COL.accent)
term.clear(); term.setCursorPos(1,1)
print("╔══════════════════════════════╗")
print("║   CGBank Server  v1.0        ║")
print("╚══════════════════════════════╝")
term.setTextColor(CFG.COL.dim)
print("Canal: " .. CFG.channel .. "  |  DB: " .. CFG.db_file)
term.setTextColor(CFG.COL.ok)

db_load()
local acct_count = 0
for _ in pairs(DB.accounts) do acct_count = acct_count + 1 end
print("Comptes charges: " .. acct_count)
term.setTextColor(CFG.COL.white)
print("Serveur en ligne. Ctrl+T pour quitter.")
print("")

-- Dispatch des commandes reseau
local handlers = {}

-- Consulter solde
handlers["balance"] = function(req)
    local acc = get_or_create(req.account)
    return { ok = true, balance = acc.balance, last_tx = acc.last_tx }
end

-- Depot physique (items)
handlers["deposit_items"] = function(req)
    local total, detail = process_deposit(req.account, req.items or {})
    local acc = DB.accounts[req.account]
    return { ok = true, added = total, detail = detail, new_balance = acc.balance }
end

-- Depot CGC direct (depuis jeux)
handlers["deposit_cgc"] = function(req)
    local ok, msg = deposit_cgc(req.account, req.amount, req.reason)
    local bal = DB.accounts[req.account] and DB.accounts[req.account].balance or 0
    return { ok = ok, msg = msg, new_balance = bal }
end

-- Retrait CGC (depuis jeux)
handlers["withdraw"] = function(req)
    local ok, msg = withdraw(req.account, req.amount, req.reason)
    local bal = DB.accounts[req.account] and DB.accounts[req.account].balance or 0
    return { ok = ok, msg = msg, new_balance = bal }
end

-- Transfert entre joueurs
handlers["transfer"] = function(req)
    local ok, msg = transfer(req.from, req.to, req.amount, req.reason)
    local bal = DB.accounts[req.from] and DB.accounts[req.from].balance or 0
    return { ok = ok, msg = msg, new_balance = bal }
end

-- Admin: liste tous les comptes
handlers["admin_list"] = function(req)
    local list = {}
    for name, acc in pairs(DB.accounts) do
        table.insert(list, {
            name    = name,
            balance = acc.balance,
            created = acc.created,
            last_tx = acc.last_tx,
        })
    end
    table.sort(list, function(a,b) return a.balance > b.balance end)
    return { ok = true, accounts = list }
end

-- Admin: modifier solde
handlers["admin_set"] = function(req)
    local ok = admin_set_balance(req.account, req.balance, req.admin)
    return { ok = ok }
end

-- Admin: supprimer compte
handlers["admin_delete"] = function(req)
    local ok, msg = admin_delete_account(req.account, req.admin)
    return { ok = ok, msg = msg }
end

-- Admin: creer compte manuellement
handlers["admin_create"] = function(req)
    local acc = get_or_create(req.account)
    if req.balance then
        acc.balance = round(req.balance)
        db_save()
    end
    return { ok = true, balance = acc.balance }
end

-- Admin: lire le journal
handlers["admin_log"] = function(req)
    local lines = {}
    if fs.exists(CFG.log_file) then
        local f = fs.open(CFG.log_file, "r")
        local content = f.readAll(); f.close()
        for line in content:gmatch("[^\n]+") do
            table.insert(lines, 1, line)  -- plus recent en premier
        end
    end
    local max = req.max or 50
    local result = {}
    for i = 1, math.min(max, #lines) do
        table.insert(result, lines[i])
    end
    return { ok = true, lines = result }
end

-- Ping
handlers["ping"] = function(_)
    return { ok = true, msg = "CGBank online", version = "1.0" }
end

-- Taux de conversion
handlers["rates"] = function(_)
    return { ok = true, rates = CFG.rates }
end

-- Boucle principale
print("En attente de requetes...")
while true do
    local event, side, channel, reply_ch, msg = os.pullEvent("modem_message")
    if channel == CFG.channel and type(msg) == "table" and msg.cmd then
        local handler = handlers[msg.cmd]
        local response
        if handler then
            local ok, result = pcall(handler, msg)
            if ok then
                response = result
            else
                response = { ok = false, msg = "Erreur interne: " .. tostring(result) }
            end
        else
            response = { ok = false, msg = "Commande inconnue: " .. tostring(msg.cmd) }
        end

        -- Log console
        term.setTextColor(CFG.COL.dim)
        io.write("[" .. msg.cmd .. "] ")
        term.setTextColor(response.ok and CFG.COL.ok or CFG.COL.err)
        print(msg.account or msg.from or "?")
        term.setTextColor(CFG.COL.white)

        modem.transmit(reply_ch, CFG.channel, response)
    end
end