#!/usr/bin/env bash

# Cleanup script for CrowdStrike Falcon Azure Policy resources
# Dynamically discovers and removes policy assignments, definitions, and deployments
# at both subscription and management group scope.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default configuration
SCOPE="subscription"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-${SUBSCRIPTION_ID:-}}"
MANAGEMENT_GROUP_ID=""
POLICY_PREFIX="CS-Falcon"
DRY_RUN="false"
DELETE_DEPLOYMENTS="true"
DEPLOYMENT_PREFIX="FALCON"

# Logging functions
log() {
    local level=$1
    shift
    local color=""
    local prefix=""

    case $level in
        "INFO") color="$BLUE"; prefix="[INFO]" ;;
        "SUCCESS") color="$GREEN"; prefix="[SUCCESS]" ;;
        "WARNING") color="$YELLOW"; prefix="[WARNING]" ;;
        "ERROR") color="$RED"; prefix="[ERROR]" ;;
    esac

    echo -e "${color}${prefix}${NC} $*" >&2
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Remove CrowdStrike Falcon Azure Policy assignments, definitions, and deployments.

Resources are discovered dynamically using the policy name prefix (default: CS-Falcon).
Deletion order: assignments → definitions → deployments (respects dependency ordering).

SCOPE OPTIONS:
  --scope SCOPE             Target scope: subscription, management-group, or both
                            (default: subscription)
  --subscription-id ID      Azure subscription ID
                            (default: AZURE_SUBSCRIPTION_ID env var)
  --management-group-id ID  Management group ID (required when scope includes
                            management-group)

FILTER OPTIONS:
  --prefix PREFIX           Policy name prefix to match
                            (default: CS-Falcon)
  --deployment-prefix PFX   Deployment name prefix to match
                            (default: FALCON)
  --skip-deployments        Skip deletion of deployment records

SAFETY OPTIONS:
  --dry-run                 Show what would be deleted without making changes

GENERAL:
  -h, --help                Show this help message

REQUIRED ENVIRONMENT VARIABLES:
  AZURE_SUBSCRIPTION_ID     Azure subscription ID (unless --subscription-id is set)

EXAMPLES:
  # Remove all CS-Falcon policies from current subscription
  $0

  # Dry run — show what would be deleted
  $0 --dry-run

  # Remove from management group
  $0 --scope management-group --management-group-id my-mg-id

  # Remove from both subscription and management group
  $0 --scope both --management-group-id my-mg-id

  # Remove only test policies (different prefix)
  $0 --prefix CS-Falcon-Policy-Test
EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --scope)
                SCOPE="$2"
                if [[ ! "$SCOPE" =~ ^(subscription|management-group|both)$ ]]; then
                    log ERROR "Invalid scope: $SCOPE. Must be 'subscription', 'management-group', or 'both'"
                    exit 1
                fi
                shift 2
                ;;
            --subscription-id)
                SUBSCRIPTION_ID="$2"
                shift 2
                ;;
            --management-group-id)
                MANAGEMENT_GROUP_ID="$2"
                shift 2
                ;;
            --prefix)
                POLICY_PREFIX="$2"
                shift 2
                ;;
            --deployment-prefix)
                DEPLOYMENT_PREFIX="$2"
                shift 2
                ;;
            --skip-deployments)
                DELETE_DEPLOYMENTS="false"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log ERROR "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

check_prerequisites() {
    if ! command -v az &> /dev/null; then
        log ERROR "Azure CLI is not installed"
        exit 1
    fi

    if [[ "$SCOPE" == "subscription" || "$SCOPE" == "both" ]]; then
        if [[ -z "$SUBSCRIPTION_ID" ]]; then
            log ERROR "SUBSCRIPTION_ID or AZURE_SUBSCRIPTION_ID is required for subscription scope"
            exit 1
        fi
    fi

    if [[ "$SCOPE" == "management-group" || "$SCOPE" == "both" ]]; then
        if [[ -z "$MANAGEMENT_GROUP_ID" ]]; then
            log ERROR "--management-group-id is required for management-group scope"
            exit 1
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Subscription-scoped cleanup
# ═══════════════════════════════════════════════════════════════════════════════

delete_subscription_assignments() {
    log INFO "Discovering policy assignments matching prefix '$POLICY_PREFIX' at subscription scope..."

    # Find assignments by name prefix
    local assignments
    assignments=$(az policy assignment list \
        --query "[?starts_with(name, '${POLICY_PREFIX}')].name" \
        --output tsv 2>/dev/null) || true

    # Also find assignments that reference definitions matching our prefix (handles
    # the case where assignment names don't match the definition prefix, e.g.
    # assignment "CS-Falcon-Linux-VM-80bcfc87" references "CS-Falcon-Policy-Test-Linux-VM")
    local def_assignments
    def_assignments=$(az policy assignment list \
        --query "[?contains(policyDefinitionId, '${POLICY_PREFIX}')].name" \
        --output tsv 2>/dev/null) || true

    # Merge and deduplicate
    local all_assignments
    all_assignments=$(printf '%s\n%s' "$assignments" "$def_assignments" | sort -u | grep -v '^$') || true

    if [[ -z "$all_assignments" ]]; then
        log INFO "No policy assignments found matching prefix '$POLICY_PREFIX'"
        return 0
    fi

    local count=0
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        ((count++))
        if [[ "$DRY_RUN" == "true" ]]; then
            log INFO "[DRY RUN] Would delete policy assignment: $name"
        else
            log INFO "Deleting policy assignment: $name"
            if az policy assignment delete --name "$name" --output none 2>/dev/null; then
                log SUCCESS "Deleted assignment: $name"
            else
                log WARNING "Failed to delete assignment: $name (may already be removed)"
            fi
        fi
    done <<< "$all_assignments"

    log INFO "Processed $count subscription policy assignment(s)"
}

delete_subscription_definitions() {
    log INFO "Discovering policy definitions matching prefix '$POLICY_PREFIX' at subscription scope..."

    local definitions
    definitions=$(az policy definition list \
        --query "[?starts_with(name, '${POLICY_PREFIX}') && policyType == 'Custom'].name" \
        --output tsv 2>/dev/null) || true

    if [[ -z "$definitions" ]]; then
        log INFO "No policy definitions found matching prefix '$POLICY_PREFIX'"
        return 0
    fi

    local count=0
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        ((count++))
        if [[ "$DRY_RUN" == "true" ]]; then
            log INFO "[DRY RUN] Would delete policy definition: $name"
        else
            log INFO "Deleting policy definition: $name"
            if az policy definition delete --name "$name" --output none 2>/dev/null; then
                log SUCCESS "Deleted definition: $name"
            else
                log WARNING "Failed to delete definition: $name (may have active assignments)"
            fi
        fi
    done <<< "$definitions"

    log INFO "Processed $count subscription policy definition(s)"
}

delete_subscription_deployments() {
    if [[ "$DELETE_DEPLOYMENTS" != "true" ]]; then
        return 0
    fi

    log INFO "Discovering subscription deployments matching prefix '$DEPLOYMENT_PREFIX'..."

    local deployments
    deployments=$(az deployment sub list \
        --query "[?starts_with(name, '${DEPLOYMENT_PREFIX}')].name" \
        --output tsv 2>/dev/null) || true

    if [[ -z "$deployments" ]]; then
        log INFO "No subscription deployments found matching prefix '$DEPLOYMENT_PREFIX'"
        return 0
    fi

    local count=0
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        ((count++))
        if [[ "$DRY_RUN" == "true" ]]; then
            log INFO "[DRY RUN] Would delete subscription deployment: $name"
        else
            log INFO "Deleting subscription deployment: $name"
            if az deployment sub delete --name "$name" --no-wait --output none 2>/dev/null; then
                log SUCCESS "Deleted deployment: $name"
            else
                log WARNING "Failed to delete deployment: $name"
            fi
        fi
    done <<< "$deployments"

    log INFO "Processed $count subscription deployment(s)"
}

cleanup_subscription() {
    log INFO "Setting subscription: $SUBSCRIPTION_ID"
    az account set -s "$SUBSCRIPTION_ID"

    delete_subscription_assignments
    delete_subscription_definitions
    delete_subscription_deployments
}

# ═══════════════════════════════════════════════════════════════════════════════
# Management group-scoped cleanup
# ═══════════════════════════════════════════════════════════════════════════════

delete_management_group_assignments() {
    log INFO "Discovering policy assignments matching prefix '$POLICY_PREFIX' at management group scope..."

    local mg_scope="/providers/Microsoft.Management/managementGroups/${MANAGEMENT_GROUP_ID}"

    # Find assignments by name prefix
    local assignments
    assignments=$(az policy assignment list \
        --scope "$mg_scope" \
        --query "[?starts_with(name, '${POLICY_PREFIX}')].name" \
        --output tsv 2>/dev/null) || true

    # Also find assignments that reference definitions matching our prefix
    local def_assignments
    def_assignments=$(az policy assignment list \
        --scope "$mg_scope" \
        --query "[?contains(policyDefinitionId, '${POLICY_PREFIX}')].name" \
        --output tsv 2>/dev/null) || true

    # Merge and deduplicate
    local all_assignments
    all_assignments=$(printf '%s\n%s' "$assignments" "$def_assignments" | sort -u | grep -v '^$') || true

    if [[ -z "$all_assignments" ]]; then
        log INFO "No policy assignments found matching prefix '$POLICY_PREFIX' at management group"
        return 0
    fi

    local count=0
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        ((count++))
        if [[ "$DRY_RUN" == "true" ]]; then
            log INFO "[DRY RUN] Would delete management group policy assignment: $name"
        else
            log INFO "Deleting management group policy assignment: $name"
            if az policy assignment delete \
                --name "$name" \
                --scope "$mg_scope" \
                --output none 2>/dev/null; then
                log SUCCESS "Deleted assignment: $name"
            else
                log WARNING "Failed to delete assignment: $name (may already be removed)"
            fi
        fi
    done <<< "$all_assignments"

    log INFO "Processed $count management group policy assignment(s)"
}

delete_management_group_definitions() {
    log INFO "Discovering policy definitions matching prefix '$POLICY_PREFIX' at management group scope..."

    local definitions
    definitions=$(az policy definition list \
        --management-group "$MANAGEMENT_GROUP_ID" \
        --query "[?starts_with(name, '${POLICY_PREFIX}') && policyType == 'Custom'].name" \
        --output tsv 2>/dev/null) || true

    if [[ -z "$definitions" ]]; then
        log INFO "No policy definitions found matching prefix '$POLICY_PREFIX' at management group"
        return 0
    fi

    local count=0
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        ((count++))
        if [[ "$DRY_RUN" == "true" ]]; then
            log INFO "[DRY RUN] Would delete management group policy definition: $name"
        else
            log INFO "Deleting management group policy definition: $name"
            if az policy definition delete \
                --name "$name" \
                --management-group "$MANAGEMENT_GROUP_ID" \
                --output none 2>/dev/null; then
                log SUCCESS "Deleted definition: $name"
            else
                log WARNING "Failed to delete definition: $name (may have active assignments)"
            fi
        fi
    done <<< "$definitions"

    log INFO "Processed $count management group policy definition(s)"
}

delete_management_group_deployments() {
    if [[ "$DELETE_DEPLOYMENTS" != "true" ]]; then
        return 0
    fi

    log INFO "Discovering management group deployments matching prefix '$DEPLOYMENT_PREFIX'..."

    local deployments
    deployments=$(az deployment mg list \
        --management-group-id "$MANAGEMENT_GROUP_ID" \
        --query "[?starts_with(name, '${DEPLOYMENT_PREFIX}')].name" \
        --output tsv 2>/dev/null) || true

    if [[ -z "$deployments" ]]; then
        log INFO "No management group deployments found matching prefix '$DEPLOYMENT_PREFIX'"
        return 0
    fi

    local count=0
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        ((count++))
        if [[ "$DRY_RUN" == "true" ]]; then
            log INFO "[DRY RUN] Would delete management group deployment: $name"
        else
            log INFO "Deleting management group deployment: $name"
            if az deployment mg delete \
                --name "$name" \
                --management-group-id "$MANAGEMENT_GROUP_ID" \
                --no-wait \
                --output none 2>/dev/null; then
                log SUCCESS "Deleted deployment: $name"
            else
                log WARNING "Failed to delete deployment: $name"
            fi
        fi
    done <<< "$deployments"

    log INFO "Processed $count management group deployment(s)"
}

cleanup_management_group() {
    delete_management_group_assignments
    delete_management_group_definitions
    delete_management_group_deployments
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    parse_arguments "$@"
    check_prerequisites

    if [[ "$DRY_RUN" == "true" ]]; then
        log WARNING "DRY RUN MODE — no changes will be made"
    fi

    echo ""
    log INFO "Policy cleanup configuration:"
    echo "  Scope:             $SCOPE"
    echo "  Policy prefix:     $POLICY_PREFIX"
    echo "  Deployment prefix: $DEPLOYMENT_PREFIX"
    echo "  Delete deployments: $DELETE_DEPLOYMENTS"
    [[ "$SCOPE" == "subscription" || "$SCOPE" == "both" ]] && echo "  Subscription ID:   $SUBSCRIPTION_ID"
    [[ "$SCOPE" == "management-group" || "$SCOPE" == "both" ]] && echo "  Management Group:  $MANAGEMENT_GROUP_ID"
    echo ""

    if [[ "$SCOPE" == "subscription" || "$SCOPE" == "both" ]]; then
        log INFO "═══ Cleaning up subscription-scoped resources ═══"
        cleanup_subscription
        echo ""
    fi

    if [[ "$SCOPE" == "management-group" || "$SCOPE" == "both" ]]; then
        log INFO "═══ Cleaning up management group-scoped resources ═══"
        cleanup_management_group
        echo ""
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log WARNING "DRY RUN complete — re-run without --dry-run to apply changes"
    else
        log SUCCESS "Policy cleanup complete"
    fi
}

main "$@"
