#!/data/data/com.termux/files/usr/bin/bash
# qtx-fm — Minimal terminal file manager
# ponytail: read + ls + cd, not ranger

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/colors.sh"

DIR="${1:-.}"
DIR="$(cd "$DIR" 2>/dev/null && pwd || echo "$HOME")"

while true; do
    clear
    echo -e "${CYAN}QTX-FM${NC}  ${DIM}$DIR${NC}"
    echo ""

    # ponytail: ls output with numbering
    items=()
    i=1
    for entry in "$DIR"/*; do
        [ -e "$entry" ] || continue
        name=$(basename "$entry")
        [ "$name" = "." ] || [ "$name" = ".." ] && continue
        if [ -d "$entry" ]; then
            echo -e "  ${GREEN}[$i]${NC} $name/"
        else
            size=$(du -h "$entry" 2>/dev/null | cut -f1)
            echo -e "  ${DIM}[$i]${NC} $name ${DIM}($size)${NC}"
        fi
        items+=("$entry")
        i=$((i + 1))
    done

    # Hidden files
    for entry in "$DIR"/.*; do
        [ -e "$entry" ] || continue
        name=$(basename "$entry")
        [ "$name" = "." ] || [ "$name" = ".." ] && continue
        echo -e "  ${DIM}[$i]${NC} ${DIM}$name${NC}"
        items+=("$entry")
        i=$((i + 1))
    done

    total=${#items[@]}
    echo ""
    echo -e "${DIM}── $total items ──${NC}"
    echo ""
    echo "  [n]ame  [c]d  [d]elete  [m]kdir"
    echo "  [e]dit  [v]iew  [s]earch  [q]uit"
    echo ""

    read -rp ">> " choice

    case "$choice" in
        q|Q) clear; break ;;
        c|C)
            read -rp "cd: " newdir
            [ -d "$newdir" ] && DIR="$(cd "$newdir" && pwd)" || warn "Not a directory"
            ;;
        d|D)
            read -rp "Delete # " idx
            [ "$idx" -ge 1 ] 2>/dev/null && [ "$idx" -le "$total" ] 2>/dev/null || { warn "Invalid"; continue; }
            target="${items[$((idx - 1))]}"
            rm -rf "$target" && ok "Deleted $(basename "$target")" || warn "Failed"
            ;;
        m|M)
            read -rp "New dir name: " dirname
            [ -n "$dirname" ] && mkdir -p "$DIR/$dirname" && ok "Created $dirname"
            ;;
        e|E)
            read -rp "Edit # " idx
            [ "$idx" -ge 1 ] 2>/dev/null && [ "$idx" -le "$total" ] 2>/dev/null || { warn "Invalid"; continue; }
            "${EDITOR:-nano}" "${items[$((idx - 1))]}"
            ;;
        v|V)
            read -rp "View # " idx
            [ "$idx" -ge 1 ] 2>/dev/null && [ "$idx" -le "$total" ] 2>/dev/null || { warn "Invalid"; continue; }
            file="${items[$((idx - 1))]}"
            if [ -f "$file" ]; then
                if has_cmd bat; then
                    bat "$file"
                elif has_cmd less; then
                    less "$file"
                else
                    head -50 "$file"
                fi
                read -rp "Press enter..."
            fi
            ;;
        s|S)
            read -rp "Search: " query
            [ -z "$query" ] && continue
            echo ""
            find "$DIR" -iname "*$query*" -maxdepth 2 2>/dev/null | head -20 | while IFS= read -r r; do
                echo "  $r"
            done
            read -rp "Press enter..."
            ;;
        ''|*[!0-9]*)
            warn "Invalid choice"
            ;;
        *)
            [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "$total" ] 2>/dev/null || { warn "Invalid"; continue; }
            target="${items[$((choice - 1))]}"
            if [ -d "$target" ]; then
                DIR="$target"
            elif [ -f "$target" ]; then
                if has_cmd bat; then
                    bat "$target"
                elif has_cmd less; then
                    less "$target"
                else
                    head -50 "$target"
                fi
                read -rp "Press enter..."
            fi
            ;;
    esac
done
