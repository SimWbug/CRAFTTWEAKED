-- ============================================================
--  CGBank Terminal Depot v1.1  |  bank_deposit.lua
--  Nouveautes v1.1:
--    - Coffre sur "back"
--    - Inscription avec mot de passe
--    - Login requis pour deposer / voir solde
--    - Transfert protege par mot de passe
-- ============================================================

local CFG = {
    modem_side  = "top",
    server_ch   = 1000,
    my_ch       = 1001,
    chest_side  = "back",    -- << COFFRE DE DEPOT (joueur pose ses items ici)
    vault_side  = "left",    -- << COFFRE-FORT BANQUE (items transferes apres depot)
                             --    Mettez nil si vous ne voulez pas de coffre-fort
    timeout     = 5,

    COL = {
        bg      = colors.black,
        frame   = colors.cyan,
        accent  = colors.yellow,
        ok      = colors.lime,
        err     = colors.red,
        dim     = colors.gray,
        white   = colors.white,
        input   = colors.lightBlue,
        title   = colors.cyan,
    }
}

local modem = peripheral.wrap(CFG.modem_side)
local chest = peripheral.wrap(CFG.chest_side)
if not modem then error("Modem introuvable: " .. CFG.modem_side) end
if not chest  then error("Coffre introuvable cote '" .. CFG.chest_side .. "' -- verifiez le placement.") end
modem.open(CFG.my_ch)

local W, H = term.getSize()

-- Session courante (joueur connecte)
local SESSION = { logged_in = false, name = "", }

-- ╔══════════════════════════════════════════╗
-- ║         UTILITAIRES UI                   ║
-- ╚══════════════════════════════════════════╝
local function cls()
    term.setBackgroundColor(CFG.COL.bg)
    term.clear(); term.setCursorPos(1,1)
end

local function at(x, y, text, col)
    term.setCursorPos(x, y)
    if col then term.setTextColor(col) end
    term.write(text)
end

local function center(y, text, col)
    at(math.floor((W - #text) / 2) + 1, y, text, col)
end

local function hline(y, col)
    term.setTextColor(col or CFG.COL.frame)
    term.setCursorPos(1, y)
    term.write(string.rep("-", W))
end

local function header(title)
    cls()
    hline(1, CFG.COL.frame)
    center(2, "CGBank  |  " .. title, CFG.COL.accent)
    -- Indicateur de session
    if SESSION.logged_in then
        at(W - #SESSION.name - 2, 2, SESSION.name, CFG.COL.ok)
    end
    hline(3, CFG.COL.frame)
end

local function footer(msg)
    hline(H-1, CFG.COL.frame)
    center(H, msg or "[ Entree pour continuer ]", CFG.COL.dim)
end

local function wait()
    footer()
    read()
end

local function ask(y, label, mask)
    at(2, y, label, CFG.COL.dim)
    term.setCursorPos(2 + #label, y)
    term.setTextColor(CFG.COL.input)
    return read(mask)
end

local function msg_line(y, text, col)
    at(2, y, string.rep(" ", W-2), col)
    at(2, y, text, col)
end

-- ╔══════════════════════════════════════════╗
-- ║         RESEAU                           ║
-- ╚══════════════════════════════════════════╝
local function send(cmd_table)
    cmd_table.reply_ch = CFG.my_ch
    modem.transmit(CFG.server_ch, CFG.my_ch, cmd_table)
    local timer = os.startTimer(CFG.timeout)
    while true do
        local e, s, ch, rch, m = os.pullEvent()
        if e == "modem_message" and ch == CFG.my_ch and type(m) == "table" then
            os.cancelTimer(timer)
            return m
        elseif e == "timer" and s == timer then
            return { ok = false, msg = "Timeout - serveur non repond" }
        end
    end
end

-- ╔══════════════════════════════════════════╗
-- ║         COFFRE                           ║
-- ╚══════════════════════════════════════════╝
local function scan_chest()
    local items = {}
    local inv = chest.list()
    for slot, item in pairs(inv) do
        local found = false
        for _, e in ipairs(items) do
            if e.name == item.name then
                e.count = e.count + item.count
                found = true; break
            end
        end
        if not found then
            table.insert(items, { name = item.name, count = item.count })
        end
    end
    return items
end

-- Vide le coffre de depot vers le coffre-fort banque
-- Si pas de coffre-fort configure, les items restent dans le coffre
-- mais un flag empeche le double-comptage
local function empty_chest()
    local inv = chest.list()
    if CFG.vault_side then
        for slot, _ in pairs(inv) do
            -- pushItems(target, fromSlot) : target = nom peripherique
            -- En CC:T le nom d'un inventaire colle est son cote ("left", etc.)
            chest.pushItems(CFG.vault_side, slot)
        end
    end
    -- Si vault_side = nil : les items restent, mais le depot
    -- a deja ete comptabilise donc le prochain scan ne les
    -- recomptabilisera pas (le serveur ne credite que si
    -- deposit_items est appele, ce qui necessite une confirmation)
end

-- ╔══════════════════════════════════════════╗
-- ║  ECRAN: INSCRIPTION                      ║
-- ╚══════════════════════════════════════════╝
local function screen_register()
    header("Creer un Compte")

    at(2, 5, "Choisissez un nom de compte et un mot de passe.", CFG.COL.dim)
    at(2, 6, "Le mot de passe protege vos transferts.", CFG.COL.dim)

    hline(8, CFG.COL.dim)

    local name = ask(10, "Nom de compte  : ")
    local pw1  = ask(12, "Mot de passe   : ", "*")
    local pw2  = ask(14, "Confirmer mdp  : ", "*")

    if name == "" or pw1 == "" then
        msg_line(16, "Champs vides. Annule.", CFG.COL.err)
        os.sleep(2); return
    end
    if pw1 ~= pw2 then
        msg_line(16, "Les mots de passe ne correspondent pas !", CFG.COL.err)
        os.sleep(2); return
    end
    if #pw1 < 4 then
        msg_line(16, "Mot de passe trop court (4 caracteres min).", CFG.COL.err)
        os.sleep(2); return
    end

    msg_line(16, "Creation en cours...", CFG.COL.dim)
    local res = send({ cmd = "register", account = name, password = pw1 })

    cls(); header("Creer un Compte")
    if res.ok then
        center(6, "Compte cree avec succes !", CFG.COL.ok)
        center(8, "Bienvenue, " .. name .. " !", CFG.COL.accent)
        center(10, "Vous pouvez maintenant vous connecter.", CFG.COL.dim)
    else
        center(6, "ECHEC: " .. (res.msg or "?"), CFG.COL.err)
    end
    wait()
end

-- ╔══════════════════════════════════════════╗
-- ║  ECRAN: CONNEXION                        ║
-- ╚══════════════════════════════════════════╝
-- Retourne true si login reussi
local function screen_login()
    header("Connexion")

    at(2, 5, "Entrez vos identifiants pour acceder", CFG.COL.dim)
    at(2, 6, "a votre compte CGBank.", CFG.COL.dim)
    hline(8, CFG.COL.dim)

    local name = ask(10, "Nom de compte  : ")
    local pw   = ask(12, "Mot de passe   : ", "*")

    if name == "" or pw == "" then
        msg_line(14, "Annule.", CFG.COL.dim)
        os.sleep(1); return false
    end

    msg_line(14, "Verification...", CFG.COL.dim)
    local res = send({ cmd = "login", account = name, password = pw })

    if res.ok then
        SESSION.logged_in = true
        SESSION.name      = name
        cls(); header("Connexion")
        center(6, "Connexion reussie !", CFG.COL.ok)
        center(8, "Bonjour, " .. name .. " !", CFG.COL.accent)
        center(9, string.format("Solde: %.4f CGC", res.balance), CFG.COL.white)
        os.sleep(1.8)
        return true
    else
        cls(); header("Connexion")
        center(6, "ECHEC: " .. (res.msg or "?"), CFG.COL.err)
        os.sleep(2)
        return false
    end
end

-- ╔══════════════════════════════════════════╗
-- ║  ECRAN: DEPOT D'ITEMS                    ║
-- ╚══════════════════════════════════════════╝
local function screen_deposit()
    header("Depot d'Items")

    at(2, 5, "Posez vos items dans le coffre (derriere", CFG.COL.dim)
    at(2, 6, "ce terminal), puis confirmez.", CFG.COL.dim)

    at(2, 8, "Analyse du coffre...", CFG.COL.dim)
    local items = scan_chest()

    if #items == 0 then
        msg_line(9, "Coffre vide ! Ajoutez des items et reessayez.", CFG.COL.err)
        wait(); return
    end

    -- Preview
    at(2, 9, "Items detectes:", CFG.COL.white)
    local row = 10
    local total_preview = 0
    for _, item in ipairs(items) do
        if row < H - 5 then
            local short = item.name:match(":(.+)$") or item.name
            at(4,   row, item.count .. "x", CFG.COL.accent)
            at(10,  row, short, CFG.COL.dim)
            row = row + 1
        end
    end

    hline(H-4, CFG.COL.dim)
    at(2, H-3, "Deposer sur le compte : ", CFG.COL.dim)
    at(26, H-3, SESSION.name, CFG.COL.ok)

    footer("Confirmer ? (o/n) : ")
    term.setCursorPos(21, H)
    term.setTextColor(CFG.COL.input)
    local c = read()

    if c:lower() ~= "o" then
        msg_line(H-2, "Depot annule.", CFG.COL.dim)
        os.sleep(1.5); return
    end

    local res = send({
        cmd     = "deposit_items",
        account = SESSION.name,
        items   = items,
    })

    -- Vider le coffre immediatement apres reponse du serveur
    -- (reussi ou pas: si le serveur a refuse, les items restent
    --  mais on les vide quand meme pour eviter double-comptage)
    if res.ok and res.added and res.added > 0 then
        empty_chest()
    end

    cls(); header("Depot d'Items")
    if res.ok then
        if res.added == 0 then
            center(6, "Aucun item reconnu dans le coffre.", CFG.COL.err)
            center(7, "(or, diamants, blocs d'or/diamant uniquement)", CFG.COL.dim)
        else
            center(6, "Depot accepte !", CFG.COL.ok)
            center(8, string.format("+%.4f CGC credites", res.added), CFG.COL.accent)
            center(9, string.format("Nouveau solde: %.4f CGC", res.new_balance), CFG.COL.white)
            center(10, "Items transferes au coffre-fort.", CFG.COL.dim)

            local r = 12
            if res.detail then
                for _, d in ipairs(res.detail) do
                    if r < H - 3 then
                        local short = d.item:match(":(.+)$") or d.item
                        at(4, r, d.qty .. "x " .. short .. " = " .. string.format("%.4f", d.cgc) .. " CGC", CFG.COL.dim)
                        r = r + 1
                    end
                end
            end
        end
    else
        center(6, "ERREUR: " .. (res.msg or "?"), CFG.COL.err)
    end
    wait()
end

-- ╔══════════════════════════════════════════╗
-- ║  ECRAN: SOLDE                            ║
-- ╚══════════════════════════════════════════╝
local function screen_balance()
    header("Mon Solde")

    at(2, 5, "Verification du solde...", CFG.COL.dim)
    local res = send({ cmd = "balance_auth",
                       account  = SESSION.name,
                       password = "" })
    -- On utilise balance simple car deja connecte
    local res2 = send({ cmd = "balance", account = SESSION.name })

    cls(); header("Mon Solde")
    if res2.ok then
        center(6, SESSION.name, CFG.COL.accent)
        center(8, string.format("%.4f CGC", res2.balance), CFG.COL.ok)
        at(2, 11, "Derniere transaction:", CFG.COL.dim)
        at(2, 12, tostring(res2.last_tx):sub(1, W-2), CFG.COL.dim)
    else
        center(7, "Erreur: " .. (res2.msg or "?"), CFG.COL.err)
    end
    wait()
end

-- ╔══════════════════════════════════════════╗
-- ║  ECRAN: TRANSFERT (protege par mdp)      ║
-- ╚══════════════════════════════════════════╝
local function screen_transfer()
    header("Transfert CGC")

    at(2, 5, "Le transfert requiert votre mot de passe.", CFG.COL.dim)
    hline(7, CFG.COL.dim)

    local to      = ask(9,  "Compte destinataire : ")
    local amt_str = ask(11, "Montant (CGC)       : ")
    local pw      = ask(13, "Votre mot de passe  : ", "*")

    local amount = tonumber(amt_str)
    if not amount or amount <= 0 then
        msg_line(15, "Montant invalide.", CFG.COL.err)
        os.sleep(2); return
    end
    if to == "" or pw == "" then
        msg_line(15, "Champs manquants.", CFG.COL.err)
        os.sleep(2); return
    end
    if to == SESSION.name then
        msg_line(15, "Vous ne pouvez pas vous envoyer a vous-meme.", CFG.COL.err)
        os.sleep(2); return
    end

    msg_line(15, "Envoi en cours...", CFG.COL.dim)
    local res = send({
        cmd      = "transfer",
        from     = SESSION.name,
        password = pw,
        to       = to,
        amount   = amount,
        reason   = "transfert joueur",
    })

    cls(); header("Transfert CGC")
    if res.ok then
        center(6, "Transfert effectue !", CFG.COL.ok)
        center(8, string.format("%.4f CGC envoyes a %s", amount, to), CFG.COL.accent)
        center(9, string.format("Nouveau solde: %.4f CGC", res.new_balance), CFG.COL.white)
    else
        center(6, "REFUSE: " .. (res.msg or "?"), CFG.COL.err)
    end
    wait()
end

-- ╔══════════════════════════════════════════╗
-- ║  ECRAN: CHANGER MOT DE PASSE             ║
-- ╚══════════════════════════════════════════╝
local function screen_change_pw()
    header("Changer Mot de Passe")

    local old  = ask(5,  "Mot de passe actuel  : ", "*")
    local new1 = ask(7,  "Nouveau mot de passe : ", "*")
    local new2 = ask(9,  "Confirmer nouveau    : ", "*")

    if new1 ~= new2 then
        msg_line(11, "Les mots de passe ne correspondent pas.", CFG.COL.err)
        os.sleep(2); return
    end
    if #new1 < 4 then
        msg_line(11, "Trop court (4 min).", CFG.COL.err)
        os.sleep(2); return
    end

    local res = send({
        cmd          = "change_password",
        account      = SESSION.name,
        old_password = old,
        new_password = new1,
    })

    cls(); header("Changer Mot de Passe")
    if res.ok then
        center(6, "Mot de passe modifie !", CFG.COL.ok)
    else
        center(6, "ECHEC: " .. (res.msg or "?"), CFG.COL.err)
    end
    wait()
end

-- ╔══════════════════════════════════════════╗
-- ║  ECRAN: TAUX                             ║
-- ╚══════════════════════════════════════════╝
local function screen_rates()
    header("Taux de Change")
    local res = send({ cmd = "rates" })
    if res.ok and res.rates then
        local row = 5
        at(2, row, "Item", CFG.COL.frame)
        at(22, row, "CGC par item", CFG.COL.frame)
        at(38, row, "Qte pour 1 CGC", CFG.COL.frame)
        hline(row+1, CFG.COL.dim)
        row = row + 2
        for item, rate in pairs(res.rates) do
            local per = math.floor(1 / rate + 0.5)
            at(2,  row, item, CFG.COL.white)
            at(22, row, string.format("%.4f", rate), CFG.COL.accent)
            at(38, row, per .. "x", CFG.COL.ok)
            row = row + 1
        end
    else
        center(6, "Impossible de charger les taux.", CFG.COL.err)
    end
    wait()
end

-- ╔══════════════════════════════════════════╗
-- ║  MENU: NON CONNECTE                      ║
-- ╚══════════════════════════════════════════╝
local function menu_guest()
    header("Accueil")

    center(5,  "Bienvenue a la CGBank !", CFG.COL.white)
    center(6,  "Deposez de l'or et des diamants,", CFG.COL.dim)
    center(7,  "recevez des CGCoins.", CFG.COL.dim)

    hline(9, CFG.COL.dim)

    at(4, 11, "[1]", CFG.COL.accent)
    at(8, 11, "Se connecter", CFG.COL.white)

    at(4, 12, "[2]", CFG.COL.accent)
    at(8, 12, "Creer un compte", CFG.COL.white)

    at(4, 13, "[3]", CFG.COL.accent)
    at(8, 13, "Voir les taux de change", CFG.COL.white)

    footer("Choix : ")
    term.setCursorPos(10, H)
    term.setTextColor(CFG.COL.input)
    local c = read()

    if     c == "1" then screen_login()
    elseif c == "2" then screen_register()
    elseif c == "3" then screen_rates()
    end
end

-- ╔══════════════════════════════════════════╗
-- ║  MENU: CONNECTE                          ║
-- ╚══════════════════════════════════════════╝
local function menu_logged_in()
    header("Menu Joueur")

    -- Affiche solde rapide
    local res = send({ cmd = "balance", account = SESSION.name })
    if res.ok then
        center(5, string.format("Solde : %.4f CGC", res.balance), CFG.COL.ok)
    end

    hline(7, CFG.COL.dim)

    at(4, 9,  "[1]", CFG.COL.accent); at(8, 9,  "Deposer des items", CFG.COL.white)
    at(4, 10, "[2]", CFG.COL.accent); at(8, 10, "Consulter mon solde", CFG.COL.white)
    at(4, 11, "[3]", CFG.COL.accent); at(8, 11, "Transferer des CGC", CFG.COL.white)
    at(4, 12, "[4]", CFG.COL.accent); at(8, 12, "Changer mot de passe", CFG.COL.white)
    at(4, 13, "[5]", CFG.COL.accent); at(8, 13, "Taux de change", CFG.COL.white)
    at(4, 14, "[6]", CFG.COL.dim);    at(8, 14, "Deconnexion", CFG.COL.dim)

    footer("Choix : ")
    term.setCursorPos(10, H)
    term.setTextColor(CFG.COL.input)
    local c = read()

    if     c == "1" then screen_deposit()
    elseif c == "2" then screen_balance()
    elseif c == "3" then screen_transfer()
    elseif c == "4" then screen_change_pw()
    elseif c == "5" then screen_rates()
    elseif c == "6" then
        SESSION.logged_in = false
        SESSION.name = ""
    end
end

-- ╔══════════════════════════════════════════╗
-- ║         BOUCLE PRINCIPALE                ║
-- ╚══════════════════════════════════════════╝
while true do
    if SESSION.logged_in then
        menu_logged_in()
    else
        menu_guest()
    end
end
