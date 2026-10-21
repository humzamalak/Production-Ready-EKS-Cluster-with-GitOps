#!/bin/bash

# =============================================================================
# Repository Cleanup Script - GitOps Audit
# =============================================================================
#
# This script safely removes obsolete files identified during the repository
# audit. It operates in dry-run mode by default for safety.
#
# Usage:
#   ./scripts/cleanup.sh                 # Dry-run mode (shows what would be deleted)
#   ./scripts/cleanup.sh --execute       # Actually delete files
#   ./scripts/cleanup.sh --backup-only   # Create backup without deletion
#
# Features:
#   - Dry-run mode by default
#   - Creates backups before deletion
#   - Confirmation prompts
#   - Rollback capability
#   - Execution logging
#
# Author: Production-Ready EKS Cluster with GitOps
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$REPO_ROOT/.cleanup-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$REPO_ROOT/reports/cleanup-execution.log"

# Operation modes
DRY_RUN=true
BACKUP_ONLY=false
FORCE=false

# Files to remove (root directory troubleshooting files)
ROOT_MD_FILES=(
    "ARGOCD_LOGGING_COMPLETE_FIX.md"
    "ARGOCD_LOGIN_FIXES.md"
    "ARGOCD_LOGIN_WINDOWS_FIXES.md"
    "ARGOCD_WINDOWS_REFACTOR_SUMMARY.md"
    "IMPLEMENTATION_SUMMARY.md"
    "LOGGING_FIX_REFERENCE.md"
    "REFACTORING_COMPLETE.md"
    "VAULT_DEPLOYMENT_FIXES.md"
    "VAULT_FIX_GUIDE.md"
    "VAULT_GITOPS_IMPLEMENTATION.md"
    "VERBOSE_LOGGING_SUMMARY.md"
    "WINDOWS_PATH_LOGGING_FIX.md"
    "WINDOWS_TESTING_GUIDE.md"
)

# Documentation files to remove
DOC_FILES=(
    "DEPLOYMENT.md"
    "docs/MONITORING_SYNC_TROUBLESHOOTING.md"
    "docs/vault-minikube-setup.md"
)

# Scripts to remove
SCRIPT_FILES=(
    "scripts/argo-diagnose.sh"
    "scripts/debug-monitoring-sync.sh"
    "scripts/setup-vault-minikube.sh"
    "scripts/test-argocd-windows.sh"
    "scripts/verify-vault.sh"
)

# Function to print colored output
print_header() {
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
}

print_status() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

print_dry_run() {
    echo -e "${YELLOW}[DRY-RUN]${NC} $1"
}

# Function to log message
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

# Function to display usage information
show_usage() {
    cat << EOF
Usage: $0 [options]

Options:
  --execute      Actually delete files (default: dry-run mode)
  --backup-only  Create backup without deletion
  --force        Skip confirmation prompts
  --help         Show this help message

Modes:
  Default (no flags)   Dry-run mode - shows what would be deleted
  --execute            Execution mode - actually deletes files (with backup)
  --backup-only        Creates backup but doesn't delete anything

Examples:
  $0                   # Preview what would be deleted (safe)
  $0 --execute         # Create backup and delete files (with confirmation)
  $0 --execute --force # Delete without confirmation (use with caution)
  $0 --backup-only     # Just create a backup

EOF
}

# Function to create backup
create_backup() {
    print_header "Creating Backup"
    
    mkdir -p "$BACKUP_DIR"
    log_message "Created backup directory: $BACKUP_DIR"
    
    print_status "Backup location: $BACKUP_DIR"
    
    local backed_up=0
    
    # Backup root MD files
    for file in "${ROOT_MD_FILES[@]}"; do
        if [[ -f "$REPO_ROOT/$file" ]]; then
            cp "$REPO_ROOT/$file" "$BACKUP_DIR/"
            print_success "Backed up: $file"
            log_message "Backed up: $file"
            ((backed_up++))
        fi
    done
    
    # Backup documentation files
    for file in "${DOC_FILES[@]}"; do
        if [[ -f "$REPO_ROOT/$file" ]]; then
            mkdir -p "$BACKUP_DIR/$(dirname "$file")"
            cp "$REPO_ROOT/$file" "$BACKUP_DIR/$file"
            print_success "Backed up: $file"
            log_message "Backed up: $file"
            ((backed_up++))
        fi
    done
    
    # Backup script files
    for file in "${SCRIPT_FILES[@]}"; do
        if [[ -f "$REPO_ROOT/$file" ]]; then
            mkdir -p "$BACKUP_DIR/$(dirname "$file")"
            cp "$REPO_ROOT/$file" "$BACKUP_DIR/$file"
            print_success "Backed up: $file"
            log_message "Backed up: $file"
            ((backed_up++))
        fi
    done
    
    # Create backup manifest
    cat > "$BACKUP_DIR/BACKUP_MANIFEST.md" <<EOF
# Backup Manifest

**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**Backup Location**: $BACKUP_DIR
**Files Backed Up**: $backed_up files

## Files Included

### Root Markdown Files
$(for file in "${ROOT_MD_FILES[@]}"; do
    if [[ -f "$REPO_ROOT/$file" ]]; then
        echo "- $file"
    fi
done)

### Documentation Files
$(for file in "${DOC_FILES[@]}"; do
    if [[ -f "$REPO_ROOT/$file" ]]; then
        echo "- $file"
    fi
done)

### Script Files
$(for file in "${SCRIPT_FILES[@]}"; do
    if [[ -f "$REPO_ROOT/$file" ]]; then
        echo "- $file"
    fi
done)

## Restore Instructions

To restore a file:
\`\`\`bash
cp $BACKUP_DIR/<file-path> $REPO_ROOT/<file-path>
\`\`\`

To restore all files:
\`\`\`bash
cp -r $BACKUP_DIR/* $REPO_ROOT/
\`\`\`

## Rollback

If cleanup causes issues, restore from this backup:
\`\`\`bash
./scripts/cleanup.sh --rollback $BACKUP_DIR
\`\`\`
EOF
    
    print_success "Created backup manifest: $BACKUP_DIR/BACKUP_MANIFEST.md"
    print_success "Total files backed up: $backed_up"
    log_message "Backup completed: $backed_up files"
}

# Function to preview files to be deleted
preview_deletion() {
    print_header "Preview: Files to be Deleted"
    
    local total=0
    
    print_status "Root Markdown Files (13 files):"
    for file in "${ROOT_MD_FILES[@]}"; do
        if [[ -f "$REPO_ROOT/$file" ]]; then
            print_dry_run "  Would delete: $file"
            ((total++))
        else
            print_warning "  Not found: $file (already deleted)"
        fi
    done
    
    echo ""
    print_status "Documentation Files (3 files):"
    for file in "${DOC_FILES[@]}"; do
        if [[ -f "$REPO_ROOT/$file" ]]; then
            print_dry_run "  Would delete: $file"
            ((total++))
        else
            print_warning "  Not found: $file (already deleted)"
        fi
    done
    
    echo ""
    print_status "Script Files (5 files):"
    for file in "${SCRIPT_FILES[@]}"; do
        if [[ -f "$REPO_ROOT/$file" ]]; then
            print_dry_run "  Would delete: $file"
            ((total++))
        else
            print_warning "  Not found: $file (already deleted)"
        fi
    done
    
    echo ""
    print_status "Total files to be deleted: $total"
    echo ""
    print_warning "This is a DRY-RUN. No files will be deleted."
    print_status "To actually delete these files, run: $0 --execute"
}

# Function to delete files
delete_files() {
    print_header "Deleting Files"
    
    local deleted=0
    local errors=0
    
    # Delete root MD files
    for file in "${ROOT_MD_FILES[@]}"; do
        if [[ -f "$REPO_ROOT/$file" ]]; then
            if rm "$REPO_ROOT/$file"; then
                print_success "Deleted: $file"
                log_message "Deleted: $file"
                ((deleted++))
            else
                print_error "Failed to delete: $file"
                log_message "ERROR: Failed to delete: $file"
                ((errors++))
            fi
        fi
    done
    
    # Delete documentation files
    for file in "${DOC_FILES[@]}"; do
        if [[ -f "$REPO_ROOT/$file" ]]; then
            if rm "$REPO_ROOT/$file"; then
                print_success "Deleted: $file"
                log_message "Deleted: $file"
                ((deleted++))
            else
                print_error "Failed to delete: $file"
                log_message "ERROR: Failed to delete: $file"
                ((errors++))
            fi
        fi
    done
    
    # Delete script files
    for file in "${SCRIPT_FILES[@]}"; do
        if [[ -f "$REPO_ROOT/$file" ]]; then
            if rm "$REPO_ROOT/$file"; then
                print_success "Deleted: $file"
                log_message "Deleted: $file"
                ((deleted++))
            else
                print_error "Failed to delete: $file"
                log_message "ERROR: Failed to delete: $file"
                ((errors++))
            fi
        fi
    done
    
    echo ""
    print_success "Successfully deleted: $deleted files"
    if [[ $errors -gt 0 ]]; then
        print_error "Failed to delete: $errors files"
    fi
    log_message "Deletion completed: $deleted files deleted, $errors errors"
}

# Function to request confirmation
confirm_deletion() {
    if [[ "$FORCE" = true ]]; then
        return 0
    fi
    
    echo ""
    print_warning "This will DELETE the files listed above."
    print_status "A backup will be created at: $BACKUP_DIR"
    echo ""
    read -p "Are you sure you want to proceed? (yes/no): " response
    
    case "$response" in
        yes|YES|y|Y)
            return 0
            ;;
        *)
            print_status "Operation cancelled by user"
            log_message "Operation cancelled by user"
            exit 0
            ;;
    esac
}

# Function to rollback from backup
rollback() {
    local backup_path="$1"
    
    if [[ ! -d "$backup_path" ]]; then
        print_error "Backup directory not found: $backup_path"
        exit 1
    fi
    
    print_header "Rolling Back from Backup"
    print_status "Backup location: $backup_path"
    
    if [[ "$FORCE" != true ]]; then
        echo ""
        print_warning "This will restore files from the backup."
        read -p "Are you sure you want to proceed? (yes/no): " response
        
        case "$response" in
            yes|YES|y|Y)
                ;;
            *)
                print_status "Rollback cancelled"
                exit 0
                ;;
        esac
    fi
    
    cp -r "$backup_path"/* "$REPO_ROOT/"
    print_success "Rollback completed"
    log_message "Rollback completed from: $backup_path"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --execute)
            DRY_RUN=false
            shift
            ;;
        --backup-only)
            BACKUP_ONLY=true
            DRY_RUN=false
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --rollback)
            rollback "$2"
            exit 0
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_header "GitOps Repository Cleanup Script"
    
    # Initialize log file
    mkdir -p "$(dirname "$LOG_FILE")"
    log_message "=== Cleanup script started ==="
    log_message "Mode: $(if [[ "$DRY_RUN" = true ]]; then echo "DRY-RUN"; elif [[ "$BACKUP_ONLY" = true ]]; then echo "BACKUP-ONLY"; else echo "EXECUTE"; fi)"
    
    if [[ "$DRY_RUN" = true ]]; then
        print_warning "Running in DRY-RUN mode (default)"
        print_status "No files will be deleted"
        echo ""
        preview_deletion
        echo ""
        print_status "To execute the cleanup, run: $0 --execute"
    elif [[ "$BACKUP_ONLY" = true ]]; then
        print_status "Running in BACKUP-ONLY mode"
        create_backup
        print_success "Backup completed successfully"
        print_status "No files were deleted"
    else
        print_warning "Running in EXECUTE mode"
        print_status "Files will be DELETED (after backup and confirmation)"
        echo ""
        
        # Preview first
        preview_deletion
        
        # Confirm
        confirm_deletion
        
        # Create backup
        create_backup
        echo ""
        
        # Delete files
        delete_files
        echo ""
        
        print_header "Cleanup Completed"
        print_success "Backup created at: $BACKUP_DIR"
        print_status "Execution log: $LOG_FILE"
        print_status "To rollback: $0 --rollback $BACKUP_DIR"
    fi
    
    log_message "=== Cleanup script completed ==="
}

# Run main function
main "$@"

