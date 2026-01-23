#!/usr/bin/env zsh
# db - REPL command
# @commands: repl

cmd::repl() {
  # Check if rlwrap available for better experience
  if ! command -v rlwrap &>/dev/null; then
    db::warn "For better experience: brew install rlwrap"
  fi
  
  repl::run
}
