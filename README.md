# hubot-rightscale

Allows Hubot to query rightscale

See [`src/rightscale.coffee`](src/rightscale.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-rightscale --save`

Then add **hubot-rightscale** to your `external-scripts.json`:

```json
[
  "hubot-rightscale"
]
```

## Sample Interaction

```
user> hubot rightscale me sit1
hubot> blah.blah.sit1.deployment
user> hubot rightscale me deployment blah.blah.sit1.deployment
hubot> Found 'webserver' (xx.xx.xx.xx)
```
