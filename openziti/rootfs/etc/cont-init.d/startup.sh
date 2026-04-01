#!/usr/bin/with-contenv bashio
####################################################################################################
# OpenZiti Add-on — Initialization Script
# Runs once at container start before services begin.
# Handles: PreCheck, directory migration, enrollment, identity validation.
#
# Enrollment strategy:
#   If a JWT is provided via config, we run explicit enrollment before the tunnel starts.
#   ziti-edge-tunnel enroll converts the JWT into a .json identity file.
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

    # Clean up stale JWT files from previous failed auto-enrollment attempts
    local STALE_JWT_COUNT
    STALE_JWT_COUNT="$(find "${IDENTITYDIRECTORY}" -type f -name "*.jwt" 2>/dev/null | wc -l)"
    if [[ "${STALE_JWT_COUNT}" -gt 0 ]]; then
        bashio::log.warning "Removing ${STALE_JWT_COUNT} stale .jwt file(s) from previous runs"
        find "${IDENTITYDIRECTORY}" -type f -name "*.jwt" -delete
    fi

    # Clean up IPC socket from previous runs to avoid permission issues
    # See: https://netfoundry.io/docs/openziti/reference/tunnelers/linux/linux-tunnel-troubleshooting
    if [[ -d /tmp/.ziti ]]; then
        bashio::log.info "Cleaning up stale IPC socket directory /tmp/.ziti"
        rm -rf /tmp/.ziti
    fi
}

function RunEnrollment() {
    local ENROLLJWT="${1}"
    local IDENTITY_NAME="ZTID-$(date +"%Y%m%d_%H%M%S")"
    local IDENTITY_FILE="${IDENTITYDIRECTORY}/${IDENTITY_NAME}.json"
    local JWT_FILE="/tmp/enroll.jwt"

    bashio::log.notice "ENROLLMENT: Starting..."
    bashio::log.info "ENROLLMENT: Identity will be saved to ${IDENTITY_FILE}"

    # Write JWT to temp file for enrollment
    echo "${ENROLLJWT}" > "${JWT_FILE}"

    if "${RUNTIME}" enroll --jwt "${JWT_FILE}" --identity "${IDENTITY_FILE}" 2>&1; then
        bashio::log.notice "ENROLLMENT: Success — identity saved to ${IDENTITY_FILE}"
    else
        bashio::log.error "ENROLLMENT: Failed — check that the JWT is valid and not expired"
        # Clean up failed enrollment artifacts
        rm -f "${IDENTITY_FILE}"
    fi

    rm -f "${JWT_FILE}"

    # Remove any empty identity files from failed enrollments
    find "${IDENTITYDIRECTORY}" -maxdepth 1 -type f -name "*.json" -empty -delete
}

function IdentityCheck() {
    local JSON_COUNT

    # Count only .json files that are NOT config.json (tunnel status file)
    JSON_COUNT="$(find "${IDENTITYDIRECTORY}" -type f -name "*.json" ! -name "config.json" 2>/dev/null | wc -l)"

    if [[ "${JSON_COUNT}" -gt 0 ]]; then
        bashio::log.info "Found ${JSON_COUNT} enrolled identity file(s):"
        find "${IDENTITYDIRECTORY}" -type f -name "*.json" ! -name "config.json" | while read -r ID; do
            bashio::log.info "  IDENTITY: ${ID}"
        done
    else
        bashio::log.error "No identity files found in ${IDENTITYDIRECTORY}"
        bashio::log.error "Please provide an EnrollmentJWT in the add-on configuration."
        bashio::exit.nok "No valid identities available."
    fi
}

####################################################################################################
# Main
####################################################################################################

IDENTITYDIRECTORY="$(bashio::config 'IdentityDirectory')"
ENROLLJWT="$(bashio::config 'EnrollmentJWT')"

bashio::log.notice "=== OpenZiti Add-on Initialization ==="

# Run pre-checks (also cleans up stale .jwt files)
PreCheck

# Perform enrollment if a JWT is provided
if bashio::var.has_value "${ENROLLJWT}"; then
    bashio::log.info "Enrollment JWT provided — enrolling..."
    RunEnrollment "${ENROLLJWT}"
else
    bashio::log.info "No enrollment JWT provided — skipping enrollment."
fi

# Verify at least one identity exists
IdentityCheck

bashio::log.notice "=== Initialization complete ==="
