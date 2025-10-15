# Lux MCP Configuration for Flora

Add this to Flora's CLAUDE.md:

```markdown
## Lux MCP Integration

Flora project has Lux MCP configured with database `lux_flora` for persistent memory.

### Available Lux Tools

#### Quick Reference
- **`confer`** - Consult GPT-5/O3/Claude for specialized reasoning
- **`traced_reasoning`** - Multi-step reasoning with metacognitive monitoring  
- **`biased_reasoning`** - Reasoning with automatic bias detection
- **`planner`** - Sequential planning with Flora codebase awareness

### Flora-Specific Usage

**Analyzing Flora's EVM Implementation:**
```json
{
  "tool": "confer",
  "arguments": {
    "message": "Analyze Flora's EVM compatibility layer for potential issues",
    "file_paths": [
      "/app/ante/cosmos_handler.go",
      "/app/decorators/evm_decorator.go"
    ],
    "model": "gpt-5"
  }
}
```

**Planning Flora Features:**
```json
{
  "tool": "planner",
  "arguments": {
    "step": "Implement new IBC cross-chain messaging for Flora",
    "step_number": 1,
    "total_steps": 6,
    "next_step_required": true,
    "auto_discover_files": true
  }
}
```

**Checking Flora Design Decisions:**
```json
{
  "tool": "biased_reasoning",
  "arguments": {
    "query": "Evaluate Flora's consensus mechanism choice for potential centralization biases"
  }
}
```

### Memory System (Active for Flora)

Flora's Lux instance uses PostgreSQL database `lux_flora` for persistent memory.

**Store Flora decisions:**
```json
{
  "tool": "memory_store",
  "arguments": {
    "kind": "decision",
    "content": "Chose Tendermint consensus for Flora due to fast finality requirements",
    "tags": ["flora", "consensus", "architecture"]
  }
}
```

**Search Flora memory:**
```json
{
  "tool": "memory_search",
  "arguments": {
    "query": "flora consensus decisions",
    "mode": "hybrid"
  }
}
```

### Configuration
- Database: `lux_flora` 
- Models: GPT-5 (default), O3-pro (deep reasoning), O4-mini (fast checks)
- Memory: Enabled with pgvector for semantic search

### Best Practices for Flora

1. **Code Analysis**: Always include relevant Go files in `file_paths`
2. **IBC Planning**: Use `planner` for cross-chain feature design
3. **EVM Compatibility**: Use `biased_reasoning` to check for Ethereum assumptions
4. **Architecture Decisions**: Store in memory with `memory_store`
5. **Testing**: Consult O3 for comprehensive test strategy
```