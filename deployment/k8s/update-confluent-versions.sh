#!/usr/bin/env bash
# ==============================================================================
# update-confluent-versions.sh
#
# Modifies and manages Confluent Docker image versions in YAML (and JSON)
# deployment files under cfk and cmf directories.
#
# Compatible with macOS and Linux (Bash 3.2+).
# ==============================================================================

set -euo pipefail

# Color formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Disable colors if not running in a terminal
if [[ ! -t 1 ]]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
fi

# Determine script location and default target directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find workspace root or fallback to SCRIPT_DIR
if [[ -d "${SCRIPT_DIR}/cfk" && -d "${SCRIPT_DIR}/cmf" ]]; then
    BASE_DIR="${SCRIPT_DIR}"
elif [[ -d "${SCRIPT_DIR}/deployment/k8s/cfk" && -d "${SCRIPT_DIR}/deployment/k8s/cmf" ]]; then
    BASE_DIR="${SCRIPT_DIR}/deployment/k8s"
else
    # Try git root
    GIT_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "${GIT_ROOT}" && -d "${GIT_ROOT}/deployment/k8s/cfk" ]]; then
        BASE_DIR="${GIT_ROOT}/deployment/k8s"
    else
        BASE_DIR="${SCRIPT_DIR}"
    fi
fi

# Options & defaults
DRY_RUN=false
CREATE_BACKUP=false
INCLUDE_JSON=false
SCOPE_CFK=true
SCOPE_CMF=true
ACTION="update" # update, list
CUSTOM_DIR=""

# Version targets
ALL_VERSION=""
CP_VERSION=""
INIT_VERSION=""
C3_VERSION=""
MONITORING_VERSION=""
FLINK_VERSION=""
FROM_TAG=""
TO_TAG=""
declare -a SPECIFIC_IMAGE_UPDATES=()

# Known CP Core components
CP_CORE_IMAGES=(
    "cp-server"
    "cp-schema-registry"
    "cp-server-connect"
    "cp-kafka-rest"
    "cp-ksqldb-server"
    "cp-ksqldb-cli"
)

# Known C3 components
C3_IMAGES=(
    "cp-enterprise-control-center-next-gen"
    "cp-enterprise-control-center"
)

# Known Monitoring components
MONITORING_IMAGES=(
    "cp-enterprise-prometheus"
    "cp-enterprise-alertmanager"
)

# Known Flink components
FLINK_IMAGES=(
    "cp-flink"
    "cp-flink-sql"
    "cp-flink-kubernetes-operator"
    "cp-flink-s3"
)

# Known Init components
INIT_IMAGES=(
    "confluent-init-container"
)

# Display usage
usage() {
    cat <<EOF
${BOLD}Usage:${NC} $(basename "$0") [OPTIONS] [VERSION]

Modify or inspect Confluent Docker image versions across YAML (and JSON) files
under the ${CYAN}cfk${NC} and ${CYAN}cmf${NC} Kubernetes deployment directories.

${BOLD}Options:${NC}
  ${GREEN}-l, --list${NC}                   List all Confluent images and their current tags found in files
  ${GREEN}-v, --cp-version <ver>${NC}       Update CP core images (cp-server, cp-schema-registry,
                               cp-server-connect, cp-kafka-rest) to <ver>
  ${GREEN}--all <ver>${NC}                  Update ALL confluentinc/* images to <ver>
  ${GREEN}--init-version <ver>${NC}         Update confluent-init-container to <ver>
  ${GREEN}--c3-version <ver>${NC}           Update Control Center images to <ver>
  ${GREEN}--monitoring-version <ver>${NC}   Update Prometheus & Alertmanager images to <ver>
  ${GREEN}--flink-version <ver>${NC}        Update cp-flink / cp-flink-sql / operator images to <ver>
  ${GREEN}--image <name>=<tag>${NC}         Update a specific image (e.g. cp-server-connect=8.1.0
                               or confluentinc/cp-server:8.1.0)
  ${GREEN}--from <old> --to <new>${NC}      Replace any image tag matching <old> with <new>

${BOLD}Scope & Safety:${NC}
  ${GREEN}-d, --dry-run${NC}                Show what would change without modifying files
  ${GREEN}-b, --backup${NC}                 Create .bak backups of modified files
  ${GREEN}--cfk-only${NC}                   Only process deployment/k8s/cfk directory
  ${GREEN}--cmf-only${NC}                   Only process deployment/k8s/cmf directory
  ${GREEN}--dir <path>${NC}                 Process a custom directory
  ${GREEN}--include-json${NC}               Also process .json files (e.g., cmf application configs)
  ${GREEN}--no-color${NC}                   Disable ANSI color output
  ${GREEN}-h, --help${NC}                   Show this help message and exit

${BOLD}Quick Examples:${NC}
  $(basename "$0") -l                             # List current images & versions
  $(basename "$0") 8.1.0                          # Update all CP core images to 8.1.0
  $(basename "$0") -v 8.1.0 --init-version 3.1.1  # Update CP to 8.1.0 and init to 3.1.1
  $(basename "$0") --image cp-server-connect=8.1.0 # Update only cp-server-connect
  $(basename "$0") --from 7.7.7 --to 8.1.0       # Replace tag 7.7.7 with 8.1.0
  $(basename "$0") -v 8.1.0 --dry-run             # Preview changes without modifying
  $(basename "$0") --all 8.1.0 --include-json    # Update all images in yaml & json

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -l|--list)
            ACTION="list"
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -b|--backup)
            CREATE_BACKUP=true
            shift
            ;;
        --no-color)
            RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''
            shift
            ;;
        --include-json)
            INCLUDE_JSON=true
            shift
            ;;
        --cfk-only)
            SCOPE_CFK=true
            SCOPE_CMF=false
            shift
            ;;
        --cmf-only)
            SCOPE_CFK=false
            SCOPE_CMF=true
            shift
            ;;
        --dir)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error:${NC} --dir requires a directory path" >&2
                exit 1
            fi
            CUSTOM_DIR="$2"
            shift 2
            ;;
        -v|--cp-version|--cp)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error:${NC} -v/--cp-version requires a version argument" >&2
                exit 1
            fi
            CP_VERSION="$2"
            shift 2
            ;;
        --all)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error:${NC} --all requires a version argument" >&2
                exit 1
            fi
            ALL_VERSION="$2"
            shift 2
            ;;
        --init-version|--init)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error:${NC} --init-version requires a version argument" >&2
                exit 1
            fi
            INIT_VERSION="$2"
            shift 2
            ;;
        --c3-version|--c3)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error:${NC} --c3-version requires a version argument" >&2
                exit 1
            fi
            C3_VERSION="$2"
            shift 2
            ;;
        --monitoring-version|--monitoring)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error:${NC} --monitoring-version requires a version argument" >&2
                exit 1
            fi
            MONITORING_VERSION="$2"
            shift 2
            ;;
        --flink-version|--flink)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error:${NC} --flink-version requires a version argument" >&2
                exit 1
            fi
            FLINK_VERSION="$2"
            shift 2
            ;;
        --image)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error:${NC} --image requires <image>=<tag> or <image>:<tag>" >&2
                exit 1
            fi
            SPECIFIC_IMAGE_UPDATES+=("$2")
            shift 2
            ;;
        --from)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error:${NC} --from requires an old tag argument" >&2
                exit 1
            fi
            FROM_TAG="$2"
            shift 2
            ;;
        --to)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error:${NC} --to requires a new tag argument" >&2
                exit 1
            fi
            TO_TAG="$2"
            shift 2
            ;;
        list)
            ACTION="list"
            shift
            ;;
        *)
            # If positional argument looks like a version or doesn't start with -
            if [[ "$1" =~ ^[0-9]+\.[0-9]+.* ]]; then
                CP_VERSION="$1"
                shift
            else
                echo -e "${RED}Error:${NC} Unknown option or argument: $1" >&2
                usage
                exit 1
            fi
            ;;
    esac
done

# Validate --from and --to
if [[ -n "${FROM_TAG}" && -z "${TO_TAG}" ]] || [[ -z "${FROM_TAG}" && -n "${TO_TAG}" ]]; then
    echo -e "${RED}Error:${NC} Both --from and --to must be specified together" >&2
    exit 1
fi

# Collect target directories
TARGET_DIRS=()
if [[ -n "${CUSTOM_DIR}" ]]; then
    if [[ ! -d "${CUSTOM_DIR}" ]]; then
        echo -e "${RED}Error:${NC} Directory '${CUSTOM_DIR}' does not exist" >&2
        exit 1
    fi
    TARGET_DIRS+=("${CUSTOM_DIR}")
else
    if [[ "${SCOPE_CFK}" == true && -d "${BASE_DIR}/cfk" ]]; then
        TARGET_DIRS+=("${BASE_DIR}/cfk")
    fi
    if [[ "${SCOPE_CMF}" == true && -d "${BASE_DIR}/cmf" ]]; then
        TARGET_DIRS+=("${BASE_DIR}/cmf")
    fi
fi

if [[ ${#TARGET_DIRS[@]} -eq 0 ]]; then
    echo -e "${RED}Error:${NC} No target directories found under ${BASE_DIR}" >&2
    exit 1
fi

# Find all relevant files
TARGET_FILES=()
for dir in "${TARGET_DIRS[@]}"; do
    while IFS= read -r file; do
        [[ -f "$file" ]] && TARGET_FILES+=("$file")
    done < <(find "$dir" -maxdepth 3 \( -name "*.yaml" -o -name "*.yml" \))

    if [[ "${INCLUDE_JSON}" == true ]]; then
        while IFS= read -r file; do
            [[ -f "$file" ]] && TARGET_FILES+=("$file")
        done < <(find "$dir" -maxdepth 3 -name "*.json")
    fi
done

if [[ ${#TARGET_FILES[@]} -eq 0 ]]; then
    echo -e "${YELLOW}Warning:${NC} No matching files found in ${TARGET_DIRS[*]}"
    exit 0
fi

# ==============================================================================
# Helper function: Check if an image name belongs to an array
# ==============================================================================
contains_element() {
    local element="$1"
    shift
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "$element" ]]; then
            return 0
        fi
        shift
    done
    return 1
}

# ==============================================================================
# Helper function: Determine desired new tag for a given image name
# Returns 0 and echoes new tag if image should be updated, else returns 1
# ==============================================================================
get_new_tag_for_image() {
    local img_name="$1" # e.g. cp-server, cp-server-connect, etc.
    local current_tag="$2" # e.g. 7.7.7

    # 1. Check explicit --image overrides (highest precedence)
    if [[ ${#SPECIFIC_IMAGE_UPDATES[@]} -gt 0 ]]; then
        for spec in "${SPECIFIC_IMAGE_UPDATES[@]}"; do
            local target_img=""
            local target_tag=""
            if [[ "$spec" == *"="* ]]; then
                target_img="${spec%%=*}"
                target_tag="${spec#*=}"
            elif [[ "$spec" == *":"* ]]; then
                target_img="${spec%%:*}"
                target_tag="${spec#*:}"
            fi
            # Strip confluentinc/ or docker.io/ prefix if provided in target_img
            target_img="${target_img#docker.io/}"
            target_img="${target_img#confluentinc/}"

            if [[ "$target_img" == "$img_name" ]]; then
                echo "$target_tag"
                return 0
            fi
        done
    fi

    # 2. Check --from and --to
    if [[ -n "${FROM_TAG}" && -n "${TO_TAG}" ]]; then
        if [[ "$current_tag" == "${FROM_TAG}" ]]; then
            echo "${TO_TAG}"
            return 0
        fi
    fi

    # 3. Check --all (overrides component groups)
    if [[ -n "${ALL_VERSION}" ]]; then
        echo "${ALL_VERSION}"
        return 0
    fi

    # 4. Check component specific versions
    if [[ -n "${INIT_VERSION}" ]] && contains_element "$img_name" "${INIT_IMAGES[@]}"; then
        echo "${INIT_VERSION}"
        return 0
    fi

    if [[ -n "${C3_VERSION}" ]] && contains_element "$img_name" "${C3_IMAGES[@]}"; then
        echo "${C3_VERSION}"
        return 0
    fi

    if [[ -n "${MONITORING_VERSION}" ]] && contains_element "$img_name" "${MONITORING_IMAGES[@]}"; then
        echo "${MONITORING_VERSION}"
        return 0
    fi

    if [[ -n "${FLINK_VERSION}" ]] && contains_element "$img_name" "${FLINK_IMAGES[@]}"; then
        echo "${FLINK_VERSION}"
        return 0
    fi

    if [[ -n "${CP_VERSION}" ]] && contains_element "$img_name" "${CP_CORE_IMAGES[@]}"; then
        echo "${CP_VERSION}"
        return 0
    fi

    return 1
}

# ==============================================================================
# ACTION: List images
# ==============================================================================
if [[ "${ACTION}" == "list" ]]; then
    echo -e "${BOLD}${BLUE}=== Scanning Confluent Images in Deployment Files ===${NC}"
    echo -e "Directories: ${CYAN}${TARGET_DIRS[*]}${NC}"
    echo ""

    SEEN_IMAGES=()
    TOTAL_OCCURRENCES=0

    for file in "${TARGET_FILES[@]}"; do
        rel_file="${file#"${BASE_DIR}/"}"
        file_header_printed=false

        line_num=0
        while IFS= read -r line || [[ -n "$line" ]]; do
            ((line_num++))
            # Match confluent image patterns e.g. (docker.io/)?confluentinc/<image>:<tag>
            if [[ "$line" =~ (docker\.io/)?confluentinc/([a-zA-Z0-9._-]+):([a-zA-Z0-9._-]+) ]]; then
                prefix="${BASH_REMATCH[1]}"
                img="${BASH_REMATCH[2]}"
                tag="${BASH_REMATCH[3]}"
                full_image="${prefix}confluentinc/${img}:${tag}"

                if [[ "$file_header_printed" == false ]]; then
                    echo -e "${BOLD}${CYAN}${rel_file}${NC}:"
                    file_header_printed=true
                fi

                echo -e "  Line ${line_num}: ${GREEN}${full_image}${NC} (component: ${YELLOW}${img}${NC}, tag: ${BOLD}${tag}${NC})"
                ((TOTAL_OCCURRENCES++))

                item="${img}:${tag}"
                already_seen=false
                if [[ ${#SEEN_IMAGES[@]} -gt 0 ]]; then
                    if contains_element "$item" "${SEEN_IMAGES[@]}"; then
                        already_seen=true
                    fi
                fi
                if [[ "$already_seen" == false ]]; then
                    SEEN_IMAGES+=("$item")
                fi
            fi
        done < "$file"

        if [[ "$file_header_printed" == true ]]; then
            echo ""
        fi
    done

    echo -e "${BOLD}Summary of Distinct Confluent Images Found:${NC}"
    if [[ ${#SEEN_IMAGES[@]} -gt 0 ]]; then
        for key in "${SEEN_IMAGES[@]}"; do
            img_name="${key%%:*}"
            tag_val="${key#*:}"
            echo -e "  • ${CYAN}${img_name}${NC} -> ${BOLD}${tag_val}${NC}"
        done
    fi
    echo ""
    echo -e "Total image references found: ${BOLD}${TOTAL_OCCURRENCES}${NC} across ${BOLD}${#TARGET_FILES[@]}${NC} files."
    exit 0
fi

# ==============================================================================
# ACTION: Update images
# ==============================================================================

# Verify at least one update rule is specified
if [[ -z "${CP_VERSION}" && -z "${ALL_VERSION}" && -z "${INIT_VERSION}" && \
      -z "${C3_VERSION}" && -z "${MONITORING_VERSION}" && -z "${FLINK_VERSION}" && \
      -z "${FROM_TAG}" && ${#SPECIFIC_IMAGE_UPDATES[@]} -eq 0 ]]; then
    echo -e "${RED}Error:${NC} No version or update rule specified." >&2
    echo ""
    usage
    exit 1
fi

echo -e "${BOLD}${BLUE}=== Confluent Image Version Updater ===${NC}"
if [[ "${DRY_RUN}" == true ]]; then
    echo -e "${YELLOW}${BOLD}[DRY RUN MODE] No files will be modified.${NC}"
fi
echo -e "Target directories: ${CYAN}${TARGET_DIRS[*]}${NC}"
echo ""

TOTAL_FILES_MODIFIED=0
TOTAL_REPLACEMENTS=0

for file in "${TARGET_FILES[@]}"; do
    rel_file="${file#"${BASE_DIR}/"}"
    file_modified=false
    file_changes=()

    temp_file=$(mktemp)
    line_num=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        new_line="$line"

        # Regex match confluentinc image
        if [[ "$line" =~ (docker\.io/)?confluentinc/([a-zA-Z0-9._-]+):([a-zA-Z0-9._-]+) ]]; then
            full_match="${BASH_REMATCH[0]}"
            prefix="${BASH_REMATCH[1]}"
            img="${BASH_REMATCH[2]}"
            current_tag="${BASH_REMATCH[3]}"

            if new_tag=$(get_new_tag_for_image "$img" "$current_tag"); then
                if [[ "$current_tag" != "$new_tag" ]]; then
                    new_image="${prefix}confluentinc/${img}:${new_tag}"
                    new_line="${line//"$full_match"/$new_image}"
                    file_modified=true
                    ((TOTAL_REPLACEMENTS++))
                    file_changes+=("  Line ${line_num}: ${RED}${full_match}${NC} -> ${GREEN}${new_image}${NC}")
                fi
            fi
        fi

        echo "$new_line" >> "$temp_file"
    done < "$file"

    if [[ "$file_modified" == true ]]; then
        ((TOTAL_FILES_MODIFIED++))
        echo -e "${BOLD}[MODIFIED]${NC} ${CYAN}${rel_file}${NC}"
        if [[ ${#file_changes[@]} -gt 0 ]]; then
            for change in "${file_changes[@]}"; do
                echo -e "$change"
            done
        fi
        echo ""

        if [[ "${DRY_RUN}" == false ]]; then
            if [[ "${CREATE_BACKUP}" == true ]]; then
                cp "$file" "${file}.bak"
            fi
            mv "$temp_file" "$file"
        else
            rm -f "$temp_file"
        fi
    else
        rm -f "$temp_file"
    fi
done

echo -e "${BOLD}${BLUE}=== Execution Summary ===${NC}"
echo -e "Files checked:     ${BOLD}${#TARGET_FILES[@]}${NC}"
echo -e "Files modified:    ${BOLD}${TOTAL_FILES_MODIFIED}${NC}"
echo -e "Replacements made: ${BOLD}${TOTAL_REPLACEMENTS}${NC}"

if [[ "${DRY_RUN}" == true ]]; then
    echo -e "${YELLOW}Dry-run complete. Run without -d/--dry-run to apply changes.${NC}"
elif [[ "${TOTAL_FILES_MODIFIED}" -gt 0 ]]; then
    echo -e "${GREEN}All requested image versions have been successfully updated!${NC}"
else
    echo -e "${YELLOW}No matching image versions needed updating.${NC}"
fi
