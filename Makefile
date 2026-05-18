.PHONY: build run install uninstall clean icon

icon:
	@swift scripts/generate-icon.swift

build:
	@bash scripts/build-app.sh

run: build
	@open dist/myclip.app

install: build
	@bash scripts/install-launchagent.sh

uninstall:
	@bash scripts/uninstall.sh

clean:
	@rm -rf .build dist
