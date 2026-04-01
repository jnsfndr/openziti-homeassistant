#!/usr/bin/with-contenv bashio
####################################################################################################
# OpenZiti Add-on — Initialization Script
# Runs once at container start before services begin.
# Handles: PreCheck, directory migration, enrollment, identity validation.
#
# Enrollment strategy:
#   If a JWT is provided via config, it is saved as a .jwt file in the identity directory.
#   ziti-edge-tunnel auto-enrolls all *.jwt files in --identity-dir at startup.
#   After successful enrollment, the .jwt file is consumed and a .json identity is created.
####################################################################################################

RUNTIME="/opt/openziti/ziti-edge-tunnel"

####################################################################################################
# Functions
####################################################################################################

function PreCheck() {
    local RuntimeVersion SystemArch

    RuntimeVersion="$("${RUNTIME}" version 2>/dev/null || echo "ERROR")"
    SystemArch="$(arch)"
    bashio::log.info "Runtime version: ${RuntimeVersion}"
    bashio::log.info "Architecture: ${SystemArch}"

    # Migrate old directory structure from NicFragale/HA-NetFoundry
    if [[ -d "/share/NetFoundry" ]]; then
        bashio::log.warning "Found old directory structure. Renaming /share/NetFoundry -> /share/openziti..."
        mv -vf "/share/NetFoundry" "/share/openziti"
    fi

    # Create identity directory if it does not exist
    if [[ ! -d "${IDENTITYDIRECTORY}" ]]; then
        bashio::log.info "Creating identity directory: ${IDENTITYDIRECTORY}"
        mkdir -p "${IDENTITYDIRECTORY}"
    fi

    # Clean up IPC socket from previous runs to avoid permission issues
    # See: https://netfoundry.io/docs/openziti/reference/tunnelers/linux/linux-tunnel-troubleshooting
    if [[ -d /tmp/.ziti ]]; then
        bashio::log.info "Cleaning up stale IPC socket directory /tmp/.ziti"
        rm -rf /tmp/.ziti
    fi
}

function SaveJWTForAutoEnrollment() {
    local ENROLLJWT="${1}"
    local JWT_FILE="${IDENTITYDIRECTORY}/ZTID-$(date +"%Y%m%d_%H%M%S").jwt"

    bashio::log.notice "ENROLLMENT: Saving JWT for auto-enrollment at tunnel startup"
    bashio::log.info "ENROLLMENT: JWT file: ${JWT_FILE}"

    echo "${ENROLLJWT}" > "${JWT_FILE}"

    if [[ -s "${JWT_FILE}" ]]; then
        bashio::log.notice "ENROLLMENT: JWT saved — will be auto-enrolled when tunnel starts"
    else
        bashio::log.error "ENROLLMENT: Failed to save JWT file"
        rm -f "${JWT_FILE}"
    fi
}

function IdentityCheck() {
    local JSON_COUNT JWT_COUNT

    JSON_COUNT="$(find "${IDENTITYDIRECTORY}" -type f -name "*.json" 2>/dev/null | wc -l)"
    JWT_COUNT="$(find "${IDENTITYDIRECTORY}" -type f -name "*.jwt" 2>/dev/null | wc -l)"

    if [[ "${JSON_COUNT}" -gt 0 ]]; then
        bashio::log.info "Found ${JSON_COUNT} enrolled identity file(s):"
        find "${IDENTITYDIRECTORY}" -type f -name "*.json" | while read -r ID; do
            bashio::log.info "  IDENTITY: ${ID}"
        done
    fi

    if [[ "${JWT_COUNT}" -gt 0 ]]; then
        bashio::log.info "Found ${JWT_COUNT} JWT file(s) pending auto-enrollment:"
        find "${IDENTITYDIRECTORY}" -type f -name "*.jwt" | while read -r JWT; do
            bashio::log.info "  PENDING: ${JWT}"
        done
    fi

    if [[ "${JSON_COUNT}" -eq 0 ]] && [[ "${JWT_COUNT}" -eq 0 ]]; then
        bashio::log.error "No identity files (.json) and no enrollment tokens (.jwt) found in ${IDENTITYDIRECTORY}"
        bashio::log.error "Please provide an EnrollmentJWT in the add-on configuration."
        bashio::exit.nok "No valid identities or enrollment tokens available."
    fi
}

####################################################################################################
# Main
####################################################################################################

IDENTITYDIRECTORY="$(bashio::config 'IdentityDirectory')"
ENROLLJWT="$(bashio::config 'EnrollmentJWT')"

bashio::log.notice "=== OpenZiti Add-on Initialization ==="

# Run pre-checks
PreCheck

# Save JWT for auto-enrollment if provided
if bashio::var.has_value "${ENROLLJWT}"; then
    bashio::log.info "Enrollment JWT provided — saving for auto-enrollment..."
    SaveJWTForAutoEnrollment "${ENROLLJWT}"
else
    bashio::log.info "No enrollment JWT provided — skipping."
fi

# Verify at least one identity or pending JWT exists
IdentityCheck

bashio::log.notice "=== Initialization complete ==="
