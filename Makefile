# Waynux Linux Distribution Makefile

WAYNUX_ROOT ?= /mnt/waynux
WAYNUX_SOURCES ?= /sources
WAYNUX_LOGS ?= /logs
ISO_OUTPUT ?= waynux.iso

.PHONY: all bootstrap iso chroot clean help

all: help

bootstrap:
	@echo "==> Starting base system bootstrap build..."
	WAYNUX_ROOT="$(WAYNUX_ROOT)" WAYNUX_SOURCES="$(WAYNUX_SOURCES)" WAYNUX_LOGS="$(WAYNUX_LOGS)" sh scripts/bootstrap.sh
iso:
	@echo "==> Building bootable ISO image..."
	WAYNUX_ROOT="$(WAYNUX_ROOT)" ISO_OUTPUT="$(ISO_OUTPUT)" sh scripts/build-iso.sh

chroot:
	@echo "==> Entering Waynux environment..."
	WAYNUX_ROOT="$(WAYNUX_ROOT)" sh scripts/chroot-enter.sh
clean:
	@echo "==> Cleaning temporary build files..."
	rm -rf /tmp/waynux-build /tmp/waynux-iso
	rm -f $(ISO_OUTPUT)
	@echo "==> Cleaned."

help:
	@echo "Waynux Build System"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Available targets:"
	@echo "  make bootstrap   - Build base system (LFS-style) using bwrap"
	@echo "  make iso         - Build bootable Live ISO (waynux.iso)"
	@echo "  make chroot      - Enter isolated system environment"
	@echo "  make clean       - Clean temporary build directories"
	@echo "  make help        - Show this help message"
	@echo ""
	@echo "Environment variables:"
	@echo "  WAYNUX_ROOT      - Target root directory (default: /mnt/waynux)"
	@echo "  WAYNUX_SOURCES   - Sources cache directory (default: /sources)"
	@echo "  WAYNUX_LOGS      - Logs directory (default: /logs)"
	@echo "  ISO_OUTPUT       - Output ISO path (default: waynux.iso)"

