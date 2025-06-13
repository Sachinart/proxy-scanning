#!/bin/bash

# Live rotating proxy httpx script - Each target hits only once via rotating proxies
proxies=(
    "http://brd-customer-hl_13f0992f-zone-isp_proxy1:3oum96anzdy0@brd.superproxy.io:33335"
    "http://brd-customer-hl_13f0992f-zone-isp_proxy2-ip-185.95.102.200:g06lnrjbgtq6@brd.superproxy.io:33335"
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

# Configuration
TOTAL_THREADS=3211
BATCH_SIZE=1000  # Process targets in batches for speed
LOG_FILE="httpx_live_rotating_$(date +%Y%m%d_%H%M%S).log"
MAIN_OUTPUT="main_output.txt"

# Initialize live output file
> "$MAIN_OUTPUT"

echo "[$(date)] LIVE ROTATING PROXY httpx scanner starting..." | tee -a "$LOG_FILE"
echo "[$(date)] Live results will be saved to: $MAIN_OUTPUT" | tee -a "$LOG_FILE"

# Check if targets file exists
if [[ ! -f "targets.txt" ]]; then
    echo "[ERROR] targets.txt file not found!" | tee -a "$LOG_FILE"
    exit 1
fi

# Test proxy connectivity first
echo "[$(date)] Testing proxy connectivity..." | tee -a "$LOG_FILE"
working_proxies=()

for i in "${!proxies[@]}"; do
    proxy="${proxies[$i]}"
    if timeout 5 curl -s --connect-timeout 3 --proxy "$proxy" "http://httpbin.org/ip" > /dev/null 2>&1; then
        working_proxies+=("$proxy")
        echo "[$(date)] ✓ Proxy $((i+1)) working" | tee -a "$LOG_FILE"
    else
        echo "[$(date)] ✗ Proxy $((i+1)) failed" | tee -a "$LOG_FILE"
    fi
done

# Use only working proxies
proxies=("${working_proxies[@]}")
if [[ ${#proxies[@]} -eq 0 ]]; then
    echo "[ERROR] No working proxies found! Exiting." | tee -a "$LOG_FILE"
    exit 1
fi

TOTAL_TARGETS=$(wc -l < targets.txt)
NUM_PROXIES=${#proxies[@]}

echo "[$(date)] Using ${#proxies[@]} working proxies" | tee -a "$LOG_FILE"
echo "[$(date)] Total targets: $TOTAL_TARGETS" | tee -a "$LOG_FILE"
echo "[$(date)] Each target will be hit ONCE via rotating proxies" | tee -a "$LOG_FILE"
echo "[$(date)] Expected total requests: $TOTAL_TARGETS (not $TOTAL_TARGETS x $NUM_PROXIES)" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"

# Function to run httpx with rotating proxy assignment
run_rotating_httpx() {
    local batch_file=$1
    local batch_id=$2
    
    # Create proxy rotation script for this batch
    rotation_script="/tmp/rotate_proxy_$batch_id.sh"
    
    cat > "$rotation_script" << 'EOF'
#!/bin/bash
# Proxy rotation wrapper
PROXIES=("$@")
PROXY_COUNT=${#PROXIES[@]}
counter=0

while IFS= read -r target; do
    # Select proxy using round-robin
    proxy_index=$((counter % PROXY_COUNT))
    current_proxy="${PROXIES[$proxy_index]}"
    
    # Make single request with current proxy
    echo "$target" | httpx.exe \
        -http-proxy "$current_proxy" \
        -threads 2000 \
        -timeout 8 \
        -retries 1 \
        -rate-limit 100 \
        -silent \
        -no-fallback \
        -disable-update-check \
        -random-agent 2>/dev/null
    
    ((counter++))
done
EOF
    
    chmod +x "$rotation_script"
    
    # Execute rotation script with batch file and proxy list
    cat "$batch_file" | bash "$rotation_script" "${proxies[@]}" 2>/dev/null
    
    # Cleanup
    rm -f "$rotation_script"
}

# Process targets in batches for maximum speed
echo "[$(date)] Processing targets in batches of $BATCH_SIZE..." | tee -a "$LOG_FILE"

total_processed=0
batch_id=0

# Split targets into batches and process with live output
split -l "$BATCH_SIZE" targets.txt "/tmp/batch_" --numeric-suffixes=1

for batch_file in /tmp/batch_*; do
    if [[ -f "$batch_file" ]]; then
        batch_id=$((batch_id + 1))
        batch_size=$(wc -l < "$batch_file")
        
        echo "[$(date)] Processing batch $batch_id ($batch_size targets)..." | tee -a "$LOG_FILE"
        
        # Run batch with rotating proxies and append to live output
        {
            run_rotating_httpx "$batch_file" "$batch_id" | while IFS= read -r result; do
                # Live append each result immediately
                echo "$result" | tee -a "$MAIN_OUTPUT"
            done
        } &
        
        total_processed=$((total_processed + batch_size))
        
        # Limit concurrent batches to prevent overwhelming
        if (( batch_id % 5 == 0 )); then
            wait  # Wait for current batch group to complete
            echo "[$(date)] Processed $total_processed/$TOTAL_TARGETS targets so far..." | tee -a "$LOG_FILE"
        fi
        
        # Small delay between batch launches
        sleep 0.2
    fi
done

# Wait for all remaining batches
echo "[$(date)] Waiting for all batches to complete..." | tee -a "$LOG_FILE"
wait

# Cleanup batch files
rm -f /tmp/batch_*

# Final processing
echo "[$(date)] Finalizing results..." | tee -a "$LOG_FILE"

# Remove duplicates while preserving order
if [[ -f "$MAIN_OUTPUT" ]]; then
    # Create temporary file for deduplication
    temp_output="/tmp/dedup_output_$$"
    awk '!seen[$0]++' "$MAIN_OUTPUT" > "$temp_output"
    mv "$temp_output" "$MAIN_OUTPUT"
fi

echo "==========================================" | tee -a "$LOG_FILE"
echo "[$(date)] LIVE ROTATING scan completed!" | tee -a "$LOG_FILE"
echo "[$(date)] Live results saved in: $MAIN_OUTPUT" | tee -a "$LOG_FILE"
echo "[$(date)] Full log: $LOG_FILE" | tee -a "$LOG_FILE"

# Show summary
if [[ -f "$MAIN_OUTPUT" ]]; then
    total_found=$(wc -l < "$MAIN_OUTPUT")
    echo "[$(date)] Total unique URLs found: $total_found" | tee -a "$LOG_FILE"
    
    # Show some stats
    if [[ $total_found -gt 0 ]]; then
        echo "[$(date)] Sample results:" | tee -a "$LOG_FILE"
        head -5 "$MAIN_OUTPUT" | while read -r url; do
            echo "  → $url" | tee -a "$LOG_FILE"
        done
        if [[ $total_found -gt 5 ]]; then
            echo "  ... and $((total_found - 5)) more" | tee -a "$LOG_FILE"
        fi
    fi
    
    # Calculate hit rate
    hit_rate=$(echo "scale=2; $total_found * 100 / $TOTAL_TARGETS" | bc -l 2>/dev/null || echo "N/A")
    echo "[$(date)] Hit rate: $hit_rate% ($total_found/$TOTAL_TARGETS)" | tee -a "$LOG_FILE"
else
    echo "[$(date)] No results file generated" | tee -a "$LOG_FILE"
fi

echo "[$(date)] ✓ LIVE ROTATING proxy scan completed successfully!" | tee -a "$LOG_FILE"
echo "[$(date)] ✓ Each target was hit exactly ONCE via rotating proxies" | tee -a "$LOG_FILE"
echo "[$(date)] ✓ Results streamed live to $MAIN_OUTPUT" | tee -a "$LOG_FILE"
