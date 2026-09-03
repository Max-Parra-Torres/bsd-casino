#!/usr/bin/env bash
#
# blackjack.sh — CLI Blackjack, part of the casino-games suite.
#
# Rules:
#   - Single 52-card deck, reshuffled each round.
#   - Dealer hits until 17+, stands on 17+ (no soft-17 hitting).
#   - Blackjack (natural 21 on first two cards) pays 3:2.
#   - Double down: on your first two cards only, ends your turn after
#     exactly one more card and doubles your bet.
#
# Pacing: cards are dealt one at a time with a short pause, and each
# result line pauses briefly too, so the game doesn't dump everything on
# screen at once. Override the defaults with:
#   CASINO_CARD_PACE=0.2 CASINO_LINE_PACE=0.5 ./blackjack.sh
#
# Usage: ./blackjack.sh  (or launched from ./casino)

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=lib_cards.sh
source "${SCRIPT_DIR}/lib_cards.sh"

player_hand=()
dealer_hand=()
bankroll=${1:-100}

CARD_PACE=${CASINO_CARD_PACE:-1}
LINE_PACE=${CASINO_LINE_PACE:-0.9}

# Formats a number as a dollar amount without ever putting a literal "$"
# directly next to a variable expansion inside a quoted string — that
# adjacency is what makes hand-edited/copy-pasted scripts fragile.
money() {
    printf '$%d' "$1"
}

# Prints a line, then pauses — used for narrative beats (results,
# announcements) so they don't all land in the same instant.
say() {
    echo "$1"
    sleep "$LINE_PACE"
}

# Wraps each card of a hand in brackets, e.g. "[10♣] [A♥]".
wrap_hand() {
    local out=()
    local c
    for c in "$@"; do
        out+=("[$(display_card "$c")]")
    done
    echo "${out[*]}"
}

is_blackjack() {
    local hand=("$@")
    ((${#hand[@]} == 2)) && (($(hand_value "${hand[@]}") == 21))
}

divider() { echo "------------------------------------"; }

new_screen() {
    clear
    echo "===================================="
    echo "        BASH BLACKJACK"
    echo "===================================="
    echo "Bankroll: $(money "$bankroll")"
    divider
}

# Redraws the table: dealer on top, player on bottom.
# Pass "hidden" to hide the dealer's hole card. Tolerates a hand that
# isn't fully dealt yet (used while cards are still being dealt out).
show_table() {
    local dealer_mode=$1

    if [[ "$dealer_mode" == "hidden" ]]; then
        local parts=()
        local i
        for i in "${!dealer_hand[@]}"; do
            if ((i == 0)); then
                parts+=("[$(display_card "${dealer_hand[$i]}")]")
            else
                parts+=("[??]")
            fi
        done
        echo "Dealer: ${parts[*]}"
    else
        echo "Dealer: $(wrap_hand "${dealer_hand[@]}")  (value: $(hand_value "${dealer_hand[@]}"))"
    fi

    echo "You:    $(wrap_hand "${player_hand[@]}")  (value: $(hand_value "${player_hand[@]}"))"

    divider
}

# Draws one card into the named hand ("player" or "dealer"), redraws the
# table, and pauses — so the deal happens one card at a time.
deal_one() {
    local who=$1
    local dealer_mode=${2:-hidden}
    draw_card
    if [[ "$who" == "player" ]]; then
        player_hand+=("$DRAWN_CARD")
    else
        dealer_hand+=("$DRAWN_CARD")
    fi
    new_screen
    show_table "$dealer_mode"
    sleep "$CARD_PACE"
}

get_bet() {
    local bet prompt
    while true; do
        prompt="Bankroll: $(money "$bankroll"). Enter your bet: "
        read -rp "$prompt" bet
        if [[ "$bet" =~ ^[0-9]+$ ]] && ((bet > 0)) && ((bet <= bankroll)); then
            echo "$bet"
            return
        fi
        echo "Enter a whole number between 1 and $bankroll."
    done
}

play_round() {
    local bet
    bet=$(get_bet)

    build_deck
    player_hand=()
    dealer_hand=()

    new_screen
    show_table hidden
    say "Dealing..."

    deal_one player hidden
    deal_one dealer hidden
    deal_one player hidden
    deal_one dealer hidden

    if is_blackjack "${player_hand[@]}"; then
        if is_blackjack "${dealer_hand[@]}"; then
            new_screen
            show_table revealed
            say "Both have Blackjack! Push."
        else
            new_screen
            show_table revealed
            say "Blackjack! You win 3:2 ($(money $((bet * 3 / 2))))."
            bankroll=$((bankroll + bet * 3 / 2))
        fi
        return
    fi

    while true; do
        local pval
        pval=$(hand_value "${player_hand[@]}")

        if ((pval > 21)); then
            new_screen
            show_table revealed
            say "Bust! You lose $(money "$bet")."
            bankroll=$((bankroll - bet))
            return
        fi

        local can_double=false
        if ((${#player_hand[@]} == 2)) && ((bet * 2 <= bankroll)); then
            can_double=true
        fi

        local action prompt_text="(h)it or (s)tand? "
        $can_double && prompt_text="(h)it, (s)tand, or (d)ouble down? "
        read -rp "$prompt_text" action
        case "$action" in
            h|H)
                deal_one player hidden
                ;;
            s|S)
                break
                ;;
            d|D)
                if ! $can_double; then
                    say "You can only double down on your first two cards, and only if your bankroll covers it."
                    continue
                fi
                bet=$((bet * 2))
                deal_one player hidden
                say "Doubled down — your turn is over."
                break
                ;;
            *)
                echo "Type 'h', 's'$($can_double && echo ", or 'd'")."
                ;;
        esac
    done

    local pval_after
    pval_after=$(hand_value "${player_hand[@]}")
    if ((pval_after > 21)); then
        new_screen
        show_table revealed
        say "Bust! You lose $(money "$bet")."
        bankroll=$((bankroll - bet))
        return
    fi

    new_screen
    say "Dealer reveals hand..."
    show_table revealed
    sleep "$LINE_PACE"

    while (($(hand_value "${dealer_hand[@]}") < 17)); do
	# Let sleep here for a little longer for readability
	sleep 1.5
	new_screen
        draw_card; dealer_hand+=("$DRAWN_CARD")
        show_table revealed
        sleep "$CARD_PACE"
    done

    local pval dval
    pval=$(hand_value "${player_hand[@]}")
    dval=$(hand_value "${dealer_hand[@]}")

    if ((dval > 21)); then
        say "Dealer busts! You win $(money "$bet")."
        bankroll=$((bankroll + bet))
    elif ((pval > dval)); then
        say "You win $(money "$bet")!"
        bankroll=$((bankroll + bet))
    elif ((pval < dval)); then
        say "Dealer wins. You lose $(money "$bet")."
        bankroll=$((bankroll - bet))
    else
        say "Push. Bet returned."
    fi
}

main() {
    new_screen

    while ((bankroll > 0)); do
        play_round
        echo
        echo "Bankroll: $(money "$bankroll")"

        if ((bankroll <= 0)); then
            say "You're out of money. Game over."
            break
        fi

        local again
        read -rp "Play another round? (y/n) " again
        [[ "$again" =~ ^[Yy]$ ]] || break
    done

    echo "Final bankroll: $(money "$bankroll"). Thanks for playing!"
}

main
