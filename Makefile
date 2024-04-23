.PHONY: serve
serve:
	go run main.go 

.PHONY: goodreq
goodreq:
	curl -v localhost:8090

.PHONY: badreq
badreq:
	curl -v -XPOST localhost:8090