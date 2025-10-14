run: build
	nix-shell -p python3 --run 'python3 -m http.server 8000'

build:
	purs-nix bundle

.PHONY: build run
