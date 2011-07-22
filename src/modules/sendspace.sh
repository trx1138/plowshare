#!/bin/bash
#
# sendspace.com module
# Copyright (c) 2010-2011 Plowshare team
#
# This file is part of Plowshare.
#
# Plowshare is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Plowshare is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Plowshare.  If not, see <http://www.gnu.org/licenses/>.

MODULE_SENDSPACE_REGEXP_URL="http://\(www\.\)\?sendspace\.com/\(file\|folder\)/"

MODULE_SENDSPACE_DOWNLOAD_OPTIONS=""
MODULE_SENDSPACE_DOWNLOAD_RESUME=yes
MODULE_SENDSPACE_DOWNLOAD_FINAL_LINK_NEEDS_COOKIE=unused

MODULE_SENDSPACE_LIST_OPTIONS=""

# Output a sendspace file download URL
# $1: cookie file (unused here)
# $2: sendspace.com url
# stdout: real file download link
sendspace_download() {
    local URL="$2"

    if match 'sendspace\.com\/folder\/' "$URL"; then
        log_error "This is a directory list, use plowlist!"
        return 1
    fi

    local FILE_URL=$(curl -L --data "download=1" "$URL" | \
        parse_attr 'spn_download_link' 'href' 2>/dev/null) ||
        { log_debug "file not found"; return $ERR_LINK_DEAD; }

    test "$CHECK_LINK" && return 0

    local FILE_NAME=$(curl -I "$FILE_URL" | \
        grep_http_header_content_disposition) || return 1

    echo "$FILE_URL"
    echo "$FILE_NAME"
}

# List a sendspace shared folder
# $1: sendspace folder URL
# stdout: list of links (file and/or folder)
sendspace_list() {
    local URL="$1"

    if ! match 'sendspace\.com\/folder\/' "$URL"; then
        log_error "This is not a directory list"
        return 1
    fi

    PAGE=$(curl "$URL") || return
    LINKS=$(echo "$PAGE" | parse_all '<td class="dl" align="center"' \
            '\(<a href="http[^<]*<\/a>\)' 2>/dev/null)
    SUBDIRS=$(echo "$PAGE" | parse_all '\/folder\/' \
            '\(<a href="http[^<]*<\/a>\)' 2>/dev/null)

    if [ -z "$LINKS" -a -z "$SUBDIRS" ]; then
        log_debug "empty folder"
        return 0
    fi

    # Stay at depth=1 (we do not recurse into directories)
    LINKS=$(echo "$LINKS" "$SUBDIRS")

    # First pass : print debug message
    while read LINE; do
        FILE_NAME=$(echo "$LINE" | parse_attr 'a' 'title')
        log_debug "$FILE_NAME"
    done <<< "$LINKS"

    # Second pass : print links (stdout)
    while read LINE; do
        FILE_URL=$(echo "$LINE" | parse_attr 'a' 'href')
        echo "$FILE_URL"
    done <<< "$LINKS"

    return 0
}
