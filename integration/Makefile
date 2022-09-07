.PHONY: all

all: schema.json required.json optional.json

schema.json: schema.ts
	@pnpx ts-json-schema-generator -p $< -e all -t Suite --strict-tuples > $@

optional.json: optional.yaml
	@yaml2json $< | jq . > $@

required.json: required.yaml
	@yaml2json $< | jq . > $@
