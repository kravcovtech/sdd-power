# validate.awk — структурная проверка файлов трекинга sdd-power.
# Вход (в этом порядке): PLAN.md WORKLOG.md TIMELINE.md LESSONS.md
# Переменные: -v stages="0 1"  -v tags="0 1"  -v hasgit=0|1  -v hascfg=0|1  -v snapdate="..."
# Выход: LEVEL<TAB>CODE<TAB>сообщение   (LEVEL: ERR | WARN | INFO)

function trim(s) { gsub(/^[ \t]+/, "", s); gsub(/[ \t]+$/, "", s); return s }
function say(lvl, code, msg) { printf "%s\t%s\t%s\n", lvl, code, msg }

function numtok(line,   n) {                     # первый номер вида 1 / 1.2 / 1.2.3 с точкой на конце
  if (match(line, /[0-9]+(\.[0-9]+)*\./)) {
    n = substr(line, RSTART, RLENGTH)
    sub(/\.$/, "", n)
    return n
  }
  return ""
}

function closetask(   k) {                       # финализация предыдущей задачи: решение принимается в END,
  if (curtask == "") return                      # когда известен статус этапа из TIMELINE
  k = curstagekey "/" curtask
  tOsn[k] = curOsn; tPro[k] = curPro
  curtask = ""; curOsn = 0; curPro = 0
}

BEGIN {
  FS = "\n"
  split(stages, sa, " "); for (i in sa) if (sa[i] != "") stagefile[sa[i]] = 1
  split(tags,   ta, " "); for (i in ta) if (ta[i] != "") stagetag[ta[i]] = 1
  okdisc["ожидает решения"] = 1; okdisc["ожидает реализации"] = 1
  okdisc["исправлено"] = 1; okdisc["учтено"] = 1; okdisc["вне объёма"] = 1
  oktl["не начат"] = 1; oktl["в работе"] = 1; oktl["завершён"] = 1
  oktl["заблокирован"] = 1; oktl["отменён"] = 1
  wlmax = 22; lesrules = 20; leslines = 120
}

{ fn = FILENAME; sub(/.*\//, "", fn) }

# ─────────────────────────── PLAN.md ───────────────────────────
fn == "PLAN.md" {
  PLANF = "PLAN.md"
  if (FNR <= 12 && index($0, "снимок") > 0) { snaphdr = $0; snapline = FNR }

  if ($0 ~ /^## /) {
    closetask()
    if (index($0, "## Этап ") == 1) {
      sid = numtok(substr($0, 3))
      if (sid == "" && match($0, /[0-9]+/)) sid = substr($0, RSTART, RLENGTH)
      curstage = sid
      if (sid != "") {
        planstage[sid] = 1; stageline[sid] = FNR; nplan++
        if (index($0, "закрыт") > 0) archived[sid] = 1     # состав перенесён в stages/ — задачи и DoD живут там
      }
      section = "stage"
    } else {
      curstage = ""
      section = "other"
      if (index($0, "Расхождения") > 0) section = "disc"
      if (index($0, "Открытые вопросы") > 0) section = "quest"
    }
    next
  }

  if (index($0, "DoD этапа") > 0 && curstage != "") { hasdod[curstage] = 1; next }

  if ($0 ~ /^- \[[ x~!]\]/) {
    closetask()
    st = substr($0, 4, 1)
    n = ""
    if (match($0, /\*\*[0-9]+(\.[0-9]+)*\./)) {
      n = substr($0, RSTART + 2, RLENGTH - 2); sub(/\.$/, "", n)
    }
    key = (curstage == "" ? "?" : curstage) "/" n
    if (n == "") {
      unnumbered++
    } else {
      if (seenkey[key]++) say("WARN", "T-DUP", "номер задачи " n " встречается в этапе " curstage " дважды (PLAN.md:" FNR ")")
      tstatus[key] = st; tnum[key] = n; tline[key] = FNR; tstage[key] = curstage; ntasks++
    }
    total[curstage]++
    if (st == "x") done[curstage]++
    if (st == "~") { inprog++; inproglist = inproglist " " (n == "" ? "?" : n) }
    curtask = (n == "" ? "" : n); curtaskline = FNR; curstatus = st; curstagekey = (curstage == "" ? "?" : curstage)
    curOsn = 0; curPro = 0
    if (index($0, "снован") > 0 || index($0, "§") > 0 || index($0, "вне ТЗ") > 0) curOsn = 1
    if (index($0, "роверка") > 0) curPro = 1
    next
  }

  if (curtask != "" && $0 ~ /^[ \t]/) {
    if (index($0, "Основание") > 0) curOsn = 1
    if (index($0, "Проверка")  > 0) curPro = 1
    if (index($0, "вне ТЗ")    > 0) curOsn = 1
    next
  }

  if (section == "disc" && $0 ~ /^\|/ && $0 !~ /^\|[- :|]+\|$/) {
    ncol = split($0, c, "|")
    if (ncol >= 3 && trim(c[2]) ~ /^[0-9]+$/) {
      stat = trim(c[ncol - 1]); found = 0
      for (k in okdisc) if (index(stat, k) > 0) found = 1
      if (!found) say("WARN", "D-STAT", "расхождение #" trim(c[2]) ": статус «" substr(stat, 1, 40) "» вне набора (ожидает решения / ожидает реализации / исправлено / учтено / вне объёма)")
    }
  }
  next
}

# ────────────────────────── WORKLOG.md ─────────────────────────
fn == "WORKLOG.md" {
  if (index($0, "<!--") > 0) incomment = 1
  if (incomment) { if (index($0, "-->") > 0) incomment = 0; next }

  # упоминания номеров задач — токеном, чтобы не ловить §17.1 (до обработки заголовков: номер часто в заголовке)
  for (key in tstatus) {
    if (tstatus[key] != "x" || wlseen[key]) continue
    n = tnum[key]
    pos = index($0, n)
    if (pos > 0) {
      prev = (pos == 1 ? " " : substr($0, pos - 1, 1))
      nxt  = substr($0, pos + length(n), 1)
      if (prev ~ /[ *`(\[«"]/ && (nxt == "" || nxt ~ /[.,: )»]/)) wlseen[key] = 1
    }
  }

  if (index($0, "## [") == 1) {
    if (entryname != "" && entrylen > wlmax)
      say("WARN", "W-LEN", "запись WORKLOG «" substr(entryname, 1, 45) "» — " entrylen " строк при бюджете ~20")
    entryname = substr($0, 4); entrylen = 0; nwl++
    next
  }
  if ($0 ~ /^---+$/) {
    if (entryname != "" && entrylen > wlmax)
      say("WARN", "W-LEN", "запись WORKLOG «" substr(entryname, 1, 45) "» — " entrylen " строк при бюджете ~20")
    entryname = ""; entrylen = 0
    next
  }
  if (entryname != "" && trim($0) != "") entrylen++

  next
}

# ───────────────────────── TIMELINE.md ─────────────────────────
fn == "TIMELINE.md" {
  if ($0 ~ /^\|/ && $0 !~ /^\|[- :|]+\|$/) {
    ncol = split($0, c, "|")
    if (ncol >= 3) {
      cell = trim(c[2]); sid = numtok(cell)
      if (sid == "" && cell ~ /^[0-9]+$/) sid = cell
      if (sid != "") {
        tlstage[sid] = trim(c[3]); ntl++
        if (!((trim(c[3])) in oktl))
          say("WARN", "L-STAT", "этап " sid " в TIMELINE: статус «" trim(c[3]) "» вне набора (не начат / в работе / завершён / заблокирован / отменён)")
      }
    }
  }
  next
}

# ────────────────────────── LESSONS.md ─────────────────────────
fn == "LESSONS.md" {
  if (index($0, "**Правило:**") > 0) nrules++
  leslinecount = FNR
  next
}

# ─────────────────────────── итоги ─────────────────────────────
END {
  closetask()
  if (entryname != "" && entrylen > wlmax)
    say("WARN", "W-LEN", "запись WORKLOG «" substr(entryname, 1, 45) "» — " entrylen " строк при бюджете ~20")

  if (unnumbered > 0)
    say("WARN", "T-NUM", unnumbered " задач без номера — сверка с WORKLOG и архивация этапа по ним невозможны, пронумеруй по шаблону «**1.2. Название**»")

  for (key in tstatus) if (tstatus[key] == "x" && !wlseen[key])
    say("WARN", "T-LOG", "задача " tnum[key] " помечена [x], но её номер не встречается в WORKLOG.md — работа без записи считается непроверенной")

  for (key in tOsn) {
    sid = key; sub(/\/.*/, "", sid); n = key; sub(/^[^\/]*\//, "", n)
    near = (tlstage[sid] == "в работе" || tlstage[sid] == "завершён" || tstatus[key] == "x" || tstatus[key] == "~")
    if (!near) continue
    if (!tOsn[key]) say("WARN", "T-OSN", "задача " n " (PLAN.md:" tline[key] ") без основания в доке — укажи раздел или «вне ТЗ: причина»")
    if (!tPro[key] && tstatus[key] != "!") say("WARN", "T-PRO", "задача " n " (PLAN.md:" tline[key] ") без строки «Проверка» — нечем будет подтвердить закрытие")
  }

  for (sid in planstage) {
    if (!hasdod[sid] && !archived[sid]) {
      lvl = (tlstage[sid] == "в работе" || tlstage[sid] == "завершён") ? "ERR" : "WARN"
      say(lvl, "S-DOD", "этап " sid " (PLAN.md:" stageline[sid] ") без строки «DoD этапа» — закрыть его будет нечем")
    }
    if (!(sid in tlstage)) say("ERR", "S-TL", "этап " sid " есть в PLAN.md, но отсутствует в TIMELINE.md")
    if (total[sid] > 0 && !archived[sid] && done[sid] == total[sid] && tlstage[sid] != "завершён" && tlstage[sid] != "отменён")
      say("WARN", "S-RITE", "этап " sid ": все " total[sid] " задач [x], но в TIMELINE «" tlstage[sid] "» — не выполнен ритуал закрытия")
  }
  for (sid in tlstage) {
    if (!(sid in planstage)) say("ERR", "S-PLAN", "этап " sid " есть в TIMELINE.md, но отсутствует в PLAN.md")
    if (tlstage[sid] == "завершён") {
      if (!(sid in stagefile)) say("ERR", "S-SUM", "этап " sid " завершён, но нет docs/sdd-power/stages/" sid "-*.md")
      if (hasgit && !(sid in stagetag)) say("WARN", "S-TAG", "этап " sid " завершён, но нет git-тега stage/" sid)
    }
  }

  if (inprog > 3) say("WARN", "T-WIP", inprog " задач в статусе [~]:" inproglist " — разбери незакрытые прежде, чем брать новые")

  if (nrules > lesrules)  say("WARN", "E-BUD", "LESSONS.md: " nrules " правил при бюджете 20 — консолидируй прежде, чем добавлять")
  if (leslinecount > leslines) say("WARN", "E-LEN", "LESSONS.md: " leslinecount " строк при бюджете ~120")

  if (snaphdr == "") say("WARN", "P-SNAP", "в шапке PLAN.md нет строки о снимке документации (дата/версия)")
  else if (hascfg && snapdate != "" && index(snaphdr, snapdate) == 0)
    say("WARN", "P-SNAP2", "дата снимка в config.yml (" snapdate ") не встречается в шапке PLAN.md:" snapline " — один из них устарел")

  say("INFO", "SUM", "этапов: " nplan ", задач: " (ntasks + unnumbered + 0) ", записей WORKLOG: " nwl ", правил LESSONS: " (nrules + 0))
}
