# next.awk — где остановились и что следующее.
# Вход (в этом порядке): PLAN.md TIMELINE.md

function base(p,   a, n) { n = split(p, a, "/"); return a[n] }

FNR == 1 { F = base(FILENAME) }

F == "PLAN.md" {
  P[++pn] = $0
  if ($0 ~ /^## Этап [0-9]+\./) {
    id = $0; sub(/^## Этап /, "", id); sub(/\..*/, "", id)
    if (cur != "") fin[cur] = pn - 1
    ns++; sid[ns] = id; head[id] = $0; start[id] = pn; cur = id
    next
  }
  if ($0 ~ /^## / || $0 ~ /^---/) { if (cur != "") { fin[cur] = pn - 1; cur = "" } next }
  next
}

F == "TIMELINE.md" {
  if ($0 ~ /^\|[[:space:]]*[0-9]+\./) {
    split($0, c, "|")
    idc = c[2]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", idc)
    id = idc; sub(/\..*/, "", id)
    stt = c[3]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", stt)
    tl[id] = stt
  }
  next
}

END {
  if (cur != "") fin[cur] = pn
  if (ns == 0) { print "В PLAN.md нет этапов — план ещё не заполнен."; exit }

  # подсчёт задач по этапам
  for (i = 1; i <= ns; i++) {
    id = sid[i]
    for (n = start[id]; n <= fin[id]; n++) {
      if (P[n] ~ /^- \[.\]/) {
        total[id]++
        if (substr(P[n], 4, 1) == "x") done[id]++
        else if (!(id in firstopen)) firstopen[id] = n
      }
    }
  }

  # текущий этап: «в работе» по TIMELINE, иначе первый с незакрытыми задачами
  for (i = 1; i <= ns && chosen == ""; i++) if (tl[sid[i]] == "в работе") chosen = sid[i]
  for (i = 1; i <= ns && chosen == ""; i++) if (sid[i] in firstopen) chosen = sid[i]
  if (chosen == "") chosen = sid[ns]

  st = (chosen in tl) ? tl[chosen] : "нет строки в TIMELINE"
  print head[chosen] "   [" st "]"
  printf "Прогресс: %d из %d задач закрыто\n", done[chosen] + 0, total[chosen] + 0

  for (n = start[chosen]; n <= fin[chosen]; n++)
    if (P[n] ~ /^\*\*DoD этапа:\*\*/) { print P[n]; break }

  print ""
  if (chosen in firstopen) {
    print "Следующая задача:"
    n = firstopen[chosen]
    print P[n]
    for (m = n + 1; m <= fin[chosen] && P[m] !~ /^- \[.\]/; m++)
      if (P[m] ~ /[^[:space:]]/) print P[m]
  } else {
    print "Все задачи этапа " chosen " закрыты → ритуал закрытия этапа:"
    print "  DoD целиком → верификация (полнота/корректность/когерентность) → sdd.sh stage " chosen " <slug>"
    print "  → sdd.sh archive-tasks " chosen " → git-тег stage/" chosen " → TIMELINE.md → LESSONS.md → sdd.sh validate"
  }
}
