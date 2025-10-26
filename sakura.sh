#!/bin/bash

# --- Parse Command Line Arguments ---
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -n, --num-leaves NUM       Number of falling leaves (default: 30)"
    echo "  -d, --delay SECONDS        Animation delay in seconds (default: 0.1)"
    echo "  -p, --petal-color R,G,B    Petal RGB color (default: 255,105,180 pink)"
    echo "  -b, --bg-color R,G,B       Background RGB color (optional)"
    echo "  -D, --drift NUM            Fixed drift per frame (default: 1)"
    echo "  -w, --wind-factor NUM      Wind random wobble factor (default: 1)"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "RGB values: 0-255 for each component (Red,Green,Blue)"
    echo ""
    echo "Examples:"
    echo "  $0 -p 255,192,203           # Light pink petals"
    echo "  $0 -p 255,0,0 -b 0,0,0      # Red petals on black background"
    echo "  $0 -p 0,255,255             # Cyan petals"
    exit 0
}

# --- Configuration ---
NUM_PETALS=30
DELAY=0.08  # Lower value means higher speed of falling

# Default colors in RGB
PETAL_R=255
PETAL_G=105
PETAL_B=180
BG_R=55
BG_G=58
BG_B=59

# --- WIND/DRIFT SETTINGS (Integer Math) ---
FIXED_DRIFT=1 
WIND_RANDOM_FACTOR=1 

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--num-leaves)
            NUM_PETALS="$2"
            shift 2
            ;;
        -d|--delay)
            DELAY="$2"
            shift 2
            ;;
        -p|--petal-color)
            IFS=',' read -r PETAL_R PETAL_G PETAL_B <<< "$2"
            shift 2
            ;;
        -b|--bg-color)
            IFS=',' read -r BG_R BG_G BG_B <<< "$2"
            shift 2
            ;;
        -D|--drift)
            FIXED_DRIFT="$2"
            shift 2
            ;;
        -w|--wind-factor)
            WIND_RANDOM_FACTOR="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            ;;
    esac
done

PETAL_COLOR="\033[38;2;${PETAL_R};${PETAL_G};${PETAL_B}m"
BG_COLOR="\033[48;2;${BG_R};${BG_G};${BG_B}m"

# --- Petal Characters ---
declare -a PETAL_CHARS=("*" "•" "o" "." "❀" "✿") 
NUM_PETAL_CHARS=${#PETAL_CHARS[@]}

# --- Terminal Setup ---
COLS=$(tput cols)
LINES=$(tput lines)
MAX_OFF_SCREEN_Y=20
MAX_OFF_SCREEN_X=$((LINES+MAX_OFF_SCREEN_Y))

# --- Cursor Functions ---
CURSOR_MOVE() { echo -e -n "\033[$1;$2H"; }
CURSOR_HOME="\033[H"

# --- Cleanup Function ---
cleanup() {
    echo -e -n "\033[?25h"  # Show cursor
    echo -e "\033[0m"        # Reset colors
    clear
    exit 0
}

# Trap Ctrl+C to run cleanup
trap cleanup SIGINT SIGTERM

# --- Arrays to store leaf positions ---
declare -a leaf_x
declare -a leaf_y
declare -a prev_x
declare -a prev_y

# --- Initialize ---
echo -e -n "\033[?25l"  # Hide cursor
clear

# Initialize leaf positions randomly
for ((i=0; i<NUM_PETALS; i++)); do
    leaf_x[$i]=$(( (RANDOM % (COLS + MAX_OFF_SCREEN_X)) - MAX_OFF_SCREEN_X ))
    leaf_y[$i]=$(( (RANDOM % (LINES + MAX_OFF_SCREEN_Y)) - MAX_OFF_SCREEN_Y ))
    prev_x[$i]=${leaf_x[$i]}
    prev_y[$i]=${leaf_y[$i]}
done

clear
tput setab 0  # Set background (might need adjustment)
echo -e -n "${BG_COLOR}"

# Fill entire visible area
for ((row=1; row<=LINES; row++)); do
    tput cup $((row-1)) 0
    printf "%${COLS}s" ""
done
tput cup 0 0

# --- Falling Animation Loop ---
while true; do
    
    echo -e -n "$CURSOR_HOME"
    
    for ((i=0; i<NUM_PETALS; i++)); do
        # 1. Erase the leaf at its ACTUAL previous position
        if [ ${prev_y[$i]} -ge 1 ] && [ ${prev_y[$i]} -le $LINES ] && [ ${prev_x[$i]} -ge 1 ] && [ ${prev_x[$i]} -le $COLS ]; then
            CURSOR_MOVE ${prev_y[$i]} ${prev_x[$i]}
            echo -n " "
        fi
        
        # 5. Store position as previous ONLY if not at bottom
        if [ ${leaf_y[$i]} -lt $LINES ]; then
            prev_x[$i]=${leaf_x[$i]}
            prev_y[$i]=${leaf_y[$i]}
        fi

        # 2. Update vertical position (fall down)
        leaf_y[$i]=$((leaf_y[$i] + 1))
        # 3. Apply wind/drift
        RANDOM_WOBBLE=$(( (RANDOM % (2 * WIND_RANDOM_FACTOR + 1)) - WIND_RANDOM_FACTOR ))
        DRIFT=$((FIXED_DRIFT + RANDOM_WOBBLE))
        leaf_x[$i]=$((leaf_x[$i] + DRIFT))
        
        # 4. Draw the leaf at its new position (if on screen)
        if [ ${leaf_y[$i]} -ge 1 ] && [ ${leaf_y[$i]} -le $LINES ] && [ ${leaf_x[$i]} -ge 1 ] && [ ${leaf_x[$i]} -le $COLS ]; then
            # Pick a random petal every frame
            RANDOM_INDEX=$((RANDOM % NUM_PETAL_CHARS))
            CURRENT_PETAL=${PETAL_CHARS[$RANDOM_INDEX]}
            
            CURSOR_MOVE ${leaf_y[$i]} ${leaf_x[$i]}
            echo -e -n "${PETAL_COLOR}${CURRENT_PETAL}${BG_COLOR}"
        fi
        
        # 6. Reset leaf if it goes off screen
        if [ ${leaf_y[$i]} -gt $LINES ]; then
            # Leaf reached the BOTTOM (ground) - respawn at top (disappear from bottom)
            leaf_y[$i]=$(( (RANDOM % MAX_OFF_SCREEN_Y) - MAX_OFF_SCREEN_Y ))
            leaf_x[$i]=$(( (RANDOM % (COLS + MAX_OFF_SCREEN_X)) - MAX_OFF_SCREEN_X ))
            # Set prev to invalid position so erase logic skips it, in order for petal to pile at bottom
            prev_y[$i]=0
        elif [ ${leaf_x[$i]} -gt $COLS ]; then
            leaf_y[$i]=$(( (RANDOM % MAX_OFF_SCREEN_Y) - MAX_OFF_SCREEN_Y ))
            leaf_x[$i]=$(( (RANDOM % (COLS + MAX_OFF_SCREEN_X)) - MAX_OFF_SCREEN_X ))
        fi
    done
    
    # 7. Wait for the next frame
    sleep $DELAY
done
