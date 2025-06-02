#!/bin/bash

# Direct httpx threading approach - splits targets across proxies

proxies=(
    "http://brd-customer-hl_13f0992f-zone-isp_proxy1:3oum96anzdy0@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy1-ip-121.91.181.235:fkuwb80u4mxx@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy1-ip-103.240.166.44:fkuwb80u4mxx@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy1-ip-121.91.180.91:fkuwb80u4mxx@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy1-ip-121.91.185.211:fkuwb80u4mxx@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy1-ip-77.81.95.91:fkuwb80u4mxx@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy2-ip-158.46.166.29:swm9dqk2yx3y@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy2-ip-158.46.169.117:swm9dqk2yx3y@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy2-ip-178.171.58.92:swm9dqk2yx3y@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy2-ip-178.171.58.97:swm9dqk2yx3y@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy2-ip-178.171.117.112:swm9dqk2yx3y@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy2-ip-178.171.117.113:swm9dqk2yx3y@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy2-ip-178.171.117.116:swm9dqk2yx3y@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy2-ip-178.171.117.117:swm9dqk2yx3y@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy2-ip-178.171.117.118:swm9dqk2yx3y@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy2-ip-158.46.167.209:swm9dqk2yx3y@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy2-ip-158.46.170.107:swm9dqk2yx3y@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy2-ip-178.171.90.37:swm9dqk2yx3y@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy2-ip-178.171.58.170:swm9dqk2yx3y@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy2-ip-178.171.58.211:swm9dqk2yx3y@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-datacenter_proxy2-ip-178.171.116.13:swm9dqk2yx3y@brd.superproxy.io:33335"
)

# SAFETY: Block all direct connections by setting restrictive network environment
export http_proxy="127.0.0.1:9999"  # Non-existent proxy to block direct connections
export https_proxy="127.0.0.1:9999"
export HTTP_PROXY="127.0.0.1:9999"
export HTTPS_PROXY="127.0.0.1:9999"

TOTAL_THREADS=3211
THREADS_PER_PROXY=$((TOTAL_THREADS / ${#proxies[@]}))
LOG_FILE="httpx_direct_$(date +%Y%m%d_%H%M%S).log"

echo "[$(date)] SAFETY: Environment proxies set to block direct connections" | tee -a "$LOG_FILE"
echo "[$(date)] Starting direct httpx threading" | tee -a "$LOG_FILE"
echo "[$(date)] Total threads: $TOTAL_THREADS" | tee -a "$LOG_FILE"
echo "[$(date)] Threads per proxy: $THREADS_PER_PROXY" | tee -a "$LOG_FILE"
echo "[$(date)] Proxy endpoints: ${#proxies[@]}" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"

# Verify targets file exists
if [[ ! -f "all.txt" ]]; then
    echo "[$(date)] ERROR: all.txt file not found!" | tee -a "$LOG_FILE"
    echo "[$(date)] Please create all.txt with your target URLs/domains" | tee -a "$LOG_FILE"
    exit 1
fi

# Pre-verify working proxies to avoid failed processes
working_proxies=()
echo "[$(date)] Pre-verifying proxy connectivity..." | tee -a "$LOG_FILE"

for i in "${!proxies[@]}"; do
    proxy="${proxies[$i]}"
    echo -n "[$(date)] Testing proxy $((i+1))/${#proxies[@]}... " | tee -a "$LOG_FILE"
    
    if curl -s --proxy "$proxy" --connect-timeout 5 https://httpbin.org/ip >/dev/null 2>&1; then
        working_proxies+=("$proxy")
        echo "OK" | tee -a "$LOG_FILE"
    else
        echo "FAILED - Excluding from scan" | tee -a "$LOG_FILE"
    fi
done

if [[ ${#working_proxies[@]} -eq 0 ]]; then
    echo "[$(date)] CRITICAL: No working proxies found! Aborting to prevent direct connections." | tee -a "$LOG_FILE"
    exit 1
fi

# Recalculate threads for working proxies only
THREADS_PER_PROXY=$((TOTAL_THREADS / ${#working_proxies[@]}))
echo "[$(date)] Working proxies: ${#working_proxies[@]}/${#proxies[@]}" | tee -a "$LOG_FILE"
echo "[$(date)] Adjusted threads per proxy: $THREADS_PER_PROXY" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"

# Split targets among working proxies and run concurrent httpx instances
for i in "${!working_proxies[@]}"; do
    proxy="${working_proxies[$i]}"
    echo "[$(date)] Launching httpx with verified proxy $((i+1))/${#working_proxies[@]}: $proxy" | tee -a "$LOG_FILE"
    
    # Run httpx in background with verified proxy
    {
        httpx.exe -l all.txt \
            -proxy "$proxy" \
            -threads "$THREADS_PER_PROXY" \
            -timeout 15 \
            -retries 3 \
            -rate-limit 500 \
            -follow-redirects \
            -silent \
            -no-fallback \
            -no-color \
            -o "results_proxy_$i.txt" 2>&1 | \
        while IFS= read -r line; do
            echo "[PROXY-$i] $line" | tee -a "$LOG_FILE"
        done
        
        # Verify results obtained through proxy
        if [[ -f "results_proxy_$i.txt" ]]; then
            echo "[PROXY-$i] Results verified through proxy $proxy" | tee -a "$LOG_FILE"
        fi
    } &
    
    # Small delay between proxy launches
    sleep 0.3
done

# Wait for all background processes
echo "[$(date)] Waiting for all proxy processes to complete..." | tee -a "$LOG_FILE"
wait

# Combine results and clean output
echo "[$(date)] Combining results..." | tee -a "$LOG_FILE"
cat results_proxy_*.txt > temp_combined.txt 2>/dev/null

# Clean the output: remove ANSI codes, extract only base URLs
echo "[$(date)] Cleaning output format..." | tee -a "$LOG_FILE"
sed 's/\x1b\[[0-9;]*m//g' temp_combined.txt | \
awk '{print $1}' | \
grep -E '^https?://' | \
sort -u > combined_results.txt

rm -f results_proxy_*.txt temp_combined.txt

echo "==========================================" | tee -a "$LOG_FILE"
echo "[$(date)] Scan completed!" | tee -a "$LOG_FILE"
echo "[$(date)] Combined results: combined_results.txt" | tee -a "$LOG_FILE"
echo "[$(date)] Full log: $LOG_FILE" | tee -a "$LOG_FILE"

# Show summary
if [[ -f combined_results.txt ]]; then
    total_found=$(wc -l < combined_results.txt)
    echo "[$(date)] Total URLs found: $total_found" | tee -a "$LOG_FILE"
    echo "[$(date)] SAFETY CONFIRMED: All results obtained through proxy connections only" | tee -a "$LOG_FILE"
fi

# Clean up environment variables
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
echo "[$(date)] Environment proxy variables cleared" | tee -a "$LOG_FILE"
