#!/bin/zsh

# Vérifier si gum est installé
if ! command -v gum &> /dev/null; then
    echo "gum n'est pas installé. Veuillez l'installer via Homebrew avec 'brew install gum'."
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

# Vérifier et créer la liste si nécessaire
create_list_if_not_exists

# Ajouter un rappel si un argument est spécifié
if [ $# -gt 0 ]; then
    add_reminder "$*"
    exit 0
fi

# Fonction pour afficher les rappels et interagir
function choose_reminder {
    while true; do
        # Créer un fichier temporaire
        TEMP_FILE=$(mktemp)
        # Nettoyer le fichier temporaire en cas d'interruption
        trap 'rm -f "$TEMP_FILE"' EXIT

        # Récupérer les rappels de la liste
        gum spin --spinner dot --title "Récupération des rappels..." --show-output -- osascript -e "tell application \"Reminders\" to get name of reminders of list \"$LIST_NAME\"" > "$TEMP_FILE"
        REMINDERS=$(<"$TEMP_FILE")
        rm "$TEMP_FILE"

        # Si la liste est vide alors proposer automatiquement d'ajouter un rappel
        if [ -z "$REMINDERS" ]; then
            # Offrir la possibilité d'ajouter un rappel si la liste est vide
            ACTION=$(gum choose --header "Aucun rappel trouvé dans la liste \"$LIST_NAME\". Veux-tu ajouter ton premier rappel ?" "Yep" "Nop")
            if [ "$ACTION" = "Nop" ]; then
                exit 0
            elif [ "$ACTION" = "Yep" ]; then
                NEW_REMINDER=$(gum input --placeholder "Entre ton premier rappel ici !")
                if [ -n "$NEW_REMINDER" ]; then
                    add_reminder "$NEW_REMINDER"
                else
                    echo "Aucun rappel ajouté."
                fi
                continue
            fi
        fi

        # Séparer les rappels par des nouvelles lignes en remplaçant ", "
        REMINDERS=$(echo "$REMINDERS" | sed 's/, /\n/g')

        # Lire les rappels dans un tableau
        REMINDERS_ARRAY=()
        while IFS= read -r line; do
            REMINDERS_ARRAY+=("$line")
        done <<< "$REMINDERS"
        REMINDERS_ARRAY+=("Ajouter un rappel")
        REMINDERS_ARRAY+=("Exit")

        # Construire la chaîne pour gum choose
        REMINDER_CHOICES=$(printf "%s\n" "${REMINDERS_ARRAY[@]}")

        # Afficher les rappels et permettre à l'utilisateur de choisir
        CHOSEN_REMINDER=$(echo -e "$REMINDER_CHOICES" | gum choose --header "Voici tes rappels, tu peux les modifier, les supprimer, les marquer comme finis ou en ajouter de nouveaux :")
        if [ "$CHOSEN_REMINDER" = "Exit" ]; then
            exit 0
        elif [ "$CHOSEN_REMINDER" = "Ajouter un rappel" ]; then
            # Ajouter un nouveau rappel
            NEW_REMINDER=$(gum input --placeholder "Entre le nouveau rappel")
            if [ -n "$NEW_REMINDER" ]; then
                add_reminder "$NEW_REMINDER"
            else
                echo "Aucun rappel ajouté."
            fi
            continue
        fi

        # Demander à l'utilisateur s'il veut renommer, supprimer ou marquer comme fini le rappel
        ACTION=$(printf "Renommer\nSupprimer\nMarquer comme fini\n" | gum choose --header "Choisis une action :")

        if [ "$ACTION" = "Supprimer" ]; then
            # Supprimer le rappel
            gum spin --spinner dot --title "Suppression du rappel..." -- osascript -e "tell application \"Reminders\" to delete (first reminder whose name is \"$CHOSEN_REMINDER\") of list \"$LIST_NAME\"" > /dev/null
            if [ $? -eq 0 ]; then
                echo "Rappel supprimé: '$CHOSEN_REMINDER'"
            else
                echo "Échec de la suppression du rappel: '$CHOSEN_REMINDER'"
            fi
        elif [ "$ACTION" = "Renommer" ]; then
            # Renommer le rappel
            NEW_NAME=$(gum input --value="$CHOSEN_REMINDER" --placeholder "Entre un nouveau nom !")
            if [ -n "$NEW_NAME" ]; then
                gum spin --spinner dot --title "Modification du rappel..." -- osascript -e "tell application \"Reminders\" to set name of (first reminder whose name is \"$CHOSEN_REMINDER\") of list \"$LIST_NAME\" to \"$NEW_NAME\"" > /dev/null
                if [ $? -eq 0 ]; then
                    echo "Rappel modifié: '$NEW_NAME'"
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
            else
                echo "Échec du marquage du rappel comme fini: '$CHOSEN_REMINDER'"
            fi
        fi
    done
}

# Appeler la fonction pour afficher les rappels et permettre l'interaction
choose_reminder