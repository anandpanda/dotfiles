# kill-be

Kill all stale pantheon backend processes (uvicorn, temporal workers, tail), clear pyc/__pycache__, and print a clean-slate summary.

```bash
PANTHEON=/home/coder/zamp/services/pantheon

echo "=== Stopping pantheon via Makefile ==="
if [ -f "$PANTHEON/Makefile" ]; then
  make -C "$PANTHEON" dev-clean 2>/dev/null && echo "make dev-clean: OK" || echo "make dev-clean: returned non-zero (may be fine if already stopped)"
else
  echo "Makefile not found at $PANTHEON — skipping make dev-stop"
fi

echo ""
echo "=== Killing orphan backend processes ==="

# uvicorn (API server)
pids=$(ps aux 2>/dev/null | grep -E 'uvicorn pantheon_v2' | grep -v grep | awk '{print $2}')
if [ -n "$pids" ]; then
  echo "$pids" | xargs kill -9 2>/dev/null
  echo "Killed uvicorn PIDs: $pids"
else
  echo "No uvicorn processes found"
fi

# Temporal workers (activity/workflow/high-priority)
pids=$(ps aux 2>/dev/null | grep -E 'pantheon_v2/platform/orchestrator/providers/temporal' | grep -v grep | awk '{print $2}')
if [ -n "$pids" ]; then
  echo "$pids" | xargs kill -9 2>/dev/null
  echo "Killed temporal worker PIDs: $pids"
else
  echo "No temporal worker processes found"
fi

# Stray tail processes for pantheon logs
pids=$(ps aux 2>/dev/null | grep 'tail -f.*pantheon' | grep -v grep | awk '{print $2}')
if [ -n "$pids" ]; then
  echo "$pids" | xargs kill -9 2>/dev/null
  echo "Killed tail PIDs: $pids"
else
  echo "No stray tail processes found"
fi

echo ""
echo "=== Clearing caches ==="

# Remove .pyc files and __pycache__ dirs
find "$PANTHEON" -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null
echo "Cleared __pycache__ dirs"

find "$PANTHEON" -name "*.pyc" -delete 2>/dev/null
echo "Cleared .pyc files"

# Remove .pytest_cache
find "$PANTHEON" -maxdepth 3 -name ".pytest_cache" -type d -exec rm -rf {} + 2>/dev/null
echo "Cleared .pytest_cache dirs"

echo ""
echo "=== Port check (8001) ==="
netstat -tlnp 2>/dev/null | grep ':8001' && echo "WARNING: port 8001 still in use!" || echo "Port 8001: free"

echo ""
echo "Clean slate. Run 'make dev' in $PANTHEON to restart."
```
