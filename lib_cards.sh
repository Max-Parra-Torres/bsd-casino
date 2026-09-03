#!/usr/bin/env bash
#
# lib_cards.sh — shared deck/card helpers for the casino-games suite.
#
# Cards are stored internally as "RANK-SUITLETTER" (e.g. "6-H", "10-S").
# We split on the literal ASCII "-" rather than counting characters/bytes,
# so this works correctly regardless of the system locale (unlike slicing
# off a fixed number of trailing chars/bytes, which breaks once you mix
# single-char ranks like "6" with multi-char ranks like "10").

RANKS=(A 2 3 4 5 6 7 8 9 10 J Q K)
SUIT_LETTERS=(S H D C)

deck=()
DRAWN_CARD=""

build_deck() {
    deck=()
    local suit rank
    for suit in "${SUIT_LETTERS[@]}"; do
        for rank in "${RANKS[@]}"; do
            deck+=("${rank}-${suit}")
        done
    done
    shuffle_deck
}

shuffle_deck() {
    local i j tmp
    local n=${#deck[@]}
    for ((i = n - 1; i > 0; i--)); do
        j=$((RANDOM % (i + 1)))
        tmp=${deck[i]}
        deck[i]=${deck[j]}
        deck[j]=$tmp
    done
}

draw_card() {
    # Pops the last card off the deck into $DRAWN_CARD.
    # Must be called directly (not inside $(...)) so the mutation to the
    # shared `deck` array isn't lost in a subshell.
    DRAWN_CARD=${deck[-1]}
    unset 'deck[-1]'
}

card_rank() {
    local card=$1
    echo "${card%-*}"
}

card_suit_letter() {
    local card=$1
    echo "${card#*-}"
}

card_suit_symbol() {
    local card=$1
    local letter
    letter=$(card_suit_letter "$card")
    case "$letter" in
        S) echo "♠" ;;
        H) echo "♥" ;;
        D) echo "♦" ;;
        C) echo "♣" ;;
        *) echo "?" ;;
    esac
}

# Rank order for high/low style comparisons (A high = 14, matching most
# casual card games; blackjack.sh does its own ace handling separately).
card_order() {
    local rank
    rank=$(card_rank "$1")
    case "$rank" in
        A) echo 14 ;;
        K) echo 13 ;;
        Q) echo 12 ;;
        J) echo 11 ;;
        *) echo "$rank" ;;
    esac
}

display_card() {
    local card=$1
    echo "$(card_rank "$card")$(card_suit_symbol "$card")"
}

display_hand() {
    local out=()
    local c
    for c in "$@"; do
        out+=("$(display_card "$c")")
    done
    echo "${out[*]}"
}

hand_value() {
    # Blackjack scoring: face cards = 10, aces = 11 (downgraded to 1 to
    # avoid busting where possible).
    local total=0
    local aces=0
    local card rank

    for card in "$@"; do
        rank=$(card_rank "$card")
        case "$rank" in
            A) aces=$((aces + 1)); total=$((total + 11)) ;;
            J|Q|K|10) total=$((total + 10)) ;;
            *) total=$((total + rank)) ;;
        esac
    done

    while ((total > 21 && aces > 0)); do
        total=$((total - 10))
        aces=$((aces - 1))
    done

    echo "$total"
}
