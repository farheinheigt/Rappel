#!/bin/zsh

# Vérifier si gum est installé
if ! command -v gum >/dev/null 2>&1; then
    echo "gum n'est pas installé. Veuillez l'installer via Homebrew avec 'brew install gum'."
    exit 1
fi

# Vérifier si fzf est installé
if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf n'est pas installé. Veuillez l'installer via Homebrew avec 'brew install fzf'."
    exit 1
fi

# Nom de la liste
LIST_NAME="HACKING"

# Fonction pour créer la liste si elle n'existe pas
function create_list_if_not_exists {
    local list_exist
    # Vérifier si la liste existe
    list_exist=$(osascript -e "tell application \"Reminders\" to (name of lists) contains \"$LIST_NAME\"")
    if [ "$list_exist" = "false" ]; then
        # Créer la liste si elle n'existe pas
        gum spin --spinner dot --title "Création de la liste '$LIST_NAME'..." -- osascript -e "tell application \"Reminders\" to make new list with properties {name:\"$LIST_NAME\"}" > /dev/null
        echo "Liste '$LIST_NAME' créée avec succès."
    fi
}

# Fonction pour ajouter un rappel
function add_reminder {
    local reminder="$1"
    # Ajouter le rappel à la liste
    gum spin --spinner dot --title "Ajout du rappel..." -- osascript -e "tell application \"Reminders\" to make new reminder at end of list \"$LIST_NAME\" with properties {name:\"$reminder\"}" > /dev/null
    if [ $? -eq 0 ]; then
        echo "Rappel ajouté: '$reminder'"
    else
        echo "Échec de l'ajout du rappel: '$reminder'"
    fi
}

figlet Rappel Moi

# Vérifier et créer la liste si nécessaire
create_list_if_not_exists

# Ajouter un rappel si un argument est spécifié
if [ $# -gt 0 ]; then
    add_reminder "$*"
    exit 0
fi

# Fonction pour afficher les rappels et interagir
function choose_reminder {
    # Créer un fichier temporaire
    TEMP_FILE=$(mktemp)
    # Nettoyer le fichier temporaire en cas d'interruption
    trap 'rm -f "$TEMP_FILE"' EXIT

    # Charger les rappels
    load_reminders

    while true; do
        # Lire les rappels dans un tableau, chaque ligne étant un rappel distinct
        REMINDERS_ARRAY=()
        while IFS= read -r line; do
            REMINDERS_ARRAY+=("$line")
        done <<< "$REMINDERS"

        # Construire la liste des options principales
        MAIN_CHOICES="Voir les rappels\nAjouter un rappel\nExit"

        # Afficher les choix principaux et permettre à l'utilisateur de choisir
        CHOSEN_ACTION=$(echo -e "$MAIN_CHOICES" | gum choose --header "Que veux-tu faire ?" --height=30)

        if [ "$CHOSEN_ACTION" = "Exit" ]; then
            exit 0
        elif [ "$CHOSEN_ACTION" = "Ajouter un rappel" ]; then
            # Ajouter un nouveau rappel
            NEW_REMINDER=$(gum input --placeholder "Entre le nouveau rappel" --width=300)
            if [ -n "$NEW_REMINDER" ]; then
                add_reminder "$NEW_REMINDER"
                load_reminders # Recharge les rappels après ajout
            else
                echo "Aucun rappel ajouté."
            fi
        elif [ "$CHOSEN_ACTION" = "Voir les rappels" ]; then
            while true; do
                # Afficher les rappels avec fzf et permettre à l'utilisateur de choisir
                CHOSEN_REMINDER=$(printf "%s\n" "${REMINDERS_ARRAY[@]}" | fzf --header="Voici tes rappels, recherche ou sélectionne un rappel :" --height=30% --border --ansi --prompt="Rappel > ")

                if [ -z "$CHOSEN_REMINDER" ]; then
                    break
                fi

                # Ajouter l'option "Retour" dans le sous-menu d'actions
                ACTION=$(printf "Modifier le rappel\nSupprimer le rappel\nMarquer comme fini\n" | gum choose --header "Choisis une action :")
                
                if [ -z "$ACTION" ]; then
                    continue
                elif [ "$ACTION" = "Supprimer le rappel" ]; then
                    # Supprimer le rappel
                    gum spin --spinner dot --title "Suppression du rappel..." -- osascript -e "tell application \"Reminders\" to delete (first reminder whose name is \"$CHOSEN_REMINDER\") of list \"$LIST_NAME\"" > /dev/null
                    if [ $? -eq 0 ]; then
                        echo "Rappel supprimé: '$CHOSEN_REMINDER'"
                        load_reminders # Recharge les rappels après suppression
                        break
                    else
                        echo "Échec de la suppression du rappel: '$CHOSEN_REMINDER'"
                    fi
                elif [ "$ACTION" = "Modifier le rappel" ]; then
                    # Modifier le rappel
                    NEW_NAME=$(gum input --value="$CHOSEN_REMINDER" --placeholder "Entre un nouveau nom !" --width=300)
                    if [ -n "$NEW_NAME" ]; then
                        gum spin --spinner dot --title "Modification du rappel..." -- osascript -e "tell application \"Reminders\" to set name of (first reminder whose name is \"$CHOSEN_REMINDER\") of list \"$LIST_NAME\" to \"$NEW_NAME\"" > /dev/null
                        if [ $? -eq 0 ]; then
                            echo "Rappel modifié: '$NEW_NAME'"
                            load_reminders # Recharge les rappels après modification
                            break
                        else
                            echo "Échec de la modification du rappel: '$CHOSEN_REMINDER'"
                        fi
                    else
                        echo "Nom de rappel non modifié."
                    fi
                elif [ "$ACTION" = "Marquer comme fini" ]; then
                    # Marquer le rappel comme fini
                    gum spin --spinner dot --title "Marquage du rappel comme fini..." -- osascript -e "tell application \"Reminders\" to set completed of (first reminder whose name is \"$CHOSEN_REMINDER\") of list \"$LIST_NAME\" to true" > /dev/null
                    if [ $? -eq 0 ]; then
                        echo "Rappel marqué comme fini: '$CHOSEN_REMINDER'"
                        load_reminders # Recharge les rappels après marquage comme fini
                        break
                    else
                        echo "Échec du marquage du rappel comme fini: '$CHOSEN_REMINDER'"
                    fi
                fi
            done
        fi
    done
}

# Fonction pour charger les rappels
function load_reminders {
    gum spin --spinner dot --title "Actualisation de la liste de rappels..." --show-output -- osascript -e 'tell application "Reminders" to set reminderNames to (name of reminders of list "'$LIST_NAME'")' -e 'set combinedNames to ""' -e 'repeat with reminderName in reminderNames' -e 'set combinedNames to combinedNames & reminderName & linefeed' -e 'end repeat' -e 'return combinedNames' > "$TEMP_FILE"

    if [ ! -s "$TEMP_FILE" ]; then
        echo "Erreur: Impossible de récupérer les rappels."
        rm "$TEMP_FILE"
        exit 1
    fi

    REMINDERS=$(<"$TEMP_FILE")
}

# Appeler la fonction pour afficher les rappels et permettre l'interaction
choose_reminder