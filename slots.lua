-- ============================================================
--  CGCasino - Slot Machine v2.0  |  slots.lua
--  Interface redesignee: symboles 5 lignes, neons, blit complet
-- ============================================================

local CFG = {
    modem_side  = "top",
    server_ch   = 1000,
    my_ch       = 1011,
    bet_min     = 0.5,
    bet_max     = 50,
}

-- ── PALETTE NEON CASINO ──────────────────────────────────────
local function setup_palette()
    term.setPaletteColor(colors.black,     0x020202)
    term.setPaletteColor(colors.gray,      0x111111)
    term.setPaletteColor(colors.lightGray, 0x2A2A2A)
    term.setPaletteColor(colors.white,     0xEEEEEE)
    term.setPaletteColor(colors.yellow,    0xFFCC00)
    term.setPaletteColor(colors.orange,    0xFF6600)
    term.setPaletteColor(colors.red,       0xDD1100)
    term.setPaletteColor(colors.pink,      0xFF2277)
    term.setPaletteColor(colors.magenta,   0xCC00AA)
    term.setPaletteColor(colors.purple,    0x7700CC)
    term.setPaletteColor(colors.blue,      0x0033CC)
    term.setPaletteColor(colors.lightBlue, 0x33AAFF)
    term.setPaletteColor(colors.cyan,      0x00BBCC)
    term.setPaletteColor(colors.green,     0x006622)
    term.setPaletteColor(colors.lime,      0x22DD55)
    term.setPaletteColor(colors.brown,     0x5C3010)
end

local function restore_palette()
    term.setPaletteColor(colors.black,     0x000000)
    term.setPaletteColor(colors.gray,      0x555555)
    term.setPaletteColor(colors.lightGray, 0xAAAAAA)
    term.setPaletteColor(colors.white,     0xFFFFFF)
    term.setPaletteColor(colors.yellow,    0xFFFF00)
    term.setPaletteColor(colors.orange,    0xFF8800)
    term.setPaletteColor(colors.red,       0xFF0000)
    term.setPaletteColor(colors.pink,      0xFFB6C1)
    term.setPaletteColor(colors.magenta,   0xFF00FF)
    term.setPaletteColor(colors.purple,    0x8B00FF)
    term.setPaletteColor(colors.blue,      0x0000FF)
    term.setPaletteColor(colors.lightBlue, 0xADD8E6)
    term.setPaletteColor(colors.cyan,      0x00FFFF)
    term.setPaletteColor(colors.green,     0x00FF00)
    term.setPaletteColor(colors.lime,      0x7FFF00)
    term.setPaletteColor(colors.brown,     0x8B4513)
end

-- ── BLIT COLOR CODES ─────────────────────────────────────────
-- 0=black 1=red 2=green 3=yellow 4=blue 5=purple 6=cyan
-- 7=white 8=gray 9=lightGray a=lightBlue b=pink c=magenta
-- d=orange e=lime f=brown

-- ── SYMBOLES 5 LIGNES ────────────────────────────────────────
-- Chaque symbole = 5 lignes de 9 chars
-- Format: { id, lignes[5], fg_blit, bg_blit, poids, mult }
-- On utilise term.blit pour chaque ligne

local SW = 11   -- largeur d'un symbole en chars (doit etre impair)
local SH = 5    -- hauteur d'un symbole en lignes

-- Fonction pour creer une ligne de symbole avec blit
-- art = string de SW chars, fg = string de SW chars blit, bg = idem
local function S(art, fg, bg)
    return { art=art, fg=fg, bg=bg }
end

-- Couleurs communes
local function rep(c, n) return string.rep(c, n or SW) end

local SYMBOLS = {
    -- ═══ SEVEN (jackpot) ═══
    {
        id="7", poids=2, mult_pair=0, mult_triple=50,
        color_name="SEVEN", color_fg=colors.yellow, color_bg=colors.red,
        lines={
            S(" .=====. ", rep("3",SW), rep("1",SW)),
            S(" |  /77| ", "9"..rep("3",7).."9", rep("1",SW)),
            S(" | /7/ | ", "9"..rep("3",7).."9", rep("1",SW)),
            S(" |777  | ", "9"..rep("3",7).."9", rep("1",SW)),
            S(" '=====` ", rep("3",SW), rep("1",SW)),
        }
    },
    -- ═══ DIAMANT ═══
    {
        id="dia", poids=4, mult_pair=0, mult_triple=20,
        color_name="DIAMANT", color_fg=colors.lightBlue, color_bg=colors.blue,
        lines={
            S("  .===.  ", rep("a",SW), rep("4",SW)),
            S(" /|   |\ ", "a77777778", rep("4",SW)),
            S("|  \\ /  |", "a"..rep("7",9).."a", rep("4",SW)),
            S(" \\  *  / ", "a777a7778", rep("4",SW)),
            S("  `===`  ", rep("a",SW), rep("4",SW)),
        }
    },
    -- ═══ CLOCHE ═══
    {
        id="bell", poids=6, mult_pair=0, mult_triple=10,
        color_name="CLOCHE", color_fg=colors.yellow, color_bg=colors.orange,
        lines={
            S("  .--.   ", rep("3",SW), rep("d",SW)),
            S(" /    \\  ", rep("3",SW), rep("d",SW)),
            S("|  ()  | ", rep("3",SW), rep("d",SW)),
            S(" \\____/  ", rep("3",SW), rep("d",SW)),
            S("  |--|   ", rep("3",SW), rep("d",SW)),
        }
    },
    -- ═══ BAR ═══
    {
        id="bar", poids=8, mult_pair=0, mult_triple=5,
        color_name="BAR", color_fg=colors.white, color_bg=colors.gray,
        lines={
            S(".========.", rep("7",SW), rep("8",SW)),
            S("|        |", rep("7",SW), rep("8",SW)),
            S("| [BAR]  |", "7777777778", rep("8",SW)),
            S("|        |", rep("7",SW), rep("8",SW)),
            S("`========`", rep("7",SW), rep("8",SW)),
        }
    },
    -- ═══ CERISE ═══
    {
        id="ceri", poids=12, mult_pair=2, mult_triple=3,
        color_name="CERISE", color_fg=colors.pink, color_bg=colors.green,
        lines={
            S("  o   o  ", "8b78b7888", rep("2",SW)),
            S(" /\\ /\\  ", "27272788", rep("2",SW)),
            S("/ (*)(*)\\ ", "2"..rep("b",8).."2", rep("2",SW)),
            S("\\ (*)(*)/ ", "2"..rep("b",8).."2", rep("2",SW)),
            S("  `---`  ", rep("b",SW), rep("2",SW)),
        }
    },
    -- ═══ CITRON ═══
    {
        id="lemon", poids=14, mult_pair=0, mult_triple=2,
        color_name="CITRON", color_fg=colors.yellow, color_bg=colors.lime,
        lines={
            S("  .==-.  ", rep("3",SW), rep("e",SW)),
            S(" /      \\ ", rep("3",SW), rep("e",SW)),
            S("|  (::)  |", rep("3",SW), rep("e",SW)),
            S(" \\      / ", rep("3",SW), rep("e",SW)),
            S("  `--=`  ", rep("3",SW), rep("e",SW)),
        }
    },
}

-- Index par id
local SYM = {}
for _, s in ipairs(SYMBOLS) do SYM[s.id] = s end

-- Roue ponderee
local REEL = {}
for _, s in ipairs(SYMBOLS) do
    for _ = 1, s.poids do table.insert(REEL, s.id) end
end
local REEL_N = #REEL

-- ── API BANQUE ────────────────────────────────────────────────
os.loadAPI("cgbank_api")
local bank = cgbank_api.new(CFG.modem_side, CFG.server_ch, CFG.my_ch)

local MODEM = peripheral.wrap(CFG.modem_side)
if not MODEM then
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name):find("modem") then
            MODEM = peripheral.wrap(name); break
        end
    end
end

local function bank_send(t)
    if not MODEM then return { ok=false, msg="Pas de modem" } end
    t.reply_ch = CFG.my_ch
    MODEM.transmit(CFG.server_ch, CFG.my_ch, t)
    local timer = os.startTimer(5)
    while true do
        local e, _, ch, _, m = os.pullEvent()
        if e == "modem_message" and ch == CFG.my_ch and type(m) == "table" then
            os.cancelTimer(timer); return m
        elseif e == "timer" then return { ok=false, msg="Timeout" } end
    end
end

-- ── DIMENSIONS ───────────────────────────────────────────────
local W, H = term.getSize()

-- Layout:
-- L1      : header titre neon
-- L2      : solde joueur
-- L3      : bord haut machine (neon)
-- L4-L8   : rouleaux (5 lignes par symbole)
-- L9      : bord bas machine (neon)
-- L10     : ligne de gain / message resultat
-- L11-L13 : paytable (3 lignes)
-- L14     : separateur
-- L15     : mise + boutons preset
-- L16     : bouton SPIN + boutons << >>
-- L17     : footer (connexion/quitter)

local MACHINE_TOP = 3
local MACHINE_BOT = MACHINE_TOP + SH + 1  -- =9
local WIN_LINE_Y  = MACHINE_TOP + 1 + math.floor(SH/2)  -- ligne centrale = L6

-- 3 rouleaux de SW=11 chars, gap de 1 char, cadre de 1 char de chaque cote
-- Total rouleaux: 3*11 + 2*1 = 35, avec cadre: 37
-- Centre dans W
local RGAP   = 2
local RTOTAL = 3*SW + 2*RGAP
local RX     = math.floor((W - RTOTAL)/2) + 1  -- X du debut du rouleau 1

-- X de depart de chaque rouleau
local function reel_x(r) return RX + (r-1)*(SW+RGAP) end

-- Positions des rouleaux
local reel_pos = {1, 8, 15}

local function get_sym_at(r, offset)
    local idx = ((reel_pos[r] + offset - 1) % REEL_N) + 1
    return REEL[idx]
end

-- ── UTILITAIRES ───────────────────────────────────────────────
local function cls()
    term.setBackgroundColor(colors.black)
    term.clear(); term.setCursorPos(1,1)
end

local function at(x, y, txt, fg, bg)
    if y<1 or y>H or x<1 or x>W then return end
    term.setCursorPos(x, y)
    if bg then term.setBackgroundColor(bg) end
    if fg then term.setTextColor(fg) end
    if x + #txt - 1 > W then txt = txt:sub(1, W-x+1) end
    term.write(txt)
end

local function center(y, txt, fg, bg)
    at(math.max(1,math.floor((W-#txt)/2)+1), y, txt, fg, bg)
end

local function fill(y, fg, bg)
    at(1, y, string.rep(" ", W), fg, bg)
end

local function blit_at(x, y, txt, fg_s, bg_s)
    if y<1 or y>H or x<1 then return end
    local max = W - x + 1
    if #txt > max then
        txt  = txt:sub(1,max)
        fg_s = fg_s:sub(1,max)
        bg_s = bg_s:sub(1,max)
    end
    term.setCursorPos(x, y)
    term.blit(txt, fg_s, bg_s)
end

-- ── DESSIN D'UN SYMBOLE ───────────────────────────────────────
local function draw_sym(x, y, sym, highlight)
    if not sym then sym = SYM["lemon"] end
    for i, line in ipairs(sym.lines) do
        local art = line.art
        local fg_s, bg_s
        if highlight then
            -- Fond jaune vif pour le highlight
            fg_s = string.rep("0", SW)
            bg_s = string.rep("3", SW)
            -- Garder le texte lisible
            fg_s = line.fg
            bg_s = string.rep("3", SW)
        else
            fg_s = line.fg
            bg_s = line.bg
        end
        -- Padding si art est plus court que SW
        while #art < SW do art = art .. " " end
        art = art:sub(1, SW)
        blit_at(x, y+i-1, art, fg_s:sub(1,SW), bg_s:sub(1,SW))
    end
end

-- ── CADRE DE LA MACHINE ───────────────────────────────────────
local function draw_machine_frame()
    -- Fond general de la zone machine
    for y = MACHINE_TOP, MACHINE_BOT do
        fill(y, colors.black, colors.lightGray)
    end

    -- Bord haut: ligne neon or/orange alternee
    local nt = ""
    local nf = ""
    local nb = ""
    for i = 1, W do
        nt = nt .. (i%2==1 and "=" or "-")
        nf = nf .. (i%2==1 and "3" or "d")
        nb = nb .. "8"
    end
    blit_at(1, MACHINE_TOP,   nt, nf, nb)
    blit_at(1, MACHINE_BOT,   nt, nf, nb)

    -- Separateurs entre rouleaux (colonne de 1 char)
    for r = 1, 2 do
        local sx = reel_x(r) + SW
        for y = MACHINE_TOP+1, MACHINE_BOT-1 do
            at(sx, y, string.rep(" ", RGAP), colors.yellow, colors.gray)
        end
    end

    -- Marges gauche/droite
    for y = MACHINE_TOP+1, MACHINE_BOT-1 do
        at(1,          y, " ", colors.black, colors.gray)
        at(RX-1,       y, "|", colors.yellow, colors.lightGray)
        at(RX+RTOTAL,  y, "|", colors.yellow, colors.lightGray)
        at(W,          y, " ", colors.black, colors.gray)
    end

    -- Fleches indicatrices de la ligne de gain
    local arrow_l = RX - 2
    local arrow_r = RX + RTOTAL + 1
    at(arrow_l, WIN_LINE_Y, ">", colors.yellow, colors.black)
    at(arrow_r, WIN_LINE_Y, "<", colors.yellow, colors.black)
end

-- ── DESSIN DES 3 ROULEAUX ────────────────────────────────────
local function draw_reels(highlights)
    highlights = highlights or {}
    for r = 1, 3 do
        local x = reel_x(r)
        -- Symbole du milieu (celui qui compte)
        local mid_id = get_sym_at(r, 0)
        local sym    = SYM[mid_id] or SYM["lemon"]
        local hl     = highlights[r] or false
        draw_sym(x, MACHINE_TOP+1, sym, hl)
    end
end

-- ── ANIMATION SPIN ───────────────────────────────────────────
local function animate_spin(results)
    -- Trouver positions cibles
    local targets = {}
    for r = 1, 3 do
        local cands = {}
        for i, s in ipairs(REEL) do
            if s == results[r] then table.insert(cands, i) end
        end
        targets[r] = cands[math.random(#cands)]
    end

    -- Animation en parallele, chaque rouleau s'arrete a des moments differents
    local function spin_one(r, target, n_steps, start_delay, end_delay)
        local x = reel_x(r)
        os.sleep((r-1) * 0.25)  -- decalage de demarrage
        for step = 1, n_steps do
            reel_pos[r] = (reel_pos[r] % REEL_N) + 1
            if step == n_steps then reel_pos[r] = target end

            local mid_id = get_sym_at(r, 0)
            draw_sym(x, MACHINE_TOP+1, SYM[mid_id] or SYM["lemon"], false)

            local t = step / n_steps
            local d
            if t < 0.35 then d = start_delay
            elseif t < 0.70 then d = (start_delay + end_delay) / 2
            elseif t < 0.90 then d = end_delay
            else d = end_delay * 1.5 end
            os.sleep(d)
        end
    end

    parallel.waitForAll(
        function() spin_one(1, targets[1], 22, 0.04, 0.18) end,
        function() spin_one(2, targets[2], 28, 0.04, 0.20) end,
        function() spin_one(3, targets[3], 34, 0.04, 0.22) end
    )
end

-- ── CALCUL GAINS ─────────────────────────────────────────────
local function calc_win(s1, s2, s3)
    if s1 == s2 and s2 == s3 then
        local s = SYM[s1]
        if s then return s.mult_triple, "TRIPLE " .. s.color_name end
    end
    -- Paire (cerises seulement)
    for _, id in ipairs({s1,s2,s3}) do
        local cnt = 0
        for _, v in ipairs({s1,s2,s3}) do if v==id then cnt=cnt+1 end end
        if cnt >= 2 then
            local s = SYM[id]
            if s and s.mult_pair > 0 then
                return s.mult_pair, "PAIRE " .. s.color_name
            end
        end
    end
    return 0, ""
end

-- ── PAYTABLE ─────────────────────────────────────────────────
local function draw_paytable(y)
    -- Header
    local ht = " TABLEAU DES GAINS "
    fill(y, colors.black, colors.black)
    center(y, ht, colors.black, colors.yellow)

    -- 2 colonnes
    local entries = {
        { sym=SYM["7"],     txt="7 7 7",            val="x50" },
        { sym=SYM["dia"],   txt="<> <> <>",          val="x20" },
        { sym=SYM["bell"],  txt="(o)(o)(o)",          val="x10" },
        { sym=SYM["bar"],   txt="BAR BAR BAR",        val="x5"  },
        { sym=SYM["ceri"],  txt="CERISE x3 / paire",  val="x3/x2"},
        { sym=SYM["lemon"], txt="CITRON CITRON CITRON",val="x2"  },
    }

    local col1 = 2
    local col2 = math.floor(W/2) + 1
    for i, e in ipairs(entries) do
        local col = (i % 2 == 1) and col1 or col2
        local row = y + 1 + math.floor((i-1)/2)
        at(col,   row, e.txt, e.sym.color_fg, colors.black)
        at(col+#e.txt+1, row, e.val, colors.lime, colors.black)
    end
end

-- ── SESSION ───────────────────────────────────────────────────
local SESSION = { logged_in=false, name="", balance=0 }
local BET     = 1.0
local LAST_WIN = 0
local SPINS    = 0
local HISTORY  = {}   -- derniers resultats {id, win}

local BET_PRESETS = {0.5, 1, 2, 5, 10, 25, 50}
local bet_idx = 2

-- ── ZONES CLIQUABLES ─────────────────────────────────────────
local BTNS = {}

local BET_Y  = 0
local SPIN_Y = 0
local FOOT_Y = 0
local PAY_Y  = 0

local function make_btn(id, x1, y1, x2, y2, lbl, fg, bg)
    table.insert(BTNS, {id=id, x1=x1,y1=y1,x2=x2,y2=y2,
                         lbl=lbl, fg=fg, bg=bg})
end

local function draw_btn(b, active)
    local bw = b.x2-b.x1+1
    local bh = b.y2-b.y1+1
    local fg = active and colors.black or b.fg
    local bg = active and colors.yellow or b.bg
    for y = b.y1, b.y2 do
        at(b.x1, y, string.rep(" ", bw), fg, bg)
    end
    local lx = b.x1 + math.floor((bw-#b.lbl)/2)
    local ly = b.y1 + math.floor(bh/2)
    at(lx, ly, b.lbl, fg, bg)
end

local function get_btn(mx, my)
    for _, b in ipairs(BTNS) do
        if mx>=b.x1 and mx<=b.x2 and my>=b.y1 and my<=b.y2 then
            return b.id
        end
    end
    return nil
end

local function build_btns()
    BTNS = {}
    PAY_Y  = MACHINE_BOT + 2
    BET_Y  = PAY_Y + 4
    SPIN_Y = BET_Y + 2
    FOOT_Y = H

    -- Boutons preset mise
    local total_w = #BET_PRESETS * 6
    local bx = math.floor((W - total_w)/2) + 1
    for i, v in ipairs(BET_PRESETS) do
        local lbl = v < 1 and ".5" or tostring(math.floor(v))
        make_btn("bet"..i, bx, BET_Y, bx+4, BET_Y,
                 " "..lbl.." ", colors.white, colors.lightGray)
        bx = bx + 6
    end

    -- Bouton << et >> pour ajuster
    local mid = math.floor(W/2)
    make_btn("bet_dn", mid-14, BET_Y+1, mid-9,  BET_Y+1,
             " << ", colors.white, colors.orange)
    make_btn("bet_up", mid+8,  BET_Y+1, mid+13, BET_Y+1,
             " >> ", colors.white, colors.orange)

    -- Bouton SPIN (grand)
    local sw = 17; local sh = 3
    local sx = math.floor((W-sw)/2)+1
    make_btn("spin", sx, SPIN_Y, sx+sw-1, SPIN_Y+sh-1,
             ">>> SPIN <<<", colors.black, colors.yellow)

    -- Footer
    make_btn("login",    2,    FOOT_Y, 12,   FOOT_Y, "[Connexion]",   colors.cyan,      colors.black)
    make_btn("register", 14,   FOOT_Y, 28,   FOOT_Y, "[Inscription]", colors.lightBlue, colors.black)
    make_btn("logout",   2,    FOOT_Y, 16,   FOOT_Y, "[Deconnexion]", colors.lightGray, colors.black)
    make_btn("quit",     W-10, FOOT_Y, W,    FOOT_Y, "[Quitter]",     colors.lightGray, colors.black)
end

local function draw_bet_zone()
    fill(BET_Y,   colors.black, colors.black)
    fill(BET_Y+1, colors.black, colors.black)

    local mid = math.floor(W/2)
    -- Label mise
    at(mid-10, BET_Y+1, "MISE:", colors.lightGray, colors.black)
    local bs = string.format("%.2f CGC", BET)
    at(mid-4,  BET_Y+1, bs, colors.yellow, colors.black)

    -- Boutons preset
    for _, b in ipairs(BTNS) do
        if b.id:sub(1,3) == "bet" and b.id ~= "bet_dn" and b.id ~= "bet_up" then
            local idx = tonumber(b.id:sub(4))
            if idx then
                draw_btn(b, math.abs(BET - BET_PRESETS[idx]) < 0.01)
            end
        elseif b.id == "bet_dn" or b.id == "bet_up" then
            draw_btn(b, false)
        end
    end
end

local function draw_spin_btn(active)
    for _, b in ipairs(BTNS) do
        if b.id == "spin" then draw_btn(b, active) end
    end
end

local function draw_footer()
    fill(FOOT_Y, colors.black, colors.black)
    if SESSION.logged_in then
        for _, b in ipairs(BTNS) do
            if b.id == "logout" or b.id == "quit" then draw_btn(b, false) end
        end
    else
        for _, b in ipairs(BTNS) do
            if b.id == "login" or b.id == "register" or b.id == "quit" then
                draw_btn(b, false)
            end
        end
    end
end

-- ── HISTORIQUE (pastilles colorees) ──────────────────────────
local function add_history(sym_id, won)
    table.insert(HISTORY, 1, {id=sym_id, won=won})
    if #HISTORY > 12 then table.remove(HISTORY) end
end

local function draw_history()
    -- Affiche les pastilles sur la ligne sous le header (L2 cote droit)
    local x = W - 1
    for i = 1, math.min(#HISTORY, 12) do
        local h = HISTORY[i]
        local s = SYM[h.id]
        if s then
            local bg = s.color_bg
            local sym_c = h.won and colors.lime or colors.red
            at(x, 2, " ", sym_c, bg)
            x = x - 2
            if x < math.floor(W/2) then break end
        end
    end
end

-- ── HUD ──────────────────────────────────────────────────────
local function draw_hud()
    -- Header neon
    local ht = ""
    local hf = ""
    local hb = ""
    for i = 1, W do
        ht = ht .. (i==1 and "*" or i==W and "*" or " ")
        hf = hf .. (i%3==0 and "3" or "d")
        hb = hb .. "d"
    end
    blit_at(1, 1, ht, hf, hb)
    center(1, " CGCasino  SLOT MACHINE ", colors.black, colors.orange)

    -- Ligne 2: solde et infos
    fill(2, colors.black, colors.black)
    if SESSION.logged_in then
        at(2, 2, SESSION.name, colors.cyan, colors.black)
        local spins_s = "Spins:"..SPINS
        at(math.floor(W/2)-math.floor(#spins_s/2), 2, spins_s, colors.lightGray, colors.black)
        local bal_s = string.format("%.4f CGC", SESSION.balance)
        -- Affiche solde a gauche de l'historique
        at(W-#bal_s-26, 2, bal_s,
           SESSION.balance>0 and colors.lime or colors.red, colors.black)
    else
        center(2, "Non connecte", colors.lightGray, colors.black)
    end
    draw_history()
end

-- ── MESSAGE RESULTAT ─────────────────────────────────────────
local function draw_msg(msg, col)
    fill(MACHINE_BOT+1, colors.black, colors.black)
    if msg and #msg>0 then
        center(MACHINE_BOT+1, msg, col or colors.white, colors.black)
    end
end

-- ── FULL UI ──────────────────────────────────────────────────
local function draw_ui(msg, msg_col)
    cls()
    draw_hud()
    draw_machine_frame()
    draw_reels()
    draw_msg(msg, msg_col)
    draw_paytable(PAY_Y)
    draw_bet_zone()
    draw_spin_btn(false)
    draw_footer()

    -- Dernier gain
    if LAST_WIN ~= 0 then
        local ws = LAST_WIN > 0
            and string.format("+%.4f CGC", LAST_WIN)
            or  string.format("%.4f CGC", LAST_WIN)
        at(W-#ws-1, MACHINE_BOT+1, ws,
           LAST_WIN>0 and colors.lime or colors.red, colors.black)
    end
end

-- ── FLASH VICTOIRE ────────────────────────────────────────────
local function flash_win(desc, mult)
    for flash = 1, 5 do
        local hl = flash%2==1
        draw_reels(hl and {true,true,true} or {})
        if hl then
            local msg = " " .. desc .. "  x" .. mult .. " !"
            center(WIN_LINE_Y, msg, colors.black, colors.yellow)
        end
        os.sleep(0.22)
    end
end

local function jackpot_anim()
    for i = 1, 8 do
        local oc = i%2==1
        fill(1, oc and colors.black or colors.yellow,
                oc and colors.yellow or colors.black)
        center(1, " *** JACKPOT *** 7 7 7 *** JACKPOT *** ",
               oc and colors.yellow or colors.black,
               oc and colors.black  or colors.yellow)
        fill(WIN_LINE_Y, colors.black,
             oc and colors.red or colors.yellow)
        center(WIN_LINE_Y, "    7  7  7  JACKPOT x50 !    ",
               oc and colors.yellow or colors.red,
               oc and colors.red    or colors.yellow)
        os.sleep(0.18)
    end
end

-- ── LOGIN / INSCRIPTION ───────────────────────────────────────
local function screen_login()
    cls()
    center(1, " CGCasino - Connexion ", colors.black, colors.orange)
    at(2,4,"Nom de compte : ",colors.lightGray,colors.black)
    term.setTextColor(colors.cyan); local name = read()
    at(2,6,"Mot de passe  : ",colors.lightGray,colors.black)
    term.setTextColor(colors.cyan); local pw = read("*")
    at(2,8,"Verification...",colors.lightGray,colors.black)
    local res = bank_send({cmd="login",account=name,password=pw})
    if res.ok then
        SESSION.logged_in=true; SESSION.name=name
        SESSION.balance=res.balance or 0
        at(2,8,"Bienvenue "..name.." !  Solde: "..
           string.format("%.4f",SESSION.balance).." CGC",
           colors.lime,colors.black)
        os.sleep(1.5)
    else
        at(2,8,"ECHEC: "..(res.msg or "?"),colors.red,colors.black)
        os.sleep(2)
    end
end

local function screen_register()
    cls()
    center(1," CGCasino - Inscription ",colors.black,colors.orange)
    at(2,4,"Nom de compte  : ",colors.lightGray,colors.black)
    term.setTextColor(colors.cyan); local name=read()
    at(2,6,"Mot de passe   : ",colors.lightGray,colors.black)
    term.setTextColor(colors.cyan); local pw1=read("*")
    at(2,8,"Confirmer mdp  : ",colors.lightGray,colors.black)
    term.setTextColor(colors.cyan); local pw2=read("*")
    if pw1~=pw2 then
        at(2,10,"Mots de passe differents !",colors.red,colors.black)
        os.sleep(2);return
    end
    if #pw1<4 then
        at(2,10,"Trop court (4 min).",colors.red,colors.black)
        os.sleep(2);return
    end
    local res=bank_send({cmd="register",account=name,password=pw1})
    if res.ok then
        at(2,10,"Compte cree ! Connectez-vous.",colors.lime,colors.black)
    else
        at(2,10,"ECHEC: "..(res.msg or "?"),colors.red,colors.black)
    end
    os.sleep(2)
end

-- ── TOUR DE JEU ──────────────────────────────────────────────
local function do_spin()
    if not SESSION.logged_in then
        draw_msg("Connectez-vous pour jouer !", colors.red)
        os.sleep(1.5); return
    end
    if SESSION.balance < BET then
        draw_msg("Solde insuffisant !", colors.red)
        os.sleep(1.5); return
    end

    local ok, msg2, new_bal = bank.withdraw(SESSION.name, BET, "Slot machine")
    if not ok then
        draw_msg("Banque: "..msg2, colors.red)
        os.sleep(2); return
    end
    SESSION.balance = new_bal
    SPINS = SPINS + 1
    draw_hud()
    draw_spin_btn(true)
    draw_msg("Bonne chance !", colors.yellow)

    -- Tirage
    math.randomseed(os.time()*997 + os.clock()*100003 + SPINS*13)
    local results = {}
    for r = 1, 3 do
        results[r] = REEL[math.random(REEL_N)]
    end

    animate_spin(results)

    local mult, desc = calc_win(results[1], results[2], results[3])
    LAST_WIN = 0

    if mult > 0 then
        if results[1]=="7" and results[2]=="7" and results[3]=="7" then
            jackpot_anim()
        else
            flash_win(desc, mult)
        end
        local gain = BET * mult
        LAST_WIN = gain - BET
        local ok2, _, nb2 = bank.deposit(SESSION.name, gain, "Gain slot x"..mult)
        if ok2 then SESSION.balance = nb2 end
        add_history(results[2], true)
        draw_ui(desc.."  +"..(string.format("%.4f",LAST_WIN)).." CGC  (x"..mult..")", colors.lime)
    else
        LAST_WIN = -BET
        add_history(results[2], false)
        local ok3,bal3=bank.balance(SESSION.name)
        if ok3 then SESSION.balance=bal3 end
        draw_ui(string.format("Perdu.  Retentez votre chance !"), colors.red)
    end
end

-- ── MISE ─────────────────────────────────────────────────────
local function set_bet_idx(i)
    bet_idx = math.max(1, math.min(#BET_PRESETS, i))
    BET = BET_PRESETS[bet_idx]
end

-- ── MAIN ─────────────────────────────────────────────────────
setup_palette()
build_btns()
cls()

center(math.floor(H/2)-1,"CGCasino",colors.yellow,colors.black)
center(math.floor(H/2),  "Slot Machine v2",colors.orange,colors.black)
center(math.floor(H/2)+2,"Connexion CGBank...",colors.lightGray,colors.black)

local pok, pmsg = bank.ping()
if not pok then
    cls()
    center(math.floor(H/2)-1,"CGBank hors ligne !",colors.red,colors.black)
    center(math.floor(H/2)+1,pmsg,colors.gray,colors.black)
    os.sleep(4); restore_palette(); cls(); return
end
os.sleep(0.4)

math.randomseed(os.time())
for r=1,3 do reel_pos[r]=math.random(REEL_N) end

local cur_msg = "Connectez-vous et cliquez SPIN pour jouer !"
local cur_col = colors.yellow

while true do
    if SESSION.logged_in then
        local ok,bal=bank.balance(SESSION.name)
        if ok then SESSION.balance=bal end
    end
    draw_ui(cur_msg, cur_col)
    cur_msg=nil; cur_col=nil

    local ev,p1,p2,p3 = os.pullEvent()

    if ev=="mouse_click" then
        local mx,my = p2,p3
        local btn = get_btn(mx,my)
        if     btn=="spin"     then do_spin()
        elseif btn=="quit"     then break
        elseif btn=="login"    and not SESSION.logged_in then screen_login()
        elseif btn=="register" and not SESSION.logged_in then screen_register()
        elseif btn=="logout"   and SESSION.logged_in then
            SESSION.logged_in=false; SESSION.name=""; SESSION.balance=0
            cur_msg="Deconnecte."; cur_col=colors.lightGray
        elseif btn=="bet_dn" then set_bet_idx(bet_idx-1)
        elseif btn=="bet_up" then set_bet_idx(bet_idx+1)
        elseif btn then
            local i=tonumber(btn:sub(4))
            if i then set_bet_idx(i) end
        end

    elseif ev=="key" then
        local key=p1
        if     key==keys.space or key==keys.enter then do_spin()
        elseif key==keys.q  then break
        elseif key==keys.left  then set_bet_idx(bet_idx-1)
        elseif key==keys.right then set_bet_idx(bet_idx+1)
        elseif key==keys.c and not SESSION.logged_in then screen_login()
        elseif key==keys.i and not SESSION.logged_in then screen_register()
        end
    end
end

cls()
center(math.floor(H/2),"A bientot au CGCasino !",colors.yellow,colors.black)
os.sleep(1.2)
restore_palette(); cls()
