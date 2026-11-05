setup:
	@docker build  --progress=plain -t lhc-detoxify:latest .

up: PORT = 8080
up:
	@docker run --rm -p $(PORT):80 --name detoxify detoxify:latest
