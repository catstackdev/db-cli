# db - Self-test command
# @commands: selftest

cmd::selftest() {
  echo "${C_BLUE}=== DB CLI Self-Test ===${C_RESET}"
  echo ""
  
  # Check if we're in the db directory
  local test_dir="$DB_ROOT/tests"
  
  if [[ ! -d "$test_dir" ]]; then
    db::err "Test directory not found: $test_dir"
    echo ""
    echo "This command runs the db CLI test suite (validation & security tests)."
    echo "It does NOT test your database connection (use 'db test' for that)."
    return 1
  fi
  
  # Check if test runner exists
  if [[ ! -x "$test_dir/run_tests.sh" ]]; then
    db::err "Test runner not found or not executable: $test_dir/run_tests.sh"
    return 1
  fi
  
  # Run the test suite
  echo "Running test suite from: $test_dir"
  echo ""
  
  cd "$test_dir" && ./run_tests.sh
  local exit_code=$?
  
  echo ""
  if [[ $exit_code -eq 0 ]]; then
    echo "${C_GREEN}✓ Self-test passed!${C_RESET}"
  else
    echo "${C_RED}✗ Self-test failed${C_RESET}"
  fi
  
  return $exit_code
}
