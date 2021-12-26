# Async git information in a ZSH prompt

This isn't really packaged up in the most consumable way, but this is the
program I use to generate my shell prompt. It runs in about 12ms on my machine
even in large git repos, but renders an indication of whether or not there are
uncommitted changes in the repo. It does this by running `git status` in the
background and redrawing the prompt when it's done.

The key here is that running `zle reset-prompt` will cause the prompt to be
regenerated, so we configure ZSH to run that when it handles `SIGALRM`. The
prompt program forks and disowns a process that continues to run after the
prompt is printed, and sends `SIGALRM` to the shell when the background process
is done.

This is the chunk I put in my `~/.zshrc`:

```zsh
PROMPT='$(
  PS1_EXEC_NO=$__ps1_exec_no \
  EXIT_STATUS=$? \
  SHADOWENV_DATA=${__shadowenv_data%%:*} \
  SHELL_PID=$$ \
  async-shell-prompt
)'

function __ps1_exec_incr() {
  __ps1_exec_no=$((__ps1_exec_no+1))
}
precmd_functions+=(__ps1_exec_incr)
TRAPALRM() {
  # Without this conditional, we sometimes get the following error. It seems to
  # happen when SIGALRM lands while executing a command; that is, between ZLE
  # instances.
  #   TRAPALRM:zle:1: widgets can only be called when ZLE is active
  if [[ -n "$WIDGET" ]]; then
    zle reset-prompt
  fi
}
```

The `__ps1_exec_no` is incremented on `precmd`, so that when we call the program
multiple times via `zle reset-prompt`, it is able to understand that it still
corresponds to the same prompt line.

The program here is pretty rough: the code sucks and it's _very_ bad for leaking
files in `/tmp`.
