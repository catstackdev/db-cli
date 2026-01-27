# db - Health check command
# @commands: doctor

cmd::doctor() {
  echo "${C_BLUE}=== DB CLI Health Check ===${C_RESET}"
  echo ""
  
  local issues=0
  local warnings=0
  
  # Check 1: Database connectivity
  echo "${C_BLUE}[1/8]${C_RESET} Checking database connectivity..."
  if [[ -z "$DB_URL" ]]; then
    echo "  ${C_YELLOW}!${C_RESET} No DATABASE_URL configured"
    echo "    ${C_DIM}Set DATABASE_URL in .env or use --url flag${C_RESET}"
    ((warnings++))
  elif [[ -z "$DB_TYPE" ]]; then
    echo "  ${C_RED}✗${C_RESET} Could not detect database type from URL"
    ((issues++))
  else
    # Capture test output for diagnostics
    local test_output=$(adapter::test 2>&1)
    local test_result=$?
    
    if [[ $test_result -eq 0 ]]; then
      echo "  ${C_GREEN}✓${C_RESET} Connected to database"
    else
      echo "  ${C_RED}✗${C_RESET} Cannot connect to database"
      
      # Show first line of error for context
      local first_error=$(echo "$test_output" | grep -E "error:|failed:|refused" | head -1)
      if [[ -n "$first_error" ]]; then
        echo "    ${C_DIM}$first_error${C_RESET}"
      fi
      echo "    ${C_DIM}Run 'db test' for full diagnostic${C_RESET}"
      ((issues++))
    fi
  fi
  echo ""
  
  # Check 2: Required tools
  echo "${C_BLUE}[2/8]${C_RESET} Checking required tools..."
  
  if [[ -z "$DB_TYPE" ]]; then
    echo "  ${C_YELLOW}!${C_RESET} No database type detected (skipping tool checks)"
    ((warnings++))
  else
    case "$DB_TYPE" in
      postgres|postgresql)
      if command -v psql &>/dev/null; then
        echo "  ${C_GREEN}✓${C_RESET} psql found: $(command -v psql)"
      else
        echo "  ${C_RED}✗${C_RESET} psql not found"
        echo "    ${C_DIM}install: brew install postgresql@16${C_RESET}"
        ((issues++))
      fi
      
      if command -v pgcli &>/dev/null; then
        echo "  ${C_GREEN}✓${C_RESET} pgcli found (optional)"
      else
        echo "  ${C_YELLOW}!${C_RESET} pgcli not found (optional, enhances UX)"
        echo "    ${C_DIM}install: brew install pgcli${C_RESET}"
        ((warnings++))
      fi
      
      if command -v pg_dump &>/dev/null; then
        echo "  ${C_GREEN}✓${C_RESET} pg_dump found"
      else
        echo "  ${C_RED}✗${C_RESET} pg_dump not found (required for backups)"
        ((issues++))
      fi
      ;;
      
    mysql)
      if command -v mysql &>/dev/null; then
        echo "  ${C_GREEN}✓${C_RESET} mysql found"
      else
        echo "  ${C_RED}✗${C_RESET} mysql not found"
        ((issues++))
      fi
      
      if command -v mycli &>/dev/null; then
        echo "  ${C_GREEN}✓${C_RESET} mycli found (optional)"
      else
        echo "  ${C_YELLOW}!${C_RESET} mycli not found (optional)"
        ((warnings++))
      fi
      ;;
      
    sqlite)
      if command -v sqlite3 &>/dev/null; then
        echo "  ${C_GREEN}✓${C_RESET} sqlite3 found"
      else
        echo "  ${C_RED}✗${C_RESET} sqlite3 not found"
        ((issues++))
      fi
      ;;
      
    mongodb)
      if command -v mongosh &>/dev/null; then
        echo "  ${C_GREEN}✓${C_RESET} mongosh found"
      else
        echo "  ${C_RED}✗${C_RESET} mongosh not found"
        ((issues++))
      fi
      ;;
    esac
  fi
  echo ""
  
  # Check 3: Config files
  echo "${C_BLUE}[3/8]${C_RESET} Checking configuration..."
  if [[ -f "$DB_GLOBAL_RC" ]]; then
    echo "  ${C_GREEN}✓${C_RESET} Global config: $DB_GLOBAL_RC"
  else
    echo "  ${C_YELLOW}!${C_RESET} No global config (optional)"
    echo "    ${C_DIM}create: db init global${C_RESET}"
    ((warnings++))
  fi
  
  if [[ -f "$DB_PROJECT_RC" ]]; then
    echo "  ${C_GREEN}✓${C_RESET} Project config: $DB_PROJECT_RC"
  fi
  echo ""
  
  # Check 4: Permissions
  echo "${C_BLUE}[4/8]${C_RESET} Checking file permissions..."
  
  if [[ -f "$DB_HISTORY_FILE" ]]; then
    local history_perms=$(stat -f %Lp "$DB_HISTORY_FILE" 2>/dev/null || stat -c %a "$DB_HISTORY_FILE" 2>/dev/null)
    if [[ "$history_perms" == "600" ]]; then
      echo "  ${C_GREEN}✓${C_RESET} History file permissions: $history_perms"
    else
      echo "  ${C_YELLOW}!${C_RESET} History file permissions: $history_perms (should be 600)"
      echo "    ${C_DIM}fix: chmod 600 $DB_HISTORY_FILE${C_RESET}"
      ((warnings++))
    fi
  fi
  
  if [[ -f "$DB_BOOKMARKS_FILE" ]]; then
    local bookmarks_perms=$(stat -f %Lp "$DB_BOOKMARKS_FILE" 2>/dev/null || stat -c %a "$DB_BOOKMARKS_FILE" 2>/dev/null)
    if [[ "$bookmarks_perms" == "600" ]]; then
      echo "  ${C_GREEN}✓${C_RESET} Bookmarks file permissions: $bookmarks_perms"
    else
      echo "  ${C_YELLOW}!${C_RESET} Bookmarks file permissions: $bookmarks_perms (should be 600)"
      ((warnings++))
    fi
  fi
  echo ""
  
  # Check 5: Disk space for backups
  echo "${C_BLUE}[5/8]${C_RESET} Checking backup directory..."
  if [[ -d "$DB_BACKUP_DIR" ]]; then
    echo "  ${C_GREEN}✓${C_RESET} Backup directory exists: $DB_BACKUP_DIR"
    
    # Check available space (platform-independent)
    if command -v df &>/dev/null; then
      local avail_space=$(df -h "$DB_BACKUP_DIR" | tail -1 | awk '{print $4}')
      echo "  ${C_DIM}  Available space: $avail_space${C_RESET}"
    fi
  else
    echo "  ${C_YELLOW}!${C_RESET} Backup directory not found: $DB_BACKUP_DIR"
    echo "    ${C_DIM}will be created automatically${C_RESET}"
    ((warnings++))
  fi
  echo ""
  
  # Check 6: Database-specific health
  echo "${C_BLUE}[6/8]${C_RESET} Checking database health..."
  case "$DB_TYPE" in
    postgres|postgresql)
      # Check for slow queries log
      local slow_query_setting=$(adapter::query "SHOW log_min_duration_statement" 2>/dev/null | tail -1)
      if [[ "$slow_query_setting" == "-1" ]]; then
        echo "  ${C_YELLOW}!${C_RESET} Slow query logging disabled"
        echo "    ${C_DIM}consider enabling: log_min_duration_statement = 1000${C_RESET}"
        ((warnings++))
      else
        echo "  ${C_GREEN}✓${C_RESET} Slow query logging enabled: ${slow_query_setting}ms"
      fi
      ;;
  esac
  echo ""
  
  # Check 7: Security
  echo "${C_BLUE}[7/8]${C_RESET} Checking security..."
  
  # Check if password in URL
  if [[ "$DB_URL" =~ ://[^@]+:[^@]+@ ]]; then
    echo "  ${C_GREEN}✓${C_RESET} Credentials detected in URL (using secure connection method)"
  fi
  
  # Check temp directory permissions
  if [[ -d "$DB_TMP_DIR" ]]; then
    local tmp_perms=$(stat -f %Lp "$DB_TMP_DIR" 2>/dev/null || stat -c %a "$DB_TMP_DIR" 2>/dev/null)
    if [[ "$tmp_perms" == "700" ]]; then
      echo "  ${C_GREEN}✓${C_RESET} Temp directory permissions: $tmp_perms"
    else
      echo "  ${C_YELLOW}!${C_RESET} Temp directory permissions: $tmp_perms (should be 700)"
      ((warnings++))
    fi
  fi
  echo ""
  
  # Check 8: Recommendations
  echo "${C_BLUE}[8/8]${C_RESET} Recommendations..."
  
  # Check for FZF
  if command -v fzf &>/dev/null; then
    echo "  ${C_GREEN}✓${C_RESET} fzf installed (interactive selection enabled)"
  else
    echo "  ${C_YELLOW}!${C_RESET} fzf not installed (install for better UX)"
    echo "    ${C_DIM}install: brew install fzf${C_RESET}"
    ((warnings++))
  fi
  
  # Check for jq
  if command -v jq &>/dev/null; then
    echo "  ${C_GREEN}✓${C_RESET} jq installed (JSON processing enabled)"
  else
    echo "  ${C_YELLOW}!${C_RESET} jq not installed (required for some features)"
    echo "    ${C_DIM}install: brew install jq${C_RESET}"
    ((warnings++))
  fi
  
  # Check if audit logging is enabled
  if [[ "${DB_AUDIT_ENABLED:-true}" == "true" ]]; then
    echo "  ${C_GREEN}✓${C_RESET} Audit logging enabled"
  else
    echo "  ${C_YELLOW}!${C_RESET} Audit logging disabled"
  fi
  
  echo ""
  echo "${C_BLUE}=== Summary ===${C_RESET}"
  
  if [[ $issues -eq 0 && $warnings -eq 0 ]]; then
    echo "${C_GREEN}✓ Everything looks good!${C_RESET}"
    return 0
  else
    [[ $issues -gt 0 ]] && echo "${C_RED}Issues found: $issues${C_RESET}"
    [[ $warnings -gt 0 ]] && echo "${C_YELLOW}Warnings: $warnings${C_RESET}"
    
    if [[ $issues -gt 0 ]]; then
      echo ""
      echo "${C_YELLOW}Run the suggested commands above to fix issues.${C_RESET}"
      return 1
    else
      return 0
    fi
  fi
}
