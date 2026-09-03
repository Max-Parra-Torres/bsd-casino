#!/usr/bin/env bash
#
# highlow.sh — guess whether the next card is higher or lower.
# Part of the casino-games suite.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=lib_cards.sh
source "${SCRIPT_DIR}/lib_cards.sh"

bankroll=${1:-100}

get_bet() {
    local bet
    while true; do
        read -rp "Bankroll: \$${bankroll}. Enter your bet: " bet
        if [[ "$bet" =~ ^[0-9]+$ ]] && ((bet > 0)) && ((bet <= bankroll)); then
            echo "$bet"
            return
        fi
        echo "Enter a whole number between 1 and $bankroll."
    done
}

play_round() {
    local bet guess current_order next_order
    bet=$(get_bet)

    build_deck
    draw_card
    local current=$DRAWN_CARD
    echo "Current card: $(display_card "$current")"

    while true; do
        read -rp "Will the next card be (h)igher, (l)ower, or (s)ame? " guess
        case "$guess" in
            h|H|l|L|s|S) break ;;
            *) echo "Type 'h', 'l', or 's'." ;;
        esac
    done

    draw_card
    local next=$DRAWN_CARD
    echo "Next card: $(display_card "$next")"

    current_order=$(card_order "$current")
    next_order=$(card_order "$next")

    local correct=false
    if [[ "$guess" =~ ^[Hh]$ ]] && ((next_order > current_order)); then
        correct=true
    elif [[ "$guess" =~ ^[Ll]$ ]] && ((next_order < current_order)); then
        correct=true
    elif [[ "$guess" =~ ^[Ss]$ ]] && ((next_order == current_order)); then
        correct=true
    fi

    if $correct; then
        if [[ "$guess" =~ ^[Ss]$ ]]; then
            # Same-rank guess is a long shot: pay out more.
            local winnings=$((bet * 10))
            echo "Correct! Same rank — big payout: you win \$${winnings}."
            bankroll=$((bankroll + winnings))
        else
            echo "Correct! You win \$${bet}."
            bankroll=$((bankroll + bet))
        fi
    else
        echo "Wrong. You lose \$${bet}."
        bankroll=$((bankroll - bet))
    fi
}

main() {
    echo "===================================="
    echo "         BASH HIGH-LOW"
    echo "===================================="
    echo "Starting bankroll: \$${bankroll}"

    while ((bankroll > 0)); do
        play_round
        echo
        echo "Bankroll: \$${bankroll}"

        if ((bankroll <= 0)); then
            echo "You're out of money. Game over."
            break
        fi

        local again
        read -rp "Play another round? (y/n) " again
        [[ "$again" =~ ^[Yy]$ ]] || break
        echo
    done

    echo "Final bankroll: \$${bankroll}. Thanks for playing!"
}

main
