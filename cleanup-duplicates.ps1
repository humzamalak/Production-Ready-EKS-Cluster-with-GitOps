# ============================================================================
# Cleanup Script - Remove Duplicate Structures (PowerShell)
# ============================================================================

Write-Host "`n🧹 Cleanup Script - Removing Duplicate Structures" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""

# Safety check
$confirm = Read-Host "⚠️  This will DELETE files. Have you created a backup? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "❌ Aborted. Please create a backup first:" -ForegroundColor Red
    Write-Host "   git tag pre-cleanup-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "📦 Creating safety backup tag..." -ForegroundColor Cyan
$backupTag = "pre-cleanup-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
git tag $backupTag
Write-Host "✅ Created tag: $backupTag" -ForegroundColor Green
Write-Host ""

$deletedCount = 0

# Phase 1: Remove duplicate AppProjects
Write-Host "🗑️  Phase 1: Removing duplicate AppProject definitions..." -ForegroundColor Cyan
if (Test-Path "bootstrap\05-argocd-projects.yaml") {
    Remove-Item "bootstrap\05-argocd-projects.yaml" -Force
    Write-Host "   ✅ Deleted: bootstrap\05-argocd-projects.yaml" -ForegroundColor Green
    $deletedCount++
}

if (Test-Path "bootstrap\projects") {
    Remove-Item "bootstrap\projects" -Recurse -Force
    Write-Host "   ✅ Deleted: bootstrap\projects\" -ForegroundColor Green
    $deletedCount++
}

# Phase 2: Remove duplicate Applications
Write-Host ""
Write-Host "🗑️  Phase 2: Removing duplicate Application definitions..." -ForegroundColor Cyan
if (Test-Path "environments\prod") {
    Remove-Item "environments\prod" -Recurse -Force
    Write-Host "   ✅ Deleted: environments\prod\" -ForegroundColor Green
    $deletedCount++
}

if (Test-Path "environments\staging") {
    Remove-Item "environments\staging" -Recurse -Force
    Write-Host "   ✅ Deleted: environments\staging\" -ForegroundColor Green
    $deletedCount++
}

# Phase 3: Remove redundant directories
Write-Host ""
Write-Host "🗑️  Phase 3: Removing redundant directories..." -ForegroundColor Cyan
if (Test-Path "clusters") {
    Remove-Item "clusters" -Recurse -Force
    Write-Host "   ✅ Deleted: clusters\" -ForegroundColor Green
    $deletedCount++
}

if (Test-Path "applications") {
    Remove-Item "applications" -Recurse -Force
    Write-Host "   ✅ Deleted: applications\" -ForegroundColor Green
    $deletedCount++
}

if (Test-Path "config") {
    Remove-Item "config" -Recurse -Force
    Write-Host "   ✅ Deleted: config\" -ForegroundColor Green
    $deletedCount++
}

# Phase 4: Remove old bootstrap files
Write-Host ""
Write-Host "🗑️  Phase 4: Removing old bootstrap files..." -ForegroundColor Cyan
$oldBootstrapFiles = @(
    "bootstrap\00-namespaces.yaml",
    "bootstrap\01-pod-security-standards.yaml",
    "bootstrap\02-network-policy.yaml",
    "bootstrap\03-helm-repos.yaml",
    "bootstrap\04-argo-cd-install.yaml",
    "bootstrap\06-vault-policies.yaml",
    "bootstrap\07-etcd-backup.yaml"
)

foreach ($file in $oldBootstrapFiles) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Write-Host "   ✅ Deleted: $file" -ForegroundColor Green
        $deletedCount++
    }
}

# Phase 5: Remove interim documentation
Write-Host ""
Write-Host "🗑️  Phase 5: Removing interim documentation..." -ForegroundColor Cyan
$interimDocs = @(
    "ARGOCD_PROJECT_FIX.md",
    "INVESTIGATION_SUMMARY.md",
    "QUICK_FIX_GUIDE.md",
    "REPOSITORY_IMPROVEMENTS_SUMMARY.md",
    "docs\MONITORING_FIX_SUMMARY.md"
)

foreach ($doc in $interimDocs) {
    if (Test-Path $doc) {
        Remove-Item $doc -Force
        Write-Host "   ✅ Deleted: $doc" -ForegroundColor Green
        $deletedCount++
    }
}

# Phase 6: Remove obsolete scripts
Write-Host ""
Write-Host "🗑️  Phase 6: Removing obsolete scripts..." -ForegroundColor Cyan
$obsoleteScripts = @(
    "scripts\validate-argocd-apps.sh",
    "scripts\validate-deployment.sh",
    "scripts\validate-fixes.sh",
    "scripts\validate-gitops-fixes.sh",
    "scripts\validate-gitops-structure.sh",
    "scripts\redeploy.sh"
)

foreach ($script in $obsoleteScripts) {
    if (Test-Path $script) {
        Remove-Item $script -Force
        Write-Host "   ✅ Deleted: $script" -ForegroundColor Green
        $deletedCount++
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "✅ Cleanup Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Summary:" -ForegroundColor Cyan
Write-Host "   - Deleted $deletedCount items" -ForegroundColor White
Write-Host ""
Write-Host "🏷️  Backup tag created: $backupTag" -ForegroundColor Cyan
Write-Host "   To restore: git reset --hard $backupTag" -ForegroundColor Yellow
Write-Host ""
Write-Host "📝 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Review git status: git status" -ForegroundColor White
Write-Host "   2. Stage deletions: git add -A" -ForegroundColor White
Write-Host "   3. Commit: git commit -m ""chore: remove duplicate structures per validation""" -ForegroundColor White
Write-Host ""

