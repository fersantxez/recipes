#!/bin/bash

# =========================================================================
# FIX: Set environment variables to C locale to prevent "illegal byte sequence"
# This is the most reliable way to handle non-ASCII characters across shell commands.
# =========================================================================
export LC_CTYPE=C
export LANG=C

# --- CHECK DEPENDENCY ---
if ! command -v id3v2 &> /dev/null
then
    echo "ERROR: 'id3v2' command-line tool is not found."
    echo "Please install it, typically using Homebrew on macOS:"
    echo "  brew install id3v2"
    exit 1
fi

# --- Configuration ---
MAX_FILENAME_LENGTH=200

# Function to clean up the extracted text and create a valid, safe filename
clean_filename() {
    local filename="$1"
    
    # 1. Trim leading/trailing whitespace
    filename=$(echo "$filename" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    # 2. Replace '/' with '-'
    filename=${filename//\// - }
    
    # 3. Remove non-safe characters: keep alphanumeric, spaces, parentheses, dots, and hyphen
    # Since LC_CTYPE=C is set globally, this sed should no longer throw errors.
    filename=$(echo "$filename" | sed 's/[^a-zA-Z0-9 _().-]//g')
    
    # 4. Limit the length
    if [ ${#filename} -gt $MAX_FILENAME_LENGTH ]; then
        filename=${filename:0:$MAX_FILENAME_LENGTH}
    fi
    echo "$filename"
}

# Function to extract a specific tag value (e.g., TPE1 or TIT2) from id3v2 output
extract_tag_value() {
    local tag_id="$1"
    local file_path="$2"
    
    # Use awk for reliable parsing: find the line starting with the tag_id and print everything
    # after the colon and space. This is now safe because the environment is C locale.
    id3v2 -l "$file_path" 2>/dev/null | awk -v tag="$tag_id" '
        $0 ~ "^" tag {
            # Print everything after the first colon and following space
            sub(/^[^:]*: /, "")
            print
            exit
        }
    '
}

echo "Starting MP3 renaming process in $(pwd)..."

# Loop through all MP3 files in the current directory (case-insensitive)
find . -maxdepth 1 -type f -iname "*.mp3" | while IFS= read -r file_path; do
    
    filename=$(basename "$file_path")
    
    echo "--- Processing: '$filename'"

    # --- Extract ID3 Tags using the reliable helper function ---
    artist_raw=$(extract_tag_value "TPE1" "$file_path")
    title_raw=$(extract_tag_value "TIT2" "$file_path")

    # --- Clean up extracted strings ---
    # The artist name (e.g., 'Charlotte Adigéry/Bolis Pupul') is cleaned here
    # The clean_filename function is where the sed error was happening.
    clean_artist=$(clean_filename "$artist_raw")
    clean_title_raw=$(clean_filename "$title_raw")
    
    # --- Check for missing tags *after* cleaning ---
    if [ -z "$clean_artist" ] || [ -z "$clean_title_raw" ]; then
        # Check if the RAW tag was present but the cleanup failed (i.e., became empty)
        if [ ! -z "$artist_raw" ] || [ ! -z "$title_raw" ]; then
             echo "   -> 🛑 Cleaned tag became empty. Reverting to raw data for renaming."
             # Use the raw (problematic) data, but strip path/extension.
             clean_artist=$(basename "$artist_raw")
             clean_title_raw=$(basename "$title_raw")
        else
            echo "   -> ⚠️ Missing tags. Falling back to filename for Title."
            # Use the filename (without extension) for the raw title
            clean_title_raw=$(clean_filename "${filename%.mp3}")
            
            # If the artist is empty, set a default
            if [ -z "$clean_artist" ]; then
                clean_artist="Unknown Artist"
            fi
        fi
        
        if [ -z "$clean_artist" ] || [ -z "$clean_title_raw" ]; then
             echo "   -> 🛑 Filename is also empty after cleanup. Skipping."
             continue
        fi
    fi
    
    # --- Split Title into Base Title and potential Remix/Suffix ---
    song_title="$clean_title_raw"
    remix_suffix=""

    # 1. Check for a suffix in parentheses (Remix)
    remix_match=$(echo "$song_title" | grep -oE '\(([^)]+)\)$' | head -n 1)

    if [ ! -z "$remix_match" ]; then
        # Remove parentheses from the suffix match
        remix_suffix="${remix_match//\(}"
        remix_suffix="${remix_suffix//\)}"
        
        # Remove the parentheses and content from the song title
        song_title="${song_title% ($remix_suffix)}"
    
    # 2. Check for a suffix separated by ' - '
    elif [[ "$song_title" =~ (.*)[[:space:]]-[[:space:]]([^[:space:]].*)$ ]]; then
        # The content after the last ' - ' is the suffix
        remix_suffix="${BASH_REMATCH[2]}"
        # The content before is the new song title
        song_title="${BASH_REMATCH[1]}"
    fi

    # Normalize the remix suffix: put parentheses around it if it's not empty
    if [ ! -z "$remix_suffix" ]; then
        remix_suffix=" ($remix_suffix)"
    fi
    
    # Remove any extra spaces from the base title after potential splitting
    song_title=$(echo "$song_title" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # --- Construct New Filename ---
    # Final format: "artist - song_title (remix).mp3"
    new_filename="${clean_artist} - ${song_title}${remix_suffix}.mp3"
    
    # Check for name collision and handle files that are already correctly named
    if [ "$filename" == "$new_filename" ]; then
        echo "   -> No change needed (already formatted)."
        continue
    fi

    if [ -f "$new_filename" ]; then
        # Append a counter if a file with the same name already exists
        count=1
        base_name="${new_filename%.*}"
        while [ -f "${base_name}.${count}.mp3" ]; do
            count=$((count+1))
        done
        new_filename="${base_name}.${count}.mp3"
        echo "⚠️ Renaming '$filename' to '$new_filename' (Collision Detected)"
    fi

    # --- Rename Action ---
    mv "$file_path" "$new_filename"
    echo "✅ Renamed: '$filename' -> '$new_filename'"

done

echo "MP3 renaming complete."
