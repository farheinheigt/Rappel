# RAPPEL Project

RAPPEL is a Zsh script that integrates with macOS Reminders to manage your to-do lists directly from the terminal. It uses `gum` for interactive prompts and `osascript` to interact with the Reminders app.

## Features

- **Check for `gum` installation**: Ensures `gum` is installed before proceeding.
- **Create a list if it does not exist**: Automatically creates a specified list in Reminders if it does not exist.
- **Add a reminder**: Adds a new reminder to the specified list.
- **Interactive reminder management**: Allows you to view, add, rename, delete, and mark reminders as completed through interactive prompts.

## Prerequisites

- **gum**: A tool for creating beautiful command-line user interfaces.
- **osascript**: A command-line tool for running AppleScript, typically pre-installed on macOS.

## Installation

1. Install `gum` using Homebrew:
   ```sh
   brew install gum
   ```

2. Save the script as `rappel.sh` in your desired directory, for example, `~/Projects/RAPPEL/`.

## Usage

1. Ensure the script is executable:
   ```sh
   chmod +x ~/Projects/RAPPEL/rappel.sh
   ```

2. Run the script:
   ```sh
   ~/Projects/RAPPEL/rappel.sh
   ```

3. The script will check if the list "HACKING" exists in Reminders and create it if it does not.

4. If no arguments are provided, it will enter interactive mode to manage reminders:
   - **View reminders**: Displays the current reminders in the specified list.
   - **Add a reminder**: Adds a new reminder to the list.
   - **Rename a reminder**: Renames an existing reminder.
   - **Delete a reminder**: Deletes a specified reminder.
   - **Mark as completed**: Marks a reminder as completed.

5. To add a reminder directly from the command line:
   ```sh
   ~/Projects/RAPPEL/rappel.sh "Your reminder text here"
   ```

## Example Script

```zsh
#!/bin/zsh

# Check if gum is installed
if ! command -v gum &> /dev/null; then
    echo "gum is not installed. Please install it via Homebrew with 'brew install gum'."
    exit 1
fi

# List name
LIST_NAME="HACKING"

# Function to create the list if it doesn't exist
function create_list_if_not_exists {
    local list_exist
    # Check if the list exists
    list_exist=$(osascript -e "tell application \"Reminders\" to (name of lists) contains \"$LIST_NAME\"")
    if [ "$list_exist" = "false" ]; then
        # Create the list if it doesn't exist
        gum spin --spinner dot --title "Creating the list '$LIST_NAME'..." -- osascript -e "tell application \"Reminders\" to make new list with properties {name:\"$LIST_NAME\"}" > /dev/null
        echo "List '$LIST_NAME' created successfully."
    fi
}

# Function to add a reminder
function add_reminder {
    local reminder="$1"
    # Add the reminder to the list
    gum spin --spinner dot --title "Adding reminder..." -- osascript -e "tell application \"Reminders\" to make new reminder at end of list \"$LIST_NAME\" with properties {name:\"$reminder\"}" > /dev/null
    if [ $? -eq 0 ]; then
        echo "Reminder added: '$reminder'"
    else
        echo "Failed to add reminder: '$reminder'"
    fi
}

# Check and create the list if necessary
create_list_if_not_exists

# Add a reminder if an argument is specified
if [ $# -gt 0 ]; then
    add_reminder "$*"
    exit 0
fi

# Function to display and interact with reminders
function choose_reminder {
    # Create a temporary file
    TEMP_FILE=$(mktemp)
    # Clean up the temporary file on exit
    trap 'rm -f "$TEMP_FILE"' EXIT

    # Get reminders from the list
    gum spin --spinner dot --title "Retrieving reminders..." --show-output -- osascript -e "tell application \"Reminders\" to get name of reminders of list \"$LIST_NAME\"" > "$TEMP_FILE"
    REMINDERS=$(<"$TEMP_FILE")
    rm "$TEMP_FILE"

    # If the list is empty, offer to add a reminder
    if [ -z "$REMINDERS" ]; then
        ACTION=$(gum choose --header "No reminders found in the list "$LIST_NAME". Would you like to add your first reminder?" "Yes" "No")
        if [ "$ACTION" = "No" ]; then
            exit 0
        elif [ "$ACTION" = "Yes" ]; then
            NEW_REMINDER=$(gum input --placeholder "Enter your first reminder here!")
            if [ -n "$NEW_REMINDER" ]; then
                add_reminder "$NEW_REMINDER"
            else
                echo "No reminder added."
            fi
            exit 0
        fi
    fi

    # Split reminders into new lines
    REMINDERS=$(echo "$REMINDERS" | sed 's/, /
/g')

    # Read reminders into an array
    REMINDERS_ARRAY=()
    while IFS= read -r line; do
        REMINDERS_ARRAY+=("$line")
    done <<< "$REMINDERS"
    REMINDERS_ARRAY+=("Add a reminder")
    REMINDERS_ARRAY+=("Exit")

    # Build the string for gum choose
    REMINDER_CHOICES=$(printf "%s
" "${REMINDERS_ARRAY[@]}")

    # Display reminders and allow the user to choose
    CHOSEN_REMINDER=$(echo -e "$REMINDER_CHOICES" | gum choose --header "Here are your reminders. You can modify, delete, mark as completed, or add new ones:")
    if [ "$CHOSEN_REMINDER" = "Exit" ]; then
        exit 0
    elif [ "$CHOSEN_REMINDER" = "Add a reminder" ]; then
        # Add a new reminder
        NEW_REMINDER=$(gum input --placeholder "Enter the new reminder")
        if [ -n "$NEW_REMINDER" ]; then
            add_reminder "$NEW_REMINDER"
        else
            echo "No reminder added."
        fi
        exit 0
    fi

    # Ask the user if they want to rename, delete, or mark the reminder as completed
    ACTION=$(printf "Rename
Delete
Mark as completed
" | gum choose --header "Choose an action:")

    if [ "$ACTION" = "Delete" ]; then
        # Delete the reminder
        gum spin --spinner dot --title "Deleting reminder..." -- osascript -e "tell application \"Reminders\" to delete (first reminder whose name is \"$CHOSEN_REMINDER\") of list \"$LIST_NAME\"" > /dev/null
        if [ $? -eq 0 ]; then
            echo "Reminder deleted: '$CHOSEN_REMINDER'"
        else
            echo "Failed to delete reminder: '$CHOSEN_REMINDER'"
        fi
    elif [ "$ACTION" = "Rename" ]; then
        # Rename the reminder
        NEW_NAME=$(gum input --value="$CHOSEN_REMINDER" --placeholder "Enter a new name!")
        if [ -n "$NEW_NAME" ]; then
            gum spin --spinner dot --title "Renaming reminder..." -- osascript -e "tell application \"Reminders\" to set name of (first reminder whose name is \"$CHOSEN_REMINDER\") of list \"$LIST_NAME\" to \"$NEW_NAME\"" > /dev/null
            if [ $? -eq 0 ]; then
                echo "Reminder renamed: '$NEW_NAME'"
            else
                echo "Failed to rename reminder: '$CHOSEN_REMINDER'"
            fi
        else
            echo "Reminder name not changed."
        fi
    elif [ "$ACTION" = "Mark as completed" ]; then
        # Mark the reminder as completed
        gum spin --spinner dot --title "Marking reminder as completed..." -- osascript -e "tell application \"Reminders\" to set completed of (first reminder whose name is \"$CHOSEN_REMINDER\") of list \"$LIST_NAME\" to true" > /dev/null
        if [ $? -eq 0 ]; then
            echo "Reminder marked as completed: '$CHOSEN_REMINDER'"
        else
            echo "Failed to mark reminder as completed: '$CHOSEN_REMINDER'"
        fi
    fi
}

# Call the function to display reminders and allow interaction
choose_reminder
```

## Contributing

Contributions are welcome! To report bugs or propose improvements, please open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.
