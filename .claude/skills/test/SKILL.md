---
name: test
description: Use when running unit tests, verifying test results, or during TDD red-green-refactor cycles
---

# Run Unit Tests

Run Swift Testing unit tests and capture output for analysis.

## Usage

- `/test` - Run all tests
- `/test -s SuiteName` - Run specific test suite
- `/test -o custom.txt` - Run all tests with custom output filename
- `/test -s SuiteName -o custom.txt` - Run specific suite with custom output
- `/test -s SuiteName --no-parallel` - Run without parallel testing (isolate crashes)
- `/test -s SuiteName --timeout 10` - Set max seconds per test (prevent crash loops)

## Workflow

1. Run the test script (clears previous output if exists, runs xcodebuild)
1. Script prints: summary line, output file path, and `.xcresult` path
1. Use grep commands below to analyze results
1. On failure, read the output file for full details

## Commands

```bash
# All tests → results/all-tests.txt
.claude/skills/test/run-tests.py

# Specific suite → results/SuiteName.txt
.claude/skills/test/run-tests.py -s SuiteName

# Custom output filename → results/custom.txt
.claude/skills/test/run-tests.py -o custom.txt

# Debugging: isolate crashes
.claude/skills/test/run-tests.py -s SuiteName --no-parallel --timeout 10
```

## Checking Results

```bash
# Summary (replace OUTPUT_FILE with actual filename)
grep -E "^\*\* TEST|Test session results" .claude/skills/test/results/OUTPUT_FILE

# Failure details
grep -E "failed|error:|FAILED" .claude/skills/test/results/OUTPUT_FILE
```

## Output File

The script prints the output path after each run. Use the Read tool to examine full details. Do not re-run tests just to check different aspects of the output.

## Debugging Crashes

- Use `--no-parallel` and `--timeout N` flags to isolate crashes and prevent retry loops
- When one test crashes (SIGTRAP), the entire process dies and all tests report "failed" at 0.000s — only one test is at fault
- The script prints the `.xcresult` path — use it with: `xcrun xcresulttool get test-results summary --path <.xcresult>`
- For unexpected issues, bare `xcodebuild` commands are still acceptable for full control over flags:
  ```bash
  xcodebuild -project AssetFlow.xcodeproj -scheme AssetFlow test -destination 'platform=macOS'
  ```
