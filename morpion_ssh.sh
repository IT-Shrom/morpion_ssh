#!/bin/bash

ROOM="${1:-default}"
BASE="/tmp/morpion_ssh_$ROOM"

STATE="$BASE.state"
PLAYERS="$BASE.players"
LOCKDIR="$BASE.lock"

mkdir -p /tmp

lock() {
    while ! mkdir "$LOCKDIR" 2>/dev/null; do
        sleep 0.1
    done
}

unlock() {
    rmdir "$LOCKDIR" 2>/dev/null
}

init_game() {
    mkdir -p "$BASE"
    cat > "$STATE" <<EOF
c1=1
c2=2
c3=3
c4=4
c5=5
c6=6
c7=7
c8=8
c9=9
joueur=X
coups=0
gagnant=
terminee=0
EOF
    : > "$PLAYERS"
}

load_state() {
    # shellcheck disable=SC1090
    . "$STATE"
}

save_state() {
    cat > "$STATE" <<EOF
c1=$c1
c2=$c2
c3=$c3
c4=$c4
c5=$c5
c6=$c6
c7=$c7
c8=$c8
c9=$c9
joueur=$joueur
coups=$coups
gagnant=$gagnant
terminee=$terminee
EOF
}

display_grid() {
    clear
    echo "Salle : $ROOM"
    echo "Tu joues : $MOI"
    echo
    echo " $c1 | $c2 | $c3 "
    echo "---+---+---"
    echo " $c4 | $c5 | $c6 "
    echo "---+---+---"
    echo " $c7 | $c8 | $c9 "
    echo
}

get_case() {
    case "$1" in
        1) echo "$c1" ;;
        2) echo "$c2" ;;
        3) echo "$c3" ;;
        4) echo "$c4" ;;
        5) echo "$c5" ;;
        6) echo "$c6" ;;
        7) echo "$c7" ;;
        8) echo "$c8" ;;
        9) echo "$c9" ;;
    esac
}

set_case() {
    case "$1" in
        1) c1="$2" ;;
        2) c2="$2" ;;
        3) c3="$2" ;;
        4) c4="$2" ;;
        5) c5="$2" ;;
        6) c6="$2" ;;
        7) c7="$2" ;;
        8) c8="$2" ;;
        9) c9="$2" ;;
    esac
}

case_disponible() {
    local v
    v=$(get_case "$1")
    [[ "$v" != "X" && "$v" != "O" ]]
}

verifier_victoire() {
    [[ "$c1" == "$c2" && "$c2" == "$c3" ]] && return 0
    [[ "$c4" == "$c5" && "$c5" == "$c6" ]] && return 0
    [[ "$c7" == "$c8" && "$c8" == "$c9" ]] && return 0

    [[ "$c1" == "$c4" && "$c4" == "$c7" ]] && return 0
    [[ "$c2" == "$c5" && "$c5" == "$c8" ]] && return 0
    [[ "$c3" == "$c6" && "$c6" == "$c9" ]] && return 0

    [[ "$c1" == "$c5" && "$c5" == "$c9" ]] && return 0
    [[ "$c3" == "$c5" && "$c5" == "$c7" ]] && return 0

    return 1
}

register_player() {
    lock

    [[ -d "$BASE" ]] || init_game
    [[ -f "$PLAYERS" ]] || : > "$PLAYERS"

    local count
    count=$(wc -l < "$PLAYERS")

    if grep -q "^$$:" "$PLAYERS" 2>/dev/null; then
        MOI=$(grep "^$$:" "$PLAYERS" | cut -d: -f2)
        unlock
        return
    fi

    if [[ "$count" -eq 0 ]]; then
        MOI="X"
        echo "$$:X" >> "$PLAYERS"
        echo "En attente du joueur O..."
    elif [[ "$count" -eq 1 ]]; then
        MOI="O"
        echo "$$:O" >> "$PLAYERS"
        echo "Joueur O connecté. La partie commence."
    else
        unlock
        echo "La salle est pleine."
        exit 1
    fi

    unlock
}

wait_for_second_player() {
    while true; do
        local count
        count=$(wc -l < "$PLAYERS")
        [[ "$count" -ge 2 ]] && break
        sleep 1
    done
}

cleanup_player() {
    lock
    if [[ -f "$PLAYERS" ]]; then
        grep -v "^$$:" "$PLAYERS" > "$PLAYERS.tmp" 2>/dev/null || true
        mv "$PLAYERS.tmp" "$PLAYERS" 2>/dev/null || true
    fi
    unlock
}

trap cleanup_player EXIT

register_player
wait_for_second_player

while true; do
    lock
    load_state
    unlock

    display_grid

    if [[ "$terminee" -eq 1 ]]; then
        if [[ -n "$gagnant" ]]; then
            if [[ "$gagnant" == "$MOI" ]]; then
                echo "Tu as gagné !"
            else
                echo "Le joueur $gagnant a gagné."
            fi
        else
            echo "Match nul !"
        fi
        break
    fi

    if [[ "$joueur" != "$MOI" ]]; then
        echo "Tour de l'autre joueur... actualisation."
        sleep 1
        continue
    fi

    echo "À toi de jouer ($MOI). Choisis une case (1-9) :"
    read -r choix

    case "$choix" in
        1|2|3|4|5|6|7|8|9) ;;
        *)
            echo "Entrée invalide."
            sleep 1
            continue
            ;;
    esac

    lock
    load_state

    if [[ "$terminee" -eq 1 ]]; then
        unlock
        continue
    fi

    if [[ "$joueur" != "$MOI" ]]; then
        unlock
        continue
    fi

    if ! case_disponible "$choix"; then
        unlock
        echo "Case déjà prise."
        sleep 1
        continue
    fi

    set_case "$choix" "$MOI"
    coups=$((coups + 1))

    if verifier_victoire; then
        gagnant="$MOI"
        terminee=1
    elif [[ "$coups" -eq 9 ]]; then
        gagnant=""
        terminee=1
    else
        if [[ "$joueur" == "X" ]]; then
            joueur="O"
        else
            joueur="X"
        fi
    fi

    save_state
    unlock
done