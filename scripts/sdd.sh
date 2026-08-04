#!/usr/bin/env bash
# sdd-power: инфраструктура трекинга, проверка её целостности и содержания.
# Идемпотентен: существующие файлы никогда не перезаписываются.
#
#   sdd.sh init          [--root DIR] [--name "Проект"] [--gitignore]
#   sdd.sh check         [--root DIR]        инфраструктура + дрейф доки + валидатор (сводка)
#   sdd.sh validate      [--root DIR]        полный разбор файлов трекинга
#   sdd.sh next          [--root DIR]        где остановились и что следующее
#   sdd.sh snapshot      [--root DIR] [--docs "путь ..."]   зафиксировать снимок документации
#   sdd.sh stage <ID> <slug>                 заготовка саммари закрытого этапа
#   sdd.sh archive-tasks <ID>                перенести состав закрытого этапа из PLAN в саммари
#
# Коды возврата: 0 — порядок (предупреждения допустимы), 1 — ошибки, 2 — ошибка вызова.

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS="$SKILL_DIR/assets"
LIB="$SKILL_DIR/scripts/lib"
TRACKED=(PLAN WORKLOG TIMELINE LESSONS)
ANCHOR_MARK="<!-- sdd-power -->"
GITIGNORE=0; NAME=""; ROOT=""; DOCS_ARG=""

die() { printf '✗ %s\n' "$*" >&2; exit 2; }
say() { printf '%s\n' "$*"; }

# ---------- аргументы ----------
CMD="${1:-help}"; shift || true
ARG1=""; ARG2=""
case "$CMD" in
  stage|archive-tasks)
    [ $# -gt 0 ] && [ "${1#--}" = "$1" ] && { ARG1="$1"; shift; }
    [ $# -gt 0 ] && [ "${1#--}" = "$1" ] && { ARG2="$1"; shift; }
    ;;
esac
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    --docs) DOCS_ARG="${2:-}"; shift 2 ;;
    --gitignore) GITIGNORE=1; shift ;;
    *) die "неизвестный аргумент: $1" ;;
  esac
done

# ---------- корень и пути ----------
[ -n "$ROOT" ] || ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
[ -d "$ROOT" ] || die "корень проекта не найден: $ROOT"
ROOT="$(cd "$ROOT" && pwd)"
SDD="$ROOT/docs/sdd-power"
CFG="$SDD/config.yml"
LOCK="$SDD/docs.lock"
[ -d "$ASSETS" ] || die "шаблоны не найдены: $ASSETS"

cfg_get() { [ -f "$CFG" ] && sed -n "s/^$1:[[:space:]]*//p" "$CFG" | head -1 || true; }
cfg_set() {
  [ -f "$CFG" ] || return 1
  if grep -q "^$1:" "$CFG"; then
    awk -v k="$1" -v v="$2" '{ if (index($0, k ":") == 1) print k ": " v; else print }' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
  else
    printf '%s: %s\n' "$1" "$2" >> "$CFG"
  fi
}
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum   >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else printf 'no-sha-tool'; fi
}
git_in_root() { git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; }
have_tracking() { [ -f "$SDD/PLAN.md" ] && [ -f "$SDD/WORKLOG.md" ] && [ -f "$SDD/TIMELINE.md" ] && [ -f "$SDD/LESSONS.md" ]; }

# ---------- init ----------
cmd_init() {
  local created="" migrated="" skipped=""
  mkdir -p "$SDD/stages" || die "не удалось создать $SDD/stages"
  [ -e "$SDD/stages/.gitkeep" ] || : > "$SDD/stages/.gitkeep"

  for f in "${TRACKED[@]}"; do
    local target="$SDD/$f.md" legacy=""
    if [ -f "$target" ]; then skipped="$skipped $f.md"; continue; fi
    for cand in "$ROOT/$f.md" "$ROOT/docs/$f.md" "$ROOT/.sdd/$f.md" "$ROOT/sdd-power/$f.md"; do
      [ -f "$cand" ] && { legacy="$cand"; break; }
    done
    if [ -n "$legacy" ]; then
      if git_in_root && git -C "$ROOT" ls-files --error-unmatch "$legacy" >/dev/null 2>&1; then
        git -C "$ROOT" mv "$legacy" "$target" >/dev/null 2>&1 || mv "$legacy" "$target"
      else mv "$legacy" "$target"; fi
      migrated="$migrated ${legacy#$ROOT/}→$f.md"
    else
      cp "$ASSETS/$f.template.md" "$target" || die "не удалось создать $target"
      [ -n "$NAME" ] && { NAME="$NAME" perl -pi -e 's/<название проекта>/$ENV{NAME}/g' "$target" 2>/dev/null || true; }
      created="$created $f.md"
    fi
  done

  if [ ! -f "$CFG" ]; then
    cat > "$CFG" <<EOF
# Машинно-читаемая конфигурация sdd-power. Человеческая шапка — в PLAN.md.
# docs: пути к файлам документации, по которым строился план (через пробел).
# snapshot: дата снимка; хеши файлов — в docs.lock, обновляются через 'sdd.sh snapshot'.
project: ${NAME:-<название проекта>}
docs:
snapshot:
rigor: full
git: $([ "$GITIGNORE" = 1 ] && echo ignored || echo tracked)
EOF
    created="$created config.yml"
  fi

  ensure_anchor "$ROOT/CLAUDE.md"
  [ -f "$ROOT/AGENTS.md" ] && ensure_anchor "$ROOT/AGENTS.md"
  [ "$GITIGNORE" = 1 ] && ensure_gitignore

  say "### sdd-power init — $ROOT"
  [ -n "$created" ]  && say "создано:   $created"
  [ -n "$migrated" ] && say "перенесено:$migrated"
  [ -n "$skipped" ]  && say "уже было:  $skipped"
  say ""
  cmd_check
}

ensure_anchor() {
  local file="$1"
  if [ -f "$file" ] && grep -qF "$ANCHOR_MARK" "$file"; then return 0; fi
  { [ -f "$file" ] && printf '\n'
    printf '%s\n' "$ANCHOR_MARK"
    printf '%s\n' "## Состояние разработки"
    printf '%s\n' "Проект ведётся по скиллу **sdd-power**. Активируй его в начале сессии и прочитай"
    printf '%s\n' "\`docs/sdd-power/\` (PLAN.md, WORKLOG.md, TIMELINE.md, LESSONS.md, stages/) прежде,"
    printf '%s\n' "чем писать код или отвечать по задачам проекта. Файлы обновляются синхронно с кодом."
  } >> "$file"
}

ensure_gitignore() {
  git_in_root || return 0
  grep -qE '^docs/sdd-power/?$' "$ROOT/.gitignore" 2>/dev/null && return 0
  { [ -s "$ROOT/.gitignore" ] && printf '\n'
    printf '%s\n' "# рабочее состояние разработки (sdd-power)"
    printf '%s\n' "docs/sdd-power/"
  } >> "$ROOT/.gitignore"
}

# ---------- снимок документации ----------
cmd_snapshot() {
  have_tracking || die "нет файлов трекинга в $SDD — начни с 'sdd.sh init'"
  [ -f "$CFG" ] || { printf 'project:\ndocs:\nsnapshot:\nrigor: full\ngit: tracked\n' > "$CFG"; }
  local docs="$DOCS_ARG"
  [ -n "$docs" ] || docs="$(cfg_get docs)"
  [ -n "$docs" ] || die "не указаны файлы документации: sdd.sh snapshot --docs \"docs/ТЗ.md docs/api.md\""

  local expanded="" n=0
  cd "$ROOT" || die "не войти в $ROOT"
  : > "$LOCK.tmp"
  for pat in $docs; do
    local matched=0
    for f in $pat; do
      [ -f "$f" ] || continue
      printf '%s  %s\n' "$(sha256_of "$f")" "$f" >> "$LOCK.tmp"
      expanded="$expanded $f"; n=$((n + 1)); matched=1
    done
    [ "$matched" = 0 ] && say "  [!] по шаблону «$pat» файлов не найдено"
  done
  [ "$n" = 0 ] && { rm -f "$LOCK.tmp"; die "ни одного файла документации не найдено"; }
  mv "$LOCK.tmp" "$LOCK"
  cfg_set docs "$docs"
  cfg_set snapshot "$(date +%Y-%m-%d)"
  say "снимок документации зафиксирован: $n файлов, дата $(date +%Y-%m-%d)"
  say "не забудь ту же дату в шапке PLAN.md — валидатор сверяет их"
}

docs_drift() {   # печатает строки о дрейфе; код 1 — есть изменения
  [ -f "$LOCK" ] || { say "  [i] снимок документации не зафиксирован — 'sdd.sh snapshot --docs \"...\"'"; return 0; }
  local changed=0 missing=0 line hash path now
  cd "$ROOT" || return 0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    hash="${line%% *}"; path="${line#*  }"
    if [ ! -f "$path" ]; then say "  [!] дока пропала: $path"; missing=$((missing + 1)); continue; fi
    now="$(sha256_of "$path")"
    [ "$now" = "$hash" ] || { say "  [!] дока изменилась с момента снимка: $path"; changed=$((changed + 1)); }
  done < "$LOCK"
  if [ "$changed" -gt 0 ] || [ "$missing" -gt 0 ]; then
    say "  → сравни изменившиеся разделы с планом, обнови задачи и снимок, зафиксируй ре-синхронизацию в WORKLOG,"
    say "    затем 'sdd.sh snapshot' — работа по устаревшему плану так же опасна, как работа по ошибочной доке"
    return 1
  fi
  say "  [ok]      документация не менялась с $(cfg_get snapshot)"
  return 0
}

# ---------- валидатор ----------
run_validator() {
  have_tracking || return 3
  local stages tags hasgit=0
  stages="$(ls "$SDD/stages" 2>/dev/null | sed -n 's/^\([0-9][0-9.]*\)-.*\.md$/\1/p' | tr '\n' ' ')"
  if git_in_root; then hasgit=1; tags="$(git -C "$ROOT" tag -l 'stage/*' 2>/dev/null | sed 's|^stage/||' | tr '\n' ' ')"; fi
  awk -f "$LIB/validate.awk" \
      -v stages="$stages" -v tags="${tags:-}" -v hasgit="$hasgit" \
      -v hascfg="$([ -f "$CFG" ] && echo 1 || echo 0)" -v snapdate="$(cfg_get snapshot)" \
      "$SDD/PLAN.md" "$SDD/WORKLOG.md" "$SDD/TIMELINE.md" "$SDD/LESSONS.md"
}

print_findings() {   # $1 — вывод валидатора
  local out="$1"
  printf '%s\n' "$out" | grep '^ERR'  | sed 's/^ERR\t\([A-Z0-9-]*\)\t/  [ошибка]        [\1] /'
  printf '%s\n' "$out" | grep '^WARN' | sed 's/^WARN\t\([A-Z0-9-]*\)\t/  [предупреждение] [\1] /'
  printf '%s\n' "$out" | grep '^INFO' | sed 's/^INFO\t[A-Z0-9-]*\t/  [i] /'
}

cmd_validate() {
  local out; out="$(run_validator)"; local rc=$?
  [ "$rc" = 3 ] && die "нет файлов трекинга в $SDD — начни с 'sdd.sh init'"
  say "### sdd-power validate — $SDD"
  print_findings "$out"
  local e w
  e=$(printf '%s\n' "$out" | grep -c '^ERR')
  w=$(printf '%s\n' "$out" | grep -c '^WARN')
  say ""
  if [ "$e" -gt 0 ]; then say "ИТОГ: ошибок $e, предупреждений $w — ошибки чинятся до продолжения работы."; return 1; fi
  [ "$w" -gt 0 ] && say "ИТОГ: ошибок нет, предупреждений $w — работать можно, но разбери их." || say "ИТОГ: трекинг непротиворечив."
  return 0
}

# ---------- check ----------
cmd_check() {
  local fail=0
  say "### sdd-power check — $ROOT"
  mark() { if [ "$1" = ok ]; then say "  [ok]      $2"; else say "  [ОТСУТСТВУЕТ] $2"; fail=1; fi; }

  [ -d "$SDD" ] && mark ok "docs/sdd-power/" || mark no "docs/sdd-power/"
  [ -d "$SDD/stages" ] && mark ok "docs/sdd-power/stages/" || mark no "docs/sdd-power/stages/"
  for f in "${TRACKED[@]}"; do
    if [ -f "$SDD/$f.md" ]; then mark ok "docs/sdd-power/$f.md ($(wc -l < "$SDD/$f.md" | tr -d ' ') строк)"
    else mark no "docs/sdd-power/$f.md"; fi
  done
  if grep -qsF "$ANCHOR_MARK" "$ROOT/CLAUDE.md"; then mark ok "якорь в CLAUDE.md"; else mark no "якорь в CLAUDE.md"; fi
  if [ -f "$CFG" ]; then mark ok "config.yml"; else say "  [!] нет config.yml — 'sdd.sh init' добавит (снимок доки не отслеживается)"; fi

  local orphans=""
  for f in "${TRACKED[@]}"; do
    for cand in "$ROOT/$f.md" "$ROOT/docs/$f.md" "$ROOT/.sdd/$f.md" "$ROOT/sdd-power/$f.md"; do
      [ -f "$cand" ] && orphans="$orphans ${cand#$ROOT/}"
    done
  done
  [ -n "$orphans" ] && say "  [!] файлы трекинга вне docs/sdd-power/:$orphans — перенеси или удали"

  if git_in_root; then
    if grep -qsE '^docs/sdd-power/?$' "$ROOT/.gitignore"; then say "  [i] git: docs/sdd-power/ в .gitignore — файлы не переживут свежий клон"
    else say "  [i] git: docs/sdd-power/ версионируется"; fi
  else
    say "  [i] git: не репозиторий — теги stage/<ID> недоступны, отметь это в PLAN.md"
  fi
  say "  [i] закрытых этапов в stages/: $(find "$SDD/stages" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"

  local drift=0
  if have_tracking; then docs_drift || drift=1; fi

  local out="" e=0 w=0
  if have_tracking; then
    out="$(run_validator)"
    e=$(printf '%s\n' "$out" | grep -c '^ERR'); w=$(printf '%s\n' "$out" | grep -c '^WARN')
    say ""
    say "Содержание трекинга: ошибок $e, предупреждений $w"
    printf '%s\n' "$out" | grep '^ERR' | sed 's/^ERR\t\([A-Z0-9-]*\)\t/  [ошибка] [\1] /'
    [ "$w" -gt 0 ] && say "  (полный разбор: sdd.sh validate)"
  fi

  say ""
  if [ "$fail" != 0 ]; then say "ИТОГ: инфраструктура НЕПОЛНА — выполни 'sdd.sh init'."; return 1; fi
  if [ "$e" -gt 0 ]; then say "ИТОГ: инфраструктура на месте, но в трекинге $e ошибок — почини до продолжения."; return 1; fi
  if [ "$drift" = 1 ]; then say "ИТОГ: инфраструктура на месте; документация разошлась со снимком — нужна ре-синхронизация."; return 0; fi
  say "ИТОГ: инфраструктура на месте."
  return 0
}

# ---------- next ----------
cmd_next() {
  have_tracking || die "нет файлов трекинга в $SDD — начни с 'sdd.sh init'"
  say "### sdd-power next — $ROOT"
  say ""
  awk -f "$LIB/next.awk" "$SDD/TIMELINE.md" "$SDD/PLAN.md"
  say ""
  say "Перед работой: LESSONS.md — $(grep -c '\*\*Правило:\*\*' "$SDD/LESSONS.md" 2>/dev/null || echo 0) правил, читается целиком."
  say "После шага — запись в WORKLOG.md сверху по шаблону:"
  say ""
  say "## [$(date +%Y-%m-%d\ %H:%M)] — <заголовок шага>"
  say ""
  say "- **Что сделано:**"
  say "- **Коммит:** \`<sha>\` (или «не коммитилось»)"
  say "- **Проверено:**"
  say "- **Решения и причины:**"
  say "- **Отклонения от плана или документации:**"
  say "- **Закрыто в PLAN.md:**"
  say "- **Урок для LESSONS.md:**"
}

# ---------- stage ----------
cmd_stage() {
  [ -n "$ARG1" ] && [ -n "$ARG2" ] || die "использование: sdd.sh stage <ID> <slug>"
  case "$ARG2" in *[!a-z0-9-]*|-*|*-) die "slug — строчные латинские буквы, цифры и дефисы: например 0-validation" ;; esac
  [ -d "$SDD/stages" ] || die "нет $SDD/stages — выполни 'sdd.sh init'"
  local target="$SDD/stages/$ARG1-$ARG2.md"
  [ -f "$target" ] && die "уже существует: ${target#$ROOT/} — саммари этапа пишется один раз"
  cp "$ASSETS/STAGE.template.md" "$target" || die "не удалось создать $target"
  ID="$ARG1" perl -pi -e 's/<ID>/$ENV{ID}/g' "$target" 2>/dev/null || true
  say "создан ${target#$ROOT/}"
  say "дальше: заполнить (включая раздел «Верификация»), затем 'sdd.sh archive-tasks $ARG1',"
  say "тег stage/$ARG1 и статус «завершён» в TIMELINE.md"
}

# ---------- archive-tasks ----------
cmd_archive_tasks() {
  [ -n "$ARG1" ] || die "использование: sdd.sh archive-tasks <ID>"
  have_tracking || die "нет файлов трекинга в $SDD"
  local id="$ARG1" sum
  sum="$(find "$SDD/stages" -maxdepth 1 -name "$id-*.md" 2>/dev/null | head -1)"
  [ -n "$sum" ] || die "нет саммари docs/sdd-power/stages/$id-*.md — сначала 'sdd.sh stage $id <slug>'"
  grep -q "^## Этап $id\." "$SDD/PLAN.md" || die "раздел «## Этап $id.» в PLAN.md не найден"
  grep -q "Состав этапа перенесён" <(awk -v id="$id" '
      index($0,"## Этап ")==1 { ins = (index($0,"## Этап " id ".")==1) }
      ins { print }' "$SDD/PLAN.md") && die "состав этапа $id уже перенесён"

  local ref="stages/$(basename "$sum")" body
  body="$(awk -f "$LIB/archive.awk" -v id="$id" -v mode=extract "$SDD/PLAN.md")" || die "не удалось извлечь раздел"
  [ -n "$body" ] || die "раздел этапа $id пуст"

  cp "$SDD/PLAN.md" "$SDD/PLAN.md.bak"
  { printf '\n---\n\n## Состав этапа (перенесено из PLAN.md %s)\n\n' "$(date +%Y-%m-%d)"
    printf 'Задачи и их номера сохранены дословно: на них ссылаются WORKLOG.md и LESSONS.md.\n\n'
    printf '%s\n' "$body"; } >> "$sum"

  awk -f "$LIB/archive.awk" -v id="$id" -v mode=strip -v ref="$ref" "$SDD/PLAN.md" > "$SDD/PLAN.md.tmp" \
    || { rm -f "$SDD/PLAN.md.tmp"; die "не удалось переписать PLAN.md (копия цела: PLAN.md.bak)"; }
  mv "$SDD/PLAN.md.tmp" "$SDD/PLAN.md"

  say "состав этапа $id перенесён в ${sum#$ROOT/}"
  say "в PLAN.md осталась заглушка со ссылкой; резервная копия — docs/sdd-power/PLAN.md.bak"
  say "PLAN.md: было $(wc -l < "$SDD/PLAN.md.bak" | tr -d ' ') строк, стало $(wc -l < "$SDD/PLAN.md" | tr -d ' ')"
}

case "$CMD" in
  init)          cmd_init ;;
  check)         cmd_check ;;
  validate)      cmd_validate ;;
  next)          cmd_next ;;
  snapshot)      cmd_snapshot ;;
  stage)         cmd_stage ;;
  archive-tasks) cmd_archive_tasks ;;
  help|--help|-h) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) die "неизвестная команда: $CMD (см. sdd.sh help)" ;;
esac
