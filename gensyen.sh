#!/bin/bash

# --- Banner Definition (Corrected Bash Syntax) ---
banner='
  _____            _     _ _
 |  __ \          | |   (_| |
 | |__) |__ _  ___| |__  _| |_
 |  _  // _` |/ __| '_ \| | __|
 | | \ | (_| | (__| | | | | |_
 |_|  \_\__,_|\___|_| |_|_|\__|


'

# --- Style Definitions ---
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
PINK='\033[1;35m' # Using the existing pink color

# --- Print Banner and User Name ---
echo -e "${PINK}${banner}${NORMAL}" # Print the banner
current_user=$(whoami)             # Get the current username
echo -e "${PINK}${BOLD}✨ Script executed by: ${current_user}${NORMAL}" # Print the user's name
echo "" # Add a blank line for spacing

# --- Existing Show Function ---
show() {
    case $2 in
        "error")
            echo -e "${PINK}${BOLD}❌ $1${NORMAL}"
            ;;
        "progress")
            echo -e "${PINK}${BOLD}⏳ $1${NORMAL}"
            ;;
        *)
            echo -e "${PINK}${BOLD}✅ $1${NORMAL}"
            ;;
    esac
}

# --- Rest of the original script ---

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    show "curl is not installed. Installing curl..." "progress"
    # Using apt-get update && apt-get install -y curl for robustness
    sudo apt-get update && sudo apt-get install -y curl
    if [ $? -ne 0 ]; then
        show "Failed to install curl. Please install it manually and rerun the script." "error"
        exit 1
    fi
    show "curl installed successfully."
fi

# Check for existing Node.js installations
EXISTING_NODE=$(which node)
if [ -n "$EXISTING_NODE" ]; then
    show "Existing Node.js found at $EXISTING_NODE. The script will install the latest version system-wide via NodeSource."
fi

# Fetch the latest Node.js version dynamically
show "Fetching latest Node.js version..." "progress"
# Improved robustness for fetching version
LATEST_VERSION=$(curl -sL https://nodejs.org/dist/latest/ | grep -oP 'node-v\K[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
if [ -z "$LATEST_VERSION" ]; then
    show "Failed to fetch latest Node.js version. Please check your internet connection or the Node.js distribution site." "error"
    exit 1
fi
show "Latest Node.js version available is $LATEST_VERSION"

# Extract the major version for NodeSource setup
MAJOR_VERSION=$(echo $LATEST_VERSION | cut -d. -f1)

# Set up the NodeSource repository for the latest major version
show "Setting up NodeSource repository for Node.js $MAJOR_VERSION.x..." "progress"
# Check if the setup script already exists to avoid re-downloading unnecessarily
if [ ! -f "/etc/apt/sources.list.d/nodesource.list" ]; then
    curl -fsSL https://deb.nodesource.com/setup_${MAJOR_VERSION}.x | sudo -E bash -
    if [ $? -ne 0 ]; then
        show "Failed to set up NodeSource repository." "error"
        exit 1
    fi
    show "NodeSource repository set up successfully."
    # Update package list after adding new repo
    show "Updating package list..." "progress"
    sudo apt-get update
    if [ $? -ne 0 ]; then
        show "Failed to update package list after adding NodeSource repository." "error"
        # Decide if this is fatal, often it's okay to proceed but good to warn
    fi
else
    show "NodeSource repository already configured."
fi


# Install Node.js and npm
show "Installing Node.js (version $MAJOR_VERSION.x series) and npm..." "progress"
sudo apt-get install -y nodejs
if [ $? -ne 0 ]; then
    show "Failed to install Node.js and npm." "error"
    exit 1
fi

# Verify installation and PATH availability
show "Verifying installation..." "progress"
if command -v node &> /dev/null && command -v npm &> /dev/null; then
    NODE_VERSION=$(node -v)
    NPM_VERSION=$(npm -v)
    INSTALLED_NODE=$(which node) # Get the path of the node executable found first in PATH

    show "Node.js ${NODE_VERSION} and npm ${NPM_VERSION} installed successfully."

    # Provide more context about the installed path vs PATH
    if [ "$INSTALLED_NODE" != "/usr/bin/node" ] && [ -x "/usr/bin/node" ]; then
         show "Note: The primary 'node' command in your PATH is currently '$INSTALLED_NODE'." "progress"
         show "The NodeSource version was installed to '/usr/bin/node'. Ensure '/usr/bin' is prioritized in your PATH if you want to use this version by default." "progress"
         show "You can check your PATH with: echo \$PATH" "progress"
    elif [ "$INSTALLED_NODE" = "/usr/bin/node" ]; then
         show "The installed Node.js is correctly sourced from /usr/bin/node."
    fi
else
    show "Installation command finished, but 'node' or 'npm' command not found in PATH." "error"
    show "This might indicate an issue with the installation or your system's PATH configuration." "error"
    show "Please check if '/usr/bin' is in your PATH (echo \$PATH) and try opening a new terminal session." "error"
    exit 1
fi

show "Node.js installation process complete!"
