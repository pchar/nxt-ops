#!/bin/bash

# dv-update-project.sh - Create/Update an Argo CD project file from a template
# Home directory: dv-ops/addons/bin
# Can be run from any path

# Get the script's home directory
SCRIPT_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DV_OPS_ROOT="$(cd "$SCRIPT_HOME/../.." && pwd)"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Icon definitions
SUCCESS_ICON="✅"
ERROR_ICON="❌"
WARNING_ICON="⚠️"
INFO_ICON="ℹ️"
SEARCH_ICON="🔍"
ROCKET_ICON="🚀"
GEAR_ICON="⚙️"
FOLDER_ICON="📁"
FILE_ICON="📄"

# Global variables
DEBUG=false
PROJECT_NAME=""
CLUSTER_NAME=""
LINE_NUMBER=0

# Function to print debug messages
debug() {
    local msg="$1"
    LINE_NUMBER=$((LINENO - 1))
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}${INFO_ICON} [DEBUG:$LINE_NUMBER] ${WHITE}$msg${NC}" >&2
    fi
}

# Function to print error messages with line numbers
error() {
    local msg="$1"
    local line="${2:-$LINENO}"
    echo -e "${RED}${ERROR_ICON} [ERROR:$line] $msg${NC}" >&2
}

# Function to print success messages
success() {
    local msg="$1"
    echo -e "${GREEN}${SUCCESS_ICON} $msg${NC}"
}

# Function to print warning messages
warning() {
    local msg="$1"
    echo -e "${YELLOW}${WARNING_ICON} $msg${NC}"
}

# Function to print info messages
info() {
    local msg="$1"
    echo -e "${CYAN}${INFO_ICON} $msg${NC}"
}

# Function to show comprehensive help
show_help() {
    echo -e "${WHITE}${ROCKET_ICON} Argo CD Project Updater${NC}"
    echo -e "${WHITE}================================${NC}"
    echo
    echo -e "${CYAN}${INFO_ICON} Description:${NC}"
    echo "  This script creates or updates an Argo CD project file using template substitution."
    echo "  It validates project and cluster existence before generating the YAML file."
    echo
    echo -e "${CYAN}${INFO_ICON} Usage:${NC}"
    echo "  dv-update-project.sh --project-name=<name> --cluster-name=<name> [options]"
    echo
    echo -e "${CYAN}${INFO_ICON} Required Arguments:${NC}"
    echo -e "  ${WHITE}--project-name=<name>${NC}     Name of the Argo CD project (e.g., sandbox)"
    echo -e "  ${WHITE}--cluster-name=<name>${NC}     Name of the target cluster (e.g., sandbox)"
    echo
    echo -e "${CYAN}${INFO_ICON} Optional Arguments:${NC}"
    echo -e "  ${WHITE}--debug${NC}                   Enable debug mode (shows detailed operations)"
    echo -e "  ${WHITE}--list-argocd-projects${NC}    List all available Argo CD projects"
    echo -e "  ${WHITE}--list-argocd-clusters${NC}    List all available Argo CD clusters"
    echo -e "  ${WHITE}--help, -h${NC}                Show this help message"
    echo
    echo -e "${CYAN}${INFO_ICON} Examples:${NC}"
    echo "  ./dv-update-project.sh --project-name=sandbox --cluster-name=sandbox"
    echo "  ./dv-update-project.sh --project-name=webapp --cluster-name=staging --debug"
    echo "  ./dv-update-project.sh --list-argocd-projects"
    echo "  ./dv-update-project.sh --list-argocd-clusters"
    echo
    echo -e "${CYAN}${INFO_ICON} What this script does:${NC}"
    echo "  1. ${SEARCH_ICON} Validates project and cluster existence in Argo CD"
    echo "  2. ${FOLDER_ICON} Checks for existing project files"
    echo "  3. ${FILE_ICON} Removes old project YAML file if it exists"
    echo "  4. ${GEAR_ICON} Generates project file using template substitution:"
    echo "     - projects/<project-name>.yaml"
    echo
    echo -e "${CYAN}${INFO_ICON} Script Home Directory:${NC}"
    echo "  dv-ops/addons/bin"
    echo
    echo -e "${CYAN}${INFO_ICON} Working Directory:${NC}"
    echo "  dv-ops"
}

# Function to list ArgoCD projects
list_argocd_projects() {
    info "Listing ArgoCD projects..."
    debug "Executing: argocd proj list"
    
    if ! command -v argocd &> /dev/null; then
        error "ArgoCD CLI not found. Please install argocd CLI first." $LINENO
        return 1
    fi
    
    echo -e "${WHITE}${FOLDER_ICON} Available ArgoCD Projects:${NC}"
    echo -e "${WHITE}===============================${NC}"
    
    if argocd proj list 2>/dev/null; then
        success "ArgoCD projects listed successfully"
    else
        error "Failed to list ArgoCD projects. Check your ArgoCD connection." $LINENO
        return 1
    fi
}

# Function to list ArgoCD clusters
list_argocd_clusters() {
    info "Listing ArgoCD clusters..."
    debug "Executing: argocd cluster list"
    
    if ! command -v argocd &> /dev/null; then
        error "ArgoCD CLI not found. Please install argocd CLI first." $LINENO
        return 1
    fi
    
    echo -e "${WHITE}${GEAR_ICON} Available ArgoCD Clusters:${NC}"
    echo -e "${WHITE}===============================${NC}"
    
    if argocd cluster list 2>/dev/null; then
        success "ArgoCD clusters listed successfully"
    else
        error "Failed to list ArgoCD clusters. Check your ArgoCD connection." $LINENO
        return 1
    fi
}

# Function to validate ArgoCD CLI availability
validate_argocd_cli() {
    debug "Validating ArgoCD CLI availability"
    
    if ! command -v argocd &> /dev/null; then
        error "ArgoCD CLI not found. Please install argocd CLI first." $LINENO
        echo -e "${INFO_ICON} Installation instructions:"
        echo "  - macOS: brew install argocd"
        echo "  - Linux: curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
        return 1
    fi
    
    success "ArgoCD CLI found"
    return 0
}

# Function to check if project exists in ArgoCD
check_project_exists() {
    local project_name="$1"
    debug "Checking if project '$project_name' exists in ArgoCD"
    debug "Executing: argocd proj list | grep '$project_name'"
    
    if argocd proj list 2>/dev/null | grep -q "^$project_name\s"; then
        success "Project '$project_name' found in ArgoCD"
        return 0
    else
        error "Project '$project_name' does not exist in ArgoCD. Please create it first." $LINENO
        echo -e "${INFO_ICON} You can create the project with:"
        echo "  argocd proj create $project_name"
        return 1
    fi
}

# Function to check if cluster exists in ArgoCD
check_cluster_exists() {
    local cluster_name="$1"
    debug "Checking if cluster '$cluster_name' exists in ArgoCD"
    debug "Executing: argocd cluster list | grep ' $cluster_name '"
    
    if argocd cluster list 2>/dev/null | grep -q "[[:space:]]$cluster_name[[:space:]]"; then
        success "Cluster '$cluster_name' found in ArgoCD"
        return 0
    else
        error "Cluster '$cluster_name' does not exist in ArgoCD. Please add it first." $LINENO
        echo -e "${INFO_ICON} You can add the cluster with:"
        echo "  argocd cluster add $cluster_name"
        return 1
    fi
}

# Resolve the Argo CD server URL for a given cluster name
resolve_cluster_server() {
    local cluster_name="$1"
    debug "Resolving server URL for cluster '$cluster_name'"
    # Extract the SERVER field (first column) for the matching NAME (second column)
    local server
    server=$(argocd cluster list 2>/dev/null | awk -v n="$cluster_name" 'NR>1 && $2==n {print $1; found=1} END{ if(!found) exit 1 }')
    if [[ -z "$server" ]]; then
        error "Could not resolve server URL for cluster '$cluster_name' from 'argocd cluster list'" $LINENO
        return 1
    fi
    echo "$server"
    return 0
}

# Function to check if project file exists
check_project_file_exists() {
    local project_name="$1"
    local project_file="$DV_OPS_ROOT/projects/${project_name}.yaml"
    
    debug "Checking if project file exists: $project_file"
    
    if [[ -f "$project_file" ]]; then
        info "Found existing project file: $project_file"
        return 0
    else
        warning "Project file does not exist: $project_file"
        return 1
    fi
}

# Function to remove existing project file
remove_project_file() {
    local project_name="$1"
    local project_file="$DV_OPS_ROOT/projects/${project_name}.yaml"
    
    debug "Removing existing project file: $project_file"
    
    if [[ -f "$project_file" ]]; then
        if rm "$project_file"; then
            success "Removed existing project file: $project_file"
        else
            error "Failed to remove project file: $project_file" $LINENO
            return 1
        fi
    fi
}

# Function to generate project files using template substitution
generate_project_files() {
    local project_name="$1"
    local cluster_name="$2"
    local dest_server="$3"
    local projects_dir="$DV_OPS_ROOT/projects"
    local templates_dir="$DV_OPS_ROOT/addons/templates"
    
    debug "Generating project file using template substitution"
    debug "Projects directory: $projects_dir"
    debug "Templates directory: $templates_dir"
    debug "Destination server: $dest_server"
    
    # Generate single project file
    local project_file="$projects_dir/${project_name}.yaml"
    debug "Creating project file: $project_file"
    
    # Read template and substitute variables
    if [[ -f "$templates_dir/project-template.yaml" ]]; then
        sed -e "s/{{ \.project }}/$project_name/g" \
            -e "s/{{ \.destinationCluster }}/$cluster_name/g" \
            -e "s/{{ \.destinationServer }}/$(printf '%s' "$dest_server" | sed 's/\//\\\//g')/g" \
            -e "s/{{ default \"0\" \.syncWave }}/0/g" \
            -e "s/{{ \.appName }}/{{ .appName }}/g" \
            -e "s/{{ \.userGivenName }}/{{ .userGivenName }}/g" \
            -e "s/{{ \.destNamespace }}/{{ .destNamespace }}/g" \
            -e "s/{{ \.helmChartURL }}/{{ .helmChartURL }}/g" \
            -e "s/{{ \.helmChartVersion }}/{{ .helmChartVersion }}/g" \
            -e "s/{{ \.helmChartName }}/{{ .helmChartName }}/g" \
            "$templates_dir/project-template.yaml" > "$project_file"
        
        if [[ -s "$project_file" ]]; then
            success "Created project file: $project_file"
        else
            error "Failed to create project file" $LINENO
            return 1
        fi
    else
        error "Project template not found: $templates_dir/project-template.yaml" $LINENO
        return 1
    fi
    
    info "Generated project file:"
    echo -e "  ${FILE_ICON} $project_file"
    
    return 0
}

# Function to validate required arguments
validate_arguments() {
    debug "Validating required arguments"
    debug "PROJECT_NAME: '$PROJECT_NAME'"
    debug "CLUSTER_NAME: '$CLUSTER_NAME'"
    
    if [[ -z "$PROJECT_NAME" ]]; then
        error "Missing required argument: --project-name" $LINENO
        return 1
    fi
    
    if [[ -z "$CLUSTER_NAME" ]]; then
        error "Missing required argument: --cluster-name" $LINENO
        return 1
    fi
    
    success "Required arguments validated"
    return 0
}

# Main function
main() {
    debug "Starting main function with arguments: $*"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --debug)
                DEBUG=true
                debug "Debug mode enabled"
                shift
                ;;
            --project-name=*)
                PROJECT_NAME="${1#*=}"
                debug "Project name set to: $PROJECT_NAME"
                shift
                ;;
            --cluster-name=*)
                CLUSTER_NAME="${1#*=}"
                debug "Cluster name set to: $CLUSTER_NAME"
                shift
                ;;
            --list-argocd-projects)
                list_argocd_projects
                exit $?
                ;;
            --list-argocd-clusters)
                list_argocd_clusters
                exit $?
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error "Unknown argument: $1" $LINENO
                echo
                show_help
                exit 1
                ;;
        esac
    done
    
    # If no arguments provided, show help
    if [[ $# -eq 0 ]] && [[ -z "$PROJECT_NAME" ]] && [[ -z "$CLUSTER_NAME" ]]; then
        show_help
        exit 0
    fi
    
    # Validate required arguments
    if ! validate_arguments; then
        echo
        show_help
        exit 1
    fi
    
    info "Starting ArgoCD project creation process..."
    debug "Script home: $SCRIPT_HOME"
    debug "DV-OPS root: $DV_OPS_ROOT"
    
    # Validate CLI tools
    if ! validate_argocd_cli; then
        exit 1
    fi
    
    # Check if project exists in ArgoCD
    if ! check_project_exists "$PROJECT_NAME"; then
        exit 1
    fi
    
    # Check if cluster exists in ArgoCD
    if ! check_cluster_exists "$CLUSTER_NAME"; then
        exit 1
    fi
    
    # Check and remove existing project file if it exists
    if check_project_file_exists "$PROJECT_NAME"; then
        if ! remove_project_file "$PROJECT_NAME"; then
            exit 1
        fi
    fi
    
    # Resolve destination server for the selected cluster
    DEST_SERVER="$(resolve_cluster_server "$CLUSTER_NAME")" || exit 1

    # Generate project files using template substitution
    if ! generate_project_files "$PROJECT_NAME" "$CLUSTER_NAME" "$DEST_SERVER"; then
        exit 1
    fi
    
    success "ArgoCD project '$PROJECT_NAME' created successfully for cluster '$CLUSTER_NAME'!"
    echo
    info "Next steps:"
    echo "  1. Review the generated files in projects/"
    echo "  2. Commit the changes to your Git repository"
    echo "  3. Apply the resources to your ArgoCD instance"
    echo
}

# Run main function with all arguments
main "$@"
