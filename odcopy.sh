#!/usr/bin/env bash
# ODRIVE COPY CLOUD TO CLOUD SCRIPT
# Script to copy from one odrive mount to another, recursively.
# Automatically syncs .cloudf files recursively.
# Automatically copies and then unsyncs files.

# INSTRUCTIONS:
#
# 1. Have odrive.py on your PATH
#
# 2. Have odriveagent running
#
# 3. Make sure you are logged in with odrive.py authenticate
#
# 4. Make sure the parent directories of the directories you want to copy are
# synced.
#
# 5. Make sure the directories themselves ar enot synced. The destination
# directory can also be nonexistent.
#
# 6. Run ./odcopy.sh PATH1/TO/SOURCE.cloudf PATH2/TO/DEST.cloudf
#
# The destination directory will be created if it doesn't exist.
#
# Any existing directories will be merged. Any existing files in the destination
# will be left alone.
#
# Nothing fancy is done to protect against or recover from partial copies.

set -e

if [[ "${#}" -ne 2 ]]; then
    echo "Usage: ${0} SOURCE.cloudf DEST.cloudf"
    exit 1
fi

SOURCE_CLOUDF="${1}"
DEST_CLOUDF="${2}"

if [[ ! "${SOURCE_CLOUDF}" == *.cloudf ]]; then
    echo "Source must be an unsynced folder"
    exit 1
fi

if [[ ! "${DEST_CLOUDF}" == *.cloudf ]]; then
    echo "Dest must be an unsynced folder"
    exit 1
fi

SOURCE="${SOURCE_CLOUDF%.cloudf}"
DEST="${DEST_CLOUDF%.cloudf}"


function synchronize_file() {
    # We're going to copy this one absolute .cloud path to this other one.
    local FROM_CLOUD="${1}"
    local TO_CLOUD="${2}"
    
    local CONTAINING_FOLDER="$(dirname "${TO_CLOUD}")"
    
    if [[ -f "${TO_CLOUD}" ]]; then
        echo "Destination cloud file ${TO_CLOUD} exists! Skip!"
        return
    fi
    
    # We assume the directories are already synced and extant.
    echo "Copy ${FROM_CLOUD}"
    echo "Stream ${FROM_CLOUD} to ${TO_CLOUD%.cloud}"
    
    # Download the file
    odrive.py stream "${FROM_CLOUD}" >"${TO_CLOUD%.cloud}"
    
    # Sync the folder
    
    odrive.py refresh "${CONTAINING_FOLDER}"
    
    while [ "$(odrive.py syncstate "${TO_CLOUD%.cloud}" | head -n1)" != 'Synced' ]; do
        echo "Waiting for ${TO_CLOUD%.cloud} to sync"
        sleep 1
    done
    
    odrive.py unsync "${TO_CLOUD%.cloud}" # Succeeds even if unsync didn't
    until [[ -f "${TO_CLOUD}" ]]; do
        echo "Waiting for ${TO_CLOUD%.cloud} to unsync"
        sleep 1
        odrive.py unsync "${TO_CLOUD%.cloud}"
    done
    
    echo "File ${TO_CLOUD} complete"
    
}

function synchronize_directory() {
    # We're going to copy this one absolute .cloudf path to this other one.
    local FROM_CLOUDF="${1}"
    local TO_CLOUDF="${2}"
    
    echo "Recursive copy: ${FROM_CLOUDF} -> ${TO_CLOUDF}"
    
    # Make the directory prefixes
    local FROM_PATH="${FROM_CLOUDF%.cloudf}"
    local TO_PATH="${TO_CLOUDF%.cloudf}"
    
    # Grab the parent directory of any directory we would need to make.
    local TO_PARENT="$(dirname "${TO_CLOUDF}")"
    
    # Download source file list
    echo "Download file list for ${FROM_CLOUDF}"
    odrive.py sync "${FROM_CLOUDF}"
    
    if [[ ! -d "${FROM_CLOUDF%.cloudf}" ]]; then
        echo "Could not get file list for ${FROM_CLOUDF}"
        exit 1
    fi
    
    if [[ ! -e "${TO_CLOUDF}" ]]; then
        # We need to make the directory
        echo "Create directory ${TO_CLOUDF}"
        mkdir "${TO_CLOUDF%.cloudf}"
        
        # Refresh the parent
        echo "Refresh ${TO_PARENT}"
        odrive.py refresh "${TO_PARENT}"
        
        # Wait for the fiolder to go into sync.
        while [ "$(odrive.py syncstate "${TO_CLOUDF%.cloudf}" | head -n1)" != 'Synced' ]; do
            echo "Waiting for ${TO_CLOUDF%.cloudf} to sync"
            odrive.py refresh "${TO_PARENT}"
            sleep 1
        done
    else
        # Download the directory
        echo "Download file list for ${TO_CLOUDF}"
        odrive.py sync "${TO_CLOUDF}"
    fi
    
    if [[ ! -d "${TO_CLOUDF%.cloudf}" ]]; then
        echo "Could not get file list for ${TO_CLOUDF}"
        exit 1
    fi
    
    echo "Copy files across..."
    
    find "${FROM_CLOUDF%.cloudf}" -type f -name "*.cloud" -printf '%p\000' | while IFS= read -r -d '' CLOUD_FILE; do
        # Handle each file in the directory
        
        # Decide its relative path
        local REL_PATH="${CLOUD_FILE#$FROM_PATH}"
        
        # And decide its destination
        local DESTINATION="${TO_PATH}${REL_PATH}"
        
        echo "Want to sync ${CLOUD_FILE} -> ${DESTINATION}"
        
        synchronize_file "${CLOUD_FILE}" "${DESTINATION}"
        
    done
    
    find "${FROM_CLOUDF%.cloudf}" -type f -name "*.cloudf" -printf '%p\000' | while IFS= read -r -d '' CLOUD_DIR; do
        # Handle each file in the directory
        
        # Decide its relative path
        local REL_PATH="${CLOUD_DIR#$FROM_PATH}"
        
        # And decide its destination
        local DESTINATION="${TO_PATH}${REL_PATH}"
        
        echo "Want to sync ${CLOUD_DIR} -> ${DESTINATION}"
        
        # Recurse
        synchronize_directory "${CLOUD_DIR}" "${DESTINATION}"
        
    done
    
    # Delete file lists
    echo "Drop file lists..."
    odrive.py unsync "${FROM_CLOUDF%.cloudf}" # Succeeds even if unsync didn't
    until [[ -f "${FROM_CLOUDF}" ]]; do
        echo "Waiting for ${FROM_CLOUDF%.cloudf} to unsync"
        sleep 1
        odrive.py unsync "${FROM_CLOUDF%.cloudf}"
    done
    
    odrive.py unsync "${TO_CLOUDF%.cloudf}" # Succeeds even if unsync didn't
    until [[ -f "${TO_CLOUDF}" ]]; do
        echo "Waiting for ${TO_CLOUDF%.cloudf} to unsync"
        sleep 1
        odrive.py unsync "${TO_CLOUDF%.cloudf}"
    done
}

synchronize_directory "${SOURCE_CLOUDF}" "${DEST_CLOUDF}"

