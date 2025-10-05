#!/bin/bash

# =============================================================================
# Configuration Management Script for EKS GitOps Infrastructure
# =============================================================================
#
# This script helps manage environment-specific configurations and ensures
# consistency across different environments and applications.
#
# Usage:
#   ./scripts/config.sh [command] [options]
#
# Commands:
#   - generate: Generate environment-specific configuration files
#   - validate: Validate configuration files
#   - merge: Merge common configuration with environment-specific overrides
#   - diff: Show differences between environments
#   - sync: Sync configuration across environments
#
# Options:
#   --environment: Specify environment (dev/staging/prod)
#   --component: Specify component (web-app/monitoring/infrastructure)
#   --output-dir: Output directory for generated files
#   --dry-run: Show what would be done without making changes
#   --help: Show this help message
#
# Examples:
#   ./scripts/config.sh generate --environment prod --component web-app
#   ./scripts/config.sh validate --environment staging
#   ./scripts/config.sh merge --environment dev --output-dir /tmp/config
#   ./scripts/config.sh diff dev prod
#
# Author: Production-Ready EKS Cluster with GitOps
# Version: 2.0.0
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
CONFIG_DIR="$REPO_ROOT/config"
ENVIRONMENTS_DIR="$REPO_ROOT/environments"
APPLICATIONS_DIR="$REPO_ROOT/applications"

# Default values
DEFAULT_ENVIRONMENT="prod"
DEFAULT_OUTPUT_DIR="/tmp/eks-config"
DRY_RUN=false

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

# Function to display usage information
show_usage() {
    cat << EOF
Usage: $0 [command] [options]

Commands:
  generate     Generate environment-specific configuration files
  validate     Validate configuration files
  merge        Merge common configuration with environment-specific overrides
  diff         Show differences between environments
  sync         Sync configuration across environments

Options:
  --environment   Specify environment (dev/staging/prod)
  --component     Specify component (web-app/monitoring/infrastructure)
  --output-dir    Output directory for generated files
  --dry-run       Show what would be done without making changes
  --help          Show this help message

Examples:
  $0 generate --environment prod --component web-app
  $0 validate --environment staging
  $0 merge --environment dev --output-dir /tmp/config
  $0 diff dev prod

EOF
}

# Function to check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check required tools
    command -v yq >/dev/null 2>&1 || missing_tools+=("yq")
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install the missing tools and try again"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to generate environment-specific configuration
generate_config() {
    local environment=$1
    local component=${2:-"all"}
    local output_dir=${3:-"$DEFAULT_OUTPUT_DIR"}
    
    print_header "Generating Configuration for $environment"
    
    # Create output directory
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$output_dir/$environment"
    fi
    
    case $component in
        web-app)
            generate_web_app_config "$environment" "$output_dir"
            ;;
        monitoring)
            generate_monitoring_config "$environment" "$output_dir"
            ;;
        infrastructure)
            generate_infrastructure_config "$environment" "$output_dir"
            ;;
        all)
            generate_web_app_config "$environment" "$output_dir"
            generate_monitoring_config "$environment" "$output_dir"
            generate_infrastructure_config "$environment" "$output_dir"
            ;;
        *)
            print_error "Unknown component: $component"
            exit 1
            ;;
    esac
    
    print_success "Configuration generation completed for $environment"
}

# Function to generate web app configuration
generate_web_app_config() {
    local environment=$1
    local output_dir=$2
    
    print_step "Generating web app configuration for $environment..."
    
    local config_file="$output_dir/$environment/web-app-values.yaml"
    
    if [ "$DRY_RUN" = false ]; then
        # Merge common configuration with environment-specific overrides
        yq eval-all '. as $item ireduce ({}; . * $item)' \
            "$CONFIG_DIR/common.yaml" \
            "$ENVIRONMENTS_DIR/$environment/apps/web-app-values.yaml" > "$config_file" 2>/dev/null || \
        yq eval-all '. as $item ireduce ({}; . * $item)' \
            "$CONFIG_DIR/common.yaml" > "$config_file"
        
        # Set environment-specific values
        yq eval ".replicaCount = $(yq eval ".environments.$environment.replicaCount // 3" "$CONFIG_DIR/common.yaml")" -i "$config_file"
        yq eval ".resources = .environments.$environment.resources" -i "$config_file"
        yq eval ".autoscaling = .environments.$environment.autoscaling" -i "$config_file"
        yq eval "del(.environments)" -i "$config_file"
    else
        print_status "Would generate web app configuration: $config_file"
    fi
}

# Function to generate monitoring configuration
generate_monitoring_config() {
    local environment=$1
    local output_dir=$2
    
    print_step "Generating monitoring configuration for $environment..."
    
    local prometheus_config="$output_dir/$environment/prometheus-values.yaml"
    local grafana_config="$output_dir/$environment/grafana-values.yaml"
    
    if [ "$DRY_RUN" = false ]; then
        # Generate Prometheus configuration
        yq eval-all '. as $item ireduce ({}; . * $item)' \
            "$CONFIG_DIR/common.yaml" \
            "$APPLICATIONS_DIR/monitoring/prometheus/values-$environment.yaml" > "$prometheus_config" 2>/dev/null || \
        yq eval-all '. as $item ireduce ({}; . * $item)' \
            "$CONFIG_DIR/common.yaml" > "$prometheus_config"
        
        # Generate Grafana configuration
        yq eval-all '. as $item ireduce ({}; . * $item)' \
            "$CONFIG_DIR/common.yaml" \
            "$APPLICATIONS_DIR/monitoring/grafana/values-$environment.yaml" > "$grafana_config" 2>/dev/null || \
        yq eval-all '. as $item ireduce ({}; . * $item)' \
            "$CONFIG_DIR/common.yaml" > "$grafana_config"
    else
        print_status "Would generate monitoring configuration:"
        print_status "  - Prometheus: $prometheus_config"
        print_status "  - Grafana: $grafana_config"
    fi
}

# Function to generate infrastructure configuration
generate_infrastructure_config() {
    local environment=$1
    local output_dir=$2
    
    print_step "Generating infrastructure configuration for $environment..."
    
    local terraform_config="$output_dir/$environment/terraform.tfvars"
    
    if [ "$DRY_RUN" = false ]; then
        # Copy and customize Terraform variables
        cp "$REPO_ROOT/infrastructure/terraform/terraform.tfvars.example" "$terraform_config"
        
        # Set environment-specific values
        case $environment in
            dev)
                sed -i 's/environment = "prod"/environment = "dev"/' "$terraform_config"
                sed -i 's/node_instance_types = \["t3.medium"\]/node_instance_types = ["t3.small"]/' "$terraform_config"
                ;;
            staging)
                sed -i 's/environment = "prod"/environment = "staging"/' "$terraform_config"
                sed -i 's/node_instance_types = \["t3.medium"\]/node_instance_types = ["t3.medium"]/' "$terraform_config"
                ;;
            prod)
                # Keep default values
                ;;
        esac
    else
        print_status "Would generate infrastructure configuration: $terraform_config"
    fi
}

# Function to validate configuration files
validate_config() {
    local environment=$1
    
    print_header "Validating Configuration for $environment"
    
    # Validate common configuration
    if [ -f "$CONFIG_DIR/common.yaml" ]; then
        print_step "Validating common configuration..."
        if yq eval '.' "$CONFIG_DIR/common.yaml" >/dev/null 2>&1; then
            print_success "Common configuration is valid"
        else
            print_error "Common configuration is invalid"
            return 1
        fi
    else
        print_error "Common configuration file not found: $CONFIG_DIR/common.yaml"
        return 1
    fi
    
    # Validate environment-specific configurations
    local env_files=(
        "$ENVIRONMENTS_DIR/$environment/app-of-apps.yaml"
        "$ENVIRONMENTS_DIR/$environment/namespaces.yaml"
        "$ENVIRONMENTS_DIR/$environment/project.yaml"
    )
    
    for file in "${env_files[@]}"; do
        if [ -f "$file" ]; then
            print_step "Validating $(basename "$file")..."
            if yq eval '.' "$file" >/dev/null 2>&1; then
                print_success "$(basename "$file") is valid"
            else
                print_error "$(basename "$file") is invalid"
                return 1
            fi
        else
            print_warning "$(basename "$file") not found"
        fi
    done
    
    # Validate application configurations
    local app_files=(
        "$ENVIRONMENTS_DIR/$environment/apps/prometheus.yaml"
        "$ENVIRONMENTS_DIR/$environment/apps/grafana.yaml"
        "$ENVIRONMENTS_DIR/$environment/apps/web-app.yaml"
    )
    
    for file in "${app_files[@]}"; do
        if [ -f "$file" ]; then
            print_step "Validating $(basename "$file")..."
            if yq eval '.' "$file" >/dev/null 2>&1; then
                print_success "$(basename "$file") is valid"
            else
                print_error "$(basename "$file") is invalid"
                return 1
            fi
        else
            print_warning "$(basename "$file") not found"
        fi
    done
    
    print_success "Configuration validation completed for $environment"
}

# Function to merge configurations
merge_config() {
    local environment=$1
    local output_dir=${2:-"$DEFAULT_OUTPUT_DIR"}
    
    print_header "Merging Configuration for $environment"
    
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$output_dir/$environment"
    fi
    
    # Merge all configurations
    generate_config "$environment" "all" "$output_dir"
    
    print_success "Configuration merge completed for $environment"
}

# Function to show differences between environments
show_diff() {
    local env1=$1
    local env2=$2
    
    print_header "Configuration Differences: $env1 vs $env2"
    
    # Compare environment files
    local env_files=(
        "app-of-apps.yaml"
        "namespaces.yaml"
        "project.yaml"
    )
    
    for file in "${env_files[@]}"; do
        local file1="$ENVIRONMENTS_DIR/$env1/$file"
        local file2="$ENVIRONMENTS_DIR/$env2/$file"
        
        if [ -f "$file1" ] && [ -f "$file2" ]; then
            print_step "Comparing $file..."
            if command -v diff >/dev/null 2>&1; then
                diff -u "$file1" "$file2" || true
            else
                print_warning "diff command not available, skipping comparison"
            fi
        else
            print_warning "Cannot compare $file (one or both files missing)"
        fi
    done
}

# Function to sync configuration across environments
sync_config() {
    local source_env=$1
    local target_env=${2:-""}
    
    print_header "Syncing Configuration from $source_env"
    
    if [ -z "$target_env" ]; then
        # Sync to all environments
        local environments=("dev" "staging" "prod")
        for env in "${environments[@]}"; do
            if [ "$env" != "$source_env" ]; then
                print_step "Syncing to $env..."
                sync_config "$source_env" "$env"
            fi
        done
    else
        print_step "Syncing from $source_env to $target_env..."
        
        if [ "$DRY_RUN" = false ]; then
            # Sync common configuration patterns
            local source_dir="$ENVIRONMENTS_DIR/$source_env"
            local target_dir="$ENVIRONMENTS_DIR/$target_env"
            
            # Copy and adapt configuration files
            for file in "$source_dir"/*.yaml; do
                if [ -f "$file" ]; then
                    local basename_file=$(basename "$file")
                    local target_file="$target_dir/$basename_file"
                    
                    # Copy file and adapt environment-specific values
                    cp "$file" "$target_file"
                    
                    # Replace environment references
                    sed -i "s/$source_env/$target_env/g" "$target_file"
                fi
            done
        else
            print_status "Would sync configuration from $source_env to $target_env"
        fi
    fi
    
    print_success "Configuration sync completed"
}

# Parse command line arguments
COMMAND=""
ENVIRONMENT="$DEFAULT_ENVIRONMENT"
COMPONENT=""
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"

while [[ $# -gt 0 ]]; do
    case $1 in
        generate|validate|merge|diff|sync)
            COMMAND="$1"
            shift
            ;;
        dev|staging|prod)
            ENVIRONMENT="$1"
            shift
            ;;
        web-app|monitoring|infrastructure|all)
            COMPONENT="$1"
            shift
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --component)
            COMPONENT="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
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

# Validate required arguments
if [ -z "$COMMAND" ]; then
    print_error "Command is required"
    show_usage
    exit 1
fi

# Main execution
main() {
    print_header "EKS GitOps Infrastructure Configuration Management"
    print_status "Command: $COMMAND"
    print_status "Environment: $ENVIRONMENT"
    print_status "Component: ${COMPONENT:-"all"}"
    print_status "Output Directory: $OUTPUT_DIR"
    print_status "Dry Run: $DRY_RUN"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    echo ""
    
    # Execute command
    case $COMMAND in
        generate)
            generate_config "$ENVIRONMENT" "$COMPONENT" "$OUTPUT_DIR"
            ;;
        validate)
            validate_config "$ENVIRONMENT"
            ;;
        merge)
            merge_config "$ENVIRONMENT" "$OUTPUT_DIR"
            ;;
        diff)
            if [ -z "${2:-}" ]; then
                print_error "Second environment required for diff command"
                exit 1
            fi
            show_diff "$ENVIRONMENT" "$2"
            ;;
        sync)
            if [ -z "${2:-}" ]; then
                sync_config "$ENVIRONMENT"
            else
                sync_config "$ENVIRONMENT" "$2"
            fi
            ;;
        *)
            print_error "Unknown command: $COMMAND"
            show_usage
            exit 1
            ;;
    esac
    
    echo ""
    print_header "Configuration Management Completed Successfully"
}

# Run main function
main "$@"
