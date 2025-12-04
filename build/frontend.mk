FRONTEND_DIR ?= $(CURDIR)/frontend

.PHONY: frontend-build frontend-run

frontend-build:
	cd $(FRONTEND_DIR) && purs-nix bundle

run: frontend-build
	cd $(FRONTEND_DIR) && nix-shell -p python3 --run 'python3 -m http.server 8000'
