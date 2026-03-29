---
name: reverse-engineering
description: Reverse engineer and debug binaries using Ghidra (static analysis, decompilation) and GDB (live debugging of running processes). Use when the user wants to analyze binaries, decompile functions, debug running processes, set breakpoints, or inspect memory.
---

# Reverse Engineering & Debugging Skill

Use Ghidra for static analysis/decompilation and GDB for live debugging of running processes.

All commands use `nix shell` to get the tools without installing them globally.

## Ghidra Headless Analysis

Use `ghidra-analyzeHeadless` for static analysis without the GUI.

### Import and analyze a binary

```bash
nix shell nixpkgs#ghidra -c ghidra-analyzeHeadless /tmp/ghidra_projects MyProject \
  -import /path/to/binary -overwrite

# With specific processor (e.g., ARM, MIPS)
nix shell nixpkgs#ghidra -c ghidra-analyzeHeadless /tmp/ghidra_projects MyProject \
  -import /path/to/binary -processor x86:LE:64:default -overwrite
```

### Run analysis scripts

Ghidra ships with many built-in scripts. Use `-postScript` to run them after analysis.

```bash
# Decompile all functions
nix shell nixpkgs#ghidra -c ghidra-analyzeHeadless /tmp/ghidra_projects MyProject \
  -process binary_name -postScript DecompileAllFunctions.java \
  -noanalysis -readOnly -scriptlog /dev/stdout 2>/dev/null

# List all functions
nix shell nixpkgs#ghidra -c ghidra-analyzeHeadless /tmp/ghidra_projects MyProject \
  -process binary_name -postScript ListFunctions.java \
  -noanalysis -readOnly -scriptlog /dev/stdout 2>/dev/null
```

### Custom Ghidra scripts (Java)

Write a custom script to extract specific information. Save as `.java` and pass with `-postScript`:

```java
// SaveTo: /tmp/ghidra_scripts/DecompileFunction.java
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.listing.*;

public class DecompileFunction extends GhidraScript {
    @Override
    public void run() throws Exception {
        String targetName = getScriptArgs()[0];
        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        FunctionManager fm = currentProgram.getFunctionManager();
        for (Function f : fm.getFunctions(true)) {
            if (f.getName().contains(targetName)) {
                DecompileResults res = decomp.decompileFunction(f, 30, monitor);
                if (res.decompileCompleted()) {
                    println("=== " + f.getName() + " at " + f.getEntryPoint() + " ===");
                    println(res.getDecompiledFunction().getC());
                }
            }
        }
        decomp.dispose();
    }
}
```

```bash
nix shell nixpkgs#ghidra -c ghidra-analyzeHeadless /tmp/ghidra_projects MyProject \
  -process binary_name \
  -postScript /tmp/ghidra_scripts/DecompileFunction.java "main" \
  -scriptPath /tmp/ghidra_scripts -noanalysis -readOnly \
  -scriptlog /dev/stdout 2>/dev/null
```

### Workflow: Analyze an unknown binary

1. Import: `nix shell nixpkgs#ghidra -c ghidra-analyzeHeadless /tmp/ghidra_projects Proj -import /path/to/binary -overwrite`
2. List functions to find interesting targets
3. Decompile specific functions of interest
4. Look for strings, cross-references, and data structures

## GDB Live Debugging

Use GDB to attach to running processes, set breakpoints, and inspect state.

### Attach to a running process

```bash
# By PID
sudo nix shell nixpkgs#gdb -c gdb -batch -p <PID> -ex "bt"

# By name (find PID first)
nix shell nixpkgs#gdb -c gdb -batch -p $(pidof process_name) -ex "bt"
```

### Non-interactive GDB commands

Use `-batch` and `-ex` for scripted debugging:

```bash
# Get backtrace of a running process
sudo nix shell nixpkgs#gdb -c gdb -batch -p <PID> -ex "thread apply all bt"

# Print a variable
sudo nix shell nixpkgs#gdb -c gdb -batch -p <PID> -ex "print some_global_var"

# Dump memory region
sudo nix shell nixpkgs#gdb -c gdb -batch -p <PID> -ex "x/100x 0x7fff12345678"

# List all threads
sudo nix shell nixpkgs#gdb -c gdb -batch -p <PID> -ex "info threads"

# Show loaded shared libraries
sudo nix shell nixpkgs#gdb -c gdb -batch -p <PID> -ex "info sharedlibrary"

# Get register state
sudo nix shell nixpkgs#gdb -c gdb -batch -p <PID> -ex "info registers"

# Set breakpoint and continue until hit
sudo nix shell nixpkgs#gdb -c gdb -batch -p <PID> \
  -ex "break function_name" \
  -ex "continue" \
  -ex "bt" \
  -ex "info locals"

# Multiple commands
sudo nix shell nixpkgs#gdb -c gdb -batch -p <PID> \
  -ex "info threads" \
  -ex "thread apply all bt" \
  -ex "info registers"
```

### GDB with binary (not attached)

```bash
# Run with arguments
nix shell nixpkgs#gdb -c gdb -batch -ex "run" -ex "bt" --args ./binary arg1 arg2

# Run until crash, get backtrace
nix shell nixpkgs#gdb -c gdb -batch -ex "run" -ex "bt full" -ex "info registers" --args ./binary

# Set breakpoint before running
nix shell nixpkgs#gdb -c gdb -batch \
  -ex "break main" \
  -ex "run" \
  -ex "step 10" \
  -ex "info locals" \
  -ex "bt" \
  --args ./binary
```

### GDB Python scripting

For complex analysis, use GDB's Python API:

```bash
sudo nix shell nixpkgs#gdb -c gdb -batch -p <PID> -ex "python
import gdb
for thread in gdb.inferiors()[0].threads():
    thread.switch()
    frame = gdb.newest_frame()
    print(f'Thread {thread.num}: {frame.name()} at {frame.pc():#x}')
"
```

### Workflow: Debug a running process

1. Find the process: `ps aux | grep process_name` or `pidof process_name`
2. Get overview: `sudo nix shell nixpkgs#gdb -c gdb -batch -p <PID> -ex "info threads" -ex "thread apply all bt"`
3. Check specific state: inspect variables, registers, memory
4. Set breakpoints if needed for dynamic analysis
5. Combine with Ghidra: decompile the binary to understand what functions do, then use GDB to observe runtime behavior

## Combining Ghidra + GDB

1. Find the binary path: `readlink -f /proc/<PID>/exe`
2. Import into Ghidra for static analysis: understand the code structure
3. Use GDB to observe runtime behavior: set breakpoints at interesting functions found in Ghidra
4. Cross-reference: Ghidra gives you function names and decompiled code, GDB shows you actual runtime values

## Tips

- Ghidra headless output goes to scriptlog; use `-scriptlog /dev/stdout` to capture it
- Use `-noanalysis -readOnly` when running scripts on already-analyzed projects
- GDB `-batch` mode is essential for non-interactive use — it runs commands and exits
- `sudo` is typically needed for GDB to attach to processes you don't own
- Check `/proc/sys/kernel/yama/ptrace_scope` if attach fails (set to 0 for debugging)
