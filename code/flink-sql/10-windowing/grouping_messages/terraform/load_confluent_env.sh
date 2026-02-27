# Load ~/.confluent/.env and export all variables into the current bash session.
# Source this before env.confluent.sh so Terraform gets Confluent Cloud settings.
#
# Usage (from terraform/):
#   source load_confluent_env.sh
#   source env.confluent.sh
#   terraform plan && terraform apply
#
# .env format: one KEY=value per line (same as Python dotenv). Lines starting
# with # are skipped. Values may be double- or single-quoted; quotes are stripped.

CONFLUENT_ENV="${HOME}/.confluent/.env"
if [ ! -f "$CONFLUENT_ENV" ]; then
  echo "load_confluent_env.sh: $CONFLUENT_ENV not found; skipping." >&2
  return 0 2>/dev/null || exit 0
fi

while IFS= read -r line || [ -n "$line" ]; do
  # Strip trailing comment (only when # is not inside quotes)
  line="${line%%#*}"
  line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -z "$line" ] && continue
  case "$line" in
    *=*)
      key="${line%%=*}"
      key="$(echo "$key" | sed 's/[[:space:]]*$//')"
      value="${line#*=}"
      value="$(echo "$value" | sed 's/^[[:space:]]*//')"
      # Remove surrounding double or single quotes
      case "$value" in
        \"*\") value="$(echo "$value" | sed 's/^"\(.*\)"$/\1/')" ;;
        \'*\') value="$(echo "$value" | sed "s/^'\\(.*\\)'$/\\1/")" ;;
      esac
      export "$key=$value"
      ;;
  esac
done < "$CONFLUENT_ENV"
