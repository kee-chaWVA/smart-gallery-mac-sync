LABEL = com.kee.smart-gallery.mac-sync
PLIST = $(LABEL).plist
AGENT = $(HOME)/Library/LaunchAgents/$(PLIST)
DOMAIN = gui/$(shell id -u)
RUNNER = bin/photosync-runner

# Only recompiles when the Swift source changed. Each rebuild produces a new program that
# needs Full Disk Access granted again, so avoid rebuilding without a reason.
$(RUNNER): runner/photosync-runner.swift
	mkdir -p bin
	swiftc -O runner/photosync-runner.swift -o $(RUNNER)

build: $(RUNNER)

install: $(RUNNER)
	mkdir -p logs
	cp $(PLIST) $(AGENT)
	-launchctl bootout $(DOMAIN)/$(LABEL) 2>/dev/null
	launchctl bootstrap $(DOMAIN) $(AGENT)

uninstall:
	-launchctl bootout $(DOMAIN)/$(LABEL)
	rm -f $(AGENT)

status:
	launchctl print $(DOMAIN)/$(LABEL) | grep -E "state =|runs =|last exit code"

logs:
	tail -f logs/sync.log

.PHONY: build install uninstall status logs
