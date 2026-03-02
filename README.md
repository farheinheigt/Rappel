# rappel

Gestionnaire de rappels macOS en `zsh`, branché sur l'application `Reminders` via `osascript`.

## Entree utilisateur

- Commande: `bin/rappel`
- Script principal: `rappel.sh`
- Helper Rust local pour le spinner: `bin/rappel-spin`

## Exemples

```bash
./bin/rappel
./bin/rappel "Acheter du cafe"
```

## Dependances

- Shell: `zsh`
- Requises: `osascript`, `fzf`
- Selon l'usage: `gum`, `figlet`, `cal` (util-linux)

## Notes

- La liste cible par defaut reste `HACKING`.
- Les interactions `gum choose` et `gum input` sont conservees.
- Les anciennes utilisations de `gum spin` ont ete remplacees par un helper Rust local.
- Les binaires Rust locaux restent confines au repo via `target/`.
