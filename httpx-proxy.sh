#!/bin/bash

# Direct httpx threading approach - splits targets across proxies
proxies=(
    "http://brd-customer-hl_13f0992f-zone-isp_proxy1:3oum96anzdy0@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy1-ip-121.91.181.235:fkuwb80u4mxx@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy1-ip-103.240.166.44:fkuwb80u4mxx@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy1-ip-121.91.180.91:fkuwb80u4mxx@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy1-ip-121.91.185.211:fkuwb80u4mxx@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy1-ip-77.81.95.91:fkuwb80u4mxx@brd.superproxy.io:33335"
)

TOTAL_THREADS=3211
THREADS_PER_PROXY=$((TOTAL_THREADS / ${#proxies[@]}))
LOG_FILE="httpx_direct_$(date +%Y%m%d_%H%M%S).log"

echo "[$(date)] Starting direct httpx threading" | tee -a "$LOG_FILE"
echo "[$(date)] Total threads: $TOTAL_THREADS" | tee -a "$LOG_FILE"
echo "[$(date)] Threads per proxy: $THREADS_PER_PROXY" | tee -a "$LOG_FILE"
echo "[$(date)] Proxy endpoints: ${#proxies[@]}" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"

# Split targets among proxies and run concurrent httpx instances
for i in "${!proxies[@]}"; do
    proxy="${proxies[$i]}"
    echo "[$(date)] Launching httpx with proxy $((i+1))/${#proxies[@]}: $proxy" | tee -a "$LOG_FILE"
    
    # Run httpx in background with specific proxy
    {
        httpx.exe -l targets.txt \
            -proxy "$proxy" \
            -threads "$THREADS_PER_PROXY" \
            -timeout 15 \
            -retries 3 \
            -rate-limit 500 \
            -follow-redirects \
            -silent \
            -o "results_proxy_$i.txt" 2>&1 | \
        while IFS= read -r line; do
            echo "[PROXY-$i] $line" | tee -a "$LOG_FILE"
        done
    } &
    
    # Small delay between proxy launches
    sleep 0.3
done

# Wait for all background processes
echo "[$(date)] Waiting for all proxy processes to complete..." | tee -a "$LOG_FILE"
wait

# Combine results
echo "[$(date)] Combining results..." | tee -a "$LOG_FILE"
cat results_proxy_*.txt > combined_results.txt 2>/dev/null
rm -f results_proxy_*.txt

echo "==========================================" | tee -a "$LOG_FILE"
echo "[$(date)] Scan completed!" | tee -a "$LOG_FILE"Add commentMore actions
echo "[$(date)] Combined results: combined_results.txt" | tee -a "$LOG_FILE"
echo "[$(date)] Full log: $LOG_FILE" | tee -a "$LOG_FILE"

# Show summary
if [[ -f combined_results.txt ]]; then
    total_found=$(wc -l < combined_results.txt)
    echo "[$(date)] Total URLs found: $total_found" | tee -a "$LOG_FILE"
fi
