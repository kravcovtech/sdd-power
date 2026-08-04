# archive.awk — перенос состава закрытого этапа из PLAN.md в stages/<ID>-<имя>.md.
# Вход: PLAN.md
# -v id=<ID> -v mode=extract|strip -v ref=stages/<файл>
#   extract — печатает раздел этапа целиком (для вклейки в саммари)
#   strip   — печатает PLAN.md, где раздел заменён заглушкой со ссылкой

function numtok(line,   n) {
  if (match(line, /[0-9]+(\.[0-9]+)*\./)) { n = substr(line, RSTART, RLENGTH); sub(/\.$/, "", n); return n }
  return ""
}

BEGIN { inside = 0; found = 0 }

{
  if (index($0, "## Этап ") == 1) {
    if (numtok(substr($0, 3)) == id) {
      inside = 1; found = 1
      if (mode == "extract") print $0
      else {
        head = $0
        sub(/[ \t]*$/, "", head)
        print head " — закрыт"
        print ""
        print "<!-- Состав этапа перенесён в " ref " — задачи и их номера сохранены там дословно."
        print "     PLAN.md отвечает на вопрос «что предстоит»; закрытый этап отвечает на «что было». -->"
        print "Состав, DoD и результат: [" ref "](" ref ")"
        print ""
      }
      next
    }
    if (inside) inside = 0
  }
  if (inside) { if (mode == "extract") print $0; next }
  if (mode == "strip") print $0
}

END {
  if (!found) { print "ARCHIVE-ERROR: этап " id " не найден в PLAN.md" > "/dev/stderr"; exit 3 }
}
