#!/bin/bash

# flatten_dir.sh: flatten a hierarchy of directories and copy/move files
# into a destination directory.

read -r -p "Directory to flatten [.]: " SRC
SRC=${SRC:-.}

read -r -p "Destination for flattened files [.]: " DEST
DEST=${DEST:-.}

if [ ! -d "$SRC" ]; then
    echo "Error: source directory does not exist: $SRC"
    exit 1
fi

if [ ! -d "$DEST" ]; then
    echo "Error: destination directory does not exist: $DEST"
    exit 1
fi

echo
echo "Source:      $SRC"
echo "Destination: $DEST"
echo

read -r -p "Proceed? [y/N]: " CONFIRM
case "$CONFIRM" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled."; exit 0 ;;
esac

echo
echo "Choose operation:"
echo "  1) Move files"
echo "  2) Copy files"
read -r -p "Choice [1]: " ACTION
ACTION=${ACTION:-1}

case "$ACTION" in
    1)
        CMD="mv -i"
        MOVE=true
        ;;
    2)
        CMD="cp -i"
        MOVE=false
        ;;
    *)
        echo "Invalid choice."
        exit 1
        ;;
esac

find "$SRC" -mindepth 2 -type f -exec $CMD '{}' "$DEST" \;

if [ "$MOVE" = true ]; then
    echo
    read -r -p "Delete intermediate empty directories? [y/N]: " DELETE_DIRS

    case "$DELETE_DIRS" in
        y|Y|yes|YES)
            find "$SRC" -depth -type d -empty -delete
            echo "Empty directories removed."
            ;;
        *)
            echo "Directories kept."
            ;;
    esac
fi

echo "Done."
