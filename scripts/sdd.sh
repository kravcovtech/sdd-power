#!/usr/bin/env bash
# sdd-power — инфраструктура и валидатор трекинга разработки.
#
# Команды:
#   init [--name NAME] [--root DIR] [--gitignore]   развернуть/подобрать трекинг, поставить якорь
#   check [--root DIR]                              инфраструктура + дрейф доки + ошибки трекинга
#   next [--root DIR]                               текущий этап, DoD, прогресс, следующая задача
#   validate [--root DIR]                           полный разбор содержания файлов трекинга
#   snapshot --docs "f1 f2 ..." [--root DIR]        зафиксировать снимок документации
#   stage <ID> <slug> [--root DIR]                  заготовка саммари этапа из шаблона
#   archive-tasks <ID> [--root DIR]                 перенести состав этапа из PLAN в саммари
#
# Код возврата 0 при успешном разборе аргументов; вердикт — в тексте вывода.
# Ненулевой код означает только сбой самого скрипта (нет аргумента, нет файла, нет шаблонов).

set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(dirname -- "$SCRIPT_DIR")
ASSETS="$SKILL_DIR/assets"

CMD=${1:-help}
[ $# -gt 0 ] && shift

ROOT=""
NAME=""
DOCS_ARG=""
GITIGNORE=0
POS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT=${2:-}; shift 2 ;;
    --name) NAME=${2:-}; shift 2 ;;
    --docs) DOCS_ARG=${2:-}; shift 2 ;;
    --gitignore) GITIGNORE=1; shift ;;
    -h|--help) CMD=help; shift ;;
    *) POS+=("$1"); shift ;;
  esac
done

if [ -z "$ROOT" ]; then
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || ROOT=""
  [ -n "$ROOT" ] || ROOT=$PWD
fi

SDD="$ROOT/docs/sdd-power"
PLAN="$SDD/PLAN.md"
WORKLOG="$SDD/WORKLOG.md"
TIMELINE="$SDD/TIMELINE.md"
LESSONS="$SDD/LESSONS.md"
STAGES="$SDD/stages"
CONFIG="$SDD/config.yml"
LOCK="$SDD/docs.lock"

TRACK_FILES="PLAN.md WORKLOG.md TIMELINE.md LESSONS.md"
ANCHOR_OPEN="<!-- sdd-power -->"
ANCHOR_CLOSE="<!-- /sdd-power -->"

# die — сбой вызова (нет аргумента, нет шаблона): stderr, код 2.
# refuse — штатный отказ по состоянию проекта: stdout, код 0, с подсказкой следующего шага.
die()    { printf '%s\n' "$*" >&2; exit 2; }
refuse() { printf '%s\n' "$*"; exit 0; }

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else echo "no-sha256"; fi
}

today() { date +%Y-%m-%d; }
now()   { date "+%Y-%m-%d %H:%M"; }

# --- поиск файлов трекинга от прежних версий скилла --------------------------
legacy_dirs() { printf '%s\n' "$ROOT" "$ROOT/docs" "$ROOT/.sdd" "$ROOT/sdd-power"; }

find_legacy() { # $1 = имя файла; печатает первый найденный путь вне docs/sdd-power
  local f=$1 d
  while read -r d; do
    [ -f "$d/$f" ] && [ "$d/$f" != "$SDD/$f" ] && { printf '%s\n' "$d/$f"; return 0; }
  done < <(legacy_dirs)
  return 1
}

anchor_block() {
  cat <<EOF
$ANCHOR_OPEN
## Трекинг разработки (sdd-power)

Состояние проекта живёт в \`docs/sdd-power/\`:
PLAN.md — что предстоит · WORKLOG.md — что и почему сделано · TIMELINE.md — где мы в целом ·
LESSONS.md — на чём уже обжигались · stages/ — саммари закрытых этапов.

В начале сессии активируй скилл **sdd-power**, прочитай эти файлы и обновляй их синхронно с кодом.
$ANCHOR_CLOSE
EOF
}

put_anchor() { # $1 = путь к CLAUDE.md / AGENTS.md
  local f=$1
  if [ -f "$f" ] && grep -qF "$ANCHOR_OPEN" "$f"; then
    echo "  якорь уже есть: ${f#$ROOT/}"
    return
  fi
  [ -f "$f" ] && printf '\n' >> "$f"
  anchor_block >> "$f"
  echo "  якорь добавлен: ${f#$ROOT/}"
}

# ============================================================ init
cmd_init() {
  [ -d "$ASSETS" ] || die "не найден каталог шаблонов: $ASSETS"
  echo "Корень проекта: $ROOT"
  mkdir -p "$STAGES" || die "не удалось создать $STAGES"
  [ -f "$STAGES/.gitkeep" ] || touch "$STAGES/.gitkeep"

  local f src tpl
  for f in $TRACK_FILES; do
    if [ -f "$SDD/$f" ]; then
      echo "  на месте: docs/sdd-power/$f (не тронут)"
      continue
    fi
    if src=$(find_legacy "$f"); then
      mv "$src" "$SDD/$f"
      echo "  подобран из ${src#$ROOT/} → docs/sdd-power/$f  [след старой версии скилла: отметь миграцию в WORKLOG]"
      continue
    fi
    tpl="$ASSETS/${f%.md}.template.md"
    [ -f "$tpl" ] || die "нет шаблона $tpl"
    if [ -n "$NAME" ]; then
      sed "s/<название проекта>/${NAME//\//\\/}/g" "$tpl" > "$SDD/$f"
    else
      cp "$tpl" "$SDD/$f"
    fi
    echo "  создан из шаблона: docs/sdd-power/$f"
  done

  put_anchor "$ROOT/CLAUDE.md"
  [ -f "$ROOT/AGENTS.md" ] && put_anchor "$ROOT/AGENTS.md"

  if [ "$GITIGNORE" = 1 ]; then
    if [ -f "$ROOT/.gitignore" ] && grep -qE '^docs/sdd-power/?$' "$ROOT/.gitignore"; then
      echo "  .gitignore: запись уже есть"
    else
      printf 'docs/sdd-power/\n' >> "$ROOT/.gitignore"
      echo "  .gitignore: добавлено docs/sdd-power/ — файлы не переживут клон и не видны команде"
    fi
  fi

  echo
  echo "Содержимое docs/sdd-power:"
  (cd "$SDD" && find . -mindepth 1 -maxdepth 2 -not -name '.gitkeep' | sed 's|^\./|  |' | sort)
  echo
  echo "Инфраструктура развёрнута. Дальше: заполнить PLAN.md по документации, затем sdd.sh validate."
}

# ============================================================ общие проверки
infra_report() { # печатает состояние инфраструктуры; ставит INFRA_OK
  INFRA_OK=1
  local f missing=""
  for f in $TRACK_FILES; do
    [ -f "$SDD/$f" ] || { missing="$missing $f"; INFRA_OK=0; }
  done
  [ -d "$STAGES" ] || { missing="$missing stages/"; INFRA_OK=0; }

  if [ "$INFRA_OK" = 1 ]; then
    echo "Инфраструктура: на месте (4 файла трекинга + stages/ в docs/sdd-power/)"
  else
    echo "Инфраструктура: НЕПОЛНАЯ — отсутствует:$missing → запусти: sdd.sh init"
  fi

  if [ -f "$ROOT/CLAUDE.md" ] && grep -qF "$ANCHOR_OPEN" "$ROOT/CLAUDE.md"; then
    echo "Якорь в CLAUDE.md: на месте"
  else
    echo "Якорь в CLAUDE.md: ПОТЕРЯН — проект перестанет подхватываться → sdd.sh init"
    INFRA_OK=0
  fi
  if [ -f "$ROOT/AGENTS.md" ] && ! grep -qF "$ANCHOR_OPEN" "$ROOT/AGENTS.md"; then
    echo "Якорь в AGENTS.md: отсутствует (файл есть) → sdd.sh init"
  fi

  local leg
  for f in $TRACK_FILES; do
    if leg=$(find_legacy "$f"); then
      echo "Файл вне docs/sdd-power: ${leg#$ROOT/} — след старой версии скилла, перенеси через init и отметь миграцию в WORKLOG"
    fi
  done
}

docs_drift() {
  if [ ! -f "$LOCK" ]; then
    echo "Снимок документации: не зафиксирован → sdd.sh snapshot --docs \"<файлы доки>\""
    return
  fi
  local changed=0 missing=0 h p cur
  while IFS=$'\t' read -r h p; do
    [ -n "${p:-}" ] || continue
    if [ ! -f "$ROOT/$p" ]; then
      echo "Документация: файл пропал — $p"
      missing=$((missing+1)); continue
    fi
    cur=$(hash_file "$ROOT/$p")
    if [ "$cur" != "$h" ]; then
      echo "Документация ИЗМЕНИЛАСЬ с момента снимка: $p"
      changed=$((changed+1))
    fi
  done < "$LOCK"
  if [ $changed -eq 0 ] && [ $missing -eq 0 ]; then
    echo "Документация: совпадает со снимком ($(grep -c . "$LOCK") файл(ов))"
  else
    echo "→ сравни изменившиеся разделы с планом, обнови задачи, запиши ре-синхронизацию в WORKLOG, затем sdd.sh snapshot"
  fi
}

# ============================================================ validate
run_validate() { # печатает находки; ставит N_ERR / N_WARN
  local f
  for f in $TRACK_FILES; do
    [ -f "$SDD/$f" ] || { echo "ОШИБКА: нет файла docs/sdd-power/$f — запусти sdd.sh init"; N_ERR=1; N_WARN=0; return; }
  done

  local stagefiles=""
  [ -d "$STAGES" ] && stagefiles=$(cd "$STAGES" && ls -1 *.md 2>/dev/null | tr '\n' ' ')

  local out
  out=$(awk -v stagefiles="$stagefiles" -f "$SCRIPT_DIR/validate.awk" \
        "$PLAN" "$TIMELINE" "$WORKLOG" "$LESSONS")

  # дата снимка: шапка PLAN.md против config.yml
  local pdate cdate
  pdate=$(grep -m1 -oE 'снимок от [^ ]+' "$PLAN" | sed 's/снимок от //')
  cdate=$([ -f "$CONFIG" ] && grep -m1 -E '^snapshot_date:' "$CONFIG" | sed 's/^snapshot_date:[[:space:]]*//')
  if [ -n "${pdate:-}" ] && [ -n "${cdate:-}" ] && [ "$pdate" != "$cdate" ] && [ "${pdate#<}" = "$pdate" ]; then
    out="${out}"$'\n'"ПРЕДУПРЕЖДЕНИЕ: дата снимка в шапке PLAN.md ($pdate) не совпадает с config.yml ($cdate)"
  fi

  out=$(printf '%s\n' "$out" | grep -v '^$')
  N_ERR=$(printf '%s\n' "$out" | grep -c '^ОШИБКА')
  N_WARN=$(printf '%s\n' "$out" | grep -c '^ПРЕДУПРЕЖДЕНИЕ')
  [ -n "$out" ] && printf '%s\n' "$out"
  return 0
}

verdict() {
  if [ "${N_ERR:-0}" -eq 0 ] && [ "${N_WARN:-0}" -eq 0 ]; then
    echo "ВЕРДИКТ: трекинг без ошибок и предупреждений."
  else
    echo "ВЕРДИКТ: ошибок — ${N_ERR:-0}, предупреждений — ${N_WARN:-0}."
    if [ "${N_ERR:-0}" -gt 0 ]; then
      echo "Ошибки чини до кода. Предупреждения разбери и либо исправь, либо заведи задачу."
    fi
  fi
}

cmd_validate() {
  echo "== Валидация трекинга: $SDD"
  run_validate
  verdict
}

cmd_check() {
  echo "== Проверка сессии: $ROOT"
  infra_report
  echo
  docs_drift
  echo
  if [ "${INFRA_OK:-0}" = 1 ]; then
    run_validate
    verdict
  else
    echo "Содержание не проверялось: сначала почини инфраструктуру."
  fi
}

# ============================================================ next
cmd_next() {
  [ -f "$PLAN" ] || refuse "Нет docs/sdd-power/PLAN.md — запусти: sdd.sh init"
  echo "== Где остановились: $ROOT"
  awk -f "$SCRIPT_DIR/next.awk" "$PLAN" "$TIMELINE"
  echo
  echo "Заготовка записи WORKLOG (новые записи — СВЕРХУ, под шапкой файла):"
  cat <<EOF

## [$(now)] — <краткий заголовок шага>

- **Что сделано:**
- **Коммит:** \`<короткий SHA>\`
- **Проверено:**
- **Решения и причины:**
- **Отклонения от плана или документации:** нет
- **Закрыто в PLAN.md:** нет
- **Урок для LESSONS.md:** нет
EOF
}

# ============================================================ snapshot
cmd_snapshot() {
  [ -d "$SDD" ] || refuse "Нет docs/sdd-power/ — запусти: sdd.sh init"
  [ -n "$DOCS_ARG" ] || die "нужен список файлов документации: sdd.sh snapshot --docs \"docs/ТЗ.md docs/api.md\""
  local p abs n=0
  : > "$LOCK"
  for p in $DOCS_ARG; do
    for abs in "$ROOT"/$p; do
      [ -f "$abs" ] || { echo "  пропущен (не файл): $p"; continue; }
      printf '%s\t%s\n' "$(hash_file "$abs")" "${abs#$ROOT/}" >> "$LOCK"
      echo "  зафиксирован: ${abs#$ROOT/}"
      n=$((n+1))
    done
  done
  [ "$n" -gt 0 ] || die "ни одного файла документации не найдено по: $DOCS_ARG"
  {
    echo "# снимок документации sdd-power"
    [ -n "$NAME" ] && echo "project: $NAME"
    echo "snapshot_date: $(today)"
    echo "docs:"
    awk -F'\t' '{print "  - " $2}' "$LOCK"
  } > "$CONFIG"
  echo
  echo "Снимок: $n файл(ов), дата $(today) → docs/sdd-power/config.yml + docs.lock"
  echo "Поставь ту же дату в шапке PLAN.md («снимок от $(today)») — иначе validate сообщит о расхождении."
}

# ============================================================ stage
cmd_stage() {
  local id=${POS[0]:-} slug=${POS[1]:-}
  [ -n "$id" ] && [ -n "$slug" ] || die "нужно: sdd.sh stage <ID> <slug>"
  [ -f "$ASSETS/STAGE.template.md" ] || die "нет шаблона $ASSETS/STAGE.template.md"
  mkdir -p "$STAGES"
  local out="$STAGES/$id-$slug.md"
  [ -f "$out" ] && refuse "Уже существует: ${out#$ROOT/} — заполняй его, а не пересоздавай."
  local title
  title=$(grep -m1 -E "^## Этап $id\." "$PLAN" 2>/dev/null | sed -E "s/^## Этап $id\.[[:space:]]*//")
  [ -n "${title:-}" ] || title="<название>"
  sed -e "s/<ID>/$id/g" -e "s/<название>/${title//\//\\/}/" -e "s/<ГГГГ-ММ-ДД>/$(today)/" \
      "$ASSETS/STAGE.template.md" > "$out"
  echo "Создан ${out#$ROOT/} — заполни разделы: что сделано, ключевые решения, отклонения, как проверить, важно знать дальше."
  echo "Затем: sdd.sh archive-tasks $id"
}

# ============================================================ archive-tasks
cmd_archive() {
  local id=${POS[0]:-}
  [ -n "$id" ] || die "нужно: sdd.sh archive-tasks <ID>"
  [ -f "$PLAN" ] || die "нет $PLAN"
  local sum
  sum=$(ls -1 "$STAGES/$id"-*.md 2>/dev/null | head -1)
  [ -n "${sum:-}" ] || refuse "Нет саммари для этапа $id — сначала: sdd.sh stage $id <slug>"
  if grep -qF "## Состав этапа" "$sum"; then
    echo "Состав этапа $id уже перенесён в ${sum#$ROOT/} — команда отрабатывает один раз, PLAN.md не тронут."
    exit 0
  fi
  grep -qE "^## Этап $id\." "$PLAN" || refuse "В PLAN.md нет этапа $id — проверь номер."

  local open
  open=$(awk -v id="$id" '
    $0 ~ "^## Этап " id "\\." {inb=1; next}
    inb && /^## / {inb=0}
    inb && /^- \[[^x]\]/ {n++}
    END{print n+0}' "$PLAN")
  [ "$open" -gt 0 ] && echo "ПРЕДУПРЕЖДЕНИЕ: в этапе $id осталось незакрытых задач: $open — закрытого этапа с открытыми задачами не бывает."

  cp "$PLAN" "$PLAN.bak"
  awk -v id="$id" -v sum="${sum#$ROOT/}" -v body="$SDD/.archive.tmp" '
    BEGIN{inb=0}
    $0 ~ "^## Этап " id "\\." {
      print; print "<!-- закрыт: см. " sum ", тег stage/" id " -->"; print "";
      inb=1; next
    }
    inb && (/^## / || /^---[-]*$/) {inb=0}
    inb { print > body; next }
    {print}
  ' "$PLAN" > "$PLAN.new" || die "не удалось разобрать PLAN.md"

  {
    echo
    echo "## Состав этапа"
    echo
    echo "Архив задач этапа из PLAN.md — номера сохранены дословно, на них ссылаются WORKLOG и LESSONS."
    echo
    sed '/^[[:space:]]*$/{N;/^\n[[:space:]]*$/D}' "$SDD/.archive.tmp"
  } >> "$sum"

  mv "$PLAN.new" "$PLAN"
  rm -f "$SDD/.archive.tmp"
  echo "Состав этапа $id перенесён в ${sum#$ROOT/}; в PLAN.md остался заголовок со ссылкой."
  echo "Резервная копия: docs/sdd-power/PLAN.md.bak"
  echo "Дальше: git-тег stage/$id, статус в TIMELINE.md, затем sdd.sh validate."
}

# ============================================================ help
cmd_help() {
  sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

case "$CMD" in
  init) cmd_init ;;
  check) cmd_check ;;
  next) cmd_next ;;
  validate) cmd_validate ;;
  snapshot) cmd_snapshot ;;
  stage) cmd_stage ;;
  archive-tasks) cmd_archive ;;
  help|--help|-h) cmd_help ;;
  *) echo "неизвестная команда: $CMD"; cmd_help; exit 2 ;;
esac

exit 0
