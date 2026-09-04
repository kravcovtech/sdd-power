# Валидатор трекинга sdd-power.
# Вход (строго в этом порядке): PLAN.md TIMELINE.md WORKLOG.md LESSONS.md
# Переменная stagefiles — список файлов docs/sdd-power/stages через пробел.
# Выход: строки «ОШИБКА: ...» и «ПРЕДУПРЕЖДЕНИЕ: ...».

function base(p,   a, n) { n = split(p, a, "/"); return a[n] }
function ph(s)           { return (s == "" || s ~ /^<.*>$/) }
# substr в mawk режет байты и ломает UTF-8 — обрезаем по словам.
function short(s, n,   a, m, i, r) {
  m = split(s, a, /[[:space:]]+/)
  if (m <= n) return s
  r = a[1]
  for (i = 2; i <= n; i++) r = r " " a[i]
  return r "…"
}
function say(strict, msg) {
  if (strict) print "ОШИБКА: " msg; else print "ПРЕДУПРЕЖДЕНИЕ: " msg
}

BEGIN { LC_ALL = "C" }

FNR == 1 { F = base(FILENAME) }

# ---------------------------------------------------------------- PLAN.md
F == "PLAN.md" {
  if ($0 ~ /^## Этап [0-9]+\./) {
    id = $0; sub(/^## Этап /, "", id); sub(/\..*/, "", id)
    nm = $0; sub(/^## Этап [0-9]+\.[[:space:]]*/, "", nm)
    ns++; sid[ns] = id; sname[id] = nm; cur = id; lastt = 0
    next
  }
  if (cur != "" && $0 ~ /^<!-- закрыт:/) { closed[cur] = 1; next }
  if ($0 ~ /^## /) { cur = ""; lastt = 0; next }
  if (cur != "" && $0 ~ /^\*\*DoD этапа:\*\*/) {
    v = $0; sub(/^\*\*DoD этапа:\*\*[[:space:]]*/, "", v)
    dod[cur] = ph(v) ? "ph" : "ok"
    next
  }
  if ($0 ~ /^- \[.\]/) {
    st = substr($0, 4, 1)
    t = $0; sub(/^- \[.\][[:space:]]*/, "", t); gsub(/\*\*/, "", t)
    nt++; tstage[nt] = cur; tstatus[nt] = st; tline[nt] = FNR
    if (match(t, /^[0-9]+\.[0-9]+/)) {
      tnum[nt] = substr(t, RSTART, RLENGTH)
      sub(/^[0-9]+\.[0-9]+[[:space:].):]*/, "", t)
    } else tnum[nt] = ""
    ttitle[nt] = t
    if (ph(t)) nph++
    lastt = nt
    next
  }
  if (lastt > 0 && $0 ~ /^[[:space:]]+-[[:space:]]*(\*\*)?Основание/) tosn[lastt] = 1
  if (lastt > 0 && $0 ~ /^[[:space:]]+-[[:space:]]*(\*\*)?Проверка/)  tprov[lastt] = 1
  next
}

# ------------------------------------------------------------ TIMELINE.md
F == "TIMELINE.md" {
  if ($0 ~ /^\|[[:space:]]*[0-9]+\./) {
    split($0, c, "|")
    idc = c[2]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", idc)
    id = idc; sub(/\..*/, "", id)
    stt = c[3]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", stt)
    tl[id] = stt; tlseen[id] = 1
  }
  next
}

# ------------------------------------------------------------- WORKLOG.md
F == "WORKLOG.md" {
  line = $0
  if (line ~ /<!--/) incom = 1
  if (incom) { if (line ~ /-->/) incom = 0; next }

  tmp = line
  while (match(tmp, /[0-9]+\.[0-9]+/)) {
    seen[substr(tmp, RSTART, RLENGTH)] = 1
    tmp = substr(tmp, RSTART + RLENGTH)
  }
  if (line ~ /^## \[/) { wn++; whdr[wn] = line; wlen[wn] = 0; wopen = 1; next }
  if (wopen && line ~ /[^[:space:]]/ && line !~ /^---/) wlen[wn]++
  next
}

# ------------------------------------------------------------- LESSONS.md
F == "LESSONS.md" {
  if ($0 ~ /\*\*Правило:\*\*/) lrules++
  if ($0 ~ /[^[:space:]]/) llines++
  next
}

# ------------------------------------------------------------------- END
END {
  tmpl = (nt > 0 && nph == nt)
  if (nt == 0)
    print "ПРЕДУПРЕЖДЕНИЕ: в PLAN.md нет ни одной задачи — план ещё не заполнен."
  else if (tmpl)
    print "ПРЕДУПРЕЖДЕНИЕ: PLAN.md остался шаблоном (все задачи — заглушки); проверки содержания плана пропущены."

  if (!tmpl) {
    for (i = 1; i <= ns; i++) {
      id = sid[i]
      st = (id in tl) ? tl[id] : ""
      strict = (st == "в работе" || st == "завершён")

      if (!(id in tlseen))
        print "ОШИБКА: этап " id " есть в PLAN.md, но нет строки в TIMELINE.md — положение дел врёт."
      if (!(id in closed) && (!(id in dod) || dod[id] == "ph"))
        say(strict, "этап " id " без DoD — нечем закрывать" (strict ? "" : " (этап ещё не в работе — детализируй при подходе)") ".")
      if (st == "завершён" && stagefiles !~ ("(^| )" id "-"))
        print "ОШИБКА: этап " id " помечен «завершён», но саммари stages/" id "-<имя>.md нет."
      if (st != "" && st !~ /^(не начат|в работе|завершён|заблокирован|отменён)$/)
        print "ПРЕДУПРЕЖДЕНИЕ: этап " id ": статус «" st "» вне разрешённого набора TIMELINE."
    }

    for (k = 1; k <= nt; k++) {
      id = tstage[k]
      st = (id in tl) ? tl[id] : ""
      strict = (st == "в работе" || st == "завершён")
      lbl = "задача «" short(ttitle[k], 6) "» (PLAN.md:" tline[k] ")"

      if (tstatus[k] !~ /^( |~|x|!)$/)
        print "ПРЕДУПРЕЖДЕНИЕ: " lbl ": статус «" tstatus[k] "» вне набора [ ] [~] [x] [!]."
      if (tnum[k] == "")
        print "ОШИБКА: " lbl " без номера вида <этап>.<N> — по номеру валидатор сверяет её с WORKLOG."
      else if (tstatus[k] == "x" && !(tnum[k] in seen))
        print "ПРЕДУПРЕЖДЕНИЕ: задача " tnum[k] " закрыта [x], но её номер не встречается в WORKLOG.md — за галочкой не видно работы."
      if (!(k in tosn)) say(strict, lbl ": нет строки «Основание» — задача не привязана к документации.")
      if (!(k in tprov)) say(strict, lbl ": нет строки «Проверка» — нечем подтвердить закрытие.")
      if (tstatus[k] == "~") inprog++
    }
    if (inprog > 3)
      print "ПРЕДУПРЕЖДЕНИЕ: задач в статусе [~]: " inprog " — больше трёх параллельных «в работе» означает, что что-то брошено."
  }

  for (w = 1; w <= wn; w++)
    if (wlen[w] > 22) {
      h = whdr[w]; sub(/^## /, "", h)
      print "ПРЕДУПРЕЖДЕНИЕ: запись WORKLOG «" short(h, 7) "» — " wlen[w] " строк при бюджете ~20."
    }

  if (lrules > 20)
    print "ПРЕДУПРЕЖДЕНИЕ: в LESSONS.md правил " lrules " при бюджете 20 — консолидируй, потом добавляй."
  if (llines > 130)
    print "ПРЕДУПРЕЖДЕНИЕ: LESSONS.md — " llines " содержательных строк при бюджете ~120."
}
