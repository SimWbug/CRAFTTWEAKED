-- ============================================================
--  CGBank API  v1.0  |  cgbank_api.lua
--  Bibliotheque a copier sur tous les computers clients
--  (casino, jeux, distributeurs, etc.)
--
--  UTILISATION:
--    os.loadAPI("cgbank_api")
--    -- ou avec require si vous utilisez un bundler --
--
--  EXEMPLE:
--    local bank = cgbank_api.new("top", 1000, 1010)
--    local ok, msg, balance = bank.withdraw("Steve", 5.0, "Mise casino")
--    if ok then print("Mise acceptee! Solde: " .. balance) end
-- ============================================================

-- Cree une instance du client banque
-- @param modem_side  : string  - cote du modem ("top","left",etc.)
-- @param server_ch   : number  - canal du serveur (1000 par defaut)
-- @param my_ch       : number  - canal de reponse UNIQUE pour ce computer
-- @param timeout_sec : number  - timeout en secondes (defaut 5)
function new(modem_side, server_ch, my_ch, timeout_sec)
    local self = {}
    local modem = peripheral.wrap(modem_side or "top")
    if not modem then error("cgbank_api: modem introuvable sur " .. (modem_side or "top")) end

    local SRV_CH = server_ch or 1000
    local MY_CH  = my_ch or 1099
    local TIMEOUT = timeout_sec or 5

    modem.open(MY_CH)

    -- Envoi une commande et attend la reponse
    -- Retourne la table reponse du serveur, ou { ok=false, msg="Timeout" }
    local function send(cmd_table)
        cmd_table.reply_ch = MY_CH
        modem.transmit(SRV_CH, MY_CH, cmd_table)
        local timer = os.startTimer(TIMEOUT)
        while true do
            local e, s, ch, rch, msg = os.pullEvent()
            if e == "modem_message" and ch == MY_CH and type(msg) == "table" then
                os.cancelTimer(timer)
                return msg
            elseif e == "timer" and s == timer then
                return { ok = false, msg = "Timeout: serveur CGBank non accessible" }
            end
        end
    end

    -- ── OPERATIONS DE BASE ────────────────────────────────

    --- Retourne le solde d'un compte
    -- @return ok(bool), balance(number), last_tx(string)
    function self.balance(account)
        local res = send({ cmd = "balance", account = account })
        return res.ok, res.balance or 0, res.last_tx or ""
    end

    --- Retire des CGC d'un compte (mise de jeu, achat, etc.)
    -- @return ok(bool), message(string), new_balance(number)
    function self.withdraw(account, amount, reason)
        local res = send({
            cmd     = "withdraw",
            account = account,
            amount  = amount,
            reason  = reason or "retrait client"
        })
        return res.ok, res.msg or "", res.new_balance or 0
    end

    --- Credite des CGC sur un compte (gain, remboursement, etc.)
    -- @return ok(bool), message(string), new_balance(number)
    function self.deposit(account, amount, reason)
        local res = send({
            cmd     = "deposit_cgc",
            account = account,
            amount  = amount,
            reason  = reason or "credit client"
        })
        return res.ok, res.msg or "", res.new_balance or 0
    end

    --- Transfert d'un compte a un autre
    -- @return ok(bool), message(string), new_balance_from(number)
    function self.transfer(from, to, amount, reason)
        local res = send({
            cmd    = "transfer",
            from   = from,
            to     = to,
            amount = amount,
            reason = reason or "transfert"
        })
        return res.ok, res.msg or "", res.new_balance or 0
    end

    --- Verifie si un compte a suffisamment de fonds
    -- @return bool
    function self.has_funds(account, amount)
        local ok, balance = self.balance(account)
        return ok and balance >= amount
    end

    --- Ping le serveur pour verifier la connexion
    -- @return ok(bool), message(string)
    function self.ping()
        local res = send({ cmd = "ping" })
        return res.ok, res.msg or ""
    end

    --- Retourne les taux de change actuels
    -- @return ok(bool), rates_table
    function self.get_rates()
        local res = send({ cmd = "rates" })
        return res.ok, res.rates or {}
    end

    -- ── HELPERS POUR JEUX ─────────────────────────────────

    --- Pattern complet "mise de jeu"
    --  Verifie le solde, retire la mise, retourne le succes.
    --  Usage: ok, msg, new_bal = bank.place_bet("Steve", 10.0)
    function self.place_bet(account, amount)
        if not self.has_funds(account, amount) then
            return false, "Solde insuffisant pour miser " .. amount .. " CGC", 0
        end
        return self.withdraw(account, amount, "Mise de jeu")
    end

    --- Paye un gain au joueur
    --  Usage: bank.pay_win("Steve", 25.0, "Jackpot slot machine")
    function self.pay_win(account, amount, reason)
        return self.deposit(account, amount, reason or "Gain de jeu")
    end

    --- Joue un pari avec calcul automatique:
    --  @param account   - nom du joueur
    --  @param bet       - montant mise
    --  @param won       - bool (victoire ou defaite)
    --  @param multiplier - multiplicateur du gain (ex: 2 = double)
    --  Si gagne: credite bet * multiplier
    --  Si perd : la mise est deja retiree, rien d'autre
    --  @return ok, msg, net_change, new_balance
    function self.resolve_bet(account, bet, won, multiplier)
        multiplier = multiplier or 2
        -- Retirer la mise d'abord
        local ok, msg, bal = self.place_bet(account, bet)
        if not ok then return false, msg, 0, bal end

        if won then
            local gain = bet * multiplier
            local ok2, msg2, new_bal = self.pay_win(account, gain, "Gain x" .. multiplier)
            local net = gain - bet
            return true, "Gagne +" .. string.format("%.4f", net) .. " CGC", net, new_bal
        else
            return true, "Perdu -" .. string.format("%.4f", bet) .. " CGC", -bet, bal
        end
    end

    return self
end

-- ── EXEMPLE D'UTILISATION (decommenter pour tester) ────────
--[[
local bank = new("top", 1000, 1098)

-- Test ping
local ok, msg = bank.ping()
print("Ping: " .. tostring(ok) .. " - " .. msg)

-- Test solde
local ok2, bal = bank.balance("Steve")
print("Solde Steve: " .. bal .. " CGC")

-- Test mise de jeu
local ok3, msg3, new_bal = bank.resolve_bet("Steve", 5.0, true, 3)
print(msg3 .. " | Solde: " .. new_bal)
--]]
