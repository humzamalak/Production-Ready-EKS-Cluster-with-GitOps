#!/bin/bash
# =============================================================================
# Cleanup Script - Remove Duplicate Structures
# =============================================================================
#
# This script removes duplicate/legacy structures identified in validation.
# Creates a backup tag before deletion for safety.
#
# Usage: bash validation-reports/remediation-patches/02-cleanup-duplicates.sh
# =============================================================================

set -e

echo "🧹 Cleanup Script - Removing Duplicate Structures"
echo "=================================================="
echo ""

# Safety check
read -p "⚠️  This will DELETE files. Have you created a backup? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "❌ Aborted. Please create a backup first:"
    echo "   git tag pre-cleanup-backup-\$(date +%Y%m%d-%H%M%S)"
    exit 1
fi

echo ""
echo "📦 Creating safety backup tag..."
backup_tag="pre-cleanup-backup-$(date +%Y%m%d-%H%M%S)"
git tag "$backup_tag"
echo "✅ Created tag: $backup_tag"
echo ""

# Phase 1: Remove duplicate AppProjects
echo "🗑️  Phase 1: Removing duplicate AppProject definitions..."
if [ -f "bootstrap/05-argocd-projects.yaml" ]; then
    rm -f bootstrap/05-argocd-projects.yaml
    echo "   ✅ Deleted: bootstrap/05-argocd-projects.yaml"
fi

if [ -d "bootstrap/projects" ]; then
    rm -rf bootstrap/projects/
    echo "   ✅ Deleted: bootstrap/projects/"
fi

# Phase 2: Remove duplicate Applications
echo ""
echo "🗑️  Phase 2: Removing duplicate Application definitions..."
if [ -d "environments/prod" ]; then
    rm -rf environments/prod/
    echo "   ✅ Deleted: environments/prod/"
fi

if [ -d "environments/staging" ]; then
    rm -rf environments/staging/
    echo "   ✅ Deleted: environments/staging/"
fi

# Phase 3: Remove redundant directories
echo ""
echo "🗑️  Phase 3: Removing redundant directories..."
if [ -d "clusters" ]; then
    rm -rf clusters/
    echo "   ✅ Deleted: clusters/"
fi

if [ -d "applications" ]; then
    rm -rf applications/
    echo "   ✅ Deleted: applications/"
fi

if [ -d "config" ]; then
    rm -rf config/
    echo "   ✅ Deleted: config/"
fi

# Phase 4: Remove old bootstrap files (keep README for reference)
echo ""
echo "🗑️  Phase 4: Removing old bootstrap files..."
old_bootstrap_files=(
    "bootstrap/00-namespaces.yaml"
    "bootstrap/01-pod-security-standards.yaml"
    "bootstrap/02-network-policy.yaml"
    "bootstrap/03-helm-repos.yaml"
    "bootstrap/04-argo-cd-install.yaml"
    "bootstrap/06-vault-policies.yaml"
    "bootstrap/07-etcd-backup.yaml"
)

for file in "${old_bootstrap_files[@]}"; do
    if [ -f "$file" ]; then
        rm -f "$file"
        echo "   ✅ Deleted: $file"
    fi
done

# Phase 5: Remove interim documentation
echo ""
echo "🗑️  Phase 5: Removing interim documentation..."
interim_docs=(
    "ARGOCD_PROJECT_FIX.md"
    "INVESTIGATION_SUMMARY.md"
    "QUICK_FIX_GUIDE.md"
    "REPOSITORY_IMPROVEMENTS_SUMMARY.md"
    "docs/MONITORING_FIX_SUMMARY.md"
)

for doc in "${interim_docs[@]}"; do
    if [ -f "$doc" ]; then
        rm -f "$doc"
        echo "   ✅ Deleted: $doc"
    fi
done

# Phase 6: Remove obsolete scripts
echo ""
echo "🗑️  Phase 6: Removing obsolete scripts..."
obsolete_scripts=(
    "scripts/validate-argocd-apps.sh"
    "scripts/validate-deployment.sh"
    "scripts/validate-fixes.sh"
    "scripts/validate-gitops-fixes.sh"
    "scripts/validate-gitops-structure.sh"
    "scripts/redeploy.sh"
)

for script in "${obsolete_scripts[@]}"; do
    if [ -f "$script" ]; then
        rm -f "$script"
        echo "   ✅ Deleted: $script"
    fi
done

echo ""
echo "=================================================="
echo "✅ Cleanup Complete!"
echo ""
echo "📊 Summary:"
echo "   - Removed duplicate AppProjects"
echo "   - Removed duplicate Applications"
echo "   - Removed redundant directories"
echo "   - Removed old bootstrap files"
echo "   - Removed interim documentation"
echo "   - Removed obsolete scripts"
echo ""
echo "🔍 Remaining structure:"
tree -L 2 -d argocd/ apps/ environments/ 2>/dev/null || ls -la argocd/ apps/ environments/
echo ""
echo "🏷️  Backup tag created: $backup_tag"
echo "   To restore: git reset --hard $backup_tag"
echo ""
echo "📝 Next steps:"
echo "   1. Review git status: git status"
echo "   2. Stage deletions: git add -A"
echo "   3. Commit: git commit -m 'chore: remove duplicate structures per validation'"
echo "   4. Validate: bash scripts/validate.sh"
echo ""

