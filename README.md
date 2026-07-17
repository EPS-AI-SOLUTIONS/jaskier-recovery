# jaskier-recovery

Bootstrap odzyskiwania środowiska Jaskier (3 CLI: Claude Code, Codex, Gemini) po awarii dysku lub całego komputera.

## Użycie (na świeżym Windows 11)

```powershell
iwr -useb https://raw.githubusercontent.com/EPS-AI-SOLUTIONS/jaskier-recovery/main/odzysk.ps1 | iex
```

Potrzebujesz **wyłącznie hasła głównego Bitwarden** (konto: `pawelserkowski@gmail.com`, serwer `vault.bitwarden.eu`) + 2FA lub recovery code.

Skrypt:
1. instaluje narzędzia (git, gh, node, python, bw, age) przez winget,
2. odblokowuje Bitwarden i pobiera `DR/github-pat` oraz `DR/age-key`,
3. klonuje prywatne `EPS-AI-SOLUTIONS/jaskier-memory-dr` (pamięć + configi + kreator),
4. uruchamia `restore/restore-all.ps1` — idempotentny kreator pełnego odtworzenia.

**To repo jest publiczne i nie zawiera żadnych sekretów.** Pełny runbook: `jaskier-memory-dr/restore/RESTORE.md`.
