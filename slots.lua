-- ============================================================
--  CGCasino - Slot Machine v2.1  |  slots.lua
--  Symboles corriges (longueurs exactes), sons speaker AP
-- ============================================================

local CFG = {
    modem_side   = "top",
    server_ch    = 1000,
    my_ch        = 1011,
    speaker_side = "left",   -- cote du speaker Advanced Peripherals
                              -- mettez nil pour desactiver les sons
    bet_min      = 0.5,
    bet_max      = 50,
}

-- ── PALETTE ──────────────────────────────────────────────────
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

-- ── SONS ─────────────────────────────────────────────────────
-- Advanced Peripherals: speaker.playNote(instrument, volume, pitch)
-- instruments: "harp","basedrum","snare","hat","bass","flute",
--              "bell","guitar","chime","xylophone","iron_xylophone",
--              "cow_bell","didgeridoo","bit","banjo","pling"
-- pitch: 0-24 (12 = la, 1 semitone per step)

local SPEAKER = nil
if CFG.speaker_side then
    SPEAKER = peripheral.wrap(CFG.speaker_side)
    if not SPEAKER then
        -- Cherche sur tous les cotes
        for _, name in ipairs(peripheral.getNames()) do
            if peripheral.getType(name) == "speaker" then
                SPEAKER = peripheral.wrap(name); break
            end
        end
    end
end

local function play(instrument, volume, pitch)
    if SPEAKER then
        pcall(function()
            SPEAKER.playNote(instrument, volume or 1, pitch or 12)
        end)
    end
end

-- Sons specifiques
local function snd_spin_tick()
    play("hat", 0.6, math.random(8, 16))
end

local function snd_reel_stop(reel_num)
    -- Chaque rouleau a un pitch different
    local pitches = {8, 10, 12}
    play("basedrum", 0.8, pitches[reel_num] or 10)
end

local function snd_win_small()
    -- Melodie courte victoire: do-mi-sol
    play("pling", 1, 12); os.sleep(0.1)
    play("pling", 1, 16); os.sleep(0.1)
    play("pling", 1, 19)
end

local function snd_win_big()
    -- Melodie victoire grande: arpege ascendant
    local notes = {12, 16, 19, 24}
    for _, n in ipairs(notes) do
        play("bell", 1, n)
        os.sleep(0.08)
    end
end

local function snd_jackpot()
    -- Fanfare jackpot
    local melody = {12,12,14,16,16,14,12,14,16,19,24}
    for _, n in ipairs(melody) do
        play("chime", 1, n)
        play("bell",  0.5, n)
        os.sleep(0.07)
    end
end

local function snd_lose()
    play("basedrum", 0.5, 6)
    os.sleep(0.1)
    play("basedrum", 0.3, 4)
end

local function snd_btn_click()
    play("hat", 0.4, 18)
end

local function snd_insert_coin()
    -- Son de piece qui tombe
    play("bit", 0.7, 20)
    os.sleep(0.05)
    play("bit", 0.7, 16)
end

-- ── SYMBOLES (SW=9, toutes strings de longueur exacte 9) ─────
local SW = 9
local SH = 5

local function S(art, fg, bg)
    -- Garantit longueur exacte SW
    art = art:sub(1,SW); while #art < SW do art = art.." " end
    fg  = fg:sub(1,SW);  while #fg  < SW do fg  = fg .."7" end
    bg  = bg:sub(1,SW);  while #bg  < SW do bg  = bg .."0" end
    return {art=art, fg=fg, bg=bg}
end

local SYMBOLS = {
    -- ═══ SEVEN (jackpot x50) ═══
    {
        id="7", poids=2, mult_pair=0, mult_triple=50,
        color_name="SEVEN", color_fg=colors.yellow, color_bg=colors.red,
        lines={
            S(" .=====. ","333333333","111111111"),
            S(" | 777 | ","933333339","111111111"),
            S(" |/7/7/| ","933333339","111111111"),
            S(" |77777| ","933333339","111111111"),
            S(" '=====` ","333333333","111111111"),
        }
    },
    -- ═══ DIAMANT (x20) ═══
    {
        id="dia", poids=4, mult_pair=0, mult_triple=20,
        color_name="DIAMANT", color_fg=colors.lightBlue, color_bg=colors.blue,
        lines={
            S(" .=====. ","aaaaaaaaa","444444444"),
            S("/|     |\\","a7777777a","444444444"),
            S("|   *   |","a777a777a","444444444"),
            S("\\|     |/","a7777777a","444444444"),
            S(" `=====` ","aaaaaaaaa","444444444"),
        }
    },
    -- ═══ CLOCHE (x10) ═══
    {
        id="bell", poids=6, mult_pair=0, mult_triple=10,
        color_name="CLOCHE", color_fg=colors.yellow, color_bg=colors.orange,
        lines={
            S("  .===.  ","333333333","ddddddddd"),
            S(" /     \\ ","333333333","ddddddddd"),
            S("| (( )) |","333333333","ddddddddd"),
            S(" \\_____/ ","333333333","ddddddddd"),
            S("   |_|   ","333333333","ddddddddd"),
        }
    },
    -- ═══ BAR (x5) ═══
    {
        id="bar", poids=8, mult_pair=0, mult_triple=5,
        color_name="BAR", color_fg=colors.white, color_bg=colors.gray,
        lines={
            S(".=======.","777777777","888888888"),
            S("|       |","777777777","888888888"),
            S("| [BAR] |","777777777","888888888"),
            S("|       |","777777777","888888888"),
            S("`=======`","777777777","888888888"),
        }
    },
    -- ═══ CERISE (triple x3, paire x2) ═══
    {
        id="ceri", poids=12, mult_pair=2, mult_triple=3,
        color_name="CERISE", color_fg=colors.pink, color_bg=colors.green,
        lines={
            S(" o     o ","b2222222b","222222222"),
            S(" |\\   /| ","b2222222b","222222222"),
            S("(*)   (*)","bbbbbbbbb","111111111"),
            S("(*)   (*)","bbbbbbbbb","111111111"),
            S(" `-----` ","bbbbbbbbb","222222222"),
        }
    },
    -- ═══ CITRON (x2) ═══
    {
        id="lemon", poids=14, mult_pair=0, mult_triple=2,
        color_name="CITRON", color_fg=colors.yellow, color_bg=colors.lime,
        lines={
            S(" .=====. ","333333333","eeeeeeeee"),
            S("/  :::  \\","333333333","eeeeeeeee"),
            S("|  :::  |","333333333","eeeeeeeee"),
            S("\\  :::  /","333333333","eeeeeeeee"),
            S(" `=====` ","333333333","eeeeeeeee"),
        }
    },
}

local SYM = {}
for _, s in ipairs(SYMBOLS) do SYM[s.id] = s end

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
    if not MODEM then return {ok=false,msg="Pas de modem"} end
    t.reply_ch = CFG.my_ch
    MODEM.transmit(CFG.server_ch, CFG.my_ch, t)
    local timer = os.startTimer(5)
    while true do
        local e,_,ch,_,m = os.pullEvent()
        if e=="modem_message" and ch==CFG.my_ch and type(m)=="table" then
            os.cancelTimer(timer); return m
        elseif e=="timer" then return {ok=false,msg="Timeout"} end
    end
end

-- ── DIMENSIONS ───────────────────────────────────────────────
local W, H = term.getSize()

local MACHINE_TOP = 3
local RGAP        = 3
local RTOTAL      = 3*SW + 2*RGAP   -- 3*9 + 6 = 33
local RX          = math.floor((W - RTOTAL)/2) + 1
local MACHINE_BOT = MACHINE_TOP + SH + 1
local WIN_LINE_Y  = MACHINE_TOP + 1 + math.floor(SH/2)

local function reel_x(r) return RX + (r-1)*(SW+RGAP) end

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
    if x+#txt-1>W then txt=txt:sub(1,W-x+1) end
    term.write(txt)
end

local function center(y, txt, fg, bg)
    at(math.max(1,math.floor((W-#txt)/2)+1), y, txt, fg, bg)
end

local function fill(y, fg, bg)
    at(1, y, string.rep(" ",W), fg, bg)
end

local function blit_at(x, y, txt, fg_s, bg_s)
    if y<1 or y>H or x<1 then return end
    -- Garantit que les 3 strings sont de meme longueur
    local max = math.min(W-x+1, #txt, #fg_s, #bg_s)
    if max <= 0 then return end
    txt  = txt:sub(1,max)
    fg_s = fg_s:sub(1,max)
    bg_s = bg_s:sub(1,max)
    term.setCursorPos(x, y)
    term.blit(txt, fg_s, bg_s)
end

-- ── DESSIN SYMBOLE ───────────────────────────────────────────
local function draw_sym(x, y, sym, highlight)
    if not sym then sym = SYM["lemon"] end
    for i, line in ipairs(sym.lines) do
        local art = line.art
        local fg_s, bg_s
        if highlight then
            fg_s = line.fg
            bg_s = string.rep("3", SW)   -- fond jaune
        else
            fg_s = line.fg
            bg_s = line.bg
        end
        blit_at(x, y+i-1, art, fg_s, bg_s)
    end
end

-- ── CADRE MACHINE ────────────────────────────────────────────
local function draw_machine_frame()
    -- Fond zone machine
    for y = MACHINE_TOP, MACHINE_BOT do
        fill(y, colors.black, colors.lightGray)
    end

    -- Bords neon haut/bas alterné or/orange
    local nt=""; local nf=""; local nb=""
    for i = 1, W do
        nt = nt..(i%2==1 and "=" or "-")
        nf = nf..(i%2==1 and "3" or "d")
        nb = nb.."8"
    end
    blit_at(1, MACHINE_TOP, nt, nf, nb)
    blit_at(1, MACHINE_BOT, nt, nf, nb)

    -- Separateurs entre rouleaux
    for r = 1, 2 do
        local sx = reel_x(r) + SW
        for y = MACHINE_TOP+1, MACHINE_BOT-1 do
            at(sx, y, string.rep(" ", RGAP), colors.yellow, colors.gray)
        end
    end

    -- Marges gauche/droite
    for y = MACHINE_TOP+1, MACHINE_BOT-1 do
        at(RX-2, y, "|", colors.yellow, colors.lightGray)
        at(RX+RTOTAL+1, y, "|", colors.yellow, colors.lightGray)
    end

    -- Fleches ligne de gain
    at(RX-3, WIN_LINE_Y, ">>", colors.yellow, colors.black)
    at(RX+RTOTAL+2, WIN_LINE_Y, "<<", colors.yellow, colors.black)

    -- Surligner la ligne de gain
    local wl=""; local wf=""; local wb=""
    for i = 1, W do
        wl=wl..(i>=RX-1 and i<=RX+RTOTAL and "-" or " ")
        wf=wf.."3"
        wb=wb.."0"
    end
    -- Juste les fleches, pas de ligne pleine sur les rouleaux
end

-- ── DESSINER LES 3 ROULEAUX ──────────────────────────────────
local function draw_reels(highlights)
    highlights = highlights or {}
    for r = 1, 3 do
        local x = reel_x(r)
        local mid_id = get_sym_at(r, 0)
        local sym = SYM[mid_id] or SYM["lemon"]
        draw_sym(x, MACHINE_TOP+1, sym, highlights[r] or false)
    end
end

-- ── ANIMATION SPIN ───────────────────────────────────────────
local function animate_spin(results)
    local targets = {}
    for r = 1, 3 do
        local cands = {}
        for i, s in ipairs(REEL) do
            if s == results[r] then table.insert(cands, i) end
        end
        targets[r] = cands[math.random(#cands)]
    end

    -- Fonction pour un rouleau
    local function spin_one(r, target, n_steps, start_d, end_d, start_delay)
        os.sleep(start_delay)
        local x = reel_x(r)
        for step = 1, n_steps do
            reel_pos[r] = (reel_pos[r] % REEL_N) + 1
            if step == n_steps then reel_pos[r] = target end

            local mid_id = get_sym_at(r, 0)
            draw_sym(x, MACHINE_TOP+1, SYM[mid_id] or SYM["lemon"], false)

            -- Son de tick pendant le spin
            if step % 3 == 0 then snd_spin_tick() end

            local t = step/n_steps
            local d
            if t < 0.4 then d = start_d
            elseif t < 0.75 then d = (start_d+end_d)/2
            else d = end_d end
            os.sleep(d)
        end
        -- Son d'arret du rouleau
        snd_reel_stop(r)
    end

    parallel.waitForAll(
        function() spin_one(1, targets[1], 22, 0.04, 0.18, 0)    end,
        function() spin_one(2, targets[2], 28, 0.04, 0.20, 0.25) end,
        function() spin_one(3, targets[3], 34, 0.04, 0.22, 0.55) end
    )
end

-- ── CALCUL GAINS ─────────────────────────────────────────────
local function calc_win(s1, s2, s3)
    if s1==s2 and s2==s3 then
        local s = SYM[s1]
        if s then return s.mult_triple, "TRIPLE "..s.color_name end
    end
    for _, id in ipairs({s1,s2,s3}) do
        local cnt=0
        for _,v in ipairs({s1,s2,s3}) do if v==id then cnt=cnt+1 end end
        if cnt>=2 then
            local s=SYM[id]
            if s and s.mult_pair>0 then
                return s.mult_pair, "PAIRE "..s.color_name
            end
        end
    end
    return 0,""
end

-- ── SESSION / ETAT ───────────────────────────────────────────
local SESSION  = {logged_in=false, name="", balance=0}
local BET      = 1.0
local LAST_WIN = 0
local SPINS    = 0
local HISTORY  = {}

local BET_PRESETS = {0.5,1,2,5,10,25,50}
local bet_idx = 2

local function set_bet_idx(i)
    bet_idx = math.max(1, math.min(#BET_PRESETS, i))
    BET = BET_PRESETS[bet_idx]
end

local function add_history(sym_id, won)
    table.insert(HISTORY, 1, {id=sym_id, won=won})
    if #HISTORY > 14 then table.remove(HISTORY) end
end

-- ── BOUTONS ──────────────────────────────────────────────────
local BTNS   = {}
local BET_Y  = 0
local SPIN_Y = 0
local FOOT_Y = 0
local PAY_Y  = 0

local function make_btn(id,x1,y1,x2,y2,lbl,fg,bg)
    table.insert(BTNS,{id=id,x1=x1,y1=y1,x2=x2,y2=y2,
                        lbl=lbl,fg=fg,bg=bg})
end

local function draw_btn(b, active)
    local bw=b.x2-b.x1+1; local bh=b.y2-b.y1+1
    local fg=active and colors.black or b.fg
    local bg=active and colors.yellow or b.bg
    for y=b.y1,b.y2 do at(b.x1,y,string.rep(" ",bw),fg,bg) end
    local lx=b.x1+math.floor((bw-#b.lbl)/2)
    local ly=b.y1+math.floor(bh/2)
    at(lx,ly,b.lbl,fg,bg)
end

local function get_btn(mx,my)
    for _,b in ipairs(BTNS) do
        if mx>=b.x1 and mx<=b.x2 and my>=b.y1 and my<=b.y2 then
            return b.id
        end
    end
    return nil
end

local function build_btns()
    BTNS={}
    PAY_Y  = MACHINE_BOT + 2
    BET_Y  = PAY_Y + 4
    SPIN_Y = BET_Y + 2
    FOOT_Y = H

    -- Presets mise
    local total_w = #BET_PRESETS * 6
    local bx = math.floor((W-total_w)/2)+1
    for i, v in ipairs(BET_PRESETS) do
        local lbl = v<1 and ".5" or tostring(math.floor(v))
        make_btn("bet"..i, bx,BET_Y, bx+4,BET_Y,
                 " "..lbl.." ", colors.white, colors.lightGray)
        bx = bx+6
    end

    local mid = math.floor(W/2)
    make_btn("bet_dn", mid-14,BET_Y+1, mid-9, BET_Y+1," << ",colors.white,colors.orange)
    make_btn("bet_up", mid+8, BET_Y+1, mid+13,BET_Y+1," >> ",colors.white,colors.orange)

    -- Bouton SPIN
    local sw=17; local sx=math.floor((W-sw)/2)+1
    make_btn("spin", sx,SPIN_Y, sx+sw-1,SPIN_Y+2,
             ">>> SPIN <<<", colors.black, colors.yellow)

    -- Footer
    make_btn("login",    2,   FOOT_Y, 12,  FOOT_Y,"[Connexion]",   colors.cyan,      colors.black)
    make_btn("register", 14,  FOOT_Y, 28,  FOOT_Y,"[Inscription]", colors.lightBlue, colors.black)
    make_btn("logout",   2,   FOOT_Y, 16,  FOOT_Y,"[Deconnexion]", colors.lightGray, colors.black)
    make_btn("quit",     W-10,FOOT_Y, W,   FOOT_Y,"[Quitter]",     colors.lightGray, colors.black)
end

local function draw_bet_zone()
    fill(BET_Y,   colors.black, colors.black)
    fill(BET_Y+1, colors.black, colors.black)
    local mid=math.floor(W/2)
    at(mid-10, BET_Y+1,"MISE :", colors.lightGray, colors.black)
    at(mid-4,  BET_Y+1, string.format("%.2f CGC", BET), colors.yellow, colors.black)
    for _,b in ipairs(BTNS) do
        if b.id:sub(1,3)=="bet" then
            if b.id=="bet_dn" or b.id=="bet_up" then
                draw_btn(b, false)
            else
                local i=tonumber(b.id:sub(4))
                if i then draw_btn(b, math.abs(BET-BET_PRESETS[i])<0.01) end
            end
        end
    end
end

local function draw_spin_btn(active)
    for _,b in ipairs(BTNS) do
        if b.id=="spin" then draw_btn(b,active) end
    end
end

local function draw_footer()
    fill(FOOT_Y, colors.black, colors.black)
    for _,b in ipairs(BTNS) do
        if b.id=="quit" then draw_btn(b,false)
        elseif b.id=="logout" and SESSION.logged_in then draw_btn(b,false)
        elseif (b.id=="login" or b.id=="register") and not SESSION.logged_in then
            draw_btn(b,false)
        end
    end
end

-- ── PAYTABLE ─────────────────────────────────────────────────
local function draw_paytable(y)
    fill(y, colors.black, colors.black)
    center(y," TABLEAU DES GAINS ",colors.black,colors.yellow)
    local col1=2; local col2=math.floor(W/2)+1
    local entries={
        {sym=SYM["7"],    txt="7 7 7",            val="x50", col=col1, row=y+1},
        {sym=SYM["dia"],  txt="<> <> <>",          val="x20", col=col2, row=y+1},
        {sym=SYM["bell"], txt="(o)(o)(o)",          val="x10", col=col1, row=y+2},
        {sym=SYM["bar"],  txt="BAR BAR BAR",        val="x5",  col=col2, row=y+2},
        {sym=SYM["ceri"], txt="CERISE x3 | paire", val="x3/2",col=col1, row=y+3},
        {sym=SYM["lemon"],txt="CITRON CITRON CITRON",val="x2", col=col2, row=y+3},
    }
    for _,e in ipairs(entries) do
        at(e.col,              e.row, e.txt, e.sym.color_fg, colors.black)
        at(e.col+#e.txt+1,    e.row, e.val, colors.lime,     colors.black)
    end
end

-- ── HISTORIQUE ───────────────────────────────────────────────
local function draw_history()
    local x = W-1
    for i=1,math.min(#HISTORY,14) do
        local h=HISTORY[i]
        local s=SYM[h.id]
        if s then
            at(x, 2, " ",
               h.won and colors.lime or colors.red,
               s.color_bg)
            x = x-2
            if x < math.floor(W/2) then break end
        end
    end
end

-- ── HUD ──────────────────────────────────────────────────────
local function draw_hud()
    -- Header neon
    local ht=""; local hf=""; local hb=""
    for i=1,W do
        ht=ht.." "
        hf=hf..(i%3==0 and "3" or "d")
        hb=hb.."d"
    end
    blit_at(1,1,ht,hf,hb)
    center(1," CGCasino  SLOT MACHINE ",colors.black,colors.orange)

    fill(2, colors.black, colors.black)
    if SESSION.logged_in then
        at(2,2,SESSION.name, colors.cyan, colors.black)
        local spins_s="Spins:"..SPINS
        at(math.floor(W/2)-math.floor(#spins_s/2), 2,
           spins_s, colors.lightGray, colors.black)
        local bal_s=string.format("%.4f CGC",SESSION.balance)
        at(W-#bal_s-28, 2, bal_s,
           SESSION.balance>0 and colors.lime or colors.red,
           colors.black)
    else
        center(2,"Non connecte",colors.lightGray,colors.black)
    end
    draw_history()
end

-- ── MESSAGE ──────────────────────────────────────────────────
local function draw_msg(msg,col)
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
    if LAST_WIN~=0 then
        local ws=LAST_WIN>0
            and string.format("+%.4f CGC",LAST_WIN)
            or  string.format("%.4f CGC",LAST_WIN)
        at(W-#ws-1, MACHINE_BOT+1, ws,
           LAST_WIN>0 and colors.lime or colors.red,
           colors.black)
    end
end

-- ── FLASH VICTOIRE ────────────────────────────────────────────
local function flash_win(desc, mult, is_big)
    for flash=1,5 do
        local hl=flash%2==1
        draw_reels(hl and {true,true,true} or {})
        if hl then
            center(WIN_LINE_Y," "..desc.."  x"..mult.." !",
                   colors.black, colors.yellow)
        end
        os.sleep(0.20)
    end
    if is_big then snd_win_big() else snd_win_small() end
end

local function jackpot_anim()
    snd_jackpot()
    for i=1,8 do
        local oc=i%2==1
        fill(1, oc and colors.yellow or colors.black,
                oc and colors.black  or colors.yellow)
        center(1,"*** JACKPOT *** 7 7 7 *** JACKPOT ***",
               oc and colors.black or colors.yellow,
               oc and colors.yellow or colors.black)
        fill(WIN_LINE_Y,
             oc and colors.yellow or colors.red,
             oc and colors.red    or colors.yellow)
        center(WIN_LINE_Y,"   7  7  7  JACKPOT x50 !   ",
               oc and colors.black  or colors.yellow,
               oc and colors.yellow or colors.red)
        os.sleep(0.18)
    end
end

-- ── LOGIN / INSCRIPTION ───────────────────────────────────────
local function screen_login()
    cls()
    center(1," CGCasino - Connexion ",colors.black,colors.orange)
    at(2,4,"Nom de compte : ",colors.lightGray,colors.black)
    term.setTextColor(colors.cyan); local name=read()
    at(2,6,"Mot de passe  : ",colors.lightGray,colors.black)
    term.setTextColor(colors.cyan); local pw=read("*")
    at(2,8,"Verification...",colors.lightGray,colors.black)
    local res=bank_send({cmd="login",account=name,password=pw})
    if res.ok then
        SESSION.logged_in=true; SESSION.name=name
        SESSION.balance=res.balance or 0
        snd_insert_coin()
        at(2,8,"Bienvenue "..name.." !  Solde: "..
           string.format("%.4f",SESSION.balance).." CGC",
           colors.lime,colors.black)
        os.sleep(1.5)
    else
        snd_lose()
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
        snd_lose(); os.sleep(2);return
    end
    if #pw1<4 then
        at(2,10,"Trop court (4 min).",colors.red,colors.black)
        snd_lose(); os.sleep(2);return
    end
    local res=bank_send({cmd="register",account=name,password=pw1})
    if res.ok then
        at(2,10,"Compte cree ! Connectez-vous.",colors.lime,colors.black)
        snd_win_small()
    else
        at(2,10,"ECHEC: "..(res.msg or "?"),colors.red,colors.black)
        snd_lose()
    end
    os.sleep(2)
end

-- ── TOUR DE JEU ──────────────────────────────────────────────
local function do_spin()
    if not SESSION.logged_in then
        draw_msg("Connectez-vous pour jouer !",colors.red)
        snd_lose(); os.sleep(1.5); return
    end
    if SESSION.balance<BET then
        draw_msg("Solde insuffisant !",colors.red)
        snd_lose(); os.sleep(1.5); return
    end

    snd_insert_coin()
    local ok,msg2,new_bal=bank.withdraw(SESSION.name,BET,"Slot machine")
    if not ok then
        draw_msg("Banque: "..msg2,colors.red)
        snd_lose(); os.sleep(2); return
    end
    SESSION.balance=new_bal
    SPINS=SPINS+1
    draw_hud()
    draw_spin_btn(true)
    draw_msg("Bonne chance !",colors.yellow)
    os.sleep(0.1)

    math.randomseed(os.time()*997+os.clock()*100003+SPINS*13)
    local results={}
    for r=1,3 do results[r]=REEL[math.random(REEL_N)] end

    animate_spin(results)

    local mult,desc=calc_win(results[1],results[2],results[3])
    LAST_WIN=0

    if mult>0 then
        local is_jackpot=(results[1]=="7" and results[2]=="7" and results[3]=="7")
        if is_jackpot then
            jackpot_anim()
        else
            flash_win(desc, mult, mult>=10)
        end
        local gain=BET*mult
        LAST_WIN=gain-BET
        local ok2,_,nb2=bank.deposit(SESSION.name,gain,"Gain slot x"..mult)
        if ok2 then SESSION.balance=nb2 end
        add_history(results[2],true)
        draw_ui(desc.."  +"..string.format("%.4f",LAST_WIN).." CGC  (x"..mult..")",
                colors.lime)
    else
        LAST_WIN=-BET
        snd_lose()
        add_history(results[2],false)
        local ok3,bal3=bank.balance(SESSION.name)
        if ok3 then SESSION.balance=bal3 end
        draw_ui("Perdu.  Retentez votre chance !",colors.red)
    end
end

-- ── MAIN ─────────────────────────────────────────────────────
setup_palette()
build_btns()
cls()

center(math.floor(H/2)-1,"CGCasino",colors.yellow,colors.black)
center(math.floor(H/2),  "Slot Machine",colors.orange,colors.black)
center(math.floor(H/2)+2,"Connexion CGBank...",colors.lightGray,colors.black)

local pok,pmsg=bank.ping()
if not pok then
    cls()
    center(math.floor(H/2)-1,"CGBank hors ligne !",colors.red,colors.black)
    center(math.floor(H/2)+1,pmsg,colors.gray,colors.black)
    os.sleep(4); restore_palette(); cls(); return
end
os.sleep(0.3)

math.randomseed(os.time())
for r=1,3 do reel_pos[r]=math.random(REEL_N) end

local cur_msg="Connectez-vous et cliquez SPIN !"
local cur_col=colors.yellow

while true do
    if SESSION.logged_in then
        local ok,bal=bank.balance(SESSION.name)
        if ok then SESSION.balance=bal end
    end
    draw_ui(cur_msg, cur_col)
    cur_msg=nil; cur_col=nil

    local ev,p1,p2,p3=os.pullEvent()

    if ev=="mouse_click" then
        local mx,my=p2,p3
        local btn=get_btn(mx,my)
        snd_btn_click()
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
