# next.awk — «где мы и что дальше» из PLAN.md.
# Вход (в этом порядке): TIMELINE.md PLAN.md
# Выход: человекочитаемый текст.

function trim(s) { gsub(/^[ \t]+/, "", s); gsub(/[ \t]+$/, "", s); return s }
function numtok(line,   n) {
  if (match(line, /[0-9]+(\.[0-9]+)*\./)) { n = substr(line, RSTART, RLENGTH); sub(/\.$/, "", n); return n }
  return ""
}

{ fn = FILENAME; sub(/.*\//, "", fn) }

fn == "TIMELINE.md" {
  if ($0 ~ /^\|/ && $0 !~ /^\|[- :|]+\|$/) {
    ncol = split($0, c, "|")
    if (ncol >= 3) { sid = numtok(trim(c[2])); if (sid != "") tl[sid] = trim(c[3]) }
  }
  if (index($0, "**Текущее положение:**") == 1) pos = $0
  if (index($0, "**Следующий шаг:**") == 1) nxt = $0
  next
}

fn == "PLAN.md" {
  L[++nl] = $0
  if (index($0, "## Этап ") == 1) {
    sid = numtok(substr($0, 3)); cur = sid
    if (sid != "") { ord[++ns] = sid; title[sid] = $0; sline[sid] = nl }
    next
  }
  if (index($0, "DoD этапа") > 0 && cur != "") { dod[cur] = $0; next }
  if ($0 ~ /^- \[[ x~!]\]/ && cur != "") {
    st = substr($0, 4, 1)
    total[cur]++
    if (st == "x") { donec[cur]++; next }
    if (st == "!") { blocked[cur]++; if (blist[cur] == "") blist[cur] = numtok($0) ; next }
    if (st == "~" && wip[cur] == 0) { wip[cur] = nl }
    if (st == " " && todo[cur] == 0) { todo[cur] = nl }
    next
  }
}

END {
  for (i = 1; i <= ns; i++) {
    s = ord[i]
    if (tl[s] == "завершён" || tl[s] == "отменён") continue
    if (total[s] > 0 && donec[s] == total[s]) {
      print "Этап " s " — все " total[s] " задач закрыты, но этап не закрыт в TIMELINE."
      print "Дальше: ритуал закрытия — DoD целиком, `sdd.sh stage " s " <имя>`, тег stage/" s ", статус в TIMELINE."
      exit
    }
    if (wip[s] || todo[s] || blocked[s]) { target = s; break }
  }
  if (target == "") { print "Незакрытых задач в плане нет. Проверь TIMELINE и «Вне объёма»."; exit }

  gsub(/^## /, "", title[target])
  print title[target] "   [" (tl[target] == "" ? "нет в TIMELINE" : tl[target]) "]"
  printf "Прогресс: %d из %d задач закрыто", donec[target] + 0, total[target] + 0
  if (blocked[target]) printf ", заблокировано %d", blocked[target]
  print ""
  if (dod[target] != "") { d = dod[target]; gsub(/\*\*/, "", d); print d }
  print ""

  start = (wip[target] ? wip[target] : todo[target])
  if (start == 0) { print "Свободных задач нет: все оставшиеся заблокированы (" blist[target] "…). Разбери блокировку или возьми задачу другого этапа."; exit }
  print (wip[target] ? "Незакрытая задача из прошлой сессии (проверь код, а не статус):" : "Следующая задача:")
  for (j = start; j <= nl; j++) {
    if (j > start && (L[j] ~ /^- \[[ x~!]\]/ || L[j] ~ /^## / || L[j] ~ /^---/)) break
    if (L[j] != "" || j == start) print "  " L[j]
  }
}
