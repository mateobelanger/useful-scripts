#!/usr/bin/env fish

# Colors and formatting
set -g red (set_color red)
set -g green (set_color green)
set -g yellow (set_color yellow)
set -g blue (set_color blue)
set -g normal (set_color normal)
set -g bold (set_color --bold)

# Log file path
set -g log_file "/tmp/update_log.txt"

# Spinner characters
set -g spinner_chars ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏

# Function to print colored and formatted messages
function print_message
    set color $argv[1]
    set message $argv[2]
    echo -e $color$bold$message$normal
end

# Function to log messages with timestamps
function log_message
    set message $argv[1]
    echo [(date '+%Y-%m-%d %H:%M:%S')] $message >> update_log.txt
end

# Function to run command with spinner animation and custom message
function run_with_spinner
    set cmd $argv[1]
    set message $argv[2]
    test -z "$message"; and set message "Running..."  # Default message if not provided
    
    set temp_file (mktemp)
    set spinner_index 1
    set start_time (date +%s.%N)

    # Start the command in the background
    fish --no-config -c "$cmd" > $temp_file 2>&1 &
    set pid (jobs -p)

    # Display spinner while command is running
    while kill -0 $pid 2>/dev/null
        printf "\r%s %s" $spinner_chars[$spinner_index] $message
        set spinner_index (math "$spinner_index % 10 + 1")
        sleep 0.1
        printf "\033[0K"  # Clear to the end of the line
    end

    # Wait for the command to finish and get its exit status
    wait $pid
    set exit_status $status

    set end_time (date +%s.%N)
    set duration (math "$end_time - $start_time")
    
    if test $exit_status -eq 0
        printf "\r✅ Completed in %.2f seconds\n" $duration
    else
        printf "\r❌ Failed in %.2f seconds\n" $duration
    end

    cat $temp_file >> $log_file
    rm $temp_file

    return $exit_status
end

# Function to update and upgrade using apt, with logging
function update_apt
    print_message $blue "APT Update"
    run_with_spinner "sudo apt-get update -y" "Updating APT..."
    print_message $blue "APT Upgrade"
    run_with_spinner "sudo apt-get upgrade -y" "Upgrading packages..."
end

# Update snaps
function update_snap
    print_message $blue "Snap Refresh"
    run_with_spinner "sudo snap refresh" "Refreshing Snaps..."
end

# Define a function to update and upgrade using brew, with logging
function update_brew
    print_message $blue "Brew Update"
    run_with_spinner "brew update" "Updating Homebrew..."
    print_message $blue "Brew Upgrade"
    run_with_spinner "brew upgrade" "Upgrading Homebrew packages..."
end

# Function to summarize update logs using shell-gpt
function summarize_logs
    set summary_file (mktemp)

    # Use run_with_spinner to show a spinner while generating the summary
    run_with_spinner "cat $log_file | sgpt \"Summarize this system update log in 3-5 bullet points. Focus on critical changes, errors, or actions needed. Start each point with a dash (-). One line per bullet point, add a newline character. Be very concise. Add relevant fish shell font highlighting (color, bold, italic etc).\" > $summary_file" "Generating summary..."

    # Format and display the summary
    echo # Add a newline before the summary
    cat $summary_file | while read -l line
        set line (string trim $line)
        if test -n "$line"
            echo $line
        end
    end

    set summary (cat $summary_file)
    log_message "Update summary: $summary"

    # Clean up temporary file
    rm $summary_file
end

function run_updates
    print_message $yellow "Executing updates"
    log_message "Update process started"

    rm -f $log_file  # Clear the log file

    update_apt
    
    if type -q snap
        update_snap
    else
        print_message $yellow "Snap is not installed. Skipping snap updates."
    end

    if type -q brew
        update_brew
    else
        print_message $yellow "Homebrew is not installed. Skipping brew updates."
    end

    print_message $green "✅ Updates completed."
    log_message "Update process completed"

    print_message $yellow "\nUpdate Summary"
    summarize_logs "Generating summary..." 

    # Check for system restart requirement
    if test -f /var/run/reboot-required
        print_message $yellow "⚠️ A system restart is required to complete the update process."
        read -l -P "Do you want to restart now? [y/N] " confirm
        switch $confirm
            case Y y
                sudo reboot
            case '' N n
                print_message $yellow "Please remember to restart your system later."
        end
    end
end

# Run the main function
function update-system
    run_updates
end
