#!/bin/bash

################################################################################
# GitHub Repository Collaborators Audit Script
# 
# Purpose: Lists all collaborators of a GitHub repository categorized by 
#          their permission levels (Admin, Write, Read)
#
# Usage: ./script.sh <repository-owner> <repository-name>
# Example: ./script.sh facebook react
#
# Requirements: 
#   - curl (for API requests)
#   - jq (for JSON parsing)
#   - GitHub Personal Access Token
#
# Author: Spandan
################################################################################

# ============================================================================
# CONFIGURATION
# ============================================================================

# GitHub API base URL - all API requests will use this
API_URL="https://api.github.com"

# GitHub credentials - should be set as environment variables for security
# Example: export GITHUB_USERNAME="your_username"
#          export GITHUB_TOKEN="ghp_your_token_here"
USERNAME=$GITHUB_USERNAME
TOKEN=$GITHUB_TOKEN

# Repository information from command line arguments
# $1 = first argument (repository owner/organization)
# $2 = second argument (repository name)
REPO_OWNER=$1
REPO_NAME=$2

# Output file to save the report
OUTPUT_FILE="collaborators_report_$(date +%Y%m%d_%H%M%S).txt"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

################################################################################
# Function: display_usage
# Description: Shows how to use the script
# Parameters: None
# Returns: Prints usage instructions
################################################################################
function display_usage {
    echo "=========================================="
    echo "GitHub Collaborators Audit Script"
    echo "=========================================="
    echo ""
    echo "Usage: $0 <repository-owner> <repository-name>"
    echo ""
    echo "Example:"
    echo "  $0 microsoft vscode"
    echo "  $0 facebook react"
    echo ""
    echo "Prerequisites:"
    echo "  1. Set environment variables:"
    echo "     export GITHUB_USERNAME='your_username'"
    echo "     export GITHUB_TOKEN='your_personal_access_token'"
    echo ""
    echo "  2. Install required tools:"
    echo "     - curl (usually pre-installed)"
    echo "     - jq (sudo apt install jq)"
    echo ""
}

################################################################################
# Function: validate_inputs
# Description: Checks if all required inputs and credentials are provided
# Parameters: None
# Returns: 0 if valid, exits script if invalid
################################################################################
function validate_inputs {
    # Check if repository owner and name are provided
    if [[ -z "$REPO_OWNER" || -z "$REPO_NAME" ]]; then
        echo "Error: Missing repository information!"
        echo ""
        display_usage
        exit 1
    fi
    
    # Check if GitHub credentials are set
    if [[ -z "$USERNAME" || -z "$TOKEN" ]]; then
        echo "Error: GitHub credentials not found!"
        echo ""
        echo "Please set your credentials as environment variables:"
        echo "  export GITHUB_USERNAME='your_username'"
        echo "  export GITHUB_TOKEN='your_token'"
        exit 1
    fi
    
    # Check if jq is installed (needed for JSON parsing)
    if ! command -v jq &> /dev/null; then
        echo "Error: 'jq' is not installed!"
        echo "Install it using: sudo apt install jq"
        exit 1
    fi
}

################################################################################
# Function: github_api_get
# Description: Makes a GET request to GitHub API with authentication
# Parameters: 
#   $1 - API endpoint (e.g., "repos/owner/repo/collaborators")
# Returns: JSON response from GitHub API
################################################################################
function github_api_get {
    local endpoint="$1"
    local url="${API_URL}/${endpoint}"
    
    # -s: silent mode (no progress bar)
    # -u: authentication (username:token)
    # The response is JSON data from GitHub
    curl -s -u "${USERNAME}:${TOKEN}" "$url"
}

################################################################################
# Function: print_header
# Description: Prints a formatted section header
# Parameters:
#   $1 - Header text to display
# Returns: Prints formatted header
################################################################################
function print_header {
    local header_text="$1"
    echo ""
    echo "=========================================="
    echo "$header_text"
    echo "=========================================="
}

################################################################################
# Function: save_to_file
# Description: Saves content to the output file
# Parameters:
#   $1 - Content to save
# Returns: Appends content to output file
################################################################################
function save_to_file {
    local content="$1"
    echo "$content" >> "$OUTPUT_FILE"
}

# ============================================================================
# MAIN FUNCTIONS
# ============================================================================

################################################################################
# Function: list_admin_users
# Description: Lists all collaborators with admin permissions
# Parameters: 
#   $1 - JSON data containing all collaborators
# Returns: Prints list of admin users
################################################################################
function list_admin_users {
    local collaborators="$1"
    
    # Filter collaborators where admin permission is true
    # jq -r: raw output (no quotes)
    # select: filter condition
    # .login: extract username
    local admins=$(echo "$collaborators" | jq -r '.[] | select(.permissions.admin == true) | .login')
    
    print_header "ADMIN USERS (Full Control)"
    
    if [[ -z "$admins" ]]; then
        echo "No admin users found."
        save_to_file "No admin users found."
    else
        echo "$admins"
        save_to_file "ADMIN USERS:"
        save_to_file "$admins"
    fi
}

################################################################################
# Function: list_write_users
# Description: Lists collaborators with write/push permissions (but not admin)
# Parameters: 
#   $1 - JSON data containing all collaborators
# Returns: Prints list of users with write access
################################################################################
function list_write_users {
    local collaborators="$1"
    
    # Filter for push permission = true AND admin = false
    # This gives us users who can push code but aren't admins
    local writers=$(echo "$collaborators" | jq -r '.[] | select(.permissions.push == true and .permissions.admin == false) | .login')
    
    print_header "WRITE ACCESS (Can Push Code)"
    
    if [[ -z "$writers" ]]; then
        echo "No users with write access found."
        save_to_file "No users with write access found."
    else
        echo "$writers"
        save_to_file "WRITE ACCESS:"
        save_to_file "$writers"
    fi
}

################################################################################
# Function: list_read_users
# Description: Lists collaborators with read-only permissions
# Parameters: 
#   $1 - JSON data containing all collaborators
# Returns: Prints list of users with read access only
################################################################################
function list_read_users {
    local collaborators="$1"
    
    # Filter for pull permission = true AND push = false
    # These users can only read/clone, cannot push changes
    local readers=$(echo "$collaborators" | jq -r '.[] | select(.permissions.pull == true and .permissions.push == false) | .login')
    
    print_header "READ-ONLY ACCESS (Can View/Clone)"
    
    if [[ -z "$readers" ]]; then
        echo "No users with read-only access found."
        save_to_file "No users with read-only access found."
    else
        echo "$readers"
        save_to_file "READ-ONLY ACCESS:"
        save_to_file "$readers"
    fi
}

################################################################################
# Function: get_collaborator_stats
# Description: Calculates and displays statistics about collaborators
# Parameters: 
#   $1 - JSON data containing all collaborators
# Returns: Prints statistics summary
################################################################################
function get_collaborator_stats {
    local collaborators="$1"
    
    # Count total number of collaborators
    local total=$(echo "$collaborators" | jq '. | length')
    
    # Count each permission level
    local admin_count=$(echo "$collaborators" | jq '[.[] | select(.permissions.admin == true)] | length')
    local write_count=$(echo "$collaborators" | jq '[.[] | select(.permissions.push == true and .permissions.admin == false)] | length')
    local read_count=$(echo "$collaborators" | jq '[.[] | select(.permissions.pull == true and .permissions.push == false)] | length')
    
    print_header "STATISTICS SUMMARY"
    echo "Total Collaborators: $total"
    echo "  - Admin: $admin_count"
    echo "  - Write: $write_count"
    echo "  - Read:  $read_count"
    
    # Save stats to file
    save_to_file ""
    save_to_file "STATISTICS:"
    save_to_file "Total: $total (Admin: $admin_count, Write: $write_count, Read: $read_count)"
}

################################################################################
# Function: audit_repository
# Description: Main function that coordinates the entire audit process
# Parameters: None (uses global variables)
# Returns: Generates complete audit report
################################################################################
function audit_repository {
    # Display audit start message
    echo ""
    echo "Starting audit for repository: ${REPO_OWNER}/${REPO_NAME}"
    echo "Timestamp: $(date)"
    echo ""
    
    # Initialize output file with header
    echo "GitHub Repository Collaborators Audit Report" > "$OUTPUT_FILE"
    echo "Repository: ${REPO_OWNER}/${REPO_NAME}" >> "$OUTPUT_FILE"
    echo "Generated: $(date)" >> "$OUTPUT_FILE"
    echo "==========================================" >> "$OUTPUT_FILE"
    
    # Define the API endpoint for fetching collaborators
    local endpoint="repos/${REPO_OWNER}/${REPO_NAME}/collaborators"
    
    # Make API request to get all collaborators
    echo "Fetching collaborators from GitHub API..."
    local collaborators=$(github_api_get "$endpoint")
    
    # Check if API request was successful
    if [[ -z "$collaborators" ]]; then
        echo "Error: Unable to fetch collaborators. Please check:"
        echo "  1. Repository exists: ${REPO_OWNER}/${REPO_NAME}"
        echo "  2. Your token has correct permissions"
        echo "  3. Your internet connection"
        exit 1
    fi
    
    # Check if repository has any collaborators
    if [[ "$collaborators" == "[]" ]]; then
        echo "No collaborators found for ${REPO_OWNER}/${REPO_NAME}"
        exit 0
    fi
    
    # Generate all sections of the report
    list_admin_users "$collaborators"
    list_write_users "$collaborators"
    list_read_users "$collaborators"
    get_collaborator_stats "$collaborators"
    
    # Display completion message
    echo ""
    echo "=========================================="
    echo "Audit completed successfully!"
    echo "Report saved to: $OUTPUT_FILE"
    echo "=========================================="
}

# ============================================================================
# SCRIPT EXECUTION STARTS HERE
# ============================================================================

# Step 1: Validate all inputs and prerequisites
validate_inputs

# Step 2: Run the complete audit
audit_repository

# Step 3: Exit successfully
exit 0
