#!/usr/bin/env bash
#
# slots.sh — CLI slot machine, part of the casino-games suite.

set -euo pipefail

SYMBOLS=(🍒 🍋 🔔 ⭐ 💎 7️⃣)
bankroll=${1:-100}

spin_reel() {
    echo "${SYMBOLS[$((RANDOM % ${#SYMBOLS[@]}))]}"
}

payout_for() {
    # $1 $2 $3 are the three symbols.
    local a=$1 b=$2 c=$3
    if [[ "$a" == "$b" && "$b" == "$c" ]]; then
        case "$a" in
            7️⃣) echo 20 ;;   # jackpot
            💎) echo 10 ;;
            ⭐) echo 8 ;;
            🔔) echo 5 ;;
            *) echo 3 ;;
        esac
    elif [[ "$a" == "$b" || "$b" == "$c" || "$a" == "$c" ]]; then
        echo 1
    else
        echo 0
    fi
}

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
    local bet r1 r2 r3 mult winnings
    bet=$(get_bet)

    r1=$(spin_reel); r2=$(spin_reel); r3=$(spin_reel)

    echo "------------------------------------"
    echo "   [ $r1 | $r2 | $r3 ]"
    echo "------------------------------------"

    mult=$(payout_for "$r1" "$r2" "$r3")

    if ((mult == 0)); then
        echo "No match. You lose \$${bet}."
        bankroll=$((bankroll - bet))
    else
        winnings=$((bet * mult))
        echo "Match! Payout x${mult} — you win \$${winnings}."
        bankroll=$((bankroll + winnings))
    fi
}

main() {
    echo "===================================="
    echo "         BASH SLOTS"
    echo "===================================="
    echo "Starting bankroll: \$${bankroll}"
    echo "(3-of-a-kind pays out most; 7️⃣7️⃣7️⃣ is the jackpot)"

    while ((bankroll > 0)); do
        play_round
        echo
        echo "Bankroll: \$${bankroll}"

        if ((bankroll <= 0)); then
            echo "You're out of money. Game over."
            break
        fi

        local again
        read -rp "Spin again? (y/n) " again
        [[ "$again" =~ ^[Yy]$ ]] || break
        echo
    done

    echo "Final bankroll: \$${bankroll}. Thanks for playing!"
}

main
