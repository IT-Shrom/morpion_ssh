#!/bin/bash

ROOM="${1:-default}"
BASE="/tmp/morpion_ssh_$ROOM"
STATE="$BASE/state"
PLAYERS="$BASE/players"
LOCKFILE="$BASE/lockfile"

mkdir -p "$BASE"
chmod 777 "$BASE"

init_game() {
    if [[ ! -f "$STATE" ]]; then
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
        chmod 666 "$STATE"
    fi

    if [[ ! -f "$PLAYERS" ]]; then
        : > "$PLAYERS"
        chmod 666 "$PLAYERS"
    fi

    if [[ ! -f "$LOCKFILE" ]]; then
        : > "$LOCKFILE"
        chmod 666 "$LOCKFILE"
    fi
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
    chmod 666 "$STATE"
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
    exec 9>"$LOCKFILE"
    flock 9

    init_game

    if grep -q "^${USER}:" "$PLAYERS" 2>/dev/null; then
        MOI=$(grep "^${USER}:" "$PLAYERS" | head -n1 | cut -d: -f2)
        flock -u 9
        return
    fi

    local count
    count=$(wc -l < "$PLAYERS")

    if [[ "$count" -eq 0 ]]; then
        MOI="X"
        echo "${USER}:X" >> "$PLAYERS"
        echo "En attente du joueur O..."
    elif [[ "$count" -eq 1 ]]; then
        MOI="O"
        echo "${USER}:O" >> "$PLAYERS"
        echo "Joueur O connecté. La partie commence."
    else
        flock -u 9
        echo "La salle est pleine."
        exit 1
    fi

    flock -u 9
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
    exec 9>"$LOCKFILE"
    flock 9

    if [[ -f "$PLAYERS" ]]; then
        grep -v "^${USER}:" "$PLAYERS" > "$PLAYERS.tmp" 2>/dev/null || true
        mv "$PLAYERS.tmp" "$PLAYERS" 2>/dev/null || true
        chmod 666 "$PLAYERS" 2>/dev/null || true
    fi

    flock -u 9
}

trap cleanup_player EXIT

init_game
register_player
wait_for_second_player

while true; do
    load_state
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
        echo "Tour de l'autre joueur..."
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

    exec 9>"$LOCKFILE"
    flock 9

    load_state

    if [[ "$terminee" -eq 1 ]]; then
        flock -u 9
        continue
    fi

    if [[ "$joueur" != "$MOI" ]]; then
        flock -u 9
        continue
    fi

    if ! case_disponible "$choix"; then
        flock -u 9
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
    flock -u 9
done
