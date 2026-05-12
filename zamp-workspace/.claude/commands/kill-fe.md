# kill-fe

Kill all stale frontend dev server processes, clear Next.js and Turbo caches, and print a clean-slate summary.

```bash
echo "=== Killing frontend processes ==="

# Kill anything on port 2000 (Next.js dev)
pid=$(netstat -tlnp 2>/dev/null | awk '/:2000 / {split($7,a,"/"); print a[1]}')
if [ -n "$pid" ]; then
  kill -9 $pid 2>/dev/null && echo "Killed PID $pid on :2000"
else
  echo "Port 2000: already free"
fi

# Kill any orphaned next-server or turbo processes for this repo
pids=$(ps aux 2>/dev/null | grep -E '(next-server|turbo run dev)' | grep -v grep | awk '{print $2}')
if [ -n "$pids" ]; then
  echo "$pids" | xargs kill -9 2>/dev/null
  echo "Killed orphan PIDs: $pids"
else
  echo "No orphaned next-server/turbo processes found"
fi

echo ""
echo "=== Clearing caches ==="

FE=/home/coder/zamp/services/application-platform-frontend

# Next.js build cache
if [ -d "$FE/apps/application-dashboard/.next" ]; then
  rm -rf "$FE/apps/application-dashboard/.next"
  echo "Cleared .next/"
fi

# Turbo cache
if [ -d "$FE/.turbo" ]; then
  rm -rf "$FE/.turbo"
  echo "Cleared .turbo/"
fi

# Node module caches (.cache dirs)
find "$FE" -maxdepth 4 -name ".cache" -type d 2>/dev/null | while read d; do
  rm -rf "$d"
  echo "Cleared $d"
done

echo ""
echo "=== Port check ==="
netstat -tlnp 2>/dev/null | grep ':2000' && echo "WARNING: port 2000 still in use!" || echo "Port 2000: free"

echo ""
echo "Clean slate. Run 'make dev' or 'npm run dev-coder' to restart."
```
