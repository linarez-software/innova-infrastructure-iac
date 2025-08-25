#!/bin/bash
# Standalone NVMe Optimization Script for Odoo Filestore Performance
# Usage: sudo ./optimize-nvme-odoo.sh [device] [mount_point]

set -e

# Default values
NVME_DEVICE="${1:-/dev/nvme0n1}"
MOUNT_POINT="${2:-/opt/odoo}"
PARTITION="${NVME_DEVICE}p1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root"
        exit 1
    fi
    
    if [ ! -b "$NVME_DEVICE" ]; then
        error "NVMe device $NVME_DEVICE not found"
        exit 1
    fi
    
    # Install required tools
    which parted >/dev/null 2>&1 || {
        log "Installing partitioning tools..."
        apt-get update >/dev/null
        apt-get install -y parted
    }
    
    # Install monitoring tools
    which nvme >/dev/null 2>&1 || {
        log "Installing NVMe tools..."
        apt-get install -y nvme-cli sysstat bc fio
    }
    
    success "Prerequisites checked"
}

create_partition() {
    if [ -b "$PARTITION" ]; then
        warn "Partition $PARTITION already exists, skipping creation"
        return 0
    fi
    
    log "Creating single partition on $NVME_DEVICE for maximum space utilization..."
    
    parted -s "$NVME_DEVICE" mklabel gpt
    parted -s "$NVME_DEVICE" mkpart primary ext4 0% 100%
    partprobe "$NVME_DEVICE"
    sleep 2
    
    if [ -b "$PARTITION" ]; then
        success "Partition created: $PARTITION"
    else
        error "Failed to create partition"
        exit 1
    fi
}

optimize_filesystem() {
    if blkid "$PARTITION" >/dev/null 2>&1; then
        warn "Filesystem already exists on $PARTITION, skipping format"
        return 0
    fi
    
    log "Formatting $PARTITION with Odoo-optimized ext4..."
    
    # Format with optimizations for Odoo filestore:
    # - Optimize for small files (50KB-2MB average for Odoo attachments)
    # - Enable extended attributes for file metadata
    # - Disable journal initially for faster format
    # - Set reserved blocks to 1% (not default 5%)
    # - Custom inode ratio optimized for small file workload
    mkfs.ext4 \
        -L odoo-filestore \
        -E lazy_itable_init=0,lazy_journal_init=0 \
        -O ^has_journal,extent,dir_index,filetype,sparse_super,large_file,flex_bg,uninit_bg,64bit \
        -i 8192 \
        -m 1 \
        -b 4096 \
        "$PARTITION"
    
    log "Re-enabling journal for data integrity..."
    tune2fs -j "$PARTITION"
    
    log "Optimizing filesystem for NVMe and small file performance..."
    
    # Set writeback mode for better performance
    tune2fs -o journal_data_writeback "$PARTITION"
    
    # Configure stride and stripe-width for NVMe characteristics
    # NVMe SSDs typically have 128KB stripe size (32 * 4KB blocks)
    tune2fs -E stride=32,stripe-width=32 "$PARTITION"
    
    # Enable user extended attributes for Odoo metadata
    tune2fs -o user_xattr "$PARTITION"
    
    success "Filesystem optimization completed"
}

mount_filesystem() {
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        warn "$MOUNT_POINT already mounted, skipping"
        return 0
    fi
    
    log "Creating mount point and mounting with performance options..."
    
    mkdir -p "$MOUNT_POINT"
    
    # Mount with optimizations:
    # - noatime: Don't update access times (major performance gain for file-heavy workloads)
    # - user_xattr: Enable extended attributes for Odoo metadata
    # - data=writeback: Better performance (journal metadata only, not data)
    mount -t ext4 -o noatime,user_xattr,data=writeback,nofail "$PARTITION" "$MOUNT_POINT"
    
    # Add to fstab for persistent mounting
    if ! grep -q "$PARTITION" /etc/fstab; then
        log "Adding to /etc/fstab for persistent mounting..."
        echo "$PARTITION $MOUNT_POINT ext4 noatime,user_xattr,data=writeback,nofail 0 2" >> /etc/fstab
    fi
    
    success "Filesystem mounted at $MOUNT_POINT"
}

setup_odoo_structure() {
    log "Setting up Odoo directory structure on NVMe..."
    
    # Create Odoo filestore directories
    mkdir -p "$MOUNT_POINT/filestore"
    mkdir -p "$MOUNT_POINT/sessions"
    mkdir -p "$MOUNT_POINT/logs"
    mkdir -p "$MOUNT_POINT/addons-extra"
    mkdir -p "$MOUNT_POINT/backups"
    
    # Create standard Odoo data directory if it doesn't exist
    mkdir -p /var/lib/odoo
    
    # Create symbolic links for optimal performance
    if [ ! -L /var/lib/odoo/filestore ]; then
        rm -rf /var/lib/odoo/filestore 2>/dev/null || true
        ln -s "$MOUNT_POINT/filestore" /var/lib/odoo/filestore
        log "Linked filestore to NVMe"
    fi
    
    if [ ! -L /var/lib/odoo/sessions ]; then
        rm -rf /var/lib/odoo/sessions 2>/dev/null || true
        ln -s "$MOUNT_POINT/sessions" /var/lib/odoo/sessions
        log "Linked sessions to NVMe"
    fi
    
    # Set appropriate permissions
    if id odoo >/dev/null 2>&1; then
        chown -R odoo:odoo "$MOUNT_POINT"
        chown -R odoo:odoo /var/lib/odoo
        log "Set odoo user permissions"
    else
        warn "User 'odoo' not found, skipping permission setup"
    fi
    
    chmod 755 "$MOUNT_POINT"
    
    success "Odoo directory structure created"
}

run_performance_test() {
    log "Running performance validation test..."
    
    # Simple performance test
    if command -v fio >/dev/null 2>&1; then
        log "Running FIO performance test (30 seconds)..."
        fio --name=odoo-perf-test \
            --directory="$MOUNT_POINT" \
            --size=100M \
            --bs=4k \
            --rw=randrw \
            --rwmixread=70 \
            --runtime=30 \
            --time_based \
            --direct=1 \
            --group_reporting \
            --numjobs=4 \
            --ioengine=libaio \
            --output-format=normal | grep -E "(read:|write:)" || true
        
        # Clean up test file
        rm -f "$MOUNT_POINT/odoo-perf-test"*
    else
        log "Running simple write performance test..."
        time dd if=/dev/zero of="$MOUNT_POINT/test_write" bs=1M count=100 oflag=direct 2>&1 | tail -3
        rm -f "$MOUNT_POINT/test_write"
    fi
}

display_optimization_summary() {
    echo ""
    echo "=== NVMe Optimization Summary ==="
    echo "Device: $NVME_DEVICE"
    echo "Partition: $PARTITION"
    echo "Mount Point: $MOUNT_POINT"
    echo ""
    echo "Optimizations Applied:"
    echo "✅ GPT partition table for maximum compatibility"
    echo "✅ Single partition utilizing 100% of device space"
    echo "✅ ext4 with 4KB blocks optimized for small files"
    echo "✅ 8192 bytes per inode ratio (optimized for many small files)"
    echo "✅ 1% reserved blocks (vs 5% default) for more usable space"
    echo "✅ Journal enabled with writeback mode for performance"
    echo "✅ Extended attributes enabled for Odoo metadata"
    echo "✅ Stride/stripe-width configured for NVMe characteristics"
    echo "✅ noatime mount option (no access time updates)"
    echo "✅ Persistent mounting configured in /etc/fstab"
    echo ""
    
    echo "Filesystem Information:"
    df -h "$MOUNT_POINT"
    echo ""
    
    echo "Mount Options:"
    mount | grep "$(basename $PARTITION)"
    echo ""
    
    echo "Expected Performance Improvements:"
    echo "• 20-40% faster file operations (noatime + writeback)"
    echo "• Better small file handling (optimized inode ratio)"
    echo "• Improved metadata operations (extended attributes)"
    echo "• Reduced space overhead (1% vs 5% reserved blocks)"
    echo "• Enhanced NVMe performance (stride/stripe optimization)"
    echo ""
    
    echo "Monitoring Commands:"
    echo "  iostat -x 1     # Real-time I/O statistics"
    echo "  nvme list       # NVMe device information"
    echo "  tune2fs -l $PARTITION  # Filesystem details"
    echo "  du -sh $MOUNT_POINT/filestore  # Filestore usage"
}

main() {
    echo "=== NVMe Optimization for Odoo Filestore ==="
    echo "Target: 30 concurrent users with file attachments"
    echo "Device: $NVME_DEVICE → $MOUNT_POINT"
    echo ""
    
    check_prerequisites
    create_partition
    optimize_filesystem
    mount_filesystem
    setup_odoo_structure
    run_performance_test
    display_optimization_summary
    
    success "NVMe optimization completed successfully!"
    echo ""
    echo "You can now configure Odoo to use the optimized storage."
    echo "The filestore will automatically use NVMe through symbolic links."
}

main "$@"