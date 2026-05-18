.PHONY: build run install uninstall clean icon release-zip

icon:
	@swift scripts/generate-icon.swift

build:
	@bash scripts/build-app.sh

run: build
	@open dist/myclip.app

install: build
	@pkill -x myclip 2>/dev/null || true
	@rm -rf /Applications/myclip.app
	@cp -R dist/myclip.app /Applications/myclip.app
	@LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister; \
		[ -x $$LSREG ] && $$LSREG -f /Applications/myclip.app >/dev/null 2>&1 || true
	@open -g /Applications/myclip.app
	@echo
	@echo "myclip installed at /Applications/myclip.app."
	@echo "  • Press ⌘⇧C to open the panel."
	@echo "  • The app registers itself as a Login Item; check Settings to opt out."

uninstall:
	@pkill -x myclip 2>/dev/null || true
	@rm -rf /Applications/myclip.app
	@echo "myclip removed."
	@echo "Your history at ~/Library/Application Support/myclip was left in place."
	@echo "Login-item entry will be cleaned up by macOS within a few logins."

release-zip: build
	@cd dist && ditto -c -k --keepParent myclip.app myclip.zip
	@shasum -a 256 dist/myclip.zip

clean:
	@rm -rf .build dist
